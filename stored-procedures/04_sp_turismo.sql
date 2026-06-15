-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: Stored Procedures del esquema Turismo

USE ParquesNacionales
GO

--------------------------------------------------------------------------------
-- VISITANTE 
--------------------------------------------------------------------------------

----------------------------------------
-- CREACION 
----------------------------------------

/*
EXEC SP_AltaVisitante '1122334455', 'visitante@gmail.com', '123123123', 'DNI', '201231231233', 30, 'Juan', 'Perez';
SELECT * FROM Turismo.Visitante;
*/

CREATE PROCEDURE SP_AltaVisitante
    @Telefono VARCHAR(20),
    @CorreoVisitante VARCHAR(100),
    @NumeroDocumento VARCHAR(15),
    @TipoDocumento VARCHAR(15),
    @CUIT VARCHAR(15),
    @Edad TINYINT,
    @Nombre VARCHAR(50),
    @Apellido VARCHAR(50),
    @IdTipoVisitante INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM Turismo.Visitante WHERE NumeroDocumento = @NumeroDocumento)
    BEGIN
        RAISERROR('Ya existe un visitante con ese número de documento.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM Turismo.Visitante WHERE CUIT = @CUIT)
    BEGIN
        RAISERROR('Ya existe un visitante con ese CUIT.', 16, 1);
        RETURN;
    END

    INSERT INTO Turismo.Visitante
        (Telefono, CorreoVisitante, NumeroDocumento, TipoDocumento, CUIT, Edad, Nombre, Apellido, IdTipoVisitante)
    VALUES
        (@Telefono, @CorreoVisitante, @NumeroDocumento, @TipoDocumento, @CUIT, @Edad, @Nombre, @Apellido, @IdTipoVisitante);
END
GO

----------------------------------------
-- MODIFICACION 
----------------------------------------

/*
EXEC SP_ModificacionVisitante 1, '999888777', 'nuevo-visitante@gmail.com', null, null, null, null, 'Juanceto';
SELECT * FROM Turismo.Visitante;
*/

CREATE PROCEDURE SP_ModificacionVisitante
    @IdVisitante INT,
    @Telefono VARCHAR(20) = NULL,
    @CorreoVisitante VARCHAR(100) = NULL,
    @NumeroDocumento VARCHAR(15) = NULL,
    @TipoDocumento VARCHAR(15) = NULL,
    @CUIT VARCHAR(15) = NULL,
    @Edad TINYINT = NULL,
    @Nombre VARCHAR(50) = NULL,
    @Apellido VARCHAR(50) = NULL,
    @IdTipoVisitante INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Turismo.Visitante WHERE IdVisitante = @IdVisitante)
    BEGIN
        RAISERROR('El visitante no existe.', 16, 1);
        RETURN;
    END

    IF @NumeroDocumento IS NOT NULL AND EXISTS (SELECT 1 FROM Turismo.Visitante WHERE NumeroDocumento = @NumeroDocumento AND IdVisitante <> @IdVisitante)
    BEGIN
        RAISERROR('Ya existe otro visitante con ese número de documento.', 16, 1);
        RETURN;
    END

    IF @CUIT IS NOT NULL AND EXISTS (SELECT 1 FROM Turismo.Visitante WHERE CUIT = @CUIT AND IdVisitante <> @IdVisitante)
    BEGIN
        RAISERROR('Ya existe otro visitante con ese CUIT.', 16, 1);
        RETURN;
    END

    UPDATE Turismo.Visitante
    SET Telefono = COALESCE(@Telefono, Telefono),
        CorreoVisitante = COALESCE(@CorreoVisitante, CorreoVisitante),
        NumeroDocumento = COALESCE(@NumeroDocumento, NumeroDocumento),
        TipoDocumento = COALESCE(@TipoDocumento, TipoDocumento),
        CUIT = COALESCE(@CUIT, CUIT),
        Edad = COALESCE(@Edad, Edad),
        Nombre = COALESCE(@Nombre, Nombre),
        Apellido = COALESCE(@Apellido, Apellido),
        IdTipoVisitante = COALESCE(@IdTipoVisitante, IdTipoVisitante)
    WHERE IdVisitante = @IdVisitante;
END
GO
----------------------------------------
-- BAJA 
----------------------------------------

/*
EXEC SP_BajaVisitante 2;
SELECT * FROM Turismo.Visitante;
*/

CREATE PROCEDURE SP_BajaVisitante
    @IdVisitante INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Turismo.Visitante WHERE IdVisitante = @IdVisitante)
    BEGIN
        RAISERROR('El visitante no existe.', 16, 1);
        RETURN;
    END

    DELETE FROM Turismo.Visitante WHERE IdVisitante = @IdVisitante;
END
GO
--------------------------------------------------------------------------------
-- TIPOVISITANTE 
--------------------------------------------------------------------------------

----------------------------------------
-- CREACION 
----------------------------------------

/*
EXEC SP_AltaTipoVisitante 'Jubilado', 20
SELECT * FROM Turismo.TipoVisitante
*/


CREATE PROCEDURE SP_AltaTipoVisitante
    @Descripcion VARCHAR(50),
    @Descuento TINYINT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM Turismo.TipoVisitante WHERE Descripcion = @Descripcion)
    BEGIN
        RAISERROR('Ya existe un tipo de visitante con esa descripción.', 16, 1);
        RETURN;
    END

    INSERT INTO Turismo.TipoVisitante (Descripcion, Descuento)
    VALUES (@Descripcion, @Descuento);
END
GO
----------------------------------------
-- MODIFICACION 
----------------------------------------

/*
EXEC SP_ModificacionTipoVisitante 1, null, 15;
SELECT * FROM Turismo.TipoVisitante;
*/

CREATE PROCEDURE SP_ModificacionTipoVisitante
    @IdTipoVisitante INT,
    @Descripcion VARCHAR(50) = NULL,
    @Descuento TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Turismo.TipoVisitante WHERE IdTipoVisitante = @IdTipoVisitante)
    BEGIN
        RAISERROR('El tipo de visitante no existe.', 16, 1);
        RETURN;
    END

    IF @Descripcion IS NOT NULL AND EXISTS (SELECT 1 FROM Turismo.TipoVisitante WHERE Descripcion = @Descripcion AND IdTipoVisitante <> @IdTipoVisitante)
    BEGIN
        RAISERROR('Ya existe otro tipo de visitante con esa descripción.', 16, 1);
        RETURN;
    END

    UPDATE Turismo.TipoVisitante
    SET Descripcion = COALESCE(@Descripcion, Descripcion),
        Descuento = COALESCE(@Descuento, Descuento)
    WHERE IdTipoVisitante = @IdTipoVisitante;
END
GO
----------------------------------------
-- BAJA 
----------------------------------------

/*
EXEC SP_BajaTipoVisitante 1;
SELECT * FROM Turismo.Visitante;
*/

CREATE PROCEDURE SP_BajaTipoVisitante
    @IdTipoVisitante INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Turismo.TipoVisitante WHERE IdTipoVisitante = @IdTipoVisitante)
    BEGIN
        RAISERROR('El tipo de visitante no existe.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM Turismo.Visitante WHERE IdTipoVisitante = @IdTipoVisitante)
    BEGIN
        RAISERROR('No se puede eliminar: el tipo de visitante tiene visitantes asociados.', 16, 1);
        RETURN;
    END

    DELETE FROM Turismo.TipoVisitante WHERE IdTipoVisitante = @IdTipoVisitante;
END
GO

--------------------------------------------------------------------------------
-- LOGICA DE NEGOCIO 
--------------------------------------------------------------------------------

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

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM Parques.Parque WHERE IdParque = @IdParque)
        BEGIN
            RAISERROR('El parque indicado no existe.', 16, 1);
            RETURN;
        END

        IF @NuevoCosto <= 0
        BEGIN
            RAISERROR('El nuevo costo debe ser mayor a cero.', 16, 1);
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Turismo.EntradaParque WHERE IdParque = @IdParque)
        BEGIN
            RAISERROR('El parque no tiene entradas registradas para actualizar.', 16, 1);
            RETURN;
        END

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

--------------------------------------------------------------------------------
-- TURNO
--------------------------------------------------------------------------------

-- =============================================
-- SP_AltaTurno
-- =============================================
/*
DROP PROCEDURE SP_AltaTurno
*/
CREATE OR ALTER PROCEDURE SP_AltaTurno
@IdActividad INT,
@Costo DECIMAL(10,2),
@HoraInicio TIME(0),
@HoraFin TIME(0),
@DiaDeSemana TINYINT
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @IdTurno INT

    IF NOT EXISTS(
        SELECT 1
        FROM Turismo.Actividad
        WHERE IdActividad = @IdActividad
    )
    BEGIN
        RAISERROR('La actividad indicada no existe',16,1)
        RETURN
    END

    BEGIN TRANSACTION
    BEGIN TRY
        
        INSERT INTO Turismo.Turno(IdActividad, Costo, HoraInicio, HoraFin, DiaDeSemana)
        VALUES(@IdActividad, @Costo, @HoraInicio, @HoraFin, @DiaDeSemana)
        SELECT @IdTurno = SCOPE_IDENTITY()
        
        COMMIT TRANSACTION
        PRINT 'El turno ' + CAST(@IdTurno AS VARCHAR) + ' fue creado con éxito'

    END TRY
    BEGIN CATCH
        PRINT 'Error: ' + ERROR_MESSAGE()
        ROLLBACK TRANSACTION
    END CATCH
END
GO

-- =============================================
-- SP_ModificacionTurno
-- =============================================
/*
DROP PROCEDURE SP_ModificacionTurno
*/
CREATE OR ALTER PROCEDURE SP_ModificacionTurno
@IdTurno INT,
@Costo DECIMAL(10,2) = NULL,
@HoraInicio TIME(0) = NULL,
@HoraFin TIME(0) = NULL,
@DiaDeSemana TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON

    IF NOT EXISTS(
    SELECT 1
    FROM Turismo.Turno
    WHERE IdTurno = @IdTurno
    )
    BEGIN
        RAISERROR('El turno indicado no existe',16,1)
        RETURN
    END

    BEGIN TRANSACTION
    BEGIN TRY

        UPDATE Turismo.Turno
        SET
            Costo = ISNULL(@Costo, Costo),
            HoraInicio = ISNULL(@HoraInicio, HoraInicio),
            HoraFin = ISNULL(@HoraFin, HoraFin),
            DiaDeSemana = ISNULL(@DiaDeSemana, DiaDeSemana)
        WHERE IdTurno = @IdTurno
        COMMIT TRANSACTION
        PRINT 'El turno ' + CAST(@IdTurno AS VARCHAR) + ' fue modificado con éxito'

    END TRY
    BEGIN CATCH
        PRINT 'Error: ' + ERROR_MESSAGE()
        ROLLBACK TRANSACTION
    END CATCH

    END
    GO  

-- =============================================
-- SP_BajaTurno
-- =============================================
/*
DROP PROCEDURE SP_BajaTurno
*/
CREATE OR ALTER PROCEDURE SP_BajaTurno
@IdTurno INT
AS
BEGIN
    SET NOCOUNT ON

    IF NOT EXISTS(
        SELECT 1
        FROM Turismo.Turno
        WHERE IdTurno = @IdTurno
    )
    BEGIN
        RAISERROR('El turno indicado no existe', 16, 1)
        RETURN
    END

    IF EXISTS (
        SELECT 1
        FROM Turismo.EntradaActividad ea
        WHERE ea.IdTurno = @IdTurno
    )
    BEGIN
        RAISERROR('El turno tiene entradas a actividades asociadas y no puede eliminarse', 16, 1)
        RETURN
    END

    BEGIN TRANSACTION
    BEGIN TRY
        DELETE FROM Turismo.Turno WHERE IdTurno = @IdTurno

        COMMIT TRANSACTION
        PRINT 'El turno ' + CAST(@IdTurno AS VARCHAR) + ' fue eliminado con éxito'

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION
        PRINT 'Error: ' + ERROR_MESSAGE()
    END CATCH
END
GO

--------------------------------------------------------------------------------
-- ACTIVIDAD
--------------------------------------------------------------------------------

----------------------------------------
-- CREACION 
----------------------------------------

/*
DROP PROCEDURE SP_AltaActividad
*/

CREATE OR ALTER PROCEDURE SP_AltaActividad
    @Nombre VARCHAR(50),
    @Tipo VARCHAR(9),
    @CupoMaximo INT,
    @IdParque INT
AS
BEGIN
    SET NOCOUNT ON

    --Validamos que el parque exista
    IF NOT EXISTS (SELECT 1 FROM Parques.Parque WHERE IdParque = @IdParque)
    BEGIN
        RAISERROR('El Parque con Id %d no existe', 16, 1, @IdParque);
        RETURN;
    END

    --Validamos que no exista la misma actividad dentro del mismo parque
    IF EXISTS (SELECT 1 FROM Turismo.Actividad A WHERE Nombre = @Nombre AND IdParque = @IdParque)
    BEGIN
        RAISERROR('La actividad "%s" ya existe dentro del parque con Id %d', 16, 1, @Nombre, @IdParque);
        RETURN;
    END

    INSERT INTO Turismo.Actividad (Nombre, Tipo, CupoMaximo, IdParque)
    VALUES (@Nombre, @Tipo, @CupoMaximo, @IdParque);

    PRINT 'La actividad se creo correctamente.'
END;
GO

----------------------------------------
-- MODIFICACION
----------------------------------------

/*
DROP PROCEDURE SP_ModificacionActividad
*/

CREATE OR ALTER PROCEDURE SP_ModificacionActividad
    @IdActividad INT,
    @Nombre VARCHAR(50) = NULL,
    @Tipo VARCHAR(9) = NULL,
    @CupoMaximo INT = NULL,
    @IdParque INT = NULL
AS
BEGIN
    SET NOCOUNT ON

    --Validamos que el parque exista
    IF NOT EXISTS (SELECT 1 FROM Parques.Parque WHERE IdParque = @IdParque)
    BEGIN
        RAISERROR('El Parque con Id %d no existe', 16, 1, @IdParque);
        RETURN;
    END

    --Verficamos que la actividad exista
    IF NOT EXISTS (SELECT 1 FROM Turismo.Actividad WHERE IdActividad = @IdActividad)
    BEGIN
        RAISERROR('La actividad que se quiere modificar no existe', 16, 1);
        RETURN;
    END

    UPDATE Turismo.Actividad
    SET Nombre     = ISNULL(@Nombre, Nombre),
        Tipo       = ISNULL(@Tipo, Tipo),
        CupoMaximo = ISNULL(@CupoMaximo, CupoMaximo)
    WHERE IdActividad = @IdActividad;

    PRINT 'Actividad actualizada correctamente.';
END;
GO

----------------------------------------
-- BAJA 
----------------------------------------

/*
DROP PROCEDURE SP_BajaActividad
*/

CREATE OR ALTER PROCEDURE SP_BajaActividad
    @IdActividad INT
AS
BEGIN
    SET NOCOUNT ON

    --Verificamos que exista la actividad
    IF NOT EXISTS (SELECT 1 FROM Turismo.Actividad WHERE IdActividad = @IdActividad)
    BEGIN
        RAISERROR('La actividad que se quiere eliminar no existe.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        DELETE FROM Turismo.Actividad WHERE IdActividad = @IdActividad;
        PRINT 'La actividad se elimino correctamente.'
    END TRY
    BEGIN CATCH
        RAISERROR('No se puede eliminar la actividad: tiene registros relacionados (parques, entradas, personal asignado, etc.).', 16, 1)
    END CATCH
END;
GO
--------------------------------------------------------------------------------
-- EntradaParque
--------------------------------------------------------------------------------
    
----------------------------------------
-- CREACION 
----------------------------------------

CREATE OR ALTER PROCEDURE SP_AltaEntradaParque
    @Costo DECIMAL(10,2),
    @FechaAcceso DATE,
    @IdParque INT
AS
BEGIN
    SET NOCOUNT ON

    --Validamos que el parque exista
    IF NOT EXISTS (SELECT 1 FROM Parques.Parque WHERE IdParque = @IdParque)
    BEGIN
        RAISERROR('El Parque con Id %d no existe', 16, 1, @IdParque);
        RETURN;
    END

    INSERT INTO Turismo.EntradaParque (Costo, FechaAcceso, IdParque) 
    VALUES (@Costo, @FechaAcceso, @IdParque)

    PRINT 'La entrada se creo correctamente.'
END;
GO

----------------------------------------
-- MODIFICACION
----------------------------------------

CREATE OR ALTER PROCEDURE SP_ModificacionEntradaParque
    @IdEntradaParque INT,
    @Costo DECIMAL(10,2) = NULL,
    @FechaAcceso DATE = NULL,
    @IdParque INT = NULL
AS
BEGIN
    SET NOCOUNT ON

    --Validamos que el parque exista si es que se ingreso alguno
    IF @IdParque IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Parques.Parque WHERE IdParque = @IdParque)
    BEGIN
        RAISERROR('El Parque con Id %d no existe', 16, 1, @IdParque);
        RETURN;
    END

    --Validamos que la entrada exista
    IF NOT EXISTS (SELECT 1 FROM Turismo.EntradaParque WHERE IdEntradaParque = @IdEntradaParque)
    BEGIN
        RAISERROR('La entrada que se quiere modificar no existe.', 16, 1);
        RETURN;
    END

    UPDATE Turismo.EntradaParque
    SET Costo       = ISNULL(@Costo, Costo),
        FechaAcceso = ISNULL(@FechaAcceso, FechaAcceso),
        IdParque    = ISNULL(@IdParque, IdParque)
    WHERE IdEntradaParque = @IdEntradaParque;

    PRINT 'La entrada al parque se modifico correctamente.'
END;
GO

----------------------------------------
-- BAJA 
----------------------------------------

CREATE OR ALTER PROCEDURE SP_BajaEntradaParque
    @IdEntradaParque INT
AS
BEGIN
    SET NOCOUNT ON

    --Validamos que la entrada exista
    IF NOT EXISTS (SELECT 1 FROM Turismo.EntradaParque WHERE IdEntradaParque = @IdEntradaParque)
    BEGIN
        RAISERROR('la entrada que se quiere eliminar no existe.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        DELETE FROM Turismo.EntradaParque WHERE IdEntradaParque = @IdEntradaParque;
        PRINT 'la entrada se elimino correctamente.'
    END TRY
    BEGIN CATCH
        RAISERROR('No se puede eliminar la entrada al parque: tiene lineas de entrada a parque asociadas.', 16, 1);
    END CATCH
END;
GO

--------------------------------------------------------------------------------
-- EntradaActividad
--------------------------------------------------------------------------------

----------------------------------------
-- CREACION 
----------------------------------------

CREATE OR ALTER PROCEDURE SP_AltaEntradaActividad
    @fechaAcceso DATE,
    @IdTurno INT
AS
BEGIN
    SET NOCOUNT ON

    --Validamos si existe el turno
    IF NOT EXISTS (SELECT 1 FROM Turismo.Turno WHERE IdTurno = @IdTurno)
    BEGIN
        RAISERROR('El turno con Id %d no existe', 16, 1, @IdTurno);
        RETURN;
    END

    --Validamos que el dia de la fecha de acceso coincida con el dia del turno
    IF DATEPART(WEEKDAY, @fechaAcceso) <> (SELECT DiaDeSemana FROM Turismo.Turno WHERE IdTurno = @IdTurno)
    BEGIN
        RAISERROR('El dia de la entrada a la actividad no coincide con el dia del turno asociado.', 16, 1);
        RETURN;
    END

    INSERT INTO Turismo.EntradaActividad (FechaAcceso, IdTurno)
    VALUES (@fechaAcceso, @IdTurno);

    PRINT'La entrada a actividad isertada correctamente.'
END;
GO

----------------------------------------
-- MODIFICACION
----------------------------------------

CREATE OR ALTER PROCEDURE SP_ModificacionEntradaActividad
    @IdEntradaActividad INT,
    @IdTurno INT
AS
BEGIN
    SET NOCOUNT ON

    --Validamos que la EntradaActividad exista
    IF NOT EXISTS (SELECT 1 FROM Turismo.EntradaActividad WHERE IdEntradaActividad = @IdEntradaActividad)
    BEGIN
        RAISERROR('El id %d de la entrada a la actividad no existe', 16, 1, @IdEntradaActividad);
        RETURN;
    END

    --Validamos que el turno ingresado exista
    IF NOT EXISTS (SELECT 1 FROM Turismo.Turno WHERE IdTurno = @IdTurno)
    BEGIN
        RAISERROR('El id %d del turno no existe', 16, 1, @IdTurno);
        RETURN;
    END

    --Validamos que al turno que se quiere cambiar sea para el mismo dia que la fechaAcceso de esa entrada a la actividad
    IF (SELECT DATEPART(WEEKDAY, FechaAcceso) FROM Turismo.EntradaActividad WHERE IdEntradaActividad = @IdEntradaActividad) 
       <> (SELECT DiaDeSemana FROM Turismo.Turno WHERE IdTurno = @IdTurno)
    BEGIN
        RAISERROR('La fecha del nuevo IdTurno %d es distinta a la fecha asociada a esta EntradaActividad %d', 16, 1, @IdTurno, @IdEntradaActividad);
        RETURN;
    END
    
    UPDATE Turismo.EntradaActividad
    SET IdTurno = @IdTurno
    WHERE IdEntradaActividad = @IdEntradaActividad

    PRINT'El turno se actualizo correctamente.'
END;
GO

----------------------------------------
-- BAJA 
----------------------------------------

CREATE OR ALTER PROCEDURE SP_BajaEntradaActividad
    @IdEntradaActividad INT
AS
BEGIN
    SET NOCOUNT ON
    
    --Verificamos que exista la entrada
    IF NOT EXISTS (SELECT 1 FROM Turismo.EntradaActividad WHERE IdEntradaActividad = @IdEntradaActividad)
    BEGIN
        RAISERROR('El id %d de entrada a la actividad no existe', 16, 1, @IdEntradaActividad);
        RETURN;
    END

    BEGIN TRY
        DELETE FROM Turismo.EntradaActividad WHERE IdEntradaActividad = @IdEntradaActividad;
        PRINT'La entrada a la actividad fue eliminada correctamente.'
    END TRY
    BEGIN CATCH
        RAISERROR('No se puede eliminar la entrada a la actividad: tiene lineas de entrada a actividad asociadas.', 16, 1);
    END CATCH

END;
GO