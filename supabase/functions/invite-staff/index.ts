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

    // 1. Check if user already exists
    const { data: existingUser, error: checkError } = await adminClient
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

    // 2. Call Supabase Auth invite API (triggers your SMTP server email)
    const { data: inviteData, error: inviteError } = await adminClient.auth.admin.inviteUserByEmail(
      normalizedEmail,
      {
        redirectTo: (() => {
          let origin = req.headers.get('origin') || 'https://dialagent-pwa-supabase-2.vercel.app';
          if (origin.includes('localhost')) {
            origin = 'https://dialagent-pwa-supabase-2.vercel.app';
          }
          return `${origin}/signup`;
        })(),
        data: {
          role: role,
          restaurant_id: profile.restaurant_id
        }
      }
    )

    if (inviteError) {
      return new Response(JSON.stringify({ error: inviteError.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 3. Insert tracking record in invites table
    await adminClient.from('invites').insert({
      email: normalizedEmail,
      role: role,
      restaurant_id: profile.restaurant_id,
      used: false,
      created_by: user.id
    })

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
