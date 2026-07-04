-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: Stored Procedure para importar Parques

USE ParquesNacionales
GO


/* 
    Nominatim (reverse geocoding) es gratuita y no requiere token.
    Referencia: https://nominatim.org/release-docs/develop/api/Reverse/
 
    Devuelve por parámetros de salida la localidad y la provincia que
    corresponden a un par de coordenadas. Si no hay resultado, quedan NULL.
*/
 
CREATE OR ALTER PROCEDURE USP_ObtenerLocalidad
    @Latitud      VARCHAR(50),
    @Longitud     VARCHAR(50),
    @Localidad    VARCHAR(50) OUTPUT,
    @Provincia    VARCHAR(50) OUTPUT,
    @Departamento VARCHAR(50) OUTPUT,
    @CodigoPostal VARCHAR(12) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
 
    -- Rate limit de Nominatim: 1 request/segundo. El delay vive acá adentro,
    -- así cada llamada respeta el límite por sí sola y quien la invoca no
    -- tiene que preocuparse por esperar.
    WAITFOR DELAY '00:00:01';
 
    SET @Localidad    = NULL;
    SET @Provincia    = NULL;
    SET @Departamento = NULL;
    SET @CodigoPostal = NULL;
 
    -- Las coordenadas del dataset usan coma decimal -> la URL necesita punto.
    DECLARE @lat NVARCHAR(50) = REPLACE(@Latitud,  ',', '.');
    DECLARE @lon NVARCHAR(50) = REPLACE(@Longitud, ',', '.');
 
    -- Armado de la URL tal como en el ejemplo de la cátedra.
    DECLARE @ruta NVARCHAR(128) = 'https://nominatim.openstreetmap.org/reverse?';
    DECLARE @url  NVARCHAR(400) = CONCAT(@ruta, 'lat=', @lat, '&lon=', @lon,
                                         '&format=json&addressdetails=1&zoom=10');
 
    DECLARE @Object INT;
    DECLARE @json TABLE (DATA NVARCHAR(MAX));
    DECLARE @respuesta NVARCHAR(MAX);
 
    EXEC sp_OACreate 'MSXML2.XMLHTTP', @Object OUT;
    EXEC sp_OAMethod @Object, 'OPEN', NULL, 'GET', @url, 'FALSE';
    -- Nominatim exige un User-Agent identificable; sin él rechaza con 403.
    EXEC sp_OAMethod @Object, 'setRequestHeader', NULL, 'User-Agent', 'ParquesNacionales-UNLaM-G2/1.0';
    EXEC sp_OAMethod @Object, 'SEND';
    EXEC sp_OAMethod @Object, 'RESPONSETEXT', @respuesta OUTPUT;
 
    INSERT INTO @json
        EXEC sp_OAGetProperty @Object, 'RESPONSETEXT';
 
    EXEC sp_OADestroy @Object;
 
    DECLARE @datos NVARCHAR(MAX) = (SELECT DATA FROM @json);
 
    -- Interpretamos el JSON con OPENJSON, igual que en los ejemplos de la cátedra.
    -- La localidad puede venir en distintos campos según la zona, por eso el COALESCE.
    -- El departamento suele venir en county o state_district; el CP en postcode.
    IF @datos IS NOT NULL AND LEFT(LTRIM(@datos), 1) = '{'
    BEGIN
        SELECT
            @Localidad    = COALESCE(City, Town, Village, County, Municipality),
            @Provincia    = State,
            @Departamento = COALESCE(County, StateDistrict, Municipality),
            @CodigoPostal = Postcode
        FROM OPENJSON(@datos)
        WITH
        (
            City          NVARCHAR(50) '$.address.city',
            Town          NVARCHAR(50) '$.address.town',
            Village       NVARCHAR(50) '$.address.village',
            County        NVARCHAR(50) '$.address.county',
            Municipality  NVARCHAR(50) '$.address.municipality',
            State         NVARCHAR(50) '$.address.state',
            StateDistrict NVARCHAR(50) '$.address.state_district',
            Postcode      NVARCHAR(12) '$.address.postcode'
        );
    END
END
GO
 
/* 
    DECLARE @loc VARCHAR(50), @prov VARCHAR(50);
    EXEC USP_ObtenerLocalidad '-31.69761', '-64.78331', @loc OUTPUT, @prov OUTPUT;
    SELECT @loc AS Localidad, @prov AS Provincia;
*/
 
CREATE OR ALTER PROCEDURE USP_ImportarParque
    @rutaArchivo VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
 
    ------------------------------------------------------------------
    -- Staging (carga cruda)
    ------------------------------------------------------------------
    -- COLLATE DATABASE_DEFAULT en cada columna de texto: el driver ACE.OLEDB
    -- (OPENROWSET sobre el Excel) devuelve los VARCHAR con la collation del
    -- servidor (Latin1_General_CI_AS), que choca con la de la base
    -- (Modern_Spanish_CI_AS). Forzándola acá, todo el staging nace con la
    -- collation de la base y ningún paso posterior (dedup, validación, COALESCE)
    -- vuelve a dar "collation conflict".
    CREATE TABLE #StagingParqueXlsx (
        NroFila             INT IDENTITY(1,1) PRIMARY KEY,
        Provincia           VARCHAR(100) COLLATE DATABASE_DEFAULT,   -- A
        AreaProtegida       VARCHAR(200) COLLATE DATABASE_DEFAULT,   -- B
        AnioCreacion        VARCHAR(50)  COLLATE DATABASE_DEFAULT,   -- C
        Region              VARCHAR(100) COLLATE DATABASE_DEFAULT,   -- D
        Superficie          VARCHAR(50)  COLLATE DATABASE_DEFAULT,   -- E (HA)
        Latitud             VARCHAR(50)  COLLATE DATABASE_DEFAULT,   -- F
        Longitud            VARCHAR(50)  COLLATE DATABASE_DEFAULT,   -- G
        Instrumento         VARCHAR(300) COLLATE DATABASE_DEFAULT,   -- H
        Ecorregiones        VARCHAR(300) COLLATE DATABASE_DEFAULT,   -- I
        CatInternacional    VARCHAR(100) COLLATE DATABASE_DEFAULT,   -- J
        EspeciesRegistradas VARCHAR(50)  COLLATE DATABASE_DEFAULT,   -- K
        Animales            VARCHAR(50)  COLLATE DATABASE_DEFAULT,   -- L
        Bacterias           VARCHAR(50)  COLLATE DATABASE_DEFAULT,   -- M
        Hongos              VARCHAR(50)  COLLATE DATABASE_DEFAULT,   -- N
        Plantas             VARCHAR(50)  COLLATE DATABASE_DEFAULT    -- O
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
    -- 1.bis) Reverse geocoding: completar Localidad (y Provincia faltante)
    --        a partir de Latitud/Longitud, llamando a la API una vez por
    --        parque. El delay de 1 segundo vive dentro de USP_ObtenerLocalidad.
    ------------------------------------------------------------------
    -- Tabla con los parques a geocodificar (solo los candidatos, Orden = 1).
    -- Procesado: marca para recorrer con WHILE sin usar cursores.
    SELECT
        d.NroFila,
        d.NombreCrudo,
        d.Latitud,
        d.Longitud,
        CAST(NULL AS VARCHAR(50)) AS LocalidadApi,
        CAST(NULL AS VARCHAR(50)) AS ProvinciaApi,
        CAST(NULL AS VARCHAR(50)) AS DepartamentoApi,
        CAST(NULL AS VARCHAR(12)) AS CodigoPostalApi,
        CAST(0 AS BIT)            AS Procesado
    INTO #Geo
    FROM #Dedup d
    WHERE d.Orden = 1;
 
    -- Las filas sin coordenadas no se llaman a la API: las marcamos ya procesadas.
    UPDATE #Geo SET Procesado = 1
    WHERE Latitud IS NULL OR Longitud IS NULL;
 
    DECLARE @NroFila INT, @lat VARCHAR(50), @lon VARCHAR(50);
    DECLARE @locApi VARCHAR(50), @provApi VARCHAR(50), @nombre VARCHAR(200);
    DECLARE @deptoApi VARCHAR(50), @cpApi VARCHAR(12);
 
    -- Recorremos fila por fila con WHILE (sin cursores).
    WHILE EXISTS (SELECT 1 FROM #Geo WHERE Procesado = 0)
    BEGIN
        -- Tomamos la próxima fila pendiente.
        SELECT TOP (1)
            @NroFila = NroFila,
            @lat     = Latitud,
            @lon     = Longitud,
            @nombre  = NombreCrudo
        FROM #Geo
        WHERE Procesado = 0
        ORDER BY NroFila;
 
        SET @locApi   = NULL;
        SET @provApi  = NULL;
        SET @deptoApi = NULL;
        SET @cpApi    = NULL;
 
        -- Llamada a la API (SP auxiliar; el delay de 1 seg está adentro).
        -- Si falla una fila, no corta la corrida.
        BEGIN TRY
            EXEC USP_ObtenerLocalidad @lat, @lon,
                 @locApi OUTPUT, @provApi OUTPUT, @deptoApi OUTPUT, @cpApi OUTPUT;
        END TRY
        BEGIN CATCH
            INSERT INTO #LogCorridaActual (TipoEvento, ClaveOrigen, Motivo)
            VALUES ('ERROR_GEOCODING', @nombre,
                    'Falló la llamada a la API: ' + ERROR_MESSAGE());
        END CATCH
 
        -- COLLATE DATABASE_DEFAULT: los valores que devuelve OLE (sp_OAGetProperty)
        -- traen la collation del servidor (Latin1_General_CI_AS) y chocan con la de
        -- la base (Modern_Spanish_CI_AS). Forzamos la de la base acá para que el
        -- COALESCE del paso 2 no dé "collation conflict".
        UPDATE #Geo
        SET LocalidadApi    = @locApi   COLLATE DATABASE_DEFAULT,
            ProvinciaApi    = @provApi  COLLATE DATABASE_DEFAULT,
            DepartamentoApi = @deptoApi COLLATE DATABASE_DEFAULT,
            CodigoPostalApi = @cpApi    COLLATE DATABASE_DEFAULT,
            Procesado       = 1
        WHERE NroFila = @NroFila;
 
        -- Registramos los parques sin localidad (p. ej. áreas marinas).
        IF @locApi IS NULL
            INSERT INTO #LogCorridaActual (TipoEvento, ClaveOrigen, Motivo)
            VALUES ('GEOCODING_SIN_LOCALIDAD', @nombre,
                    'La API no devolvió localidad para estas coordenadas.');
    END
 
    ------------------------------------------------------------------
    -- 2) Normalizar los campos sobre los candidatos
    ------------------------------------------------------------------
    SELECT
        d.NombreCrudo AS Nombre,
        -- Provincia: 1) la del archivo, 2) la que devolvió la API, 3) 'Sin Provincia'.
        COALESCE(
            NULLIF(LTRIM(RTRIM(d.Provincia)), ''),
            NULLIF(LTRIM(RTRIM(g.ProvinciaApi)), ''),
            'Sin Provincia'
        ) AS Provincia,
        -- Localidad: 1) la que devolvió la API, 2) si no hay, la Región del archivo
        --            como respaldo, 3) 'Sin Localidad'.
        COALESCE(
            NULLIF(LTRIM(RTRIM(g.LocalidadApi)), ''),
            NULLIF(LTRIM(RTRIM(d.Region)), ''), -- respaldo: la Región del Excel
            'Sin Localidad'
        ) AS Localidad,
        -- Latitud / Longitud vienen del archivo (TRY_CAST por si trae basura).
        TRY_CAST(REPLACE(LTRIM(RTRIM(d.Latitud)),  ',', '.') AS DECIMAL(9,6)) AS Latitud,
        TRY_CAST(REPLACE(LTRIM(RTRIM(d.Longitud)), ',', '.') AS DECIMAL(9,6)) AS Longitud,
        -- Departamento y CódigoPostal los aporta la API (pueden quedar NULL).
        NULLIF(LTRIM(RTRIM(g.DepartamentoApi)), '') AS Departamento,
        NULLIF(LTRIM(RTRIM(g.CodigoPostalApi)), '') AS CodigoPostal,
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
    LEFT JOIN #Geo g ON g.NroFila = d.NroFila
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
        Latitud,
        Longitud,
        Departamento,
        CodigoPostal,
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
            SET p.Superficie   = v.Superficie,
                p.Provincia    = v.Provincia,
                p.Localidad    = v.Localidad,
                p.TipoParque   = v.TipoParque,
                p.Latitud      = v.Latitud,
                p.Longitud     = v.Longitud,
                p.Departamento = v.Departamento,
                p.CodigoPostal = v.CodigoPostal
        FROM Parques.Parque p
        INNER JOIN #Validos v ON p.Nombre = v.Nombre COLLATE DATABASE_DEFAULT;
 
        -- Inserta los que no existen.
        INSERT INTO Parques.Parque
            (Nombre, HorarioApertura, HorarioCierre, Superficie, Provincia, Numero, Localidad, TipoParque,
             Latitud, Longitud, Departamento, CodigoPostal)
        SELECT
            v.Nombre, v.HorarioApertura, v.HorarioCierre, v.Superficie,
            v.Provincia, v.Numero, v.Localidad, v.TipoParque,
            v.Latitud, v.Longitud, v.Departamento, v.CodigoPostal
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
    DROP TABLE #Geo;
    DROP TABLE #CandidatosLimpios;
    DROP TABLE #Validacion;
    DROP TABLE #Validos;
    DROP TABLE #LogCorridaActual;
END
GO

/*
DROP PROCEDURE USP_ImportarParque
EXEC USP_ImportarParque @rutaArchivo = 'C:\Users\Usuario\source\repos\parques-nacionales-bda-grupo-2\dml\imports\parques.xlsx'
SELECT * FROM Parques.Parque
DELETE FROM Parques.Parque
*/