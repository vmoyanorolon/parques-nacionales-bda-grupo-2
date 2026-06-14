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
	SET NOCOUNT ON
	SET XACT_ABORT ON

	IF NOT EXISTS(SELECT 1 FROM Turismo.Visitante WHERE IdVisitante = @IdVisitante)
	BEGIN
		RAISERROR('El ID de visitante indicado no existe',16,1)
		RETURN
	END

	DECLARE @FechaReal DATETIME = ISNULL(@Fecha, GETDATE())
	DECLARE @TranPropia BIT = 0

	IF @@TRANCOUNT = 0
	BEGIN
		BEGIN TRANSACTION
		SET @TranPropia = 1
	END
	ELSE
		SAVE TRANSACTION SP_AltaVenta

	BEGIN TRY
		INSERT INTO Ventas.Venta(IdVisitante, Monto, Fecha, MetodoDePago, PuntoDeVenta)
		VALUES(@IdVisitante, 0, @FechaReal, @MetodoDePago, @PuntoDeVenta)
		SELECT @IdVenta = SCOPE_IDENTITY() -- ultimo identity del scope actual

		IF @TranPropia = 1
			COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		IF @TranPropia = 1 AND @@TRANCOUNT > 0
			ROLLBACK TRANSACTION
		ELSE IF XACT_STATE() = 1 -- solo si existe (no es 0) y se pude salvar (no es -1)
			ROLLBACK TRANSACTION SP_AltaVenta
		;THROW -- progago error
	END CATCH
END
GO

-- =============================================
-- SP_AltaLineasDeEntradaActividad (plural)
-- =============================================

/*
DROP PROCEDURE SP_AltaLineaDeEntradaActividad
*/

CREATE OR ALTER PROCEDURE SP_AltaLineasDeEntradaActividad
	@IdVenta INT,
	@Lineas Ventas.TVP_LineaActividad READONLY,
	@Factor DECIMAL(10,4) = 1.0 -- descuento enviado por padre (llamador)
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT ON

	IF NOT EXISTS(SELECT 1 FROM Ventas.Venta WHERE IdVenta = @IdVenta)
	BEGIN
		RAISERROR('La venta indicada no existe',16,1)
		RETURN
	END

	IF NOT EXISTS(SELECT 1 FROM @Lineas) RETURN

	IF EXISTS(SELECT 1 FROM @Lineas WHERE Cantidad <= 0)
	BEGIN
		RAISERROR('Hay líneas de actividad con cantidad menor o igual a cero',16,1)
		RETURN
	END

	-- Existencia de las entradas
	IF EXISTS(
		SELECT 1 FROM @Lineas l
		WHERE NOT EXISTS(SELECT 1 FROM Turismo.EntradaActividad ea WHERE ea.IdEntradaActividad = l.IdEntradaActividad))
	BEGIN
		RAISERROR('Alguna entrada de actividad indicada no existe',16,1)
		RETURN
	END

	-- Validación de cupo
	IF EXISTS(
		SELECT 1
		FROM (
			-- lo que solicitamos en este TVP
			SELECT t.IdTurno, a.CupoMaximo, SUM(l.Cantidad) AS CantSolicitada
			FROM @Lineas l
			INNER JOIN Turismo.EntradaActividad ea ON ea.IdEntradaActividad = l.IdEntradaActividad
			INNER JOIN Turismo.Turno t ON t.IdTurno = ea.IdTurno
			INNER JOIN Turismo.Actividad a ON a.IdActividad = t.IdActividad
			GROUP BY t.IdTurno, a.CupoMaximo
		) sol
		OUTER APPLY (
			-- lo ya vendido del turno en particular (todas sus entradas)
			SELECT ISNULL(SUM(l2.Cantidad),0) AS Ocupada
			FROM Ventas.LineaDeEntradaActividad l2
			INNER JOIN Turismo.EntradaActividad ea2 ON ea2.IdEntradaActividad = l2.IdEntradaActividad
			WHERE ea2.IdTurno = sol.IdTurno
		) oc
		WHERE sol.CantSolicitada + oc.Ocupada > sol.CupoMaximo
	)
	BEGIN
		RAISERROR('Algún turno supera el cupo máximo de la actividad',16,1)
		RETURN
	END

	SAVE TRANSACTION SP_LineasActividad
	BEGIN TRY
		DECLARE @MaxItem INT = (
			SELECT ISNULL(MAX(NumeroDeItem), 0)
			FROM (
				SELECT NumeroDeItem FROM Ventas.LineaDeEntradaParque WHERE IdVenta = @IdVenta
				UNION ALL
				SELECT NumeroDeItem FROM Ventas.LineaDeEntradaActividad WHERE IdVenta = @IdVenta
			) AS Comb
		)

		INSERT INTO Ventas.LineaDeEntradaActividad(IdEntradaActividad, IdVenta, PrecioUnitario, Cantidad, NumeroDeItem)
		SELECT
			l.IdEntradaActividad,
			@IdVenta,
			t.Costo * @Factor,
			l.Cantidad,
			@MaxItem + ROW_NUMBER() OVER (ORDER BY l.IdEntradaActividad) -- + row_number en vez de + 1 por ser TVP
		FROM @Lineas l
		INNER JOIN Turismo.EntradaActividad ea ON ea.IdEntradaActividad = l.IdEntradaActividad
		INNER JOIN Turismo.Turno t ON t.IdTurno = ea.IdTurno

		UPDATE Ventas.Venta
		SET Monto = Monto + ISNULL((
			SELECT SUM(t.Costo * @Factor * l.Cantidad)
			FROM @Lineas l
			INNER JOIN Turismo.EntradaActividad ea ON ea.IdEntradaActividad = l.IdEntradaActividad
			INNER JOIN Turismo.Turno t ON t.IdTurno = ea.IdTurno
		), 0)
		WHERE IdVenta = @IdVenta
	END TRY
	BEGIN CATCH
		IF XACT_STATE() = 1
			ROLLBACK TRANSACTION SP_LineasActividad
		;THROW
	END CATCH
END
GO

-- =============================================
-- SP_AltaLineasDeEntradaParque
-- =============================================

/*
DROP PROCEDURE SP_AltaLineaDeEntradaParque
*/

CREATE OR ALTER PROCEDURE SP_AltaLineasDeEntradaParque
	@IdVenta INT,
	@Lineas Ventas.TVP_LineaParque READONLY,
	@Factor DECIMAL(10,4) = 1.0
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT ON

	IF NOT EXISTS(SELECT 1 FROM Ventas.Venta WHERE IdVenta = @IdVenta)
	BEGIN
		RAISERROR('La venta indicada no existe',16,1)
		RETURN
	END

	IF NOT EXISTS(SELECT 1 FROM @Lineas) RETURN

	-- Cantidades válidas
	IF EXISTS(SELECT 1 FROM @Lineas WHERE Cantidad <= 0)
	BEGIN
		RAISERROR('Hay líneas de parque con cantidad menor o igual a cero',16,1)
		RETURN
	END

	-- Existencia de todas las entradas referenciadas
	IF EXISTS(
		SELECT 1 FROM @Lineas l
		WHERE NOT EXISTS(SELECT 1 FROM Turismo.EntradaParque ep WHERE ep.IdEntradaParque = l.IdEntradaParque))
	BEGIN
		RAISERROR('Alguna entrada de parque indicada no existe',16,1)
		RETURN
	END

	SAVE TRANSACTION SP_LineasParque
	BEGIN TRY
		DECLARE @MaxItem INT = (
			SELECT ISNULL(MAX(NumeroDeItem), 0)
			FROM (
				SELECT NumeroDeItem FROM Ventas.LineaDeEntradaParque WHERE IdVenta = @IdVenta
				UNION ALL
				SELECT NumeroDeItem FROM Ventas.LineaDeEntradaActividad WHERE IdVenta = @IdVenta
			) AS Comb
		)

		INSERT INTO Ventas.LineaDeEntradaParque(IdEntradaParque, IdVenta, PrecioUnitario, Cantidad, NumeroDeItem)
		SELECT
			l.IdEntradaParque,
			@IdVenta,
			ep.Costo * @Factor,
			l.Cantidad,
			@MaxItem + ROW_NUMBER() OVER (ORDER BY l.IdEntradaParque)
		FROM @Lineas l
		INNER JOIN Turismo.EntradaParque ep ON ep.IdEntradaParque = l.IdEntradaParque

		-- Acumulo el monto con los subtotales recién insertados
		UPDATE Ventas.Venta
		SET Monto = Monto + ISNULL((
			SELECT SUM(ep.Costo * @Factor * l.Cantidad)
			FROM @Lineas l
			INNER JOIN Turismo.EntradaParque ep ON ep.IdEntradaParque = l.IdEntradaParque
		), 0)
		WHERE IdVenta = @IdVenta
	END TRY
	BEGIN CATCH
		IF XACT_STATE() = 1
			ROLLBACK TRANSACTION SP_LineasParque
		;THROW
	END CATCH
END
GO
