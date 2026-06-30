-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: Scripts testing para el Stored Procedure de importación de Organizaciones Concesionarias

USE ParquesNacionales
GO

SET NOCOUNT ON;
SET XACT_ABORT OFF;

-- Destrabar cualquier transacción abierta de una Ejecucion anterior que haya fallado.
IF @@TRANCOUNT > 0
BEGIN
    PRINT 'Se detectó una transacción abierta de una ejecución anterior. Se hace ROLLBACK antes de continuar.';
    WHILE @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
END

-- Configuraciones de instancia para poder leer el Excel vía OPENROWSET.
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;
EXEC sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.16.0', N'AllowInProcess', 1;

-- Ruta del archivo a importar. Ajustar según la máquina donde se ejecute el test.
DECLARE @rutaArchivo VARCHAR(2048) = '';

IF @rutaArchivo = ''
BEGIN
    ;THROW 50000, 'Definir la ruta del archivo para continuar la ejecución.', 1;
END

-- Estado inicial limpio. Asume que no hay Concesion que referencie estas
-- organizaciones; si las hubiera, primero hay que borrar Concesiones.Concesion
-- (y sus PagoConcesion) por la FK.
DELETE FROM Concesiones.OrganizacionConcesionaria;

-- Test 1: estado inicial limpio.
-- Resultado esperado: 0 filas.
SELECT Test = 1, COUNT(*) AS Cantidad FROM Concesiones.OrganizacionConcesionaria;

-- Test 2: primera importación del archivo.
-- Resultado esperado: 28 filas (cantidad de CUITs únicos en el archivo).
EXEC USP_ImportarOrganizacionConcesionaria @rutaArchivo = @rutaArchivo;

SELECT Test = 2, * FROM Concesiones.OrganizacionConcesionaria;

-- Test 3: organización con múltiples actividades en el archivo (TURISUR SRL,
-- CUIT 30506949471, aparece 5 veces con actividades distintas).
-- Resultado esperado: TipoActividad = 'EXC. NAVEGACIÓN - CONCESION O PERMISO X DDJJ'
-- (la primera actividad según el orden de aparición en el archivo).
SELECT Test = 3, CUIT, Nombre, TipoActividad
FROM Concesiones.OrganizacionConcesionaria
WHERE CUIT = '30506949471';

-- Test 4: ningún CUIT debe quedar duplicado tras la importación.
-- Resultado esperado: 0 filas.
SELECT Test4 = 4, CUIT, COUNT(*) AS Repeticiones
FROM Concesiones.OrganizacionConcesionaria
GROUP BY CUIT
HAVING COUNT(*) > 1;

-- Test 5: reimportación del mismo archivo (idempotencia).
-- Resultado esperado: sigue habiendo 28 filas; no se duplican registros.
EXEC USP_ImportarOrganizacionConcesionaria @rutaArchivo = @rutaArchivo;

SELECT Test = 5, COUNT(*) AS Cantidad FROM Concesiones.OrganizacionConcesionaria;

PRINT 'Suite completa de importación de Organización Concesionaria (5 tests) finalizada.';
GO