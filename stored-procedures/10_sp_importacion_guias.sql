-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Fecha: 04/07/2026
-- Descripción: Stored Procedure para importar Guias

USE ParquesNacionales
GO

CREATE OR ALTER PROCEDURE USP_ImportarGuiasCsv
    @rutaArchivo VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    ------------------------------------------------------------------
    -- 0) Staging: carga cruda, tal cual viene el archivo
    ------------------------------------------------------------------
    
    CREATE TABLE #StagingGuia (
        Legajo          VARCHAR(50)  NULL,
        ApellidoNombre  VARCHAR(200) NULL,
        Domicilio       VARCHAR(200) NULL,
        Localidad       VARCHAR(100) NULL,
        Telefonos       VARCHAR(100) NULL,
        Titulo          VARCHAR(200) NULL,   --esto en realidad mapea a Especialidad
        Documento       VARCHAR(50)  NULL,
        Resolucion      VARCHAR(50)  NULL,
        Actualizacion   VARCHAR(50)  NULL,
        AnioInscripcion VARCHAR(50)  NULL,
        ResolReinscrip  VARCHAR(50)  NULL,
        Email           VARCHAR(200) NULL
    );

    DECLARE @rutaSegura VARCHAR(500) = REPLACE(@rutaArchivo, '''', '''''');
    DECLARE @sql NVARCHAR(MAX) = N'
        BULK INSERT #StagingGuia
        FROM ''' + @rutaSegura + N'''
        WITH (
            FORMAT          = ''CSV'',
            FIRSTROW        = 2,
            FIELDTERMINATOR = '';'',
            ROWTERMINATOR   = ''0x0d0a'',
            FIELDQUOTE      = ''"'',
            CODEPAGE        = ''850'',
            KEEPNULLS
        );';
    EXEC SP_executesql @sql;


    -- log para esta corrida (se persiste al final, también se devuelve como resultado)
    
    CREATE TABLE #LogCorridaActual (
        TipoEvento         VARCHAR(30),
        NumeroLegajoOrigen VARCHAR(50),
        NumeroDocumento    VARCHAR(15),
        Motivo             VARCHAR(500)
    );

    ------------------------------------------------------------------
    -- 1) Deduplicar dentro del archivo: por Documento, gana el legajo
    --    más alto (registro más reciente)
    ------------------------------------------------------------------

    SELECT
        s.*,
        LTRIM(RTRIM(ISNULL(s.ApellidoNombre,''))) AS NombreCompleto, --Armado de la columna 'NombreCompleto' totalmente limpia
        ROW_NUMBER() OVER (
            PARTITION BY LTRIM(RTRIM(ISNULL(s.Documento,''))) COLLATE DATABASE_DEFAULT
            ORDER BY TRY_CAST(LTRIM(RTRIM(s.Legajo)) AS INT) DESC --Convierte el led a int pero sin explotar si por algun motivo no es numerico.
        ) AS Orden --window function que agrupa ("particiona") todas las filas que comparten el mismo Documento y, dentro de cada grupo, les asigna un número de orden (1, 2, 3...) según el criterio del ORDER BY
    INTO #Dedup
    FROM #StagingGuia s
    WHERE NOT (s.Legajo IS NULL AND s.ApellidoNombre IS NULL AND s.Documento IS NULL); -- descarta filas en blanco (ej. CRLF final)

    INSERT INTO #LogCorridaActual (TipoEvento, NumeroLegajoOrigen, NumeroDocumento, Motivo)
    SELECT 'DUPLICADO_INTRAARCHIVO', LTRIM(RTRIM(Legajo)), LTRIM(RTRIM(Documento)),
           'Documento repetido en el archivo; se utilizó el registro con legajo más reciente.'
    FROM #Dedup
    WHERE Orden > 1;

    ------------------------------------------------------------------
    -- 2) Parsear Apellido/Nombre sobre los candidatos (Orden = 1)
    ------------------------------------------------------------------

    --En este bloque de codigo se extrae el Nombre y Apellido de aquellos guias que su numero de orden es 1
    SELECT
        d.*,
        CASE
            WHEN RIGHT(ApellidoCrudo,1) = '.' THEN LEFT(ApellidoCrudo, LEN(ApellidoCrudo)-1) --Te devuelve el apellido real limpio
            ELSE ApellidoCrudo
        END AS Apellido,
        NombreCrudo AS Nombre
    INTO #CandidatosLimpios
    FROM (
        SELECT
            d.*,
            CASE WHEN CHARINDEX(',', d.NombreCompleto) > 0 --Pregunto si el nombre completo tiene una coma: Perez, Juan.     
                 THEN LTRIM(RTRIM(LEFT(d.NombreCompleto, CHARINDEX(',', d.NombreCompleto) - 1)))
                 ELSE LTRIM(RTRIM(LEFT(d.NombreCompleto, CHARINDEX(' ', d.NombreCompleto + ' ') - 1)))
            END AS ApellidoCrudo,
            CASE WHEN CHARINDEX(',', d.NombreCompleto) > 0
                 THEN LTRIM(RTRIM(SUBSTRING(d.NombreCompleto, CHARINDEX(',', d.NombreCompleto) + 1, 200)))
                 ELSE LTRIM(RTRIM(SUBSTRING(d.NombreCompleto, CHARINDEX(' ', d.NombreCompleto + ' ') + 1, 200)))
            END AS NombreCrudo
        FROM #Dedup d
        WHERE d.Orden = 1
    ) d;

    ------------------------------------------------------------------
    -- 3) Validar y acumular motivos de rechazo por fila
    --    (el patrón de email debe quedar igual al CHECK de la tabla)
    ------------------------------------------------------------------

    SELECT
        cl.*,
        LTRIM(RTRIM(
            ISNULL(CASE WHEN LTRIM(RTRIM(ISNULL(cl.Documento,''))) = '' THEN 'Documento vacío. ' END,'') +
            ISNULL(CASE WHEN LEN(LTRIM(RTRIM(ISNULL(cl.Documento,'')))) > 15 THEN 'Documento excede 15 caracteres. ' END,'') +
            ISNULL(CASE WHEN ISNULL(cl.Apellido,'') = '' THEN 'No se pudo determinar el apellido. ' END,'') +
            ISNULL(CASE WHEN ISNULL(cl.Nombre,'')   = '' THEN 'No se pudo determinar el nombre. ' END,'') +
            ISNULL(CASE WHEN LEN(cl.Apellido) > 50 THEN 'Apellido excede 50 caracteres. ' END,'') +
            ISNULL(CASE WHEN LEN(cl.Nombre)   > 50 THEN 'Nombre excede 50 caracteres. ' END,'') +
            ISNULL(CASE WHEN LTRIM(RTRIM(ISNULL(cl.Telefonos,''))) = '' THEN 'Teléfono vacío. ' END,'') +
            ISNULL(CASE WHEN LEN(LTRIM(RTRIM(ISNULL(cl.Telefonos,'')))) > 20 THEN 'Teléfono excede 20 caracteres. ' END,'') +
            ISNULL(CASE WHEN LTRIM(RTRIM(ISNULL(cl.Titulo,''))) = '' THEN 'Especialidad vacía. ' END,'') +
            ISNULL(CASE WHEN LEN(LTRIM(RTRIM(ISNULL(cl.Titulo,'')))) > 50 THEN 'Especialidad excede 50 caracteres. ' END,'') +
            ISNULL(CASE WHEN LTRIM(RTRIM(ISNULL(cl.Email,''))) = '' THEN 'Email vacío. ' END,'') +
            ISNULL(CASE WHEN LTRIM(RTRIM(ISNULL(cl.Email,''))) <> '' AND LTRIM(RTRIM(cl.Email)) NOT LIKE '%_@__%.__%' THEN 'Email con formato inválido. ' END,'') +
            ISNULL(CASE WHEN LEN(LTRIM(RTRIM(ISNULL(cl.Email,'')))) > 100 THEN 'Email excede 100 caracteres. ' END,'')
        )) AS Motivo --Acumulo los motivos de error de validacion por fila
    INTO #Validacion
    FROM #CandidatosLimpios cl;

    INSERT INTO #LogCorridaActual (TipoEvento, NumeroLegajoOrigen, NumeroDocumento, Motivo)
    SELECT 'ERROR_VALIDACION', LTRIM(RTRIM(Legajo)), LTRIM(RTRIM(Documento)), Motivo
    FROM #Validacion
    WHERE Motivo <> ''; --Insertamos aquellos registros que tengan al menos un mensaje registrado .

    
    SELECT
        LTRIM(RTRIM(Documento)) AS NumeroDocumento,
        Apellido,
        Nombre,
        LTRIM(RTRIM(Telefonos)) AS Telefono,
        LTRIM(RTRIM(Email))     AS CorreoGuia,
        LTRIM(RTRIM(Titulo))    AS Especialidad,
        'DNI'                   AS TipoDocumento,  -- fijo, sin dato de origen
        1                       AS Edad            -- fijo, sin dato de origen
    INTO #Validos
    FROM #Validacion
    WHERE Motivo = ''; --Insertamos en Validos aquellos donde no tengan motivos de error. Son los verdaderos clean

    ------------------------------------------------------------------
    -- 4) Upsert contra Personal.Guia por NumeroDocumento
    ------------------------------------------------------------------
    SET XACT_ABORT ON;
    
    DECLARE @insertados INT = 0;
    
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE g
            SET g.Telefono       = v.Telefono,
                g.CorreoGuia     = v.CorreoGuia,
                g.TipoDocumento  = v.TipoDocumento,
                g.Edad           = v.Edad,
                g.Apellido       = v.Apellido,
                g.Nombre         = v.Nombre,
                g.Titulo         = NULL,
                g.Especialidad   = v.Especialidad
        FROM Personal.Guia g
        INNER JOIN #Validos v ON g.NumeroDocumento = v.NumeroDocumento COLLATE DATABASE_DEFAULT;

        INSERT INTO Personal.Guia
            (Telefono, CorreoGuia, NumeroDocumento, TipoDocumento, Edad, Apellido, Nombre, Titulo, Especialidad)
        SELECT
            v.Telefono, v.CorreoGuia, v.NumeroDocumento, v.TipoDocumento, v.Edad, v.Apellido, v.Nombre, NULL, v.Especialidad
        FROM #Validos v
        WHERE NOT EXISTS (
            SELECT 1 FROM Personal.Guia g WHERE g.NumeroDocumento = v.NumeroDocumento COLLATE DATABASE_DEFAULT
        );

        SET @insertados = @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO #LogCorridaActual (TipoEvento, Motivo)
        VALUES ('ERROR_VALIDACION', 'Error inesperado al aplicar el upsert: ' + ERROR_MESSAGE());
    END CATCH

    ------------------------------------------------------------------
    -- 5) Persistir el log de esta corrida + devolver resumen y detalle
    ------------------------------------------------------------------
    INSERT INTO Personal.LogImportacionGuia (NombreArchivo, TipoEvento, NumeroLegajoOrigen, NumeroDocumento, Motivo)
    SELECT @rutaArchivo, TipoEvento, NumeroLegajoOrigen, NumeroDocumento, Motivo
    FROM #LogCorridaActual;

    SELECT
        (SELECT COUNT(*) FROM #StagingGuia) AS TotalFilasLeidas,
        (SELECT COUNT(*) FROM #Dedup WHERE Orden > 1) AS DuplicadosIntraArchivo,
        (SELECT COUNT(*) FROM #Validacion WHERE Motivo <> '') AS RechazadosPorValidacion,
         @insertados AS InsertadosEnEstaCorrida,
        (SELECT COUNT(*) FROM #Validos) AS TotalValidosProcesados;

    SELECT TipoEvento, NumeroLegajoOrigen, NumeroDocumento, Motivo
    FROM #LogCorridaActual
    ORDER BY TipoEvento, NumeroLegajoOrigen;
END
GO