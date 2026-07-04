-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamin Velazquez (46.641.239), Valentin Moyano Rolon (46.292.248)
-- Descripcion: Testing de USP_CrearRolesSeguridad.
--              Verifica creacion de roles, idempotencia y otorgamiento de permisos granulares.

USE ParquesNacionales
GO

PRINT '=========================================================='
PRINT ' TESTING USP_CrearRolesSeguridad'
PRINT '=========================================================='
GO

SET NOCOUNT ON;

----------------------------------------------------------------------
-- PRUEBA 1: Primera ejecucion - creacion de los 7 roles
----------------------------------------------------------------------
-- Resultado esperado: el SP se ejecuta sin error. Al consultar sys.database_principals
-- deben existir EXACTAMENTE los 7 roles definidos por el SP (ademas de los fixed roles,
-- que se excluyen con is_fixed_role = 0).
----------------------------------------------------------------------
PRINT ''
PRINT '--- PRUEBA 1: primera ejecucion (creacion de roles) ---'
GO

EXEC USP_CrearRolesSeguridad;
GO

-- Verificacion: deben aparecer los 7 roles esperados. Conteo esperado = 7.
SELECT dp.name AS RolCreado
FROM sys.database_principals dp
WHERE dp.type = 'R'
  AND dp.is_fixed_role = 0
  AND dp.name IN ('RolAdministrador','RolTurismo','RolVentas','RolPersonal',
                  'RolConcesiones','RolImportador','RolConsultas')
ORDER BY dp.name;
-- Esperado (7 filas): RolAdministrador, RolConcesiones, RolConsultas,
--                     RolImportador, RolPersonal, RolTurismo, RolVentas

GO

----------------------------------------------------------------------
-- PRUEBA 2: Idempotencia - segunda ejecucion consecutiva
----------------------------------------------------------------------
-- La cantidad de roles no se duplica, el procedure detecta que ya existen
----------------------------------------------------------------------
PRINT ''
PRINT '--- PRUEBA 2: idempotencia (segunda ejecucion) ---'
GO

EXEC USP_CrearRolesSeguridad;
GO

SELECT COUNT(*) AS CantidadRolesPropios
FROM sys.database_principals
WHERE type = 'R'
  AND is_fixed_role = 0
  AND name IN ('RolAdministrador','RolTurismo','RolVentas','RolPersonal',
               'RolConcesiones','RolImportador','RolConsultas');
-- Esperado: CantidadRolesPropios = 7 (sin error, sin duplicados)

GO

----------------------------------------------------------------------
-- PRUEBA 3: RolAdministrador es miembro de db_owner
----------------------------------------------------------------------
-- El SP hace ALTER ROLE db_owner ADD MEMBER RolAdministrador.
-- Resultado esperado: 1 fila que confirma la membresia.
----------------------------------------------------------------------
PRINT ''
PRINT '--- PRUEBA 3: RolAdministrador pertenece a db_owner ---'
GO

SELECT r.name AS RolContenedor, m.name AS RolMiembro
FROM sys.database_role_members drm
JOIN sys.database_principals r ON r.principal_id = drm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = drm.member_principal_id
WHERE r.name = 'db_owner'
  AND m.name = 'RolAdministrador';
-- Esperado (1 fila): db_owner | RolAdministrador

GO

----------------------------------------------------------------------
-- PRUEBA 4: Permisos EXECUTE otorgados por rol
----------------------------------------------------------------------
-- Verifica que cada rol tenga concedido EXECUTE sobre los SP correspondientes.
-- Se cuenta la cantidad de permisos EXECUTE (OBJECT_OR_COLUMN, permission GRANT)
-- por rol. Esto detecta si algun GRANT fallo silenciosamente.
--
-- Resultado esperado (segun el cuerpo del SP):
--   RolTurismo     : 15 EXECUTE
--   RolVentas      :  5 EXECUTE
--   RolPersonal    : 14 EXECUTE
--   RolConcesiones :  8 EXECUTE
--   RolImportador  :  6 EXECUTE
--   RolConsultas   :  5 EXECUTE
-- (RolAdministrador no recibe GRANT EXECUTE directo: hereda todo via db_owner.)
----------------------------------------------------------------------
PRINT ''
PRINT '--- PRUEBA 4: cantidad de permisos EXECUTE por rol ---'
GO

SELECT dp.name AS Rol,
       COUNT(*) AS CantidadExecute
FROM sys.database_permissions perm
JOIN sys.database_principals dp ON dp.principal_id = perm.grantee_principal_id
WHERE dp.type = 'R'
  AND dp.name IN ('RolTurismo','RolVentas','RolPersonal',
                  'RolConcesiones','RolImportador','RolConsultas')
  AND perm.permission_name = 'EXECUTE'
  AND perm.state_desc = 'GRANT'
GROUP BY dp.name
ORDER BY dp.name;
-- Esperado (6 filas):
--   RolConcesiones = 8 | RolConsultas = 5 | RolImportador = 6
--   RolPersonal = 14   | RolTurismo = 15  | RolVentas = 5

GO

----------------------------------------------------------------------
-- PRUEBA 5: Permisos SELECT otorgados por rol
----------------------------------------------------------------------
-- Verifica los GRANT SELECT sobre tablas. Confirma que los roles operativos
-- tengan lectura sobre las tablas que necesitan consultar.
--
-- Resultado esperado (segun el cuerpo del SP):
--   RolTurismo     : 6 SELECT
--   RolVentas      : 7 SELECT
--   RolPersonal    : 5 SELECT
--   RolConcesiones : 3 SELECT
--   RolImportador  : 3 SELECT (solo tablas de log de auditoria)
----------------------------------------------------------------------
PRINT ''
PRINT '--- PRUEBA 5: cantidad de permisos SELECT por rol ---'
GO

SELECT dp.name AS Rol,
       COUNT(*) AS CantidadSelect
FROM sys.database_permissions perm
JOIN sys.database_principals dp ON dp.principal_id = perm.grantee_principal_id
WHERE dp.type = 'R'
  AND dp.name IN ('RolTurismo','RolVentas','RolPersonal','RolConcesiones','RolImportador')
  AND perm.permission_name = 'SELECT'
  AND perm.state_desc = 'GRANT'
GROUP BY dp.name
ORDER BY dp.name;
-- Esperado (5 filas):
--   RolConcesiones = 3 | RolImportador = 3 | RolPersonal = 5
--   RolTurismo = 6     | RolVentas = 7

GO

----------------------------------------------------------------------
-- PRUEBA 6 (validacion de aislamiento): RolImportador NO puede leer tablas destino
----------------------------------------------------------------------
-- El comentario del SP indica que RolImportador solo lee las tablas de LOG,
-- no las tablas destino de la importacion (Parque, Guia, OrganizacionConcesionaria).
-- Resultado esperado: 0 filas. Si aparece alguna fila, se violo el principio de
-- minimo privilegio declarado.
----------------------------------------------------------------------
PRINT ''
PRINT '--- PRUEBA 6: RolImportador NO tiene SELECT sobre tablas destino ---'
GO

SELECT dp.name AS Rol,
       OBJECT_SCHEMA_NAME(perm.major_id) + '.' + OBJECT_NAME(perm.major_id) AS TablaDestino
FROM sys.database_permissions perm
JOIN sys.database_principals dp ON dp.principal_id = perm.grantee_principal_id
WHERE dp.name = 'RolImportador'
  AND perm.permission_name = 'SELECT'
  AND perm.state_desc = 'GRANT'
  AND OBJECT_NAME(perm.major_id) IN ('Parque','Guia','OrganizacionConcesionaria');
-- Esperado: 0 filas (RolImportador no debe leer las tablas destino)

GO

----------------------------------------------------------------------
-- LIMPIEZA OPCIONAL (descomentar para dejar la base como estaba)
----------------------------------------------------------------------
-- ADVERTENCIA: solo ejecutar si se quiere revertir el efecto del testing.
-- Hay que quitar la membresia antes de dropear el rol.
/*
ALTER ROLE db_owner DROP MEMBER RolAdministrador;
DROP ROLE IF EXISTS RolAdministrador;
DROP ROLE IF EXISTS RolTurismo;
DROP ROLE IF EXISTS RolVentas;
DROP ROLE IF EXISTS RolPersonal;
DROP ROLE IF EXISTS RolConcesiones;
DROP ROLE IF EXISTS RolImportador;
DROP ROLE IF EXISTS RolConsultas;
*/
GO

PRINT ''
PRINT '=========================================================='
PRINT ' FIN TESTING USP_CrearRolesSeguridad'
PRINT '=========================================================='
GO
