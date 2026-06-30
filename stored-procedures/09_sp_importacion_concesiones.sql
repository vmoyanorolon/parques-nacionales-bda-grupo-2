-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: Stored Procedure para importar Organizaciones Concesionarias

USE ParquesNacionales
GO

CREATE OR ALTER PROCEDURE USP_ImportarOrganizacionConcesionaria
    @rutaArchivo VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    ------------------------------------------------------------------
    -- 0) Staging: carga cruda desde el Excel, tal cual viene
    ------------------------------------------------------------------
    CREATE TABLE #StagingConcesionXlsx (
        NroFila  INT IDENTITY(1,1) PRIMARY KEY,
        TipoFila VARCHAR(20),
        Col1     VARCHAR(200),
        Col2     VARCHAR(200),
        Col3     VARCHAR(200),
        Col4     VARCHAR(200),
        Col5     VARCHAR(300),
        Col6     VARCHAR(50),
        Col7     VARCHAR(50)
    );

    INSERT INTO #StagingConcesionXlsx (Col1, Col2, Col3, Col4, Col5, Col6, Col7)
    EXEC('
        SELECT *
        FROM OPENROWSET(''Microsoft.ACE.OLEDB.16.0'',
            ''Excel 12.0;Database=' + @rutaArchivo + ';HDR=NO'',
            ''SELECT * FROM [Hoja1$]'')');

    UPDATE #StagingConcesionXlsx
    SET TipoFila =
        CASE
            WHEN TRIM(Col1) = 'RAZON SOCIAL' THEN 'ENCABEZADO_COL'
            WHEN Col1 IS NOT NULL AND Col2 IS NULL AND Col3 IS NULL THEN 'NOMBRE_PARQUE'
            WHEN Col3 IS NOT NULL THEN 'DATO'
            ELSE 'DESCONOCIDA'
        END;

    -- log para esta ejecución (se persiste al final, también se devuelve como resultado)
    CREATE TABLE #LogEjecucionActual (
        TipoEvento        VARCHAR(30),
        CuitOrigen        VARCHAR(50),
        RazonSocialOrigen VARCHAR(200),
        Motivo            VARCHAR(500)
    );

    ------------------------------------------------------------------
    -- 1) Deduplicar dentro del archivo: por Cuit, gana la primera aparición
    ------------------------------------------------------------------
    SELECT
        TRIM(Col1) AS RazonSocial,
        TRIM(Col3) AS Cuit,
        TRIM(Col5) AS TipoActividad,
        ROW_NUMBER() OVER (PARTITION BY TRIM(Col3) ORDER BY NroFila) AS Orden
    INTO #OrganizacionesLimpias
    FROM #StagingConcesionXlsx
    WHERE TipoFila = 'DATO';

    INSERT INTO #LogEjecucionActual (TipoEvento, CuitOrigen, RazonSocialOrigen, Motivo)
    SELECT 'DUPLICADO', Cuit, RazonSocial,
           'CUIT repetido en el archivo; se utilizó la primera aparición.'
    FROM #OrganizacionesLimpias
    WHERE Orden > 1;

    ------------------------------------------------------------------
    -- 2) Validar y acumular motivos de rechazo por fila
    --    (contra los NOT NULL / largos de OrganizacionConcesionaria)
    ------------------------------------------------------------------
    SELECT
        ol.*,
        LTRIM(RTRIM(
            ISNULL(CASE WHEN LTRIM(RTRIM(ISNULL(ol.Cuit,''))) = '' THEN 'CUIT vacío. ' END,'') +
            ISNULL(CASE WHEN LTRIM(RTRIM(ISNULL(ol.Cuit,''))) <> '' AND LEN(LTRIM(RTRIM(ol.Cuit))) <> 11 THEN 'CUIT debe tener 11 caracteres. ' END,'') +
            ISNULL(CASE WHEN LTRIM(RTRIM(ISNULL(ol.Cuit,''))) <> '' AND LTRIM(RTRIM(ol.Cuit)) LIKE '%[^0-9]%' THEN 'CUIT contiene caracteres no numéricos. ' END,'') +
            ISNULL(CASE WHEN LTRIM(RTRIM(ISNULL(ol.RazonSocial,''))) = '' THEN 'Razón social vacía. ' END,'') +
            ISNULL(CASE WHEN LEN(LTRIM(RTRIM(ISNULL(ol.RazonSocial,'')))) > 50 THEN 'Razón social excede 50 caracteres. ' END,'') +
            ISNULL(CASE WHEN LTRIM(RTRIM(ISNULL(ol.TipoActividad,''))) = '' THEN 'Tipo de actividad vacío. ' END,'') +
            ISNULL(CASE WHEN LEN(LTRIM(RTRIM(ISNULL(ol.TipoActividad,'')))) > 200 THEN 'Tipo de actividad excede 200 caracteres. ' END,'')
        )) AS Motivo
    INTO #Validacion
    FROM #OrganizacionesLimpias ol
    WHERE ol.Orden = 1;

    INSERT INTO #LogEjecucionActual (TipoEvento, CuitOrigen, RazonSocialOrigen, Motivo)
    SELECT 'ERROR_VALIDACION', Cuit, RazonSocial, Motivo
    FROM #Validacion
    WHERE Motivo <> '';

    SELECT Cuit, RazonSocial, TipoActividad
    INTO #Validos
    FROM #Validacion
    WHERE Motivo = '';

    -- contador de nuevos ANTES del upsert (si no, el NOT EXISTS post-insert siempre daría 0)
    DECLARE @aInsertar INT = (
        SELECT COUNT(*) FROM #Validos v
        WHERE NOT EXISTS (
            SELECT 1 FROM Concesiones.OrganizacionConcesionaria oc
            WHERE oc.Cuit = v.Cuit COLLATE DATABASE_DEFAULT
        )
    );

    ------------------------------------------------------------------
    -- 3) Upsert contra Concesiones.OrganizacionConcesionaria por Cuit
    ------------------------------------------------------------------
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE oc
            SET oc.Nombre        = v.RazonSocial,
                oc.TipoActividad = v.TipoActividad
        FROM Concesiones.OrganizacionConcesionaria oc
        INNER JOIN #Validos v ON oc.Cuit = v.Cuit COLLATE DATABASE_DEFAULT;

        INSERT INTO Concesiones.OrganizacionConcesionaria (Cuit, Nombre, TipoActividad)
        SELECT v.Cuit, v.RazonSocial, v.TipoActividad
        FROM #Validos v
        WHERE NOT EXISTS (
            SELECT 1 FROM Concesiones.OrganizacionConcesionaria oc
            WHERE oc.Cuit = v.Cuit COLLATE DATABASE_DEFAULT
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO #LogEjecucionActual (TipoEvento, Motivo)
        VALUES ('ERROR_VALIDACION', 'Error inesperado al aplicar el upsert: ' + ERROR_MESSAGE());
    END CATCH

    ------------------------------------------------------------------
    -- 4) Persistir el log de esta Ejecucion + devolver resumen y detalle
    ------------------------------------------------------------------
    INSERT INTO Concesiones.LogImportacionConcesionaria (NombreArchivo, TipoEvento, CuitOrigen, RazonSocialOrigen, Motivo)
    SELECT @rutaArchivo, TipoEvento, CuitOrigen, RazonSocialOrigen, Motivo
    FROM #LogEjecucionActual;

    SELECT
        (SELECT COUNT(*) FROM #OrganizacionesLimpias)                 AS TotalFilasLeidas,
        (SELECT COUNT(*) FROM #OrganizacionesLimpias WHERE Orden > 1) AS DuplicadosIntraArchivo,
        (SELECT COUNT(*) FROM #Validacion WHERE Motivo <> '')         AS RechazadosPorValidacion,
        @aInsertar                                                    AS InsertadosEnEstaEjecucion,
        (SELECT COUNT(*) FROM #Validos)                               AS TotalValidosProcesados;

    SELECT TipoEvento, CuitOrigen, RazonSocialOrigen, Motivo
    FROM #LogEjecucionActual
    ORDER BY TipoEvento, CuitOrigen;
END
GO