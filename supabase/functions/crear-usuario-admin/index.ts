import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  // 1. Manejar CORS (Obligatorio para evitar errores al llamar desde Flutter)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    }})
  }

  try {
    // 2. Cargar variables de entorno (Supabase te las da automáticamente aquí adentro)
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    // ¡Esta es la clave mágica que soluciona tu error 401!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    // Inicializar Supabase con privilegios completos de administrador
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

    // 3. Leer los datos enviados desde tu app Flutter
    const { email, password, role, name, document, phone } = await req.json()

    // 4. Crear el usuario en Auth
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: email,
      password: password,
      email_confirm: true, // Auto-confirmar el correo
    })

    if (authError) throw authError

    // 5. Insertar el perfil en tu tabla pública 'profiles'
    const { error: profileError } = await supabaseAdmin.from('profiles').insert({
      auth_user_id: authData.user.id,
      full_name: name,
      role: role,
      document_number: document,
      phone: phone
    })

    if (profileError) throw profileError

    // 6. Responder éxito a Flutter
    return new Response(
      JSON.stringify({ message: 'Usuario y perfil creados exitosamente' }),
      { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }, status: 200 }
    )

  } catch (error) {
    // Si algo falla, devolver el error a Flutter
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }, status: 400 }
    )
  }
})