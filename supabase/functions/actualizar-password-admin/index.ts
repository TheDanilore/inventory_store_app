import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Manejo de CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
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

    const { auth_user_id, user_id, new_password } = await req.json()
    const targetId = auth_user_id ?? user_id

    if (!targetId || !new_password) {
      return new Response(JSON.stringify({ error: 'Faltan parámetros requeridos (auth_user_id o user_id, new_password).' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    let authUserIdToUpdate = targetId

    // Si se envió un ID de perfil en lugar del auth_user_id, resolverlo desde profiles
    const { data: profile } = await supabaseClient
      .from('profiles')
      .select('auth_user_id')
      .eq('id', targetId)
      .maybeSingle()

    if (profile?.auth_user_id) {
      authUserIdToUpdate = profile.auth_user_id
    }

    // Actualizamos la contraseña del usuario mediante su ID de Auth
    const { data, error } = await supabaseClient.auth.admin.updateUserById(
      authUserIdToUpdate,
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
