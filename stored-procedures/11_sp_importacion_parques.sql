-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: Stored Procedure para importar Parques

USE ParquesNacionales
GO

CREATE OR ALTER PROCEDURE USP_ImportarParque
    @rutaArchivo VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    ------------------------------------------------------------------
    -- Staging (carga cruda)
    ------------------------------------------------------------------
    CREATE TABLE #StagingParqueXlsx (
        NroFila             INT IDENTITY(1,1) PRIMARY KEY,
        Provincia           VARCHAR(100),   -- A
        AreaProtegida       VARCHAR(200),   -- B
        AnioCreacion        VARCHAR(50),    -- C
        Region              VARCHAR(100),   -- D
        Superficie          VARCHAR(50),    -- E (HA)
        Latitud             VARCHAR(50),    -- F
        Longitud            VARCHAR(50),    -- G
        Instrumento         VARCHAR(300),   -- H
        Ecorregiones        VARCHAR(300),   -- I
        CatInternacional    VARCHAR(100),   -- J
        EspeciesRegistradas VARCHAR(50),    -- K
        Animales            VARCHAR(50),    -- L
        Bacterias           VARCHAR(50),    -- M
        Hongos              VARCHAR(50),    -- N
        Plantas             VARCHAR(50)     -- O
    );

    INSERT INTO #StagingParqueXlsx
        (Provincia, AreaProtegida, AnioCreacion, Region, Superficie, Latitud, Longitud,
         Instrumento, Ecorregiones, CatInternacional, EspeciesRegistradas, Animales,
         Bacterias, Hongos, Plantas)
    EXEC('
        SELECT *
        FROM OPENROWSET(''Microsoft.ACE.OLEDB.16.0'',
            ''Excel 12.0;Database=' + @rutaArchivo + ';HDR=NO'',
            ''SELECT * FROM [Sheet1$]'')');

    -- Log de esta corrida (se persiste al final y se devuelve como resultado).
    CREATE TABLE #LogCorridaActual (
        TipoEvento  VARCHAR(30),
        ClaveOrigen VARCHAR(200),
        Motivo      VARCHAR(500)
    );

    ------------------------------------------------------------------
    -- 1) Deduplicar dentro del archivo: por Nombre de parque.
    ------------------------------------------------------------------
    SELECT
        s.*,
        LTRIM(RTRIM(ISNULL(s.AreaProtegida,''))) AS NombreCrudo,
        ROW_NUMBER() OVER (
            PARTITION BY LTRIM(RTRIM(ISNULL(s.AreaProtegida,'')))
            ORDER BY s.NroFila DESC
        ) AS Orden
    INTO #Dedup
    FROM #StagingParqueXlsx s
    WHERE NOT (s.AreaProtegida IS NULL AND s.Superficie IS NULL AND s.Provincia IS NULL)
      AND LTRIM(RTRIM(ISNULL(s.AreaProtegida,''))) <> 'Área protegida';  -- fila de encabezado

    INSERT INTO #LogCorridaActual (TipoEvento, ClaveOrigen, Motivo)
    SELECT 'DUPLICADO_INTRAARCHIVO', NombreCrudo,
           'Nombre de parque repetido en el archivo; se utilizó la última aparición.'
    FROM #Dedup
    WHERE Orden > 1;

    ------------------------------------------------------------------
    -- 2) Normalizar los campos sobre los candidatos
    ------------------------------------------------------------------
    SELECT
        d.NombreCrudo AS Nombre,
        -- La provincia viene NULL en las áreas marinas -> valor por defecto = 'Sin Provincia'.
        COALESCE(NULLIF(LTRIM(RTRIM(d.Provincia)), ''), 'Sin Provincia') AS Provincia,
        LTRIM(RTRIM(d.Region)) AS Localidad,
        -- TRY_CAST: si no convierte, queda NULL y lo detecta la validación (paso 3).
        TRY_CAST(REPLACE(LTRIM(RTRIM(d.Superficie)), ',', '.') AS DECIMAL(10,2)) AS Superficie,
        
        CASE
            WHEN d.NombreCrudo LIKE 'Parque Nacional%'           THEN 'Parque Nacional'
            WHEN d.NombreCrudo LIKE 'Monumento Natural%'         THEN 'Monumento Natural'
            WHEN d.NombreCrudo LIKE 'Reserva Nacional%'          THEN 'Reserva Nacional'
            WHEN d.NombreCrudo LIKE 'Reserva Natural Estricta%'  THEN 'Reserva Natural Estricta'
            WHEN d.NombreCrudo LIKE 'Reserva Natural Silvestre%' THEN 'Reserva Natural Silvestre'
            WHEN d.NombreCrudo LIKE 'Reserva Natural Educativa%' THEN 'Reserva Natural Educativa'
            ELSE 'Parque Nacional'  -- Áreas Marinas, Interjurisdiccionales, etc.
        END AS TipoParque
    INTO #CandidatosLimpios
    FROM #Dedup d
    WHERE d.Orden = 1;

    ------------------------------------------------------------------
    -- 3) Validar y acumular los motivos de rechazo por fila.
    --    Si Motivo queda en '' la fila es válida; si no, se rechaza.
    ------------------------------------------------------------------
    SELECT
        cl.*,
        LTRIM(RTRIM(
            ISNULL(CASE WHEN LTRIM(RTRIM(ISNULL(cl.Nombre,''))) = '' THEN 'Nombre vacío. ' END,'') +
            ISNULL(CASE WHEN LEN(cl.Nombre) > 100 THEN 'Nombre excede 100 caracteres. ' END,'') +
            ISNULL(CASE WHEN cl.Superficie IS NULL THEN 'Superficie no numérica o vacía. ' END,'') +
            ISNULL(CASE WHEN cl.Superficie IS NOT NULL AND cl.Superficie <= 0 THEN 'Superficie debe ser mayor a 0. ' END,'') +
            ISNULL(CASE WHEN LTRIM(RTRIM(ISNULL(cl.Provincia,''))) = '' THEN 'Provincia vacía. ' END,'') +
            ISNULL(CASE WHEN LEN(cl.Provincia) > 50 THEN 'Provincia excede 50 caracteres. ' END,'') +
            ISNULL(CASE WHEN LTRIM(RTRIM(ISNULL(cl.Localidad,''))) = '' THEN 'Localidad vacía. ' END,'') +
            ISNULL(CASE WHEN LEN(cl.Localidad) > 50 THEN 'Localidad excede 50 caracteres. ' END,'') +
            ISNULL(CASE WHEN LEN(cl.TipoParque) > 50 THEN 'TipoParque excede 50 caracteres. ' END,'')
        )) AS Motivo
    INTO #Validacion
    FROM #CandidatosLimpios cl;

    INSERT INTO #LogCorridaActual (TipoEvento, ClaveOrigen, Motivo)
    SELECT 'ERROR_VALIDACION', Nombre, Motivo
    FROM #Validacion
    WHERE Motivo <> '';

    -- Solo las filas limpias pasan a la inserción.
    -- Horario y Numero no vienen en el Excel: valores por defecto.
    SELECT
        Nombre,
        Provincia,
        Localidad,
        Superficie,
        TipoParque,
        CAST('08:00:00' AS TIME) AS HorarioApertura,
        CAST('18:00:00' AS TIME) AS HorarioCierre,
        0                        AS Numero
    INTO #Validos
    FROM #Validacion
    WHERE Motivo = '';

    -- Cuento cuántos se van a insertar ANTES del upsert (después ya existirían todos y el conteo daría 0).
    DECLARE @aInsertar INT = (
        SELECT COUNT(*) FROM #Validos v
        WHERE NOT EXISTS (SELECT 1 FROM Parques.Parque p WHERE p.Nombre = v.Nombre COLLATE DATABASE_DEFAULT));

    ------------------------------------------------------------------
    -- 4) Upsert Parques.Parque por Nombre.
    ------------------------------------------------------------------
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Actualiza los parques que ya existen (match por Nombre).
        UPDATE p
            SET p.Superficie = v.Superficie,
                p.Provincia  = v.Provincia,
                p.Localidad  = v.Localidad,
                p.TipoParque = v.TipoParque
        FROM Parques.Parque p
        INNER JOIN #Validos v ON p.Nombre = v.Nombre COLLATE DATABASE_DEFAULT;

        -- Inserta los que no existen.
        INSERT INTO Parques.Parque
            (Nombre, HorarioApertura, HorarioCierre, Superficie, Provincia, Numero, Localidad, TipoParque)
        SELECT
            v.Nombre, v.HorarioApertura, v.HorarioCierre, v.Superficie,
            v.Provincia, v.Numero, v.Localidad, v.TipoParque
        FROM #Validos v
        WHERE NOT EXISTS (
            SELECT 1 FROM Parques.Parque p
            WHERE p.Nombre = v.Nombre COLLATE DATABASE_DEFAULT
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO #LogCorridaActual (TipoEvento, ClaveOrigen, Motivo)
        VALUES ('ERROR_VALIDACION', NULL, 'Error inesperado al aplicar el upsert: ' + ERROR_MESSAGE());
    END CATCH

    ------------------------------------------------------------------
    -- 5) Persistir el log de esta corrida + devolver resumen y detalle.
    ------------------------------------------------------------------
    INSERT INTO Parques.LogImportacionParque (NombreArchivo, TipoEvento, ClaveOrigen, Motivo)
    SELECT @rutaArchivo, TipoEvento, ClaveOrigen, Motivo
    FROM #LogCorridaActual;

    SELECT
        (SELECT COUNT(*) FROM #StagingParqueXlsx)                AS TotalFilasLeidas,
        (SELECT COUNT(*) FROM #Dedup WHERE Orden > 1)            AS DuplicadosIntraArchivo,
        (SELECT COUNT(*) FROM #Validacion WHERE Motivo <> '')    AS RechazadosPorValidacion,
        @aInsertar                                                AS InsertadosEnEstaCorrida,
        (SELECT COUNT(*) FROM #Validos)                          AS TotalValidosProcesados;

    SELECT TipoEvento, ClaveOrigen, Motivo
    FROM #LogCorridaActual
    ORDER BY TipoEvento, ClaveOrigen;

    DROP TABLE #StagingParqueXlsx;
    DROP TABLE #Dedup;
    DROP TABLE #CandidatosLimpios;
    DROP TABLE #Validacion;
    DROP TABLE #Validos;
    DROP TABLE #LogCorridaActual;
END
GO

/*
EXEC USP_ImportarParque @rutaArchivo = 'C:\Users\Usuario\source\repos\parques-nacionales-bda-grupo-2\dml\imports\parques.xlsx'
SELECT * FROM Parques.Parque
DELETE FROM Parques.Parque
*/