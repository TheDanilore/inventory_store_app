import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // 1. Manejar CORS (Obligatorio para evitar errores al llamar desde Flutter)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 2. Cargar variables de entorno
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    // Inicializar Supabase con privilegios completos de administrador
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

    // 3. Leer los datos enviados desde tu app Flutter
    const {
      email,
      password,
      role,
      roles,
      name,
      document,
      document_number,
      document_type,
      phone,
    } = await req.json()

    // 4. Crear el usuario en Auth
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: email,
      password: password,
      email_confirm: true, // Auto-confirmar el correo
    })

    if (authError) throw authError

    // 5. Insertar el perfil en 'profiles' (sin la columna 'role' eliminada)
    const docNumber = document_number ?? document
    const { data: profileData, error: profileError } = await supabaseAdmin
      .from('profiles')
      .insert({
        auth_user_id: authData.user.id,
        full_name: name,
        document_type: document_type ?? 'DNI',
        document_number: docNumber,
        phone: phone,
      })
      .select('id')
      .single()

    if (profileError) throw profileError

    // 6. Asignar los roles en la tabla intermedia 'user_roles'
    const rolesList: string[] = Array.isArray(roles) && roles.length > 0
      ? roles
      : (role ? [role] : ['employee'])

    if (rolesList.length > 0 && profileData?.id) {
      const { data: dbRoles, error: rolesError } = await supabaseAdmin
        .from('roles')
        .select('id, name')
        .in('name', rolesList)

      if (!rolesError && dbRoles && dbRoles.length > 0) {
        const rowsToInsert = dbRoles.map((r: { id: string }) => ({
          profile_id: profileData.id,
          role_id: r.id,
        }))
        await supabaseAdmin.from('user_roles').insert(rowsToInsert)
      }
    }

    // 7. Responder éxito a Flutter
    return new Response(
      JSON.stringify({
        message: 'Usuario, perfil y roles creados exitosamente',
        profile_id: profileData?.id,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})