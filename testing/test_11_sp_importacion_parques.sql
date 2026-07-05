-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Fecha: 04/07/2026
-- Descripción: Test simple para el SP de reverse geocoding + testing de importación de Parque.
--              La parte de importación de datos corre dentro de una transacción que SIEMPRE hace
--              ROLLBACK al final (para no dejar nada insertado), y también ROLLBACK ante cualquier error.

USE ParquesNacionales
GO

-- Requiere OLE Automation habilitado:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE;
GO

------------------------------------------------------------------
-- Parte A: test del SP de reverse geocoding.
-- Es de solo lectura (llamadas a API, sin INSERT/UPDATE/DELETE en tablas),
-- por lo que no necesita transacción.
------------------------------------------------------------------
DECLARE @loc VARCHAR(50), @prov VARCHAR(50), @depto VARCHAR(50), @cp VARCHAR(12);

-- Test 1: Parque Nacional Iguazú (Misiones). Esperado: devuelve localidad y provincia.
EXEC USP_ObtenerLocalidad '-25.66836', '-54.31053',
     @loc OUTPUT, @prov OUTPUT, @depto OUTPUT, @cp OUTPUT;
SELECT Test = 1, Coordenadas = 'Iguazú',
       Localidad = @loc, Provincia = @prov, Departamento = @depto, CodigoPostal = @cp;

-- Test 2: Parque Nacional Nahuel Huapi (Río Negro).
EXEC USP_ObtenerLocalidad '-40.95411', '-71.53639',
     @loc OUTPUT, @prov OUTPUT, @depto OUTPUT, @cp OUTPUT;
SELECT Test = 2, Coordenadas = 'Nahuel Huapi',
       Localidad = @loc, Provincia = @prov, Departamento = @depto, CodigoPostal = @cp;

-- Test 3: Área Marina Protegida Yaganes (en el océano). Esperado: NULL en todo.
EXEC USP_ObtenerLocalidad '-56.93301', '-65.45820',
     @loc OUTPUT, @prov OUTPUT, @depto OUTPUT, @cp OUTPUT;
SELECT Test = 3, Coordenadas = 'Yaganes (mar)',
       Localidad = @loc, Provincia = @prov, Departamento = @depto, CodigoPostal = @cp;
GO



SET NOCOUNT ON;
SET XACT_ABORT ON;  -- Ante error en tiempo de ejecución, marca la transacción como no confirmable.

-- Destrabar cualquier transacción abierta de una ejecución anterior que haya fallado.
IF @@TRANCOUNT > 0
    WHILE @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

------------------------------------------------------------------
-- Configuraciones de instancia (NO transaccionales): deben ir FUERA
-- de la transacción de usuario.
------------------------------------------------------------------

-- Configuraciones de instancia para poder leer el Excel vía OPENROWSET.
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;
EXEC sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.16.0', N'AllowInProcess', 1;
-- OLE Automation, necesario para las llamadas a la API de geolocalización.
EXEC sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE;

-- Ruta del archivo a importar. Ajustar según la máquina donde se ejecute el test.
DECLARE @rutaArchivo VARCHAR(2048) = '';

IF @rutaArchivo = ''
BEGIN
    ;THROW 50000, 'Definir la ruta del archivo antes de continuar la ejecución.', 1;
END

------------------------------------------------------------------
-- Parte B: testing de importación de Parque, dentro de una transacción que:
--   * hace ROLLBACK ante cualquier error (bloque CATCH), y
--   * hace ROLLBACK SIEMPRE al final aunque no haya error,
--     de modo que nada quede insertado en la base.
------------------------------------------------------------------
BEGIN TRY

    BEGIN TRANSACTION;

    -- Estado inicial limpio.
    -- Ventas
    DELETE lp
    FROM Ventas.LineaDeEntradaParque lp
    INNER JOIN Turismo.EntradaParque ep ON ep.IdEntradaParque = lp.IdEntradaParque;

    DELETE la
    FROM Ventas.LineaDeEntradaActividad la
    INNER JOIN Turismo.Actividad a ON a.IdActividad = la.IdActividad;

    -- Concesiones (PagoConcesion -> Concesion -> Parque)
    DELETE FROM Concesiones.PagoConcesion;
    DELETE FROM Concesiones.Concesion;

    -- Turismo dependiente de Parque
    DELETE FROM Turismo.Turno;                    -- Turno -> Actividad
    DELETE FROM Personal.Habilitacion;            -- Habilitacion -> Actividad
    DELETE FROM Turismo.Actividad;                -- Actividad -> Parque
    DELETE FROM Turismo.EntradaParque;            -- EntradaParque -> Parque

    -- Personal dependiente de Parque
    DELETE FROM Personal.GuiaTrabajaEnParque;     -- -> Parque
    DELETE FROM Personal.Asignacion;              -- -> Parque

    -- Finalmente, Parque
    DELETE FROM Parques.Parque; 


    ----------------------------------------------------------------------
    -- Test 1: importar el archivo. Esperado: se insertan las 52 filas.
    ----------------------------------------------------------------------
    EXEC USP_ImportarParque @rutaArchivo = @rutaArchivo;

    SELECT Test = 1, COUNT(*) AS FilasInsertadas FROM Parques.Parque;

    ----------------------------------------------------------------------
    -- Test 2: ver todo lo insertado, para confirmar a ojo que los datos
    --         (incluidos Localidad, Departamento y CodigoPostal de la API) llegaron.
    ----------------------------------------------------------------------
    SELECT Test = 2, Nombre, Provincia, Localidad, Departamento, CodigoPostal,
           Latitud, Longitud, Superficie, TipoParque
    FROM Parques.Parque
    ORDER BY Nombre;

    ----------------------------------------------------------------------
    -- Test 3: reimportar el mismo archivo. Esperado: sigue la misma cantidad,
    --         no se duplican registros (upsert por Nombre).
    ----------------------------------------------------------------------
    EXEC USP_ImportarParque @rutaArchivo = @rutaArchivo;

    SELECT Test = 3, COUNT(*) AS FilasTrasReimportar FROM Parques.Parque;

    ----------------------------------------------------------------------
    -- Test 4: log de la corrida (informativo: áreas marinas sin localidad, etc.).
    ----------------------------------------------------------------------
    SELECT Test = 4, TipoEvento, ClaveOrigen, Motivo
    FROM Parques.LogImportacionParque
    ORDER BY FechaImportacion, TipoEvento;

    ------------------------------------------------------------------
    -- Fin de los tests SIN error: se hace ROLLBACK de todos modos
    -- para no dejar nada insertado en la base.
    ------------------------------------------------------------------
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    PRINT 'Testing de importación de Parque finalizado.';
    PRINT 'ROLLBACK realizado: no se dejó ningún dato insertado en la base.';

END TRY
BEGIN CATCH

    -- Ante cualquier error, se deshace todo lo hecho dentro de la transacción.
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    PRINT 'Se produjo un ERROR durante la ejecución. Se hizo ROLLBACK: no se insertó nada en la base.';
    PRINT 'Mensaje: ' + ERROR_MESSAGE();
    PRINT 'Línea:   ' + CAST(ERROR_LINE() AS VARCHAR(10));

    -- Re-lanzar el error para que quede visible en la consola / cliente.
    THROW;

END CATCH
GO