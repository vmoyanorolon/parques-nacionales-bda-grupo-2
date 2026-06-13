-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: Stored Procedures del esquema Ventas

USE ParquesNacionales
GO

-- =============================================
-- SP_AltaVenta
-- =============================================
/*
DROP PROCEDURE SP_AltaVenta
*/
CREATE OR ALTER PROCEDURE SP_AltaVenta
	@IdVisitante INT,
	@Fecha DATETIME = NULL,
	@MetodoDePago VARCHAR(20),
	@PuntoDeVenta VARCHAR(20),
	@IdVenta INT OUTPUT
AS
BEGIN
	DECLARE @FechaReal DATETIME

	IF NOT EXISTS(SELECT 1 FROM Turismo.Visitante WHERE IdVisitante = @IdVisitante)
	BEGIN
		RAISERROR('El ID de visitante indicado no existe',16,1)
		RETURN
	END

	SELECT @FechaReal = ISNULL(@Fecha, GETDATE())

	BEGIN TRANSACTION
	BEGIN TRY
		INSERT INTO Ventas.Venta(IdVisitante,Monto,Fecha,MetodoDePago,PuntoDeVenta)
		VALUES(@IdVisitante,0,@FechaReal,@MetodoDePago,@PuntoDeVenta)
		SELECT @IdVenta = SCOPE_IDENTITY()

		COMMIT TRANSACTION
		PRINT 'La venta ' + CAST(@IdVenta AS VARCHAR) + ' fue dada de alta con éxito'

	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION
		PRINT 'Error: ' + ERROR_MESSAGE()
	END CATCH
END
GO

-- =============================================
-- SP_AltaLineaDeEntradaActividad
-- =============================================
/*
DROP PROCEDURE SP_AltaLineaDeEntradaActividad
*/
CREATE OR ALTER PROCEDURE SP_AltaLineaDeEntradaActividad
	@IdVenta INT,
	@IdEntradaActividad INT,
	@Cantidad TINYINT
AS
BEGIN
	DECLARE @IdLineaDeEntradaActividad INT
	DECLARE @PrecioUnitario DECIMAL(10,2)
	DECLARE @NumeroDeItem TINYINT
	DECLARE @CantidadMaxima INT
	DECLARE @CantidadOcupada INT

	IF NOT EXISTS(
		SELECT IdVenta FROM Ventas.Venta WHERE IdVenta = @IdVenta
	)
	BEGIN
		RAISERROR('La venta indicada no existe',16,1)
		RETURN
	END

	IF NOT EXISTS(
		SELECT @IdEntradaActividad FROM Turismo.EntradaActividad WHERE IdEntradaActividad = @IdEntradaActividad
	)
	BEGIN
		RAISERROR('La entrada a la actividad indicada no existe',16,1)
		RETURN
	END

	-- Me traigo el cupo máximo de la actividad, su costo y la cantidad que ya se ocupó
	SELECT	@CantidadMaxima = a.CupoMaximo,
			@CantidadOcupada = ISNULL(SUM(l.Cantidad), 0),
			@PrecioUnitario = t.Costo 
	FROM Turismo.EntradaActividad ea
	INNER JOIN Turismo.Turno t ON t.IdTurno = ea.IdTurno
	INNER JOIN Turismo.Actividad a ON a.IdActividad = t.IdActividad
	LEFT JOIN Ventas.LineaDeEntradaActividad l ON l.IdEntradaActividad = ea.IdEntradaActividad
	WHERE ea.IdEntradaActividad = @IdEntradaActividad
	GROUP BY a.CupoMaximo, t.Costo

	IF @Cantidad + @CantidadOcupada > @CantidadMaxima
	BEGIN
		RAISERROR('La cantidad indicada supera la cantidad de cupos disponibles',16,1)
		RETURN
	END

	-- Busco el mayor número de item existente y le sumo 1 para obtener el número de item de esta línea
	SELECT @NumeroDeItem = ISNULL(MAX(NumeroDeItem), 0) + 1
	FROM (
		SELECT NumeroDeItem FROM Ventas.LineaDeEntradaActividad WHERE IdVenta = @IdVenta
		UNION ALL
		SELECT NumeroDeItem FROM Ventas.LineaDeEntradaParque WHERE IdVenta = @IdVenta
	) AS LineasCombinadas

	BEGIN TRANSACTION
	BEGIN TRY
		INSERT INTO Ventas.LineaDeEntradaActividad(IdEntradaActividad, IdVenta, PrecioUnitario, Cantidad, NumeroDeItem)
		VALUES(@IdEntradaActividad, @IdVenta, @PrecioUnitario, @Cantidad, @NumeroDeItem)
		SELECT @IdLineaDeEntradaActividad = SCOPE_IDENTITY()

		UPDATE Ventas.Venta
		SET Monto = Monto + (@PrecioUnitario * @Cantidad)
		WHERE IdVenta = @IdVenta

		COMMIT TRANSACTION
		PRINT 'La línea de entrada a actividad ' + CAST(@IdLineaDeEntradaActividad AS VARCHAR) + ' fue agregada con éxito'

	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION
		PRINT 'Error: ' + ERROR_MESSAGE()
	END CATCH
END
GO

-- =============================================
-- SP_AltaLineaDeEntradaParque
-- =============================================
/*
DROP PROCEDURE SP_AltaLineaDeEntradaParque
*/
CREATE OR ALTER PROCEDURE SP_AltaLineaDeEntradaParque
	@IdVenta INT,
	@IdEntradaParque INT,
	@Cantidad TINYINT
AS
BEGIN
	DECLARE @IdLineaDeEntradaParque INT
	DECLARE @PrecioUnitario DECIMAL(10,2)
	DECLARE @NumeroDeItem TINYINT

	IF NOT EXISTS(
		SELECT IdVenta FROM Ventas.Venta WHERE IdVenta = @IdVenta
	)
	BEGIN
		RAISERROR('La venta indicada no existe',16,1)
		RETURN
	END

	IF NOT EXISTS(
		SELECT @IdEntradaParque FROM Turismo.EntradaParque WHERE IdEntradaParque = @IdEntradaParque
	)
	BEGIN
		RAISERROR('La entrada al parque indicado no existe',16,1)
		RETURN
	END

	-- Me traigo el costo de la entrada al parque
	SELECT	@PrecioUnitario = Costo 
	FROM Turismo.EntradaParque
	WHERE IdEntradaParque = @IdEntradaParque

	-- Busco el mayor número de item existente y le sumo 1 para obtener el número de item de esta línea
	SELECT @NumeroDeItem = ISNULL(MAX(NumeroDeItem), 0) + 1
	FROM (
		SELECT NumeroDeItem FROM Ventas.LineaDeEntradaActividad WHERE IdVenta = @IdVenta
		UNION ALL
		SELECT NumeroDeItem FROM Ventas.LineaDeEntradaParque WHERE IdVenta = @IdVenta
	) AS LineasCombinadas

	BEGIN TRANSACTION
	BEGIN TRY
		INSERT INTO Ventas.LineaDeEntradaParque(IdEntradaParque, IdVenta, PrecioUnitario, Cantidad, NumeroDeItem)
		VALUES(@IdEntradaParque, @IdVenta, @PrecioUnitario, @Cantidad, @NumeroDeItem)
		SELECT @IdLineaDeEntradaParque = SCOPE_IDENTITY()

		UPDATE Ventas.Venta
		SET Monto = Monto + (@PrecioUnitario * @Cantidad)
		WHERE IdVenta = @IdVenta

		COMMIT TRANSACTION
		PRINT 'La línea de entrada a parque ' + CAST(@IdLineaDeEntradaParque AS VARCHAR) + ' fue agregada con éxito'

	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION
		PRINT 'Error: ' + ERROR_MESSAGE()
	END CATCH
END
GO