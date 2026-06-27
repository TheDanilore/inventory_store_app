import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Manejo de CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Es vital usar el SERVICE_ROLE_KEY para poder editar usuarios por ID sin su sesión actual
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    const { auth_user_id, new_password } = await req.json()

    if (!auth_user_id || !new_password) {
      return new Response(JSON.stringify({ error: 'Faltan parámetros requeridos.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    // Actualizamos la contraseña del usuario mediante su ID de Auth
    const { data, error } = await supabaseClient.auth.admin.updateUserById(
      auth_user_id,
      { password: new_password }
    )

    if (error) {
      throw error
    }

    return new Response(JSON.stringify({ message: 'Contraseña actualizada correctamente', user: data.user }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
