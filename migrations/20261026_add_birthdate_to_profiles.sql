-- ==============================================================================
-- Migración: Agregar fecha de nacimiento (birthdate) a la tabla profiles
-- ==============================================================================
-- Permite registrar el cumpleaños de colaboradores y administradores para
-- enviar felicitaciones interactivas al ingresar al sistema y en el Dashboard.

ALTER TABLE "public"."profiles" 
ADD COLUMN IF NOT EXISTS "birthdate" DATE;

COMMENT ON COLUMN "public"."profiles"."birthdate" 
IS 'Fecha de nacimiento del usuario para felicitaciones y métricas corporativas';
