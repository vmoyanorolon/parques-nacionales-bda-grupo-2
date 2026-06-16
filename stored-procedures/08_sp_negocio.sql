-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: Stored Procedures sobre lógica de negocio

USE ParquesNacionales
GO

-- =============================================
-- SP_RegistrarVentaEntradaMasiva
-- Abre UNA transacción, calcula el descuento y delega creacion a los SPs.
-- =============================================
/*
DROP PROCEDURE SP_RegistrarVentaEntradaMasiva
*/

CREATE OR ALTER PROCEDURE SP_RegistrarVentaEntradaMasiva
	@IdVisitante INT,
	@MetodoDePago VARCHAR(20),
	@PuntoDeVenta VARCHAR(20),
	@LineasParque Ventas.TVP_LineaParque READONLY,
	@LineasActividad Ventas.TVP_LineaActividad READONLY,
	@Fecha DATETIME = NULL,
	@IdVenta INT OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT ON

	DECLARE @errores VARCHAR(2048) = ''

	IF NOT EXISTS(SELECT 1 FROM Turismo.Visitante WHERE IdVisitante = @IdVisitante)
		SET @errores += '- El ID de visitante indicado no existe.' + CHAR(13)

	-- Al menos una línea válida
	IF NOT EXISTS(SELECT 1 FROM @LineasParque)
	   AND NOT EXISTS(SELECT 1 FROM @LineasActividad)
		SET @errores += '- La venta debe incluir al menos una línea de entrada.' + CHAR(13)

	IF @errores <> ''
	BEGIN
		SET @errores = 'No se pudo registrar la venta:' + CHAR(13) + @errores
		THROW 50000, @errores, 1
	END

	-- Descuento del tipo de visitante (0 si no tiene)
	DECLARE @Descuento TINYINT
	SELECT @Descuento = ISNULL(tv.Descuento, 0)
	FROM Turismo.Visitante v
	LEFT JOIN Turismo.TipoVisitante tv ON tv.IdTipoVisitante = v.IdTipoVisitante
	WHERE v.IdVisitante = @IdVisitante

	DECLARE @Factor DECIMAL(10,4) = 1.0 - (@Descuento / 100.0)

	BEGIN TRANSACTION
	BEGIN TRY
		EXEC SP_AltaVenta @IdVisitante, @Fecha, @MetodoDePago, @PuntoDeVenta, @IdVenta = @IdVenta OUTPUT
		EXEC SP_AltaLineasDeEntradaParque @IdVenta, @LineasParque, @Factor
		EXEC SP_AltaLineasDeEntradaActividad @IdVenta, @LineasActividad, @Factor

		COMMIT TRANSACTION
		PRINT 'La venta ' + CAST(@IdVenta AS VARCHAR) + ' fue registrada con éxito (descuento ' + CAST(@Descuento AS VARCHAR) + '%)'
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
		;THROW
	END CATCH
END
GO

-- =============================================
-- SP_AsignarGuiaATour
-- =============================================
/*
DROP PROCEDURE SP_AsignarGuiaATour;
*/
CREATE OR ALTER PROCEDURE SP_AsignarGuiaATour
    @IdGuia INT,
    @IdActividad INT,
    @DiasVigentes INT,
    @FechaInicio DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @FechaInicio IS NULL SET @FechaInicio = CAST(GETDATE() AS DATE);

    DECLARE @errores VARCHAR(2048) = '';
    DECLARE @Tipo VARCHAR(9), @IdParqueActividad INT;

    SELECT @Tipo = Tipo, @IdParqueActividad = IdParque
    FROM Turismo.Actividad
    WHERE IdActividad = @IdActividad;

    -- Validaciones independientes (se pueden acumular)
    IF NOT EXISTS (SELECT 1 FROM Personal.Guia WHERE IdGuia = @IdGuia)
        SET @errores += '- El guía indicado no existe.' + CHAR(13);

    IF @DiasVigentes <= 0
        SET @errores += '- Los días vigentes deben ser mayores a 0.' + CHAR(13);

    IF @Tipo IS NULL
        SET @errores += '- La actividad indicada no existe.' + CHAR(13);
    ELSE IF @Tipo <> 'Tour'
        -- Solo tiene sentido evaluar el tipo si la actividad existe (si no, @Tipo es NULL)
        SET @errores += '- La actividad no es de tipo Tour.' + CHAR(13);

    -- El guía debe trabajar en el parque de la actividad.
    -- Solo se puede evaluar si la actividad existe (necesitamos su parque).
    IF @IdParqueActividad IS NOT NULL
       AND NOT EXISTS (
            SELECT 1 FROM Personal.GuiaTrabajaEnParque
            WHERE IdGuia = @IdGuia AND IdParque = @IdParqueActividad)
        SET @errores += '- El guía no trabaja en el parque de esta actividad.' + CHAR(13);

    -- Evitar habilitación vigente duplicada para la misma actividad
    IF EXISTS (
        SELECT 1 FROM Personal.Habilitacion
        WHERE IdGuia = @IdGuia
          AND IdActividad = @IdActividad
          AND DATEADD(DAY, DiasVigentes, FechaInicio) >= CAST(GETDATE() AS DATE))
        SET @errores += '- El guía ya tiene una habilitación vigente para esta actividad.' + CHAR(13);

    IF @errores <> ''
    BEGIN
        SET @errores = 'No se pudo asignar el guía al tour:' + CHAR(13) + @errores;
        THROW 50000, @errores, 1;
    END

    BEGIN TRY
        INSERT INTO Personal.Habilitacion (FechaInicio, DiasVigentes, IdGuia, IdActividad)
        VALUES (@FechaInicio, @DiasVigentes, @IdGuia, @IdActividad);

        PRINT 'Habilitación registrada correctamente.';
    END TRY
    BEGIN CATCH
        DECLARE @Msg NVARCHAR(2048) = ERROR_MESSAGE();
        RAISERROR(@Msg, 16, 1);
    END CATCH
END
GO

-- =============================================
-- SP_RegistrarPagoConcesion
-- =============================================

/*
DROP PROCEDURE SP_RegistrarPagoConcesion
*/

CREATE OR ALTER PROCEDURE SP_RegistrarPagoConcesion
    @IdConcesion INT,
    @Monto DECIMAL(10,2),
    @Fecha DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Fecha IS NULL SET @Fecha = GETDATE();

    DECLARE @errores VARCHAR(2048) = '';
    DECLARE @Estado VARCHAR(8), @Canon DECIMAL(10,2),
            @FechaInicio DATE, @FechaFin DATE;

    SELECT @Estado = EstadoConcesion,
           @Canon = CanonMensual,
           @FechaInicio = FechaInicio,
           @FechaFin = FechaFin
    FROM Concesiones.Concesion
    WHERE IdConcesion = @IdConcesion;

    -- Validaciones previas
    IF @Estado IS NULL
        SET @errores += '- La concesión indicada no existe.' + CHAR(13);
    ELSE IF @Estado <> 'Activo'
        -- Solo evaluable si la concesión existe
        SET @errores += '- La concesión no está activa. No se puede registrar el pago.' + CHAR(13);

    IF @Monto <= 0
        SET @errores += '- El monto debe ser mayor a cero.' + CHAR(13);

    IF @errores <> ''
    BEGIN
        SET @errores = 'No se pudo registrar el pago de la concesión:' + CHAR(13) + @errores;
        THROW 50000, @errores, 1;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO Concesiones.PagoConcesion (IdConcesion, Fecha, Monto)
        VALUES (@IdConcesion, @Fecha, @Monto);

        /*
            Cálculo de pagos atrasados:
            meses transcurridos desde el inicio (acotado a la fecha fin si existe)
            vs. cantidad de pagos ya registrados.
        */

        DECLARE @FechaCorte DATE = CASE
            WHEN @FechaFin IS NOT NULL AND @FechaFin < CAST(@Fecha AS DATE)
            THEN @FechaFin ELSE CAST(@Fecha AS DATE) END;

        DECLARE @MesesEsperados INT =
            DATEDIFF(MONTH, @FechaInicio, @FechaCorte) + 1;

        DECLARE @PagosRealizados INT =
            (SELECT COUNT(*) FROM Concesiones.PagoConcesion WHERE IdConcesion = @IdConcesion);

        DECLARE @PagosAtrasados INT =
            CASE WHEN @MesesEsperados - @PagosRealizados > 0
                 THEN @MesesEsperados - @PagosRealizados ELSE 0 END;

        COMMIT TRANSACTION;

        PRINT 'Pago registrado correctamente.';

        IF @PagosAtrasados > 0
            PRINT 'La concesión tiene ' + CAST(@PagosAtrasados AS VARCHAR(10)) + ' pago(s) mensual(es) atrasado(s).';
        ELSE
            PRINT 'La concesión se encuentra al día.';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        DECLARE @Msg NVARCHAR(2048) = ERROR_MESSAGE();
        RAISERROR(@Msg, 16, 1);
    END CATCH
END
GO

-- =============================================
-- SP_ActualizarPrecioEntrada
-- Actualiza el costo de las entradas (EntradaParque) de un parque.
-- =============================================

/*
DROP PROCEDURE SP_ActualizarPrecioEntrada
*/

CREATE OR ALTER PROCEDURE SP_ActualizarPrecioEntrada
    @IdParque INT,
    @NuevoCosto DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores VARCHAR(2048) = '';

    IF NOT EXISTS (SELECT 1 FROM Parques.Parque WHERE IdParque = @IdParque)
        SET @errores += '- El parque indicado no existe.' + CHAR(13);

    IF @NuevoCosto <= 0
        SET @errores += '- El nuevo costo debe ser mayor a cero.' + CHAR(13);

    -- Solo evaluable si el parque existe (si no, igual no tendría entradas)
    IF EXISTS (SELECT 1 FROM Parques.Parque WHERE IdParque = @IdParque)
       AND NOT EXISTS (SELECT 1 FROM Turismo.EntradaParque WHERE IdParque = @IdParque)
        SET @errores += '- El parque no tiene entradas registradas para actualizar.' + CHAR(13);

    IF @errores <> ''
    BEGIN
        SET @errores = 'No se pudo actualizar el precio de las entradas:' + CHAR(13) + @errores;
        THROW 50000, @errores, 1;
    END

    BEGIN TRY
        UPDATE Turismo.EntradaParque
        SET Costo = @NuevoCosto
        WHERE IdParque = @IdParque;

        PRINT 'Se actualizaron ' + CAST(@@ROWCOUNT AS VARCHAR(10))
              + ' entrada(s) del parque.';
    END TRY
    BEGIN CATCH
        DECLARE @Msg NVARCHAR(2048) = ERROR_MESSAGE();
        RAISERROR(@Msg, 16, 1);
    END CATCH
END
GO