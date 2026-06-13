-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: Stored Procedures del esquema Personal

USE ParquesNacionales
GO

-- =============================================
-- SP_ModificacionAsignacion
-- =============================================
/*
DROP PROCEDURE SP_ModificacionAsignacion
*/
CREATE OR ALTER PROCEDURE SP_ModificacionAsignacion
	@IdAsignacion INT,
	@Motivo VARCHAR(200) = NULL
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @FechaEgreso DATE = GETDATE()
	DECLARE @FechaEgresoActual DATE
	DECLARE @IdGuardaparque INT

	SELECT @IdGuardaparque = IdGuardaparque,
		   @FechaEgresoActual = FechaEgreso
	FROM Personal.Asignacion
	WHERE IdAsignacion = @IdAsignacion
	
	IF @IdGuardaparque IS NULL
	BEGIN
		RAISERROR ('La asignación referenciada no existe',16,1)
		RETURN
	END

	IF @FechaEgresoActual IS NOT NULL
	BEGIN
		RAISERROR ('La asignación ya tiene fecha de egreso registrada',16,1)
		RETURN
	END

	BEGIN TRANSACTION
	BEGIN TRY
		UPDATE Personal.Asignacion
		SET FechaEgreso = @FechaEgreso,
			Motivo = @Motivo
		WHERE IdAsignacion = @IdAsignacion

		UPDATE Personal.Guardaparque
		SET Estado = 'Inactivo'
		WHERE IdGuardaparque = @IdGuardaparque

		COMMIT TRANSACTION
		PRINT 'La asignación ' + CAST(@IdAsignacion AS VARCHAR) + ' fue modificada con éxito'

	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION
		PRINT 'Error: ' + ERROR_MESSAGE()
	END CATCH
END
GO

-- =============================================
-- SP_AltaHabilitacion
-- =============================================
/*
DROP PROCEDURE SP_AltaHabilitacion
*/
CREATE OR ALTER PROCEDURE SP_AltaHabilitacion
	@IdGuia INT,
	@IdActividad INT,
	@DiasVigentes INT
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @IdParqueActividad INT
	DECLARE @IdNuevoParqueParaGuia INT
	DECLARE @IdHabilitacion INT
	DECLARE @FechaInicio DATE = GETDATE()

	SELECT @IdParqueActividad = IdParque
	FROM Turismo.Actividad
	WHERE IdActividad = @IdActividad

	IF @IdParqueActividad IS NULL
	BEGIN
		RAISERROR ('La actividad no existe',16,1)
		RETURN
	END

	IF NOT EXISTS (
	SELECT 1 FROM Personal.Guia WHERE IdGuia = @IdGuia
	)
	BEGIN
		RAISERROR ('El guía no existe',16,1)
		RETURN
	END
	
	-- Si el guia no trabaja en el parque en el que se ofrece la actividad, significa que
	-- es un nuevo parque para el guía y hay que registrarlo en Personal.GuiaTrabajaEnParque
	
	IF NOT EXISTS(
	SELECT 1
	FROM Personal.GuiaTrabajaEnParque
	WHERE	IdGuia = @IdGuia AND
			IdParque = @IdParqueActividad)
	BEGIN
		SELECT @IdNuevoParqueParaGuia = @IdParqueActividad
	END

	BEGIN TRANSACTION
	BEGIN TRY
		INSERT INTO Personal.Habilitacion(FechaInicio, DiasVigentes, IdGuia, IdActividad)
		VALUES(@FechaInicio, @DiasVigentes, @IdGuia, @IdActividad)
		SELECT @IdHabilitacion = SCOPE_IDENTITY()

		IF @IdNuevoParqueParaGuia IS NOT NULL
		BEGIN
			INSERT INTO Personal.GuiaTrabajaEnParque(IdGuia, IdParque)
			VALUES(@IdGuia, @IdNuevoParqueParaGuia)
		END

		COMMIT TRANSACTION
		PRINT 'La habilitación ' + CAST(@IdHabilitacion AS VARCHAR) + ' fue dada de alta con éxito'

	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION
		PRINT 'Error: ' + ERROR_MESSAGE()
	END CATCH
END
GO

-- =============================================
-- SP_ModificacionHabilitacion
-- =============================================
/*
DROP PROCEDURE SP_ModificacionHabilitacion
*/
CREATE OR ALTER PROCEDURE SP_ModificacionHabilitacion
	@IdHabilitacion INT,
	@DiasVigentes INT
AS
BEGIN
	SET NOCOUNT ON

	IF NOT EXISTS(
		SELECT 1
		FROM Personal.Habilitacion
		WHERE IdHabilitacion = @IdHabilitacion
	)
	BEGIN
		RAISERROR ('La habilitación no existe',16,1)
		RETURN
	END

	IF @DiasVigentes <= 0
	BEGIN
		RAISERROR ('Los días vigentes deben ser mayores a 0',16,1)
		RETURN
	END

	BEGIN TRANSACTION
	BEGIN TRY
		UPDATE Personal.Habilitacion
		SET DiasVigentes = @DiasVigentes
		WHERE IdHabilitacion = @IdHabilitacion

		COMMIT TRANSACTION
		PRINT 'La habilitación ' + CAST(@IdHabilitacion AS VARCHAR) + ' fue actualizada con éxito'
	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION
		PRINT 'Error: ' + ERROR_MESSAGE()
	END CATCH
END
GO

-- =============================================
-- SP_BajaHabilitacion
-- =============================================
/*
DROP SP_BajaHabilitacion
*/
CREATE OR ALTER PROCEDURE SP_BajaHabilitacion
	@IdHabilitacion INT
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @IdActividad INT
	DECLARE @IdGuia INT

	SELECT @IdActividad = IdActividad, @IdGuia = IdGuia
	FROM Personal.Habilitacion
	WHERE IdHabilitacion = @IdHabilitacion

	IF @IdActividad IS NULL
	BEGIN
		RAISERROR ('La habilitación no existe',16,1)
		RETURN
	END

	BEGIN TRANSACTION
	BEGIN TRY
		DELETE FROM Personal.Habilitacion WHERE IdHabilitacion = @IdHabilitacion
		COMMIT TRANSACTION
		PRINT 'La habilitación' + CAST(@IdHabilitacion AS VARCHAR) + 'fue eliminada con éxito'
	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION
		PRINT 'Error: ' + ERROR_MESSAGE()
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

    BEGIN TRY
        -- Existencia de guía
        IF NOT EXISTS (SELECT 1 FROM Personal.Guia WHERE IdGuia = @IdGuia)
        BEGIN
            RAISERROR('El guía indicado no existe.', 16, 1);
            RETURN;
        END

		IF @DiasVigentes <= 0
        BEGIN
            RAISERROR('Los días vigentes deben ser mayores a 0.', 16, 1);
            RETURN;
        END

        -- Existencia y tipo de actividad
        DECLARE @Tipo VARCHAR(9), @IdParqueActividad INT;

        SELECT @Tipo = Tipo, @IdParqueActividad = IdParque
        FROM Turismo.Actividad
        WHERE IdActividad = @IdActividad;

        IF @Tipo <> 'Tour'
        BEGIN
            RAISERROR('La actividad no es de tipo Tour.', 16, 1);
            RETURN;
        END

        -- El guía debe trabajar en el parque de la actividad
        IF NOT EXISTS (
            SELECT 1 FROM Personal.GuiaTrabajaEnParque
            WHERE IdGuia = @IdGuia AND IdParque = @IdParqueActividad
        )
        BEGIN
            RAISERROR('El guía no trabaja en el parque de esta actividad.', 16, 1);
            RETURN;
        END

        -- Evitar habilitación vigente duplicada para la misma actividad
        IF EXISTS (
            SELECT 1 FROM Personal.Habilitacion
            WHERE IdGuia = @IdGuia
              AND IdActividad = @IdActividad
              AND DATEADD(DAY, DiasVigentes, FechaInicio) >= CAST(GETDATE() AS DATE)
        )
        BEGIN
            RAISERROR('El guía ya tiene una habilitación vigente para esta actividad.', 16, 1);
            RETURN;
        END

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