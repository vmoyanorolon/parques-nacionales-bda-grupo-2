-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: Stored Procedures del esquema Personal

USE ParquesNacionales
GO

-- =============================================
-- SP_ModificacionAsignacion
-- Registrar fecha en la que el guardaparque dejó de trabajar en el parque
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
		RAISERROR ('La asignación referenciada no existe, no se hará ningún cambio',16,1)
		RETURN
	END

	IF @FechaEgresoActual IS NOT NULL
	BEGIN
		RAISERROR ('La asignación ya tiene fecha de egreso registrada, no se hará ningún cambio',16,1)
		RETURN
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
		PRINT 'Error: ' + ERROR_MESSAGE()
	END CATCH
END
GO

-- =============================================
-- SP_AltaHabilitacion
-- Dar de alta a un guía para que pueda dar una actividad
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
		RAISERROR ('La actividad no existe, no se dará de alta la habilitación',16,1)
		RETURN
	END

	IF NOT EXISTS (
	SELECT 1 FROM Personal.Guia WHERE IdGuia = @IdGuia
	)
	BEGIN
		RAISERROR ('El guía no existe, no se dará de alta la habilitación',16,1)
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
-- Cambiar días de vigencia que tiene un guía para dar una actividad
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
		RAISERROR ('La habilitación no existe, no se modificará la habilitación',16,1)
		RETURN
	END

	IF @DiasVigentes <= 0
	BEGIN
		RAISERROR ('Los días vigentes deben ser mayores a 0, no se modificará la habilitación',16,1)
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
-- Dar de baja la habilitación de un guía para dar una actividad
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
		RAISERROR ('La habilitación no existe, no se hará ningún cambio',16,1)
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

--------------------------------------------------------------------------------
-- Guia
--------------------------------------------------------------------------------

----------------------------------------
-- CREACION 
----------------------------------------

--DROP PROCEDURE SP_AltaGuia

CREATE OR ALTER PROCEDURE SP_AltaGuia
	@Telefono VARCHAR(20),
	@CorreoGuia VARCHAR(100),
	@NumeroDocumento VARCHAR(15),
	@TipoDocumento VARCHAR(15),
	@Edad TINYINT,
	@Apellido VARCHAR(50),
	@Nombre VARCHAR(50),
	@Titulo VARCHAR(50)
AS
BEGIN
	SET NOCOUNT ON

	--Validamos si ya existe el numero de documento
	IF EXISTS (SELECT 1 FROM Personal.Guia WHERE NumeroDocumento = @NumeroDocumento)
	BEGIN
		RAISERROR('El Guia con documento %s ya existe.', 16, 1, @NumeroDocumento);
		RETURN;
	END

	--Validamos que no haya otro guia con el mismo correo
	IF EXISTS (SELECT 1 FROM Personal.Guia WHERE CorreoGuia = @CorreoGuia)
	BEGIN
		RAISERROR('El correo %s ya existe.', 16, 1, @CorreoGuia);
		RETURN;
	END

	INSERT INTO Personal.Guia (Telefono, CorreoGuia, NumeroDocumento, TipoDocumento, Edad, Apellido, Nombre, Titulo)
	VALUES (@Telefono, @CorreoGuia, @NumeroDocumento, @TipoDocumento, @Edad, @Apellido, @Nombre, @Titulo);

	PRINT 'Guia creado correctamente.'
END;
GO

----------------------------------------
-- MODIFICACION 
----------------------------------------

--DROP PROCEDURE SP_ModificacionGuia

CREATE OR ALTER PROCEDURE SP_ModificacionGuia
	@IdGuia INT,
	@Telefono VARCHAR(20) = NULL,
	@CorreoGuia VARCHAR(100) = NULL,
	@NumeroDocumento VARCHAR(15) = NULL,
	@TipoDocumento VARCHAR(15) = NULL,
	@Edad TINYINT = NULL,
	@Apellido VARCHAR(50) = NULL,
	@Nombre VARCHAR(50) = NULL,
	@Titulo VARCHAR(50) = NULL
AS
BEGIN
	SET NOCOUNT ON

	--Validamos que el guia exista
	IF NOT EXISTS (SELECT 1 FROM Personal.Guia WHERE IdGuia = @IdGuia)
	BEGIN
		RAISERROR('El guia con id %d no existe', 16, 1, @IdGuia);
		RETURN;
	END

	--Validamos que el numero de documento nuevo no exista
	IF @NumeroDocumento IS NOT NULL AND EXISTS (SELECT 1 FROM Personal.Guia WHERE NumeroDocumento = @NumeroDocumento)
	BEGIN
		RAISERROR('El guia con documento %s ya existe.', 16, 1, @NumeroDocumento);
		RETURN;
	END

	UPDATE Personal.Guia
	SET Telefono		= ISNULL(@Telefono, Telefono),
		CorreoGuia		= ISNULL(@CorreoGuia, CorreoGuia),
		NumeroDocumento = ISNULL(@NumeroDocumento, NumeroDocumento),
		TipoDocumento	= ISNULL(@TipoDocumento, TipoDocumento),
		Edad			= ISNULL(@Edad, Edad),
		Apellido		= ISNULL(@Apellido, Apellido),
		Nombre			= ISNULL(@Nombre, Nombre),
		Titulo			=  ISNULL(@Titulo, Titulo)
	WHERE IdGuia = @IdGuia

	PRINT'Guia actualizado correctamente.'
END;
GO

----------------------------------------
-- BAJA 
----------------------------------------

--DROP PROCEDURE SP_BajaGuia

CREATE OR ALTER PROCEDURE SP_BajaGuia
	@IdGuia INT
AS
BEGIN
	SET NOCOUNT ON

	--Verficamos que el guia exista
	IF NOT EXISTS (SELECT 1 FROM Personal.Guia WHERE IdGuia = @IdGuia)
	BEGIN
		RAISERROR('El guia con id %d no existe.', 16, 1, @IdGuia);
		RETURN;
	END

	BEGIN TRY
		DELETE FROM Personal.Guia WHERE IdGuia = @IdGuia
		PRINT'Guia eliminado correctamente.'
	END TRY
	BEGIN CATCH
		RAISERROR('No se puede eliminar el Guia: Tiene registros de Habilitaciones asociadas y Parques donde trabaja asociados', 16, 1);
	END CATCH

END;
GO

--------------------------------------------------------------------------------
-- GuiaTrabajaParque
--------------------------------------------------------------------------------

----------------------------------------
-- CREACION 
----------------------------------------

--DROP PROCEDURE SP_AltaGuiaTrabajaEnParque

CREATE OR ALTER PROCEDURE SP_AltaGuiaTrabajaEnParque
	@IdGuia INT,
	@IdParque INT
AS
BEGIN
	SET NOCOUNT ON

	--Verificamos que el Guia exista
	IF NOT EXISTS (SELECT 1 FROM Personal.Guia WHERE IdGuia = @IdGuia)
	BEGIN
		RAISERROR('El guia con id %d no existe.', 16, 1, @IdGuia);
		RETURN;
	END

	--Verificamos que el Parque exista
	IF NOT EXISTS (SELECT 1 FROM Parques.Parque WHERE IdParque = @IdParque)
	BEGIN
		RAISERROR('El parque con id %d no existe.', 16, 1, @IdParque);
		RETURN;
	END

	--Verificamos que no existe la combinacion IdGuia+IdParque
	IF EXISTS (SELECT 1 FROM Personal.GuiaTrabajaEnParque WHERE IdGuia = @IdGuia AND IdParque = @IdParque)
	BEGIN
		RAISERROR('El guia con id %d ya trabaja en el parque con id %d.', 16, 1, @IdGuia, @IdParque);
		RETURN;
	END

	INSERT INTO Personal.GuiaTrabajaEnParque (IdGuia, IdParque)
	VALUES (@IdGuia, @IdParque)

	PRINT'Guia trabaja en Parque creado correctamente.'
END;
GO

----------------------------------------
-- BAJA 
----------------------------------------

--DROP PROCEDURE SP_BajaGuiaTrabajaEnParque

CREATE OR ALTER PROCEDURE SP_BajaGuiaTrabajaEnParque
	@IdGuia INT,
	@IdParque INT
AS
BEGIN
	SET NOCOUNT ON

	--Verificamos que el par IdGuia-IdParque exista
	IF NOT EXISTS (SELECT 1 FROM Personal.GuiaTrabajaEnParque WHERE IdGuia = @IdGuia AND IdParque = @IdParque)
	BEGIN
		RAISERROR('No existe un guia con id %d que trabaje en el parque con id %d.', 16, 1, @IdGuia, @IdParque);
		RETURN;
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

--DROP PROCEDURE SP_AltaGuardaparque

CREATE OR ALTER PROCEDURE SP_AltaGuardaparque
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

	--Validamos si ya existe el numero de documento
	IF EXISTS (SELECT 1 FROM Personal.Guardaparque WHERE NumeroDocumento = @NumeroDocumento)
	BEGIN
		RAISERROR('El guardaparque con documento %s ya existe.', 16, 1, @NumeroDocumento);
		RETURN;
	END

	--Validamos que no haya otro guardaparque con el mismo correo
	IF EXISTS (SELECT 1 FROM Personal.Guardaparque WHERE CorreoGuardaparque = @CorreoGuardaparque)
	BEGIN
		RAISERROR('El guardaparque con correo %s ya existe.', 16, 1, @CorreoGuardaparque);
		RETURN;
	END

	INSERT INTO Personal.Guardaparque (Telefono, CorreoGuardaparque, NumeroDocumento, TipoDocumento, Edad, Apellido, Nombre, Estado)
	VALUES (@Telefono, @CorreoGuardaparque, @NumeroDocumento, @TipoDocumento, @Edad, @Apellido, @Nombre, @Estado)

	PRINT'Guardaparque creado correctamente.'
END;
GO

----------------------------------------
-- MODIFICACION 
----------------------------------------

--DROP PROCEDURE SP_ModificacionGuardaparque

CREATE OR ALTER PROCEDURE SP_ModificacionGuardaparque
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

	--Validamos que el guardaparque exista
	IF NOT EXISTS (SELECT 1 FROM Personal.Guardaparque WHERE IdGuardaparque = @IdGuardaparque)
	BEGIN
		RAISERROR('El guardaparque con id %d no existe', 16, 1, @IdGuardaparque);
		RETURN;
	END

	--Validamos que el numero de documento nuevo no exista
	IF @NumeroDocumento IS NOT NULL AND EXISTS (SELECT 1 FROM Personal.Guardaparque WHERE NumeroDocumento = @NumeroDocumento)
	BEGIN
		RAISERROR('El guardaparque con documento %s ya existe.', 16, 1, @NumeroDocumento);
		RETURN;
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

--DROP PROCEDURE SP_BajaGuardaparque

CREATE OR ALTER PROCEDURE SP_BajaGuardaparque
	@IdGuardaparque INT
AS
BEGIN
	SET NOCOUNT ON

	--Verficamos que el guardaparque exista
	IF NOT EXISTS (SELECT 1 FROM Personal.Guardaparque WHERE IdGuardaparque = @IdGuardaparque)
	BEGIN
		RAISERROR('El guardaparque con id %d no existe.', 16, 1, @IdGuardaparque);
		RETURN;
	END

	BEGIN TRY
		DELETE FROM Personal.Guardaparque WHERE IdGuardaparque = @IdGuardaparque
		PRINT'Guardaparque eliminado correctamente.'
	END TRY
	BEGIN CATCH
		RAISERROR('No se puede eliminar el Guardaparque: Tiene una Asignacion asociada', 16, 1);
	END CATCH

END;
GO

--------------------------------------------------------------------------------
-- Asignacion
--------------------------------------------------------------------------------

----------------------------------------
-- CREACION 
----------------------------------------

--DROP PROCEDURE SP_AltaAsignacion

CREATE OR ALTER PROCEDURE SP_AltaAsignacion
	@FechaIngreso DATE,
	@FechaEgreso DATE = NULL,
	@Motivo VARCHAR(200) = NULL,
	@IdParque INT,
	@IdGuardaparque INT
AS
BEGIN
	SET NOCOUNT ON

	--Verificamos que el parque exista
	IF NOT EXISTS (SELECT 1 FROM Parques.Parque WHERE IdParque = @IdParque)
	BEGIN
		RAISERROR('El parque con id %d no existe.', 16, 1, @IdParque);
		RETURN;
	END

	--Verificamos que el guardaparque exista
	IF NOT EXISTS (SELECT 1 FROM Personal.Guardaparque WHERE IdGuardaparque = @IdGuardaparque)
	BEGIN
		RAISERROR('El guardaparque con id %d no existe.', 16, 1, @IdGuardaparque);
		RETURN;
	END

	--Verificamos que el guardaparque no tenga una asignacion activa
	IF EXISTS (SELECT 1 FROM Personal.Asignacion WHERE IdGuardaparque = @IdGuardaparque 
				AND FechaEgreso IS NULL)
	BEGIN
		RAISERROR('El guardaparque con id %d tiene una asignacion activa. Para dar de alta esta asignacion se debe asignar una fecha de egreso en la activa', 16, 1, @IdGuardaparque);
		RETURN;
	END

	INSERT INTO Personal.Asignacion (FechaIngreso, FechaEgreso, Motivo, IdParque, IdGuardaparque)
	VALUES (@FechaIngreso, @FechaEgreso, @Motivo, @IdParque, @IdGuardaparque)

	PRINT'La asignacion fue creada correctamente'
END
GO
