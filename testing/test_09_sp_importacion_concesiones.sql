-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Fecha: 04/07/2026
-- Descripción: Scripts testing para el Stored Procedure de importación de Organizaciones Concesionarias y Concesiones
--              Toda la ejecución de datos corre dentro de una transacción que SIEMPRE hace ROLLBACK al final
--              (para no dejar nada insertado), y también hace ROLLBACK ante cualquier error.

USE ParquesNacionales
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;  -- Ante error en tiempo de ejecución, marca la transacción como no confirmable.

-- Destrabar cualquier transacción abierta de una ejecución anterior que haya fallado.
IF @@TRANCOUNT > 0
BEGIN
    PRINT 'Se detectó una transacción abierta de una ejecución anterior. Se hace ROLLBACK antes de continuar.';
    WHILE @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
END

------------------------------------------------------------------
-- Configuraciones de instancia (NO transaccionales): deben ir FUERA
-- de la transacción de usuario. sp_configure/RECONFIGURE y
-- sp_MSset_oledb_prop no participan de un BEGIN/ROLLBACK TRAN.
------------------------------------------------------------------

-- Configuraciones de instancia para leer el Excel vía OPENROWSET.
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;
EXEC sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.16.0', N'AllowInProcess', 1;

-- Configuración de instancia para las APIs (feriados) que usa el cálculo de canon.
EXEC sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE;

-- Ruta del archivo a importar. Ajustar según la máquina donde se ejecute el test.
DECLARE @rutaArchivo VARCHAR(2048) = '';

IF @rutaArchivo = ''
BEGIN
    ;THROW 50000, 'Definir la ruta del archivo para continuar la ejecución.', 1;
END

------------------------------------------------------------------
-- A partir de acá, todo corre dentro de una transacción que:
--   * hace ROLLBACK ante cualquier error (bloque CATCH), y
--   * hace ROLLBACK SIEMPRE al final aunque no haya error,
--     de modo que nada quede insertado en la base.
------------------------------------------------------------------
BEGIN TRY

    BEGIN TRANSACTION;

    ------------------------------------------------------------------
    -- Limpieza dirigida: borra cualquier residuo de corridas anteriores
    -- de ESTE archivo, y cualquier fila con estos nombres exactos que
    -- haya dejado test_11 (importación real de Parque) o una corrida
    -- previa de este mismo test. Se borra en orden de FK.
    ------------------------------------------------------------------
    DECLARE @idIguazuPrevio INT = (SELECT IdParque FROM Parques.Parque WHERE Nombre = 'Parque Nacional Iguazú');
    DECLARE @idTierraDelFuegoPrevio INT = (SELECT IdParque FROM Parques.Parque WHERE Nombre = 'Parque Nacional Tierra del Fuego');
    DECLARE @idElPalmarPrevio INT = (SELECT IdParque FROM Parques.Parque WHERE Nombre = 'Parque Nacional El Palmar');
    DECLARE @idLagoPueloPrevio INT = (SELECT IdParque FROM Parques.Parque WHERE Nombre = 'Parque Nacional Lago Puelo');

    DELETE pc
    FROM Concesiones.PagoConcesion pc
    INNER JOIN Concesiones.Concesion c ON c.IdConcesion = pc.IdConcesion
    WHERE c.IdParque IN (@idIguazuPrevio, @idTierraDelFuegoPrevio, @idElPalmarPrevio, @idLagoPueloPrevio);

    DELETE FROM Concesiones.Concesion WHERE IdParque IN (@idIguazuPrevio, @idTierraDelFuegoPrevio, @idElPalmarPrevio, @idLagoPueloPrevio);
    DELETE la
    FROM Ventas.LineaDeEntradaActividad la
    INNER JOIN Turismo.Actividad a ON a.IdActividad = la.IdActividad
    WHERE a.IdParque IN (@idIguazuPrevio, @idTierraDelFuegoPrevio, @idElPalmarPrevio, @idLagoPueloPrevio);

    DELETE lp
    FROM Ventas.LineaDeEntradaParque lp
    INNER JOIN Turismo.EntradaParque ep ON ep.IdEntradaParque = lp.IdEntradaParque
    WHERE ep.IdParque IN (@idIguazuPrevio, @idTierraDelFuegoPrevio, @idElPalmarPrevio, @idLagoPueloPrevio);

    DELETE FROM Turismo.Turno WHERE IdActividad IN (SELECT IdActividad FROM Turismo.Actividad WHERE IdParque IN (@idIguazuPrevio, @idTierraDelFuegoPrevio, @idElPalmarPrevio, @idLagoPueloPrevio));
    DELETE FROM Turismo.Actividad WHERE IdParque IN (@idIguazuPrevio, @idTierraDelFuegoPrevio, @idElPalmarPrevio, @idLagoPueloPrevio);
    DELETE FROM Turismo.EntradaParque WHERE IdParque IN (@idIguazuPrevio, @idTierraDelFuegoPrevio, @idElPalmarPrevio, @idLagoPueloPrevio);
    DELETE FROM Personal.GuiaTrabajaEnParque WHERE IdParque IN (@idIguazuPrevio, @idTierraDelFuegoPrevio, @idElPalmarPrevio, @idLagoPueloPrevio);
    DELETE FROM Personal.Asignacion WHERE IdParque IN (@idIguazuPrevio, @idTierraDelFuegoPrevio, @idElPalmarPrevio, @idLagoPueloPrevio);
    DELETE FROM Parques.Parque WHERE IdParque IN (@idIguazuPrevio, @idTierraDelFuegoPrevio, @idElPalmarPrevio, @idLagoPueloPrevio);

    -- Limpieza total de organizaciones/concesiones
    DELETE FROM Concesiones.PagoConcesion;
    DELETE FROM Concesiones.Concesion;
    DELETE FROM Concesiones.OrganizacionConcesionaria;

    ------------------------------------------------------------------
    -- Setup: dos parques de control con Superficie/CostoHectarea conocidos,
    -- usando los nombres EXACTOS que matchean tras la normalización.
    ------------------------------------------------------------------

    -- 'Parque Nacional Iguazú': cupo del 10% se deja EN CERO a propósito,
    -- vía una concesión dummy previa, para probar LIMITE_HECTAREAS_ALCANZADO.
    INSERT INTO Parques.Parque (Nombre, HorarioCierre, HorarioApertura, Superficie, CostoHectarea, Provincia, Numero, Localidad, TipoParque)
    VALUES ('Parque Nacional Iguazú', '18:00', '08:00', 1000.00, 200.00, 'Misiones', 1, 'Puerto Iguazú', 'Parque Nacional');
    DECLARE @idParqueIguazu INT = SCOPE_IDENTITY();
    -- 10% de 1000.00 = 100.00 ha de límite.

    INSERT INTO Concesiones.OrganizacionConcesionaria (Nombre, TipoActividad, Cuit)
    VALUES ('Organización Dummy Test Cupo', 'Otros', '99999999999');
    DECLARE @idOrgDummy INT = SCOPE_IDENTITY();

    INSERT INTO Concesiones.Concesion (IdParque, IdOrganizacionConcesionaria, CanonMensual, ExtensionConcedida, EstadoConcesion, FechaInicio)
    VALUES (@idParqueIguazu, @idOrgDummy, 1000.00, 100.00, 'Activo', '2020-01-01');
    -- Consume el 100% del cupo de Iguazú (100.00 de 100.00 ha) antes de importar.

    -- 'Parque Nacional Tierra del Fuego': sin concesiones previas, cupo libre.
    INSERT INTO Parques.Parque (Nombre, HorarioCierre, HorarioApertura, Superficie, CostoHectarea, Provincia, Numero, Localidad, TipoParque)
    VALUES ('Parque Nacional Tierra del Fuego', '18:00', '08:00', 500.00, 300.00, 'Tierra del Fuego', 1, 'Ushuaia', 'Parque Nacional');
    DECLARE @idParqueTdF INT = SCOPE_IDENTITY();
    -- 10% de 500.00 = 50.00 ha de límite, sin concesiones previas.

    -- 'Parque Nacional El Palmar' y 'Parque Nacional Lago Puelo' NO se crean:
    -- quedan sin match a propósito.

    ------------------------------------------------------------------
    -- Test 1: estado inicial de organizaciones, limpio.
    -- Resultado esperado: 1 fila (la dummy que acabamos de insertar).
    ------------------------------------------------------------------
    SELECT Test = 1, COUNT(*) AS Cantidad FROM Concesiones.OrganizacionConcesionaria;

    ------------------------------------------------------------------
    -- Test 2: primera importación del archivo.
    -- Resultado esperado: 29 filas (28 CUITs únicos del archivo + la dummy).
    ------------------------------------------------------------------
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

    ------------------------------------------------------------------
    -- Test 5: Tierra del Fuego matcheó (normalización 'P. N.' -> 'Parque
    -- Nacional') y creó una Concesion con toda la extensión disponible.
    -- Resultado esperado: 1 fila, ExtensionConcedida = 50.00.
    ------------------------------------------------------------------
    SELECT Test = 5, c.*
    FROM Concesiones.Concesion c
    WHERE c.IdParque = @idParqueTdF;

    -- Test 6: el canon de Tierra del Fuego tiene recargo por feriados
    -- (contrato 2011-02-01 a 2033-01-31, ~22 años, tiene que haber varios).
    -- Resultado esperado: 1 fila, con CanonMensual > base sin recargo (15000.00)
    -- y por debajo de un techo razonable (22500.00, +50% de margen).
    SELECT Test = 6, CanonMensual,
           CASE WHEN CanonMensual > 15000.00 THEN 1 ELSE 0 END AS SuperaBaseSinRecargo,
           CASE WHEN CanonMensual < 22500.00 THEN 1 ELSE 0 END AS DentroDeTechoRazonable
    FROM Concesiones.Concesion
    WHERE IdParque = @idParqueTdF;

    -- Test 7: Iguazú NO generó concesiones nuevas (cupo consumido por la dummy).
    -- Resultado esperado: 1 fila (solo la dummy que insertamos nosotros).
    SELECT Test = 7, COUNT(*) AS CantidadConcesionesIguazu
    FROM Concesiones.Concesion
    WHERE IdParque = @idParqueIguazu;

    -- Test 8: las dos organizaciones reales de Iguazú sí se crearon/actualizaron
    -- (IGUAZU ARGENTINA S.A. y LA GRAN AVENTURA NÁUTICA SRL), aunque sin concesión.
    -- Resultado esperado: 2 filas.
    SELECT Test = 8, CUIT, Nombre
    FROM Concesiones.OrganizacionConcesionaria
    WHERE CUIT IN ('30716067978', '30717863689');

    -- Test 9: el log persistente registra el límite alcanzado en Iguazú.
    -- Resultado esperado: al menos 1 fila.
    SELECT Test = 9, TipoEvento, Motivo
    FROM Concesiones.LogImportacionConcesionaria
    WHERE NombreArchivo = @rutaArchivo AND TipoEvento = 'LIMITE_HECTAREAS_ALCANZADO';

    -- Test 10: el log persistente registra la concesión creada en Tierra del Fuego.
    -- Resultado esperado: al menos 1 fila. Este test verifica específicamente que
    -- el INSERT de persistencia (paso 8) corre DESPUÉS de crear las concesiones.
    SELECT Test = 10, TipoEvento, CuitOrigen, Motivo
    FROM Concesiones.LogImportacionConcesionaria
    WHERE NombreArchivo = @rutaArchivo AND TipoEvento = 'CONCESION_CREADA';

    -- Test 11: el log persistente registra el sin-match de El Palmar y Lago Puelo.
    -- Resultado esperado: 2 filas (una por cada organización sin parque matcheado).
    SELECT Test = 11, CuitOrigen, Motivo
    FROM Concesiones.LogImportacionConcesionaria
    WHERE NombreArchivo = @rutaArchivo AND TipoEvento = 'SIN_MATCH_PARQUE'
      AND CuitOrigen IN ('30714548847', '30714973408');

    ------------------------------------------------------------------
    -- Test 12: reimportación del mismo archivo (idempotencia).
    -- Resultado esperado: mismas 29 organizaciones, y NINGUNA concesión nueva
    -- (ni en Tierra del Fuego -ya tiene una-, ni en Iguazú -sigue sin cupo-).
    ------------------------------------------------------------------
    EXEC USP_ImportarOrganizacionConcesionaria @rutaArchivo = @rutaArchivo;

    SELECT Test = 12, COUNT(*) AS Cantidad FROM Concesiones.OrganizacionConcesionaria;

    SELECT Test = 12, COUNT(*) AS CantidadConcesionesTdF
    FROM Concesiones.Concesion
    WHERE IdParque = @idParqueTdF;
    -- Debe seguir siendo 1, no 2.

    ------------------------------------------------------------------
    -- Fin de los tests SIN error: se hace ROLLBACK de todos modos
    -- para no dejar nada insertado en la base.
    ------------------------------------------------------------------
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    PRINT 'Suite completa de importación de Organización Concesionaria y Concesion (12 tests) finalizada.';
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

/*
SELECT * FROM Concesiones.OrganizacionConcesionaria
SELECT * FROM Concesiones.Concesion
SELECT * FROM Parques.Parque
*/