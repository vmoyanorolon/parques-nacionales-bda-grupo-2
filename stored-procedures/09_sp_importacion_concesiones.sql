-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: Stored Procedure para importar Organizaciones Concesionarias

USE ParquesNacionales
GO

------------------------------------------------------------------
-- Concesiones.FN_NormalizarNombreParque
-- Convierte abreviaturas del archivo ('P. N.', 'P.N.', etc.) a la
-- forma canónica 'Parque Nacional X' usada en Parques.Parque.Nombre.
------------------------------------------------------------------
CREATE OR ALTER FUNCTION Concesiones.FN_NormalizarNombreParque(@NombreArchivo VARCHAR(200))
RETURNS VARCHAR(200)
AS
BEGIN

    DECLARE @nombre VARCHAR(200) = LTRIM(RTRIM(@NombreArchivo));
    DECLARE @prefijo VARCHAR(20);

    SELECT TOP(1) @prefijo = Prefijo
    FROM (VALUES ('P. N.'), ('P.N.'), ('PN '), ('P.Nac.'), ('Parque Nac.')) AS Prefijos(Prefijo)
    WHERE @nombre LIKE Prefijo + '%'
    ORDER BY LEN(Prefijo) DESC;

    IF @prefijo IS NOT NULL
        SET @nombre = 'Parque Nacional ' + LTRIM(SUBSTRING(@nombre, LEN(@prefijo) + 1, 200));
    ELSE IF @nombre NOT LIKE 'Parque Nacional%'
        SET @nombre = 'Parque Nacional ' + @nombre;

    RETURN LTRIM(RTRIM(@nombre));
END
GO

------------------------------------------------------------------
-- USP_ObtenerFeriadosAnio
-- Consulta ArgentinaDatos API (gratuita, sin token) y devuelve todos
-- los feriados nacionales de un año en una sola llamada.
------------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_ObtenerFeriadosAnio
    @Anio INT
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#FeriadosAnioResultado') IS NULL
        THROW 50000, 'USP_ObtenerFeriadosAnio requiere que el llamador cree antes la tabla temporal #FeriadosAnioResultado (Fecha DATE, Nombre VARCHAR(100)).', 1;

    DECLARE @url NVARCHAR(200) = CONCAT('https://api.argentinadatos.com/v1/feriados/', @Anio);
    DECLARE @Object INT, @respuesta NVARCHAR(MAX);
    DECLARE @json TABLE (DATA NVARCHAR(MAX));

    EXEC sp_OACreate 'MSXML2.XMLHTTP', @Object OUT;
    EXEC sp_OAMethod @Object, 'OPEN', NULL, 'GET', @url, 'FALSE';
    EXEC sp_OAMethod @Object, 'setRequestHeader', NULL, 'User-Agent', 'ParquesNacionales-UNLaM-G2/1.0';
    EXEC sp_OAMethod @Object, 'SEND';
    INSERT INTO @json EXEC sp_OAGetProperty @Object, 'responseText';
    EXEC sp_OADestroy @Object;
    SET @respuesta = (SELECT DATA FROM @json);

    INSERT INTO #FeriadosAnioResultado (Fecha, Nombre)
    SELECT Fecha, Nombre
    FROM OPENJSON(@respuesta)
    WITH (
        Fecha  DATE         '$.fecha',
        Nombre VARCHAR(100) '$.nombre'
    );
END
GO

------------------------------------------------------------------
-- USP_ObtenerFeriadosEnRango
-- Cuenta los feriados exactos dentro de [@FechaInicio, @FechaFin],
-- recorriendo año por año y descartando lo que cae fuera del rango
------------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_ObtenerFeriadosEnRango
    @FechaInicio      DATE,
    @FechaFin         DATE,
    @CantidadFeriados INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @CantidadFeriados = 0;
    IF @FechaFin < @FechaInicio RETURN;

    CREATE TABLE #FeriadosRango (Fecha DATE, Nombre VARCHAR(100));

    DECLARE @anio INT = YEAR(@FechaInicio);
    DECLARE @anioFin INT = YEAR(@FechaFin);

    WHILE @anio <= @anioFin
    BEGIN
        CREATE TABLE #FeriadosAnioResultado (Fecha DATE, Nombre VARCHAR(100));

        BEGIN TRY
            EXEC USP_ObtenerFeriadosAnio @anio;
        END TRY
        BEGIN CATCH
            -- si falla un año puntual, seguimos con el resto; el total
            -- queda subestimado para ese tramo y se loguea afuera de este SP.
        END CATCH

        INSERT INTO #FeriadosRango (Fecha, Nombre)
        SELECT Fecha, Nombre FROM #FeriadosAnioResultado
        WHERE Fecha BETWEEN @FechaInicio AND @FechaFin;

        DROP TABLE #FeriadosAnioResultado;
        SET @anio += 1;
    END

    SELECT @CantidadFeriados = COUNT(*) FROM #FeriadosRango;
    DROP TABLE #FeriadosRango;
END
GO

------------------------------------------------------------------
-- USP_ImportarOrganizacionConcesionaria
------------------------------------------------------------------
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
        Col7     VARCHAR(50),
        NombreParqueOrigen VARCHAR(200) NULL
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

    -- Cada fila DATO hereda el NOMBRE_PARQUE más reciente por encima de ella
    -- (arrastre hacia adelante por NroFila). El archivo agrupa por secciones:
    -- una fila NOMBRE_PARQUE, seguida de su ENCABEZADO_COL, seguida de N filas DATO.
    UPDATE s
    SET s.NombreParqueOrigen = pq.NombreParqueMasReciente
    FROM #StagingConcesionXlsx s
    CROSS APPLY (
        SELECT TOP(1) Col1 AS NombreParqueMasReciente
        FROM #StagingConcesionXlsx anterior
        WHERE anterior.TipoFila = 'NOMBRE_PARQUE'
          AND anterior.NroFila < s.NroFila
        ORDER BY anterior.NroFila DESC
    ) pq
    WHERE s.TipoFila = 'DATO';

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
        Concesiones.FN_NormalizarNombreParque(NombreParqueOrigen) AS NombreParqueNormalizado,
        TRY_CAST(TRIM(Col6) AS DATE) AS FechaInicio,
        TRY_CAST(TRIM(Col7) AS DATE) AS FechaFin,
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

    -- contador de nuevos ANTES del upsert
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
    -- 4) Agrupar por organización distinta dentro de cada parque:
    --    una Concesion por combinación (Parque, Cuit), sin importar
    --    cuántas filas/actividades tenga esa organización en el
    --    archivo para ese parque. Solo entran organizaciones que ya
    --    pasaron la validación del paso 2 (#Validos)
    ------------------------------------------------------------------
    SELECT
        ol.NombreParqueNormalizado,
        ol.Cuit,
        MIN(ol.FechaInicio) AS FechaInicio,
        MAX(ol.FechaFin)    AS FechaFin,
        COUNT(*)            AS CantidadActividadesEnArchivo
    INTO #OrganizacionesPorParque
    FROM #OrganizacionesLimpias ol
    INNER JOIN #Validos v ON v.Cuit = ol.Cuit COLLATE DATABASE_DEFAULT
    WHERE ol.NombreParqueNormalizado IS NOT NULL
    GROUP BY ol.NombreParqueNormalizado, ol.Cuit;

    -- Fechas inválidas: Desde/Hasta no parseables, o Hasta anterior a Desde.
    INSERT INTO #LogEjecucionActual (TipoEvento, CuitOrigen, RazonSocialOrigen, Motivo)
    SELECT 'ERROR_VALIDACION', opp.Cuit, v.RazonSocial,
           CASE
               WHEN opp.FechaInicio IS NULL THEN 'Fecha de inicio (Desde) no pudo interpretarse como fecha válida.'
               WHEN opp.FechaFin IS NULL THEN 'Fecha de fin (Hasta) no pudo interpretarse como fecha válida.'
               ELSE 'Fecha de fin (Hasta) es anterior a la fecha de inicio.'
           END
    FROM #OrganizacionesPorParque opp
    INNER JOIN #Validos v ON v.Cuit = opp.Cuit COLLATE DATABASE_DEFAULT
    WHERE opp.FechaInicio IS NULL
       OR opp.FechaFin IS NULL
       OR opp.FechaFin < opp.FechaInicio;

    DELETE FROM #OrganizacionesPorParque
    WHERE FechaInicio IS NULL
       OR FechaFin IS NULL
       OR FechaFin < FechaInicio;

    ------------------------------------------------------------------
    -- 5) Resolver IdParque contra Parques.Parque (comparación sin
    --    tildes/mayúsculas) y calcular ExtensionConcedida: 10% de la
    --    Superficie del parque, menos lo ya concedido, repartido entre
    --    las organizaciones NUEVAS de ese parque (las que ya tienen
    --    Concesion ahí no cuentan ni consumen cupo de nuevo).
    ------------------------------------------------------------------
    SELECT
        opp.NombreParqueNormalizado,
        opp.Cuit,
        opp.FechaInicio,
        opp.FechaFin,
        p.IdParque,
        CASE WHEN EXISTS (
            SELECT 1 FROM Concesiones.Concesion c
            INNER JOIN Concesiones.OrganizacionConcesionaria org ON org.IdOrganizacionConcesionaria = c.IdOrganizacionConcesionaria
            WHERE c.IdParque = p.IdParque AND org.Cuit = opp.Cuit COLLATE DATABASE_DEFAULT
        ) THEN 1 ELSE 0 END AS YaTieneConcesion
    INTO #OrganizacionesConParque
    FROM #OrganizacionesPorParque opp
    LEFT JOIN Parques.Parque p
        ON UPPER(TRANSLATE(p.Nombre, 'ÁÉÍÓÚáéíóú', 'AEIOUaeiou'))
         = UPPER(TRANSLATE(opp.NombreParqueNormalizado, 'ÁÉÍÓÚáéíóú', 'AEIOUaeiou'));

    -- Sin match de parque: la organización ya se creó/actualizó en el paso 3,
    -- acá solo dejamos constancia de que no hay concesión posible para ella.
    INSERT INTO #LogEjecucionActual (TipoEvento, CuitOrigen, RazonSocialOrigen, Motivo)
    SELECT 'SIN_MATCH_PARQUE', ocp.Cuit, v.RazonSocial,
           CONCAT('No se encontró el parque ''', ocp.NombreParqueNormalizado, ''' en Parques.Parque; se creó/actualizó solo la organización.')
    FROM #OrganizacionesConParque ocp
    INNER JOIN #Validos v ON v.Cuit = ocp.Cuit COLLATE DATABASE_DEFAULT
    WHERE ocp.IdParque IS NULL;

    -- Parques con al menos una organización nueva (matcheada, sin Concesion previa).
    SELECT DISTINCT ocp.IdParque
    INTO #ParquesConNuevas
    FROM #OrganizacionesConParque ocp
    WHERE ocp.IdParque IS NOT NULL AND ocp.YaTieneConcesion = 0;

    SELECT
        pcn.IdParque,
        p.Superficie * 0.10 AS LimiteHectareas,
        ISNULL((SELECT SUM(c.ExtensionConcedida) FROM Concesiones.Concesion c WHERE c.IdParque = pcn.IdParque), 0) AS YaConcedidas,
        (SELECT COUNT(*) FROM #OrganizacionesConParque x WHERE x.IdParque = pcn.IdParque AND x.YaTieneConcesion = 0) AS CantidadOrgsNuevas
    INTO #ResumenPorParque
    FROM #ParquesConNuevas pcn
    INNER JOIN Parques.Parque p ON p.IdParque = pcn.IdParque;

    ALTER TABLE #ResumenPorParque ADD Disponible DECIMAL(10,2), ExtensionPorConcesion DECIMAL(10,2);

    UPDATE #ResumenPorParque SET Disponible = LimiteHectareas - YaConcedidas;

    UPDATE #ResumenPorParque
    SET ExtensionPorConcesion = CASE WHEN Disponible > 0 AND CantidadOrgsNuevas > 0
                                      THEN Disponible / CantidadOrgsNuevas END;

    INSERT INTO #LogEjecucionActual (TipoEvento, Motivo)
    SELECT 'LIMITE_HECTAREAS_ALCANZADO',
           CONCAT('IdParque=', IdParque, ' sin cupo disponible (límite 10%: ', LimiteHectareas,
                  ' ha, ya concedidas: ', YaConcedidas, ' ha) para ', CantidadOrgsNuevas, ' organización(es) nueva(s).')
    FROM #ResumenPorParque
    WHERE Disponible <= 0;

    ALTER TABLE #OrganizacionesConParque ADD ExtensionConcedida DECIMAL(10,2);

    UPDATE ocp
    SET ocp.ExtensionConcedida = rp.ExtensionPorConcesion
    FROM #OrganizacionesConParque ocp
    INNER JOIN #ResumenPorParque rp ON rp.IdParque = ocp.IdParque
    WHERE ocp.YaTieneConcesion = 0;

    ------------------------------------------------------------------
    -- 6) CanonMensual = ExtensionConcedida × CostoHectarea × (1 + feriados exactos en el rango Desde-Hasta / días del contrato)
    ------------------------------------------------------------------
    ALTER TABLE #OrganizacionesConParque ADD CanonMensual DECIMAL(10,2), CantidadFeriados INT, Procesado BIT NOT NULL DEFAULT(0);

    UPDATE #OrganizacionesConParque
    SET Procesado = 1
    WHERE YaTieneConcesion = 1 OR ExtensionConcedida IS NULL;
    -- ya tienen concesión o no tienen cupo: no calculan canon, quedan marcadas para no entrar al loop

    DECLARE @cuitActual VARCHAR(11), @idParqueActual INT, @fechaInicioActual DATE, @fechaFinActual DATE;
    DECLARE @feriadosContrato INT, @diasContrato INT, @extensionActual DECIMAL(10,2), @costoHectareaActual DECIMAL(10,2);

    WHILE EXISTS (SELECT 1 FROM #OrganizacionesConParque WHERE Procesado = 0)
    BEGIN
        SELECT TOP(1)
            @cuitActual = ocp.Cuit, @idParqueActual = ocp.IdParque,
            @fechaInicioActual = ocp.FechaInicio, @fechaFinActual = ocp.FechaFin,
            @extensionActual = ocp.ExtensionConcedida, @costoHectareaActual = p.CostoHectarea
        FROM #OrganizacionesConParque ocp
        INNER JOIN Parques.Parque p ON p.IdParque = ocp.IdParque
        WHERE ocp.Procesado = 0;

        SET @feriadosContrato = NULL;

        BEGIN TRY
            EXEC USP_ObtenerFeriadosEnRango @fechaInicioActual, @fechaFinActual, @feriadosContrato OUTPUT;
        END TRY
        BEGIN CATCH
            INSERT INTO #LogEjecucionActual (TipoEvento, CuitOrigen, Motivo)
            VALUES ('ERROR_FERIADOS', @cuitActual, 'Falló el cálculo de feriados para el canon: ' + ERROR_MESSAGE());
        END CATCH

        SET @feriadosContrato = ISNULL(@feriadosContrato, 0);
        SET @diasContrato = DATEDIFF(DAY, @fechaInicioActual, @fechaFinActual) + 1;

        UPDATE #OrganizacionesConParque
        SET CantidadFeriados = @feriadosContrato,
            CanonMensual = @extensionActual * @costoHectareaActual
                * (1 + CAST(@feriadosContrato AS DECIMAL(10,4)) / @diasContrato),
            Procesado = 1
        WHERE Cuit = @cuitActual COLLATE DATABASE_DEFAULT AND IdParque = @idParqueActual;
    END

    ------------------------------------------------------------------
    -- 7) INSERT final a Concesiones.Concesion: solo organizaciones
    --    nuevas que efectivamente calcularon ExtensionConcedida y
    --    CanonMensual. Las sin match de parque, sin cupo, o que ya
    --    tenían Concesion, quedan afuera (ya logueadas en pasos 5/6).
    ------------------------------------------------------------------
    BEGIN TRY
        INSERT INTO Concesiones.Concesion
            (IdParque, IdOrganizacionConcesionaria, CanonMensual, ExtensionConcedida, EstadoConcesion, FechaInicio, FechaFin)
        SELECT
            ocp.IdParque,
            org.IdOrganizacionConcesionaria,
            ocp.CanonMensual,
            ocp.ExtensionConcedida,
            'Activo',
            ocp.FechaInicio,
            ocp.FechaFin
        FROM #OrganizacionesConParque ocp
        INNER JOIN Concesiones.OrganizacionConcesionaria org ON org.Cuit = ocp.Cuit COLLATE DATABASE_DEFAULT
        WHERE ocp.YaTieneConcesion = 0
          AND ocp.ExtensionConcedida IS NOT NULL
          AND ocp.CanonMensual IS NOT NULL;

        INSERT INTO #LogEjecucionActual (TipoEvento, CuitOrigen, RazonSocialOrigen, Motivo)
        SELECT 'CONCESION_CREADA', ocp.Cuit, v.RazonSocial,
               CONCAT('Concesión creada en IdParque=', ocp.IdParque, ': ', ocp.ExtensionConcedida,
                      ' ha, canon $', ocp.CanonMensual, '/mes (', ocp.CantidadFeriados, ' feriados en el contrato).')
        FROM #OrganizacionesConParque ocp
        INNER JOIN #Validos v ON v.Cuit = ocp.Cuit COLLATE DATABASE_DEFAULT
        WHERE ocp.YaTieneConcesion = 0
          AND ocp.ExtensionConcedida IS NOT NULL
          AND ocp.CanonMensual IS NOT NULL;
    END TRY
    BEGIN CATCH
        INSERT INTO #LogEjecucionActual (TipoEvento, Motivo)
        VALUES ('ERROR_VALIDACION', 'Error inesperado al crear las concesiones: ' + ERROR_MESSAGE());
    END CATCH

    ------------------------------------------------------------------
    -- 8) Persistir el log de esta ejecución + devolver resumen y detalle.
    --    Va al final a propósito: tiene que correr después de TODOS los
    --    pasos que insertan en #LogEjecucionActual (4 a 7), si no los
    --    eventos posteriores a este punto nunca llegan a la tabla real.
    ------------------------------------------------------------------
    INSERT INTO Concesiones.LogImportacionConcesionaria (NombreArchivo, TipoEvento, CuitOrigen, RazonSocialOrigen, Motivo)
    SELECT @rutaArchivo, TipoEvento, CuitOrigen, RazonSocialOrigen, Motivo
    FROM #LogEjecucionActual;

    SELECT
        (SELECT COUNT(*) FROM #OrganizacionesLimpias)                 AS TotalFilasLeidas,
        (SELECT COUNT(*) FROM #OrganizacionesLimpias WHERE Orden > 1) AS DuplicadosIntraArchivo,
        (SELECT COUNT(*) FROM #Validacion WHERE Motivo <> '')         AS RechazadosPorValidacion,
        @aInsertar                                                    AS InsertadosEnEstaEjecucion,
        (SELECT COUNT(*) FROM #Validos)                               AS TotalValidosProcesados,
        (SELECT COUNT(*) FROM #OrganizacionesConParque
         WHERE YaTieneConcesion = 0 AND ExtensionConcedida IS NOT NULL AND CanonMensual IS NOT NULL) AS ConcesionesCreadas;

    SELECT TipoEvento, CuitOrigen, RazonSocialOrigen, Motivo
    FROM #LogEjecucionActual
    ORDER BY TipoEvento, CuitOrigen;
END
GO