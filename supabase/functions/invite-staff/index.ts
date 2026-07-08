import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ""
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ""
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ""
    
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'No authorization header' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Initialize user client to verify identity
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    })
    const { data: { user }, error: authError } = await userClient.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized user' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Initialize admin client to perform writes and invites
    const adminClient = createClient(supabaseUrl, supabaseServiceKey)

    // Check requester role
    const { data: profile, error: profileError } = await adminClient
      .from('users')
      .select('role, restaurant_id')
      .eq('uid', user.id)
      .single()

    if (profileError || !profile || (profile.role !== 'Owner' && profile.role !== 'Manager')) {
      return new Response(JSON.stringify({ error: 'Only Owners or Managers can invite staff' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { email, role } = await req.json()
    if (!email || !role) {
      return new Response(JSON.stringify({ error: 'Missing email or role' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const normalizedEmail = email.trim().toLowerCase()

    // 1. Check if user already exists in public.users
    const { data: existingUser } = await adminClient
      .from('users')
      .select('uid')
      .eq('email', normalizedEmail)
      .maybeSingle()

    if (existingUser) {
      return new Response(JSON.stringify({ error: 'This email is already registered.' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 2. PRE-INSERT the invite row into the invites table BEFORE calling inviteUserByEmail.
    //    This is critical: inviteUserByEmail immediately creates the auth.users row which
    //    fires the handle_new_user trigger. That trigger reads from the invites table to
    //    assign the correct role and onboarding_completed=true. If the invite row doesn't
    //    exist yet when the trigger fires, the user gets assigned Owner role instead — broken!
    const { error: inviteInsertError } = await adminClient.from('invites').insert({
      email: normalizedEmail,
      role: role,
      restaurant_id: profile.restaurant_id,
      used: false,
      created_by: user.id
    })

    if (inviteInsertError) {
      return new Response(JSON.stringify({ error: 'Failed to create invite record: ' + inviteInsertError.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 3. Now call the Auth invite API. The handle_new_user trigger will fire here,
    //    find the invite row we just inserted, and set the correct role + onboarding_completed=true.
    const redirectOrigin = 'https://dialagent-pwa-supabase-2.vercel.app'
    const { data: inviteData, error: inviteError } = await adminClient.auth.admin.inviteUserByEmail(
      normalizedEmail,
      {
        redirectTo: `${redirectOrigin}/welcome`,
        data: {
          // Also pass role and restaurant_id in user metadata as a backup,
          // in case of any edge-case where the trigger reads metadata instead of the table.
          role: role,
          restaurant_id: profile.restaurant_id
        }
      }
    )

    if (inviteError) {
      // Roll back: delete the invite row we just inserted since the invite failed
      await adminClient.from('invites').delete().eq('email', normalizedEmail).eq('used', false)
      return new Response(JSON.stringify({ error: inviteError.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    return new Response(JSON.stringify({ success: true, user: inviteData.user }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message || 'Internal Server Error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
