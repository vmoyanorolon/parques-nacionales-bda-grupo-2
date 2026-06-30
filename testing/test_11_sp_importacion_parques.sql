-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: Scripts testing para el Stored Procedure de importación de Parques

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

-- Estado inicial limpio. Asume que NINGUNA tabla hija referencia a Parques.Parque
-- (Actividad, EntradaParque, Concesion, GuiaTrabajaEnParque, Asignacion). Si las
-- hubiera, primero hay que borrar esas filas por las FKs, o el DELETE fallará.
DELETE FROM Parques.Parque;
-- Limpio también el log para que los conteos de las corridas sean claros.
DELETE FROM Parques.LogImportacionParque;

----------------------------------------------------------------------
-- Test 1: estado inicial limpio.
-- Resultado esperado: 0 filas.
----------------------------------------------------------------------
SELECT Test = 1, COUNT(*) AS Cantidad FROM Parques.Parque;

----------------------------------------------------------------------
-- Test 2: primera importación del archivo.
-- Resultado esperado: 55 filas (cantidad de nombres únicos en el archivo).
-- El SP devuelve además su propio resumen (TotalFilasLeidas, etc.) y el detalle del log.
----------------------------------------------------------------------
EXEC USP_ImportarParque @rutaArchivo = @rutaArchivo;

SELECT Test = 2, COUNT(*) AS Cantidad FROM Parques.Parque;

----------------------------------------------------------------------
-- Test 3: caso puntual de un parque conocido.
-- Resultado esperado: 1 fila, TipoParque = 'Parque Nacional', Provincia = 'Misiones'.
----------------------------------------------------------------------
SELECT Test = 3, Nombre, Provincia, Localidad, Superficie, TipoParque
FROM Parques.Parque
WHERE Nombre = 'Parque Nacional Iguazú';

----------------------------------------------------------------------
-- Test 4: ningún Nombre debe quedar duplicado tras la importación.
-- Resultado esperado: 0 filas.
----------------------------------------------------------------------
SELECT Test = 4, Nombre, COUNT(*) AS Repeticiones
FROM Parques.Parque
GROUP BY Nombre
HAVING COUNT(*) > 1;

----------------------------------------------------------------------
-- Test 5: manejo de provincia NULL en áreas marinas.
-- Resultado esperado: Provincia = 'Sin Provincia' (valor por defecto del SP).
----------------------------------------------------------------------
SELECT Test = 5, Nombre, Provincia
FROM Parques.Parque
WHERE Nombre = 'Área Marina Protegida Yaganes';

----------------------------------------------------------------------
-- Test 6: todo TipoParque debe respetar el CHECK de la tabla.
-- Resultado esperado: 0 filas (ningún tipo fuera del dominio permitido).
----------------------------------------------------------------------
SELECT Test = 6, Nombre, TipoParque
FROM Parques.Parque
WHERE TipoParque NOT IN ('Parque Nacional','Monumento Natural','Reserva Nacional',
                         'Reserva Natural Estricta','Reserva Natural Silvestre',
                         'Reserva Natural Educativa');

----------------------------------------------------------------------
-- Test 7: reimportación del mismo archivo (idempotencia).
-- Resultado esperado: sigue habiendo 55 filas; no se duplican registros.
----------------------------------------------------------------------
EXEC USP_ImportarParque @rutaArchivo = @rutaArchivo;

SELECT Test = 7, COUNT(*) AS Cantidad FROM Parques.Parque;

----------------------------------------------------------------------
-- Test 8: el log de importación registró las dos corridas.
-- Resultado esperado: como no hay duplicados ni rechazos esperados en este
-- archivo, lo normal es 0 eventos. Si aparece algo, el detalle dice qué y por qué.
----------------------------------------------------------------------
SELECT Test = 8, TipoEvento, COUNT(*) AS Cantidad
FROM Parques.LogImportacionParque
GROUP BY TipoEvento;

SELECT Test = 8, TipoEvento, ClaveOrigen, Motivo, FechaImportacion
FROM Parques.LogImportacionParque
ORDER BY FechaImportacion, TipoEvento;

PRINT 'Suite completa de importación de Parque (8 tests) finalizada.';
GO