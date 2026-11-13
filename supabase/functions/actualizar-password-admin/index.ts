import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    // 1. Verificar JWT del usuario autenticado
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

    // 2. Verificar permisos RBAC (admin o users.manage / users.update)
    const { data: perms } = await supabaseUser
      .from('user_effective_permissions')
      .select('role_name, permission_code')
      .eq('auth_user_id', caller.id)

    const hasAccess = (perms ?? []).some(
      (p: { role_name: string; permission_code: string }) =>
        ['admin', 'superadmin'].includes(p.role_name?.toLowerCase()) ||
        ['users.manage', 'users.update'].includes(p.permission_code)
    )

    if (!hasAccess) {
      return new Response(JSON.stringify({ error: 'No tienes permisos para cambiar contraseñas.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 403,
      })
    }

    const { auth_user_id, user_id, new_password } = await req.json()
    const targetId = auth_user_id ?? user_id

    if (!targetId || !new_password) {
      return new Response(JSON.stringify({ error: 'Faltan parámetros requeridos (auth_user_id o user_id, new_password).' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    if (typeof new_password !== 'string' || new_password.length < 6) {
      return new Response(JSON.stringify({ error: 'La contraseña debe tener al menos 6 caracteres.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    let authUserIdToUpdate = targetId

    // Si se envió un ID de perfil en lugar del auth_user_id, resolverlo desde profiles
    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('auth_user_id')
      .eq('id', targetId)
      .maybeSingle()

    if (profile?.auth_user_id) {
      authUserIdToUpdate = profile.auth_user_id
    }

    const { data, error } = await supabaseAdmin.auth.admin.updateUserById(
      authUserIdToUpdate,
      { password: new_password }
    )

    if (error) throw error

    return new Response(
      JSON.stringify({
        message: 'Contraseña actualizada correctamente',
        user_id: data.user?.id,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error?.message ?? 'Error al actualizar contraseña.' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
