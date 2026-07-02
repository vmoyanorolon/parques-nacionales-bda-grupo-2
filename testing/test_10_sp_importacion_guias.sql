-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: Scripts testing para el Stored Procedure de importación de Guias.

USE ParquesNacionales
GO

SET NOCOUNT ON;
SET XACT_ABORT OFF;

-- Destrabar cualquier transacción abierta de una ejecución anterior que haya fallado.
IF @@TRANCOUNT > 0
BEGIN
    PRINT 'Se detectó una transacción abierta de una ejecución anterior. Se hace ROLLBACK antes de continuar.';
    WHILE @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
END

-- Ruta del archivo a importar. Ajustar según la máquina donde se ejecute el test.
-- IMPORTANTE: la ruta debe ser visible para el SERVICIO de SQL Server, no para el cliente.
DECLARE @rutaArchivo VARCHAR(500) = 'C:\temp\guias-a-julio-2019.csv';

IF @rutaArchivo = ''
BEGIN
    ;THROW 50000, 'Definir la ruta del archivo antes de continuar la ejecución.', 1;
END

-- Estado inicial limpio.
-- Si Personal.Guia es referenciada por otras tablas vía FK (por ejemplo, asignaciones
-- de guías a actividades), primero hay que borrar esas tablas dependientes.
DELETE FROM Personal.LogImportacionGuia;
DELETE FROM Personal.Guia;

-- Test 1: estado inicial limpio.
-- Resultado esperado: 0 filas en Personal.Guia.
SELECT
    Test        = 1,
    Descripcion = 'Estado inicial limpio',
    Cantidad    = COUNT(*)
FROM Personal.Guia;

-- Test 2: primera importación del archivo.
-- El SP devuelve dos result sets:
--   Result set A: resumen numérico de la corrida.
--   Result set B: detalle fila a fila de duplicados y errores.
-- Resultado esperado result set A:
--   TotalFilasLeidas           = 555  (filas de datos en el CSV, sin el encabezado)
--   DuplicadosIntraArchivo     = 5    (documentos que aparecían más de una vez en el archivo)
--   RechazadosPorValidacion    = 341  (completar tras la primera ejecución — estimado ~323 por emails vacíos)
--   InsertadosEnEstaCorrida    = ???  (completar tras la primera ejecución)
--   TotalValidosProcesados     = 209  (completar tras la primera ejecución)
PRINT 'Test 2 - Primera importación:';
EXEC USP_ImportarGuiasCsv @rutaArchivo = @rutaArchivo;

-- Test 3: conteo total en la tabla tras la primera importación.
-- Resultado esperado: igual a InsertadosEnEstaCorrida del test 2.
SELECT
    Test        = 3,
    Descripcion = 'Conteo total tras primera importación',
    Cantidad    = COUNT(*)
FROM Personal.Guia;

-- Test 4: dentro del archivo había documentos repetidos; debe haberse importado
-- el registro con el Legajo más alto (el más reciente) y descartado el otro.
-- Usando el documento 12974007 como caso de prueba (aparecía dos veces en el archivo).
-- Resultado esperado: exactamente 1 fila, y los datos deben corresponder
-- al registro de mayor Legajo entre los dos del archivo.
SELECT
    Test        = 4,
    Descripcion = 'Duplicado intraarchivo: solo debe existir el registro más reciente',
    *
FROM Personal.Guia
WHERE NumeroDocumento = '12974007';

-- Test 5: ningún NumeroDocumento puede estar duplicado en la tabla.
-- Resultado esperado: 0 filas.
SELECT
    Test           = 5,
    Descripcion    = 'Sin duplicados de NumeroDocumento en la tabla',
    NumeroDocumento,
    Repeticiones   = COUNT(*)
FROM Personal.Guia
GROUP BY NumeroDocumento
HAVING COUNT(*) > 1;

-- Test 6: una fila sin email no debe haber sido importada.
-- El documento 8149267 (ALONSO, ARMANDO SALVADOR) no tiene email en el archivo.
-- Resultado esperado: 0 filas.
SELECT
    Test        = 6,
    Descripcion = 'Fila sin email no debe existir en la tabla',
    *
FROM Personal.Guia
WHERE NumeroDocumento = '8149267';

-- Test 7: una fila con email válido sí debe haberse importado correctamente,
-- con TipoDocumento = 'DNI' y Edad = 1 (valores fijos definidos para esta fuente).
-- Usar un documento que se sepa que tenía email en el archivo.
-- Resultado esperado: 1 fila, TipoDocumento = 'DNI', Edad = 1.
SELECT
    Test        = 7,
    Descripcion = 'Fila válida importada con valores fijos correctos',
    NumeroDocumento,
    Apellido,
    Nombre,
    TipoDocumento,
    Edad,
    CorreoGuia
FROM Personal.Guia
WHERE NumeroDocumento = '13608130'; -- ARAMBURU, BELEN (tenía email en el archivo)

-- Test 8: verificar que los errores de la corrida quedaron persistidos en el log.
-- Resultado esperado: cantidad de filas > 0, igual a DuplicadosIntraArchivo
-- + RechazadosPorValidacion del result set del test 2.
SELECT
    Test        = 8,
    Descripcion = 'Log de importación persistido correctamente',
    TipoEvento,
    Cantidad    = COUNT(*)
FROM Personal.LogImportacionGuia
GROUP BY TipoEvento;

-- Test 9: reimportación del mismo archivo (idempotencia).
-- Resultado esperado result set A:
--   InsertadosEnEstaCorrida = 0  (nadie nuevo — todos ya estaban en la tabla)
--   TotalValidosProcesados  = mismo valor que en el test 2
-- Resultado esperado result set B: solo duplicados intraarchivo, 0 errores de validación nuevos.
PRINT 'Test 9 - Reimportación (idempotencia):';
EXEC USP_ImportarGuiasCsv @rutaArchivo = @rutaArchivo;

-- Test 10: el conteo total en la tabla no debe haber cambiado tras la reimportación.
-- Resultado esperado: mismo valor que test 3.
SELECT
    Test        = 10,
    Descripcion = 'Conteo sin cambios tras reimportación',
    Cantidad    = COUNT(*)
FROM Personal.Guia;

-- Test 11: upsert — modificar manualmente un campo de un guía ya importado,
-- reimportar y verificar que el SP restauró el dato original del archivo.
UPDATE Personal.Guia
SET CorreoGuia = 'correo.modificado.manualmente@test.com'
WHERE NumeroDocumento = '13608130';

EXEC USP_ImportarGuiasCsv @rutaArchivo = @rutaArchivo;

-- Resultado esperado: CorreoGuia debe ser el del archivo original, no el modificado.
SELECT
    Test        = 11,
    Descripcion = 'Upsert: el campo modificado manualmente fue restaurado por la reimportación',
    NumeroDocumento,
    CorreoGuia
FROM Personal.Guia
WHERE NumeroDocumento = '13608130';

PRINT 'Suite completa de importación de Guías (11 tests) finalizada.';
GO