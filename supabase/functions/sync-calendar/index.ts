// supabase/functions/sync-calendar/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { google } from "npm:googleapis@105"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Get Supabase client to verify auth
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ""
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ""
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ""
    
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'No authorization header' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    })

    // Verify token & get user
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized user' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 2. Parse request payload
    const { action, taskId, task, calendarEventId } = await req.json()

    // 3. Initialize Google Calendar client using service account from Env variables
    const clientEmail = Deno.env.get('GOOGLE_CLIENT_EMAIL')
    const privateKey = Deno.env.get('GOOGLE_PRIVATE_KEY')
    const calendarId = Deno.env.get('GOOGLE_CALENDAR_ID') || 'primary'

    if (!clientEmail || !privateKey) {
      return new Response(JSON.stringify({ error: 'Google Calendar credentials not configured on server' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const jwtClient = new google.auth.JWT(
      clientEmail,
      null,
      privateKey.replace(/\\n/g, '\n'),
      ['https://www.googleapis.com/auth/calendar']
    )

    const calendar = google.calendar({ version: 'v3', auth: jwtClient })

    const adminSupabase = createClient(supabaseUrl, supabaseServiceKey)

    if (action === 'sync') {
      if (!taskId || !task) {
        return new Response(JSON.stringify({ error: 'Missing taskId or task' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      // Build calendar event payload
      const event = {
        summary: task.title,
        description: task.description || '',
        start: { dateTime: task.dueDate || new Date().toISOString() },
        end: { dateTime: task.dueDate || new Date().toISOString() },
        attendees: task.assignedTo ? [{ email: `${task.assignedTo}@yourdomain.com` }] : [],
        status: 'confirmed',
      }

      let eventId = calendarEventId || task.calendarEventId

      if (eventId) {
        // Update existing event
        const res = await calendar.events.update({
          calendarId,
          eventId,
          requestBody: event,
        })
        return new Response(JSON.stringify({ success: true, eventId: res.data.id }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      } else {
        // Insert new event
        const res = await calendar.events.insert({
          calendarId,
          requestBody: event,
        })
        
        // Save calendar details back to DB using admin client (bypasses RLS write checks securely)
        await adminSupabase
          .from('tasks')
          .update({ calendar_event_id: res.data.id, synced_to_calendar: true })
          .eq('id', taskId)

        return new Response(JSON.stringify({ success: true, eventId: res.data.id }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }
    } else if (action === 'delete') {
      const eventIdToDelete = calendarEventId || task?.calendarEventId
      if (!eventIdToDelete) {
        return new Response(JSON.stringify({ error: 'Missing calendarEventId' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      await calendar.events.delete({
        calendarId,
        eventId: eventIdToDelete,
      })

      return new Response(JSON.stringify({ success: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    } else {
      return new Response(JSON.stringify({ error: `Invalid action: ${action}` }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

  } catch (err) {
    console.error('Error handling calendar sync request:', err)
    return new Response(JSON.stringify({ error: err.message || 'Internal Server Error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
