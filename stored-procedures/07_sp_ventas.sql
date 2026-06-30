-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: Stored Procedures del esquema Ventas

USE ParquesNacionales
GO

-- =============================================
-- USP_AltaVenta
-- =============================================

/*
DROP PROCEDURE USP_AltaVenta
*/

CREATE OR ALTER PROCEDURE USP_AltaVenta
	@IdVisitante INT,
	@Fecha DATETIME = NULL,
	@MetodoDePago VARCHAR(20),
	@PuntoDeVenta VARCHAR(20),
	@IdVenta INT OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT ON

	DECLARE @errores VARCHAR(2048) = ''

	IF NOT EXISTS(SELECT 1 FROM Turismo.Visitante WHERE IdVisitante = @IdVisitante)
		SET @errores += '- El ID de visitante indicado no existe.' + CHAR(13)

	IF @errores <> ''
	BEGIN
		SET @errores = 'No se pudo dar de alta la venta:' + CHAR(13) + @errores;
		THROW 50000, @errores, 1
	END

	DECLARE @FechaReal DATETIME = ISNULL(@Fecha, GETDATE())
	DECLARE @TranPropia BIT = 0

	IF @@TRANCOUNT = 0
	BEGIN
		BEGIN TRANSACTION
		SET @TranPropia = 1
	END
	ELSE
		SAVE TRANSACTION USP_AltaVenta

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
			ROLLBACK TRANSACTION USP_AltaVenta
		;THROW -- progago error
	END CATCH
END
GO

-- =============================================
-- USP_AltaLineasDeEntradaActividad (plural) — versión NUEVO DER
-- La línea apunta directo a Actividad. Precio = Actividad.Costo.
-- Cupo = global de la actividad (CupoMaximo vs. lo ya vendido de esa actividad).
-- =============================================
CREATE OR ALTER PROCEDURE USP_AltaLineasDeEntradaActividad
	@IdVenta INT,
	@Lineas Ventas.TVP_LineaActividad READONLY,
	@Factor DECIMAL(10,4) = 1.0
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT ON

	DECLARE @errores VARCHAR(2048) = ''

	IF NOT EXISTS(SELECT 1 FROM @Lineas) RETURN

	IF NOT EXISTS(SELECT 1 FROM Ventas.Venta WHERE IdVenta = @IdVenta)
		SET @errores += '- La venta indicada no existe.' + CHAR(13)

	IF EXISTS(SELECT 1 FROM @Lineas WHERE Cantidad <= 0)
		SET @errores += '- Hay líneas de actividad con cantidad menor o igual a cero.' + CHAR(13)

	-- Existencia de las actividades
	IF EXISTS(
		SELECT 1 FROM @Lineas l
		WHERE NOT EXISTS(SELECT 1 FROM Turismo.Actividad a WHERE a.IdActividad = l.IdActividad))
		SET @errores += '- Alguna actividad indicada no existe.' + CHAR(13)

	-- Validación de cupo GLOBAL por actividad:
	-- (lo solicitado en este TVP) + (lo ya vendido de esa actividad) <= CupoMaximo
	IF EXISTS(
		SELECT 1
		FROM (
			SELECT l.IdActividad, SUM(l.Cantidad) AS CantSolicitada
			FROM @Lineas l
			GROUP BY l.IdActividad
		) sol
		INNER JOIN Turismo.Actividad a ON a.IdActividad = sol.IdActividad
		OUTER APPLY (
			SELECT ISNULL(SUM(le.Cantidad),0) AS Ocupada
			FROM Ventas.LineaDeEntradaActividad le
			WHERE le.IdActividad = sol.IdActividad
		) oc
		WHERE sol.CantSolicitada + oc.Ocupada > a.CupoMaximo
	)
		SET @errores += '- Alguna actividad supera la cantidad de cupos disponibles.' + CHAR(13)

	IF @errores <> ''
	BEGIN
		SET @errores = 'No se pudieron registrar las líneas de actividad:' + CHAR(13) + @errores;
		THROW 50000, @errores, 1
	END

	SAVE TRANSACTION USP_LineasActividad
	BEGIN TRY
		DECLARE @MaxItem INT = (
			SELECT ISNULL(MAX(NumeroDeItem), 0)
			FROM (
				SELECT NumeroDeItem FROM Ventas.LineaDeEntradaParque WHERE IdVenta = @IdVenta
				UNION ALL
				SELECT NumeroDeItem FROM Ventas.LineaDeEntradaActividad WHERE IdVenta = @IdVenta
			) AS Comb
		)

		INSERT INTO Ventas.LineaDeEntradaActividad(IdActividad, IdVenta, PrecioUnitario, Cantidad, NumeroDeItem)
		SELECT
			l.IdActividad,
			@IdVenta,
			a.Costo * @Factor,
			l.Cantidad,
			@MaxItem + ROW_NUMBER() OVER (ORDER BY l.IdActividad)
		FROM @Lineas l
		INNER JOIN Turismo.Actividad a ON a.IdActividad = l.IdActividad

		UPDATE Ventas.Venta
		SET Monto = Monto + ISNULL((
			SELECT SUM(a.Costo * @Factor * l.Cantidad)
			FROM @Lineas l
			INNER JOIN Turismo.Actividad a ON a.IdActividad = l.IdActividad
		), 0)
		WHERE IdVenta = @IdVenta
	END TRY
	BEGIN CATCH
		IF XACT_STATE() = 1
			ROLLBACK TRANSACTION USP_LineasActividad
		;THROW
	END CATCH
END
GO

-- =============================================
-- USP_AltaLineasDeEntradaParque
-- =============================================

/*
DROP PROCEDURE USP_AltaLineaDeEntradaParque
*/

CREATE OR ALTER PROCEDURE USP_AltaLineasDeEntradaParque
	@IdVenta INT,
	@Lineas Ventas.TVP_LineaParque READONLY,
	@Factor DECIMAL(10,4) = 1.0
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT ON

	DECLARE @errores VARCHAR(2048) = ''

	IF NOT EXISTS(SELECT 1 FROM @Lineas) RETURN

	IF NOT EXISTS(SELECT 1 FROM Ventas.Venta WHERE IdVenta = @IdVenta)
		SET @errores += '- La venta indicada no existe.' + CHAR(13)

	-- Cantidades válidas
	IF EXISTS(SELECT 1 FROM @Lineas WHERE Cantidad <= 0)
		SET @errores += '- Hay líneas de parque con cantidad menor o igual a cero.' + CHAR(13)

	-- Existencia de todas las entradas referenciadas
	IF EXISTS(
		SELECT 1 FROM @Lineas l
		WHERE NOT EXISTS(SELECT 1 FROM Turismo.EntradaParque ep WHERE ep.IdEntradaParque = l.IdEntradaParque))
		SET @errores += '- Alguna entrada de parque indicada no existe.' + CHAR(13)

	IF @errores <> ''
	BEGIN
		SET @errores = 'No se pudieron registrar las líneas de parque:' + CHAR(13) + @errores;
		THROW 50000, @errores, 1
	END

	SAVE TRANSACTION USP_LineasParque
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
			ROLLBACK TRANSACTION USP_LineasParque
		;THROW
	END CATCH
END
GO