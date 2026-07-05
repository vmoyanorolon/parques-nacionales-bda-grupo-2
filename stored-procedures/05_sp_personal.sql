-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Fecha: 04/07/2026
-- Descripción: Stored Procedures del esquema Personal

USE ParquesNacionales
GO

-- =============================================
-- USP_ModificacionAsignacion
-- Registrar fecha en la que el guardaparque dejó de trabajar en el parque
-- =============================================
/*
DROP PROCEDURE USP_ModificacionAsignacion
*/
CREATE OR ALTER PROCEDURE USP_ModificacionAsignacion
	@IdAsignacion INT,
	@Motivo VARCHAR(200) = NULL
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @errores VARCHAR(2048) = ''
	DECLARE @FechaEgreso DATE = GETDATE()
	DECLARE @FechaEgresoActual DATE
	DECLARE @IdGuardaparque INT

	SELECT @IdGuardaparque = IdGuardaparque,
		   @FechaEgresoActual = FechaEgreso
	FROM Personal.Asignacion
	WHERE IdAsignacion = @IdAsignacion

	IF @IdGuardaparque IS NULL
	BEGIN
		SET @errores = 'No se pudo modificar la asignación:' + CHAR(13) + '- La asignación referenciada no existe.' + CHAR(13);
		THROW 50000, @errores, 1
	END

	IF @FechaEgresoActual IS NOT NULL
		SET @errores += '- La asignación ya tiene fecha de egreso registrada.' + CHAR(13)

	IF @errores <> ''
	BEGIN
		SET @errores = 'No se pudo modificar la asignación:' + CHAR(13) + @errores;
		THROW 50000, @errores, 1
	END

	BEGIN TRANSACTION
	BEGIN TRY
		UPDATE Personal.Asignacion
		SET FechaEgreso = @FechaEgreso,
			Motivo = ISNULL(@Motivo, Motivo)
		WHERE IdAsignacion = @IdAsignacion

		UPDATE Personal.Guardaparque
		SET Estado = 'Inactivo'
		WHERE IdGuardaparque = @IdGuardaparque

		COMMIT TRANSACTION
		PRINT 'La asignación ' + CAST(@IdAsignacion AS VARCHAR) + ' fue modificada con éxito'

	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION
		PRINT 'Error: ' + ERROR_MESSAGE();
		THROW
	END CATCH
END
GO

-- =============================================
-- USP_AltaHabilitacion
-- Dar de alta a un guía para que pueda dar una actividad
-- =============================================
/*
DROP PROCEDURE USP_AltaHabilitacion
*/
CREATE OR ALTER PROCEDURE USP_AltaHabilitacion
	@IdGuia INT,
	@IdActividad INT,
	@DiasVigentes INT
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @errores VARCHAR(2048) = ''
	DECLARE @IdParqueActividad INT
	DECLARE @IdNuevoParqueParaGuia INT
	DECLARE @IdHabilitacion INT
	DECLARE @FechaInicio DATE = GETDATE()

	SELECT @IdParqueActividad = IdParque
	FROM Turismo.Actividad
	WHERE IdActividad = @IdActividad

	IF @IdParqueActividad IS NULL
		SET @errores += '- La actividad indicada no existe.' + CHAR(13)

	IF NOT EXISTS (SELECT 1 FROM Personal.Guia WHERE IdGuia = @IdGuia)
		SET @errores += '- El guía indicado no existe.' + CHAR(13)

	IF @DiasVigentes <= 0
		SET @errores += '- Los días vigentes deben ser mayores a 0.' + CHAR(13)

	IF @errores <> ''
	BEGIN
		SET @errores = 'No se pudo dar de alta la habilitación:' + CHAR(13) + @errores;
		THROW 50000, @errores, 1
	END

	-- Si el guía no trabaja en el parque en el que se ofrece la actividad, significa que
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
		PRINT 'Error: ' + ERROR_MESSAGE();
		THROW
	END CATCH
END
GO

-- =============================================
-- USP_ModificacionHabilitacion
-- Cambiar días de vigencia que tiene un guía para dar una actividad
-- =============================================
/*
DROP PROCEDURE USP_ModificacionHabilitacion
*/
CREATE OR ALTER PROCEDURE USP_ModificacionHabilitacion
	@IdHabilitacion INT,
	@DiasVigentes INT
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @errores VARCHAR(2048) = ''

	IF NOT EXISTS(
		SELECT 1
		FROM Personal.Habilitacion
		WHERE IdHabilitacion = @IdHabilitacion
	)
		SET @errores += '- La habilitación indicada no existe.' + CHAR(13)

	IF @DiasVigentes <= 0
		SET @errores += '- Los días vigentes deben ser mayores a 0.' + CHAR(13)

	IF @errores <> ''
	BEGIN
		SET @errores = 'No se pudo modificar la habilitación:' + CHAR(13) + @errores;
		THROW 50000, @errores, 1
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
		PRINT 'Error: ' + ERROR_MESSAGE();
		THROW
	END CATCH
END
GO

-- =============================================
-- USP_BajaHabilitacion
-- Dar de baja la habilitación de un guía para dar una actividad
-- =============================================
/*
DROP PROCEDURE USP_BajaHabilitacion
*/
CREATE OR ALTER PROCEDURE USP_BajaHabilitacion
	@IdHabilitacion INT
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @errores VARCHAR(2048) = ''
	DECLARE @IdActividad INT
	DECLARE @IdGuia INT

	SELECT @IdActividad = IdActividad, @IdGuia = IdGuia
	FROM Personal.Habilitacion
	WHERE IdHabilitacion = @IdHabilitacion

	IF @IdActividad IS NULL
		SET @errores += '- La habilitación indicada no existe.' + CHAR(13)

	IF @errores <> ''
	BEGIN
		SET @errores = 'No se pudo dar de baja la habilitación:' + CHAR(13) + @errores;
		THROW 50000, @errores, 1
	END

	BEGIN TRANSACTION
	BEGIN TRY
		DELETE FROM Personal.Habilitacion WHERE IdHabilitacion = @IdHabilitacion
		COMMIT TRANSACTION
		PRINT 'La habilitación ' + CAST(@IdHabilitacion AS VARCHAR) + ' fue eliminada con éxito'
	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION
		PRINT 'Error: ' + ERROR_MESSAGE();
		THROW
	END CATCH
END
GO

--------------------------------------------------------------------------------
-- Guia
--------------------------------------------------------------------------------

----------------------------------------
-- CREACION
----------------------------------------

--DROP PROCEDURE USP_AltaGuia

CREATE OR ALTER PROCEDURE USP_AltaGuia
	@Telefono VARCHAR(20),
	@CorreoGuia VARCHAR(100),
	@NumeroDocumento VARCHAR(15),
	@TipoDocumento VARCHAR(15),
	@Edad TINYINT,
	@Apellido VARCHAR(50),
	@Nombre VARCHAR(50),
	@Titulo VARCHAR(50),
	@Especialidad VARCHAR(50)
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @errores VARCHAR(2048) = ''

	--Validamos si ya existe el numero de documento
	IF EXISTS (SELECT 1 FROM Personal.Guia WHERE NumeroDocumento = @NumeroDocumento)
		SET @errores += '- El guía con documento ' + @NumeroDocumento + ' ya existe.' + CHAR(13)

	--Validamos que no haya otro guia con el mismo correo
	IF EXISTS (SELECT 1 FROM Personal.Guia WHERE CorreoGuia = @CorreoGuia)
		SET @errores += '- El correo ' + @CorreoGuia + ' ya existe.' + CHAR(13)

	IF @errores <> ''
	BEGIN
		SET @errores = 'No se pudo dar de alta el guía:' + CHAR(13) + @errores;
		THROW 50000, @errores, 1
	END

	INSERT INTO Personal.Guia (Telefono, CorreoGuia, NumeroDocumento, TipoDocumento, Edad, Apellido, Nombre, Titulo, Especialidad)
	VALUES (@Telefono, @CorreoGuia, @NumeroDocumento, @TipoDocumento, @Edad, @Apellido, @Nombre, @Titulo, @Especialidad);

	PRINT 'Guia creado correctamente.'
END;
GO

----------------------------------------
-- MODIFICACION
----------------------------------------

--DROP PROCEDURE USP_ModificacionGuia

CREATE OR ALTER PROCEDURE USP_ModificacionGuia
	@IdGuia INT,
	@Telefono VARCHAR(20) = NULL,
	@CorreoGuia VARCHAR(100) = NULL,
	@NumeroDocumento VARCHAR(15) = NULL,
	@TipoDocumento VARCHAR(15) = NULL,
	@Edad TINYINT = NULL,
	@Apellido VARCHAR(50) = NULL,
	@Nombre VARCHAR(50) = NULL,
	@Titulo VARCHAR(50) = NULL,
	@Especialidad VARCHAR(50) = NULL
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @errores VARCHAR(2048) = ''

	--Validamos que el guia exista
	IF NOT EXISTS (SELECT 1 FROM Personal.Guia WHERE IdGuia = @IdGuia)
		SET @errores += '- El guía con id ' + CAST(@IdGuia AS VARCHAR) + ' no existe.' + CHAR(13)

	--Validamos que el numero de documento nuevo no exista
	IF @NumeroDocumento IS NOT NULL AND EXISTS (SELECT 1 FROM Personal.Guia WHERE NumeroDocumento = @NumeroDocumento AND IdGuia <> @IdGuia)
		SET @errores += '- El guía con documento ' + @NumeroDocumento + ' ya existe.' + CHAR(13)

	IF @errores <> ''
	BEGIN
		SET @errores = 'No se pudo modificar el guía:' + CHAR(13) + @errores;
		THROW 50000, @errores, 1
	END

	UPDATE Personal.Guia
	SET Telefono		= ISNULL(@Telefono, Telefono),
		CorreoGuia		= ISNULL(@CorreoGuia, CorreoGuia),
		NumeroDocumento = ISNULL(@NumeroDocumento, NumeroDocumento),
		TipoDocumento	= ISNULL(@TipoDocumento, TipoDocumento),
		Edad			= ISNULL(@Edad, Edad),
		Apellido		= ISNULL(@Apellido, Apellido),
		Nombre			= ISNULL(@Nombre, Nombre),
		Titulo			=  ISNULL(@Titulo, Titulo),
		Especialidad	= ISNULL(@Especialidad, Especialidad)
	WHERE IdGuia = @IdGuia

	PRINT'Guia actualizado correctamente.'
END;
GO

----------------------------------------
-- BAJA
----------------------------------------

--DROP PROCEDURE USP_BajaGuia

CREATE OR ALTER PROCEDURE USP_BajaGuia
	@IdGuia INT
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @errores VARCHAR(2048) = ''

	--Verficamos que el guia exista
	IF NOT EXISTS (SELECT 1 FROM Personal.Guia WHERE IdGuia = @IdGuia)
		SET @errores += '- El guía con id ' + CAST(@IdGuia AS VARCHAR) + ' no existe.' + CHAR(13)

	IF @errores <> ''
	BEGIN
		SET @errores = 'No se pudo dar de baja el guía:' + CHAR(13) + @errores;
		THROW 50000, @errores, 1
	END

	BEGIN TRY
		DELETE FROM Personal.Guia WHERE IdGuia = @IdGuia
		PRINT'Guia eliminado correctamente.'
	END TRY
	BEGIN CATCH
		THROW 50000, 'No se puede eliminar el Guia: Tiene registros de Habilitaciones asociadas y Parques donde trabaja asociados', 1
	END CATCH

END;
GO

--------------------------------------------------------------------------------
-- GuiaTrabajaParque
--------------------------------------------------------------------------------

----------------------------------------
-- CREACION
----------------------------------------

--DROP PROCEDURE USP_AltaGuiaTrabajaEnParque

CREATE OR ALTER PROCEDURE USP_AltaGuiaTrabajaEnParque
	@IdGuia INT,
	@IdParque INT
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @errores VARCHAR(2048) = ''

	--Verificamos que el Guia exista
	IF NOT EXISTS (SELECT 1 FROM Personal.Guia WHERE IdGuia = @IdGuia)
		SET @errores += '- El guía con id ' + CAST(@IdGuia AS VARCHAR) + ' no existe.' + CHAR(13)

	--Verificamos que el Parque exista
	IF NOT EXISTS (SELECT 1 FROM Parques.Parque WHERE IdParque = @IdParque)
		SET @errores += '- El parque con id ' + CAST(@IdParque AS VARCHAR) + ' no existe.' + CHAR(13)

	--Verificamos que no existe la combinacion IdGuia+IdParque
	IF EXISTS (SELECT 1 FROM Personal.GuiaTrabajaEnParque WHERE IdGuia = @IdGuia AND IdParque = @IdParque)
		SET @errores += '- El guía con id ' + CAST(@IdGuia AS VARCHAR) + ' ya trabaja en el parque con id ' + CAST(@IdParque AS VARCHAR) + '.' + CHAR(13)

	IF @errores <> ''
	BEGIN
		SET @errores = 'No se pudo registrar que el guía trabaja en el parque:' + CHAR(13) + @errores;
		THROW 50000, @errores, 1
	END

	INSERT INTO Personal.GuiaTrabajaEnParque (IdGuia, IdParque)
	VALUES (@IdGuia, @IdParque)

	PRINT'Guia trabaja en Parque creado correctamente.'
END;
GO

----------------------------------------
-- BAJA
----------------------------------------

--DROP PROCEDURE USP_BajaGuiaTrabajaEnParque

CREATE OR ALTER PROCEDURE USP_BajaGuiaTrabajaEnParque
	@IdGuia INT,
	@IdParque INT
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @errores VARCHAR(2048) = ''

	--Verificamos que el par IdGuia-IdParque exista
	IF NOT EXISTS (SELECT 1 FROM Personal.GuiaTrabajaEnParque WHERE IdGuia = @IdGuia AND IdParque = @IdParque)
		SET @errores += '- No existe un guía con id ' + CAST(@IdGuia AS VARCHAR) + ' que trabaje en el parque con id ' + CAST(@IdParque AS VARCHAR) + '.' + CHAR(13)

	IF @errores <> ''
	BEGIN
		SET @errores = 'No se pudo eliminar el registro de guía trabaja en parque:' + CHAR(13) + @errores;
		THROW 50000, @errores, 1
	END

	--No hace falta hacer un TRY - CATCH ya que eliminar un registro en esta tabla no afecta en nada a otras
	DELETE FROM Personal.GuiaTrabajaEnParque WHERE IdGuia = @IdGuia AND IdParque = @IdParque

	PRINT'Guia trabaja en Parque eliminado correctamente.'
END;
GO

--------------------------------------------------------------------------------
-- Guardaparque
--------------------------------------------------------------------------------

----------------------------------------
-- CREACION
----------------------------------------

--DROP PROCEDURE USP_AltaGuardaparque

CREATE OR ALTER PROCEDURE USP_AltaGuardaparque
	@Telefono VARCHAR(20),
	@CorreoGuardaparque VARCHAR(100),
	@NumeroDocumento VARCHAR(15),
	@TipoDocumento VARCHAR(15),
	@Edad TINYINT,
	@Apellido VARCHAR(50),
	@Nombre VARCHAR(50),
	@Estado VARCHAR(20)
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @errores VARCHAR(2048) = ''

	--Validamos si ya existe el numero de documento
	IF EXISTS (SELECT 1 FROM Personal.Guardaparque WHERE NumeroDocumento = @NumeroDocumento)
		SET @errores += '- El guardaparque con documento ' + @NumeroDocumento + ' ya existe.' + CHAR(13)

	--Validamos que no haya otro guardaparque con el mismo correo
	IF EXISTS (SELECT 1 FROM Personal.Guardaparque WHERE CorreoGuardaparque = @CorreoGuardaparque)
		SET @errores += '- El guardaparque con correo ' + @CorreoGuardaparque + ' ya existe.' + CHAR(13)

	IF @errores <> ''
	BEGIN
		SET @errores = 'No se pudo dar de alta el guardaparque:' + CHAR(13) + @errores;
		THROW 50000, @errores, 1
	END

	INSERT INTO Personal.Guardaparque (Telefono, CorreoGuardaparque, NumeroDocumento, TipoDocumento, Edad, Apellido, Nombre, Estado)
	VALUES (@Telefono, @CorreoGuardaparque, @NumeroDocumento, @TipoDocumento, @Edad, @Apellido, @Nombre, @Estado)

	PRINT'Guardaparque creado correctamente.'
END;
GO

----------------------------------------
-- MODIFICACION
----------------------------------------

--DROP PROCEDURE USP_ModificacionGuardaparque

CREATE OR ALTER PROCEDURE USP_ModificacionGuardaparque
	@IdGuardaparque INT,
	@Telefono VARCHAR(20) = NULL,
	@CorreoGuardaparque VARCHAR(100) = NULL,
	@NumeroDocumento VARCHAR(15) = NULL,
	@TipoDocumento VARCHAR(15) = NULL,
	@Edad TINYINT = NULL,
	@Apellido VARCHAR(50) = NULL,
	@Nombre VARCHAR(50) = NULL,
	@Estado VARCHAR(20) = NULL
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @errores VARCHAR(2048) = ''

	--Validamos que el guardaparque exista
	IF NOT EXISTS (SELECT 1 FROM Personal.Guardaparque WHERE IdGuardaparque = @IdGuardaparque)
		SET @errores += '- El guardaparque con id ' + CAST(@IdGuardaparque AS VARCHAR) + ' no existe.' + CHAR(13)

	--Validamos que el numero de documento nuevo no exista
	IF @NumeroDocumento IS NOT NULL AND EXISTS (SELECT 1 FROM Personal.Guardaparque WHERE NumeroDocumento = @NumeroDocumento AND IdGuardaparque <> @IdGuardaparque)
		SET @errores += '- El guardaparque con documento ' + @NumeroDocumento + ' ya existe.' + CHAR(13)

	IF @errores <> ''
	BEGIN
		SET @errores = 'No se pudo modificar el guardaparque:' + CHAR(13) + @errores;
		THROW 50000, @errores, 1
	END

	UPDATE Personal.Guardaparque
	SET Telefono		= ISNULL(@Telefono, Telefono),
		CorreoGuardaparque = ISNULL(@CorreoGuardaparque, CorreoGuardaparque),
		NumeroDocumento = ISNULL(@NumeroDocumento, NumeroDocumento),
		TipoDocumento	= ISNULL(@TipoDocumento, TipoDocumento),
		Edad			= ISNULL(@Edad, Edad),
		Apellido		= ISNULL(@Apellido, Apellido),
		Nombre			= ISNULL(@Nombre, Nombre),
		Estado			=  ISNULL(@Estado, Estado)
	WHERE IdGuardaparque = @IdGuardaparque

	PRINT'Guardparque modificado correctamente.'
END;
GO

----------------------------------------
-- BAJA
----------------------------------------

--DROP PROCEDURE USP_BajaGuardaparque

CREATE OR ALTER PROCEDURE USP_BajaGuardaparque
	@IdGuardaparque INT
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @errores VARCHAR(2048) = ''

	--Verficamos que el guardaparque exista
	IF NOT EXISTS (SELECT 1 FROM Personal.Guardaparque WHERE IdGuardaparque = @IdGuardaparque)
		SET @errores += '- El guardaparque con id ' + CAST(@IdGuardaparque AS VARCHAR) + ' no existe.' + CHAR(13)

	IF @errores <> ''
	BEGIN
		SET @errores = 'No se pudo dar de baja el guardaparque:' + CHAR(13) + @errores;
		THROW 50000, @errores, 1
	END

	BEGIN TRY
		DELETE FROM Personal.Guardaparque WHERE IdGuardaparque = @IdGuardaparque
		PRINT'Guardaparque eliminado correctamente.'
	END TRY
	BEGIN CATCH
		THROW 50000, 'No se puede eliminar el Guardaparque: Tiene una Asignacion asociada', 1
	END CATCH

END;
GO

--------------------------------------------------------------------------------
-- Asignacion
--------------------------------------------------------------------------------

----------------------------------------
-- CREACION
----------------------------------------

--DROP PROCEDURE USP_AltaAsignacion

CREATE OR ALTER PROCEDURE USP_AltaAsignacion
	@FechaIngreso DATE,
	@FechaEgreso DATE = NULL,
	@Motivo VARCHAR(200) = NULL,
	@IdParque INT,
	@IdGuardaparque INT
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @errores VARCHAR(2048) = ''

	--Verificamos que el parque exista
	IF NOT EXISTS (SELECT 1 FROM Parques.Parque WHERE IdParque = @IdParque)
		SET @errores += '- El parque con id ' + CAST(@IdParque AS VARCHAR) + ' no existe.' + CHAR(13)

	--Verificamos que el guardaparque exista
	IF NOT EXISTS (SELECT 1 FROM Personal.Guardaparque WHERE IdGuardaparque = @IdGuardaparque)
		SET @errores += '- El guardaparque con id ' + CAST(@IdGuardaparque AS VARCHAR) + ' no existe.' + CHAR(13)

	--Verificamos que el guardaparque no tenga una asignacion activa
	IF EXISTS (SELECT 1 FROM Personal.Asignacion WHERE IdGuardaparque = @IdGuardaparque
				AND FechaEgreso IS NULL)
		SET @errores += '- El guardaparque con id ' + CAST(@IdGuardaparque AS VARCHAR) + ' tiene una asignación activa. Para dar de alta esta asignación se debe asignar una fecha de egreso en la activa.' + CHAR(13)

	IF @errores <> ''
	BEGIN
		SET @errores = 'No se pudo dar de alta la asignación:' + CHAR(13) + @errores;
		THROW 50000, @errores, 1
	END

	BEGIN TRANSACTION
    BEGIN TRY
		INSERT INTO Personal.Asignacion (FechaIngreso, FechaEgreso, Motivo, IdParque, IdGuardaparque)
		VALUES (@FechaIngreso, @FechaEgreso, @Motivo, @IdParque, @IdGuardaparque)

		 -- Si la asignación es abierta, el guardaparque vuelve a estar activo
		UPDATE Personal.Guardaparque
		SET Estado = 'Activo'
		WHERE IdGuardaparque = @IdGuardaparque
			AND @FechaEgreso IS NULL

		COMMIT TRANSACTION
		PRINT 'La asignacion fue creada correctamente'
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
		;THROW
	END CATCH
END
GO