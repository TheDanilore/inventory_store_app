import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  let createdAuthUserId: string | null = null

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    // 1. Verificar JWT del usuario que invoca la función
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'No autorizado: falta token de sesión.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 401,
      })
    }

    const supabaseUser = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false },
    })

    const { data: { user: caller }, error: callerError } = await supabaseUser.auth.getUser()
    if (callerError || !caller) {
      return new Response(JSON.stringify({ error: 'Sesión inválida o expirada.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 401,
      })
    }

    // 2. Verificar permisos RBAC del caller (admin o users.manage / users.create)
    const { data: perms } = await supabaseUser
      .from('user_effective_permissions')
      .select('role_name, permission_code')
      .eq('auth_user_id', caller.id)

    const hasAccess = (perms ?? []).some(
      (p: { role_name: string; permission_code: string }) =>
        ['admin', 'superadmin'].includes(p.role_name?.toLowerCase()) ||
        ['users.manage', 'users.create'].includes(p.permission_code)
    )

    if (!hasAccess) {
      return new Response(JSON.stringify({ error: 'No tienes permisos para crear usuarios.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 403,
      })
    }

    // 3. Cliente Admin solo después de validar autorización
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

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
      warehouse_id,
    } = await req.json()

    if (!email || !password || !name) {
      return new Response(JSON.stringify({ error: 'Faltan campos requeridos (email, password, name).' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    // 4. Crear usuario en Auth
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    })

    if (authError) throw authError
    createdAuthUserId = authData.user.id

    // 5. Insertar perfil en 'profiles'
    const docNumber = document_number ?? document
    const { data: profileData, error: profileError } = await supabaseAdmin
      .from('profiles')
      .insert({
        auth_user_id: authData.user.id,
        full_name: name,
        document_type: document_type ?? 'DNI',
        document_number: docNumber,
        phone,
      })
      .select('id')
      .single()

    if (profileError) throw profileError

    // 6. Asignar roles en 'user_roles'
    const rolesList: string[] = Array.isArray(roles) && roles.length > 0
      ? roles
      : (role ? [role] : ['employee'])

    if (rolesList.length > 0 && profileData?.id) {
      const { data: dbRoles, error: rolesError } = await supabaseAdmin
        .from('roles')
        .select('id, name')
        .in('name', rolesList)

      if (rolesError) throw rolesError

      if (dbRoles && dbRoles.length > 0) {
        const rowsToInsert = dbRoles.map((r: { id: string }) => ({
          profile_id: profileData.id,
          role_id: r.id,
        }))
        const { error: assignErr } = await supabaseAdmin.from('user_roles').insert(rowsToInsert)
        if (assignErr) throw assignErr
      }

      // Si es cliente, asegurar vínculo en public.customers
      if (rolesList.includes('customer')) {
        await supabaseAdmin.from('customers').insert({
          profile_id: profileData.id,
          customer_type: (document_type ?? 'DNI') === 'RUC' ? 'COMPANY' : 'PERSON',
          document_type: document_type ?? 'DNI',
          document_number: docNumber || null,
          full_name: name,
          email,
          phone: phone || null,
        })
      }
    }

    // 7. Asignar almacén por defecto si se especificó
    if (warehouse_id && profileData?.id) {
      const { error: whErr } = await supabaseAdmin.from('user_warehouses').insert({
        profile_id: profileData.id,
        warehouse_id,
        is_default: true,
      })
      if (whErr) throw whErr
    }

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
    // Rollback en Auth si falló después de crear el usuario
    if (createdAuthUserId) {
      try {
        const supabaseAdmin = createClient(
          Deno.env.get('SUPABASE_URL') ?? '',
          Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
          { auth: { autoRefreshToken: false, persistSession: false } }
        )
        await supabaseAdmin.auth.admin.deleteUser(createdAuthUserId)
      } catch (_) {
        // Ignorar error secundario de rollback
      }
    }

    return new Response(
      JSON.stringify({ error: error?.message ?? 'Error interno al crear usuario.' }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})
