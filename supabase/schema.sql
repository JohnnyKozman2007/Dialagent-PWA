-- Create USERS table
create table public.users (
    uid uuid primary key references auth.users(id) on delete cascade,
    email text not null,
    role text not null default 'Staff',
    restaurant_name text default '',
    restaurant_id uuid,
    phone text,
    address text,
    cuisine_type text,
    table_count integer,
    onboarding_completed boolean default false,
    two_fa_enabled boolean default false,
    two_fa_secret text,
    created_at timestamptz default now(),
    is_approved boolean default false,
    is_rejected boolean default false,
    dark_mode boolean default false,
    permissions jsonb default '{"canManageStaff": false, "canManageMenu": false, "canManageTables": false, "canViewRevenue": false, "canManageReservations": false, "canViewSettings": false}'::jsonb
);

-- Enable RLS on users
alter table public.users enable row level security;

-- Create INVITES table
create table public.invites (
    id uuid primary key default gen_random_uuid(),
    email text not null,
    role text not null default 'Staff',
    restaurant_id uuid not null,
    used boolean not null default false,
    created_at timestamptz default now(),
    created_by uuid references auth.users(id) on delete set null
);

-- Enable RLS on invites
alter table public.invites enable row level security;

-- Create TASKS table
create table public.tasks (
    id uuid primary key default gen_random_uuid(),
    title text not null,
    description text default '',
    restaurant_id uuid not null,
    assigned_to uuid references auth.users(id) on delete set null,
    assigned_to_name text,
    status text not null default 'pending',
    created_at timestamptz default now(),
    due_date timestamptz,
    synced_to_calendar boolean default false,
    calendar_event_id text
);

-- Enable RLS on tasks
alter table public.tasks enable row level security;

-- Create SHIFTS table
create table public.shifts (
    id uuid primary key default gen_random_uuid(),
    title text not null,
    start_time timestamptz not null,
    end_time timestamptz not null,
    assigned_to uuid references public.users(uid) on delete set null,
    assigned_to_name text default '',
    role text default 'Staff',
    is_available boolean default true,
    created_at timestamptz default now()
);

-- Enable RLS on shifts
alter table public.shifts enable row level security;


------------------
-- Helper Functions for RLS
------------------

-- Safely get the current user's restaurant_id without infinite recursion
create or replace function public.get_auth_user_restaurant_id()
returns uuid security definer as $$
begin
  return (select restaurant_id from public.users where uid = auth.uid());
end;
$$ language plpgsql;

-- Safely get the current user's role without infinite recursion
create or replace function public.get_auth_user_role()
returns text security definer as $$
begin
  return (select role from public.users where uid = auth.uid());
end;
$$ language plpgsql;


------------------
-- RLS Policies
------------------

-- 1. Users policies
create policy "Allow users to read their coworkers / same restaurant users"
on public.users for select
using (
  auth.uid() = uid 
  or restaurant_id = public.get_auth_user_restaurant_id()
);

create policy "Allow users to update their own profile"
on public.users for update
using (auth.uid() = uid)
with check (auth.uid() = uid);

create policy "Allow inserts during signup"
on public.users for insert
with check (auth.uid() = uid);

-- 2. Invites policies
create policy "Allow select invites if same restaurant"
on public.invites for select
using (
  restaurant_id = public.get_auth_user_restaurant_id()
  or email = (select email from auth.users where id = auth.uid())
);

create policy "Allow managers and owners to insert invites"
on public.invites for insert
with check (
  public.get_auth_user_role() in ('Owner', 'Manager')
  and restaurant_id = public.get_auth_user_restaurant_id()
);

create policy "Allow updates/deletes to invites"
on public.invites for all
using (
  public.get_auth_user_role() in ('Owner', 'Manager')
  and restaurant_id = public.get_auth_user_restaurant_id()
);

create policy "Allow email check for verification"
on public.invites for update
using (true);

-- 3. Tasks policies
create policy "Allow read tasks if same restaurant"
on public.tasks for select
using (restaurant_id = public.get_auth_user_restaurant_id());

create policy "Allow create tasks if same restaurant"
on public.tasks for insert
with check (restaurant_id = public.get_auth_user_restaurant_id());

create policy "Allow update/delete tasks if same restaurant"
on public.tasks for all
using (restaurant_id = public.get_auth_user_restaurant_id());

-- 4. Shifts policies
-- Shifts don't have a direct restaurant_id, but we can check if the assigned user shares the same restaurant,
-- or if the shift is available, or if the creator/manager has permissions.
-- Wait, let's look at shifts: we can add restaurant_id to shifts to make RLS extremely clean!
-- In Firestore, shifts were in a global 'shifts' collection. Let's add a restaurant_id to the shifts table as well.
alter table public.shifts add column restaurant_id uuid;

create policy "Allow read shifts if same restaurant"
on public.shifts for select
using (restaurant_id = public.get_auth_user_restaurant_id() or is_available = true);

create policy "Allow insert shifts if manager or owner"
on public.shifts for insert
with check (
  restaurant_id = public.get_auth_user_restaurant_id()
  and public.get_auth_user_role() in ('Owner', 'Manager')
);

create policy "Allow update/delete shifts if manager/owner or assigned to self"
on public.shifts for all
using (
  restaurant_id = public.get_auth_user_restaurant_id()
  and (
    public.get_auth_user_role() in ('Owner', 'Manager')
    or assigned_to = auth.uid()
  )
);


------------------
-- Triggers for Auth Schema Integration
------------------

-- Trigger function to automatically create a public.users row when a new user signs up in auth.users
create or replace function public.handle_new_user()
returns trigger security definer as $$
declare
  is_first_user boolean;
  assigned_role text;
  assigned_restaurant_id uuid;
  assigned_is_approved boolean;
  matched_invite_role text;
  matched_invite_restaurant_id uuid;
begin
  -- Check if any users exist in public.users. If none, this is the Owner.
  select not exists (select 1 from public.users) into is_first_user;
  
  -- Check if there is a pending invite for this email
  select role, restaurant_id into matched_invite_role, matched_invite_restaurant_id
  from public.invites
  where email = new.email and used = false
  limit 1;

  if new.email = 'kozmanjohnny82@gmail.com' then
    assigned_role := 'Admin';
    assigned_restaurant_id := null;
    assigned_is_approved := true;
  elsif matched_invite_restaurant_id is not null then
    assigned_role := matched_invite_role;
    assigned_restaurant_id := matched_invite_restaurant_id;
    assigned_is_approved := true; -- Invited staff are auto-approved
  else
    assigned_role := 'Owner';
    assigned_restaurant_id := new.id; -- Owner's own ID is the initial restaurant ID
    assigned_is_approved := false; -- Owner needs manual approval from backoffice
  end if;

  insert into public.users (uid, email, role, restaurant_id, is_approved)
  values (new.id, new.email, assigned_role, assigned_restaurant_id, assigned_is_approved);

  -- Mark the invite as used if we matched one
  if matched_invite_restaurant_id is not null then
    update public.invites set used = true where email = new.email;
  end if;

  return new;
end;
$$ language plpgsql;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- Create TIMECARDS table for clocking in/out
create table public.timecards (
    id uuid primary key default gen_random_uuid(),
    uid uuid not null references public.users(uid) on delete cascade,
    email text not null,
    restaurant_id uuid not null,
    shift_id uuid references public.shifts(id) on delete set null,
    clock_in_time timestamptz not null default now(),
    clock_out_time timestamptz,
    shift_start_time timestamptz,
    minutes_late integer default 0,
    hours_worked double precision default 0.0,
    created_at timestamptz default now()
);

-- Enable RLS on timecards
alter table public.timecards enable row level security;

-- RLS Policies for timecards
create policy "Allow read timecards if same restaurant"
on public.timecards for select
using (restaurant_id = public.get_auth_user_restaurant_id());

create policy "Allow insert own timecards"
on public.timecards for insert
with check (
  uid = auth.uid()
  and restaurant_id = public.get_auth_user_restaurant_id()
);

create policy "Allow update own timecards"
on public.timecards for update
using (
  (uid = auth.uid() or public.get_auth_user_role() in ('Owner', 'Manager'))
  and restaurant_id = public.get_auth_user_restaurant_id()
);
