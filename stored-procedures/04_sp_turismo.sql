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
EXEC USP_AltaVisitante '1122334455', 'visitante@gmail.com', '123123123', 'DNI', '201231231233', 30, 'Juan', 'Perez';
SELECT * FROM Turismo.Visitante;
*/

CREATE OR ALTER PROCEDURE USP_AltaVisitante
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

    DECLARE @errores VARCHAR(2048) = ''

    IF EXISTS (SELECT 1 FROM Turismo.Visitante WHERE NumeroDocumento = @NumeroDocumento)
        SET @errores += 'Ya existe un visitante con ese número de documento.' + CHAR(13)

    IF EXISTS (SELECT 1 FROM Turismo.Visitante WHERE CUIT = @CUIT)
        SET @errores += 'Ya existe un visitante con ese CUIT.' + CHAR(13)

    IF @errores <> ''
    BEGIN
        SET @errores = 'No se pudo dar de alta al visitante:' + CHAR(13) + @errores;
        THROW 50000, @errores, 1
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
EXEC USP_ModificacionVisitante 1, '999888777', 'nuevo-visitante@gmail.com', null, null, null, null, 'Juanceto';
SELECT * FROM Turismo.Visitante;
*/

CREATE OR ALTER PROCEDURE USP_ModificacionVisitante
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

    DECLARE @errores VARCHAR(2048) = ''

    IF NOT EXISTS (SELECT 1 FROM Turismo.Visitante WHERE IdVisitante = @IdVisitante)
        SET @errores += 'El visitante no existe.' + CHAR(13)

    IF @NumeroDocumento IS NOT NULL AND EXISTS (SELECT 1 FROM Turismo.Visitante WHERE NumeroDocumento = @NumeroDocumento AND IdVisitante <> @IdVisitante)
        SET @errores += 'Ya existe otro visitante con ese número de documento.' + CHAR(13)

    IF @CUIT IS NOT NULL AND EXISTS (SELECT 1 FROM Turismo.Visitante WHERE CUIT = @CUIT AND IdVisitante <> @IdVisitante)
        SET @errores += 'Ya existe otro visitante con ese CUIT.' + CHAR(13)

    IF @errores <> ''
    BEGIN
        SET @errores = 'No se pudo modificar al visitante:' + CHAR(13) + @errores;
        THROW 50000, @errores, 1
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
EXEC USP_BajaVisitante 2;
SELECT * FROM Turismo.Visitante;
*/

CREATE OR ALTER PROCEDURE USP_BajaVisitante
    @IdVisitante INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Turismo.Visitante WHERE IdVisitante = @IdVisitante)
        THROW 50000, 'No se puede eliminar al visitante: no existe.', 1;

    IF EXISTS (SELECT 1 FROM Ventas.Venta WHERE IdVisitante = @IdVisitante)
        THROW 50000, 'No se puede eliminar al visitante: tiene ventas asociadas.', 1;

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
EXEC USP_AltaTipoVisitante 'Jubilado', 20
SELECT * FROM Turismo.TipoVisitante
*/


CREATE OR ALTER PROCEDURE USP_AltaTipoVisitante
    @Descripcion VARCHAR(50),
    @Descuento TINYINT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM Turismo.TipoVisitante WHERE Descripcion = @Descripcion)
        THROW 50000, 'Ya existe un tipo de visitante con esa descripción.', 1

    INSERT INTO Turismo.TipoVisitante (Descripcion, Descuento)
    VALUES (@Descripcion, @Descuento);
END
GO
----------------------------------------
-- MODIFICACION 
----------------------------------------

/*
EXEC USP_ModificacionTipoVisitante 1, null, 15;
SELECT * FROM Turismo.TipoVisitante;
*/

CREATE OR ALTER PROCEDURE USP_ModificacionTipoVisitante
    @IdTipoVisitante INT,
    @Descripcion VARCHAR(50) = NULL,
    @Descuento TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores VARCHAR(2048) = ''

    IF NOT EXISTS (SELECT 1 FROM Turismo.TipoVisitante WHERE IdTipoVisitante = @IdTipoVisitante)
        THROW 50000, 'El tipo de visitante no existe.', 1

    IF @Descripcion IS NOT NULL AND EXISTS (SELECT 1 FROM Turismo.TipoVisitante WHERE Descripcion = @Descripcion AND IdTipoVisitante <> @IdTipoVisitante)
        THROW 50000, 'Ya existe otro tipo de visitante con esa descripción.',1

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
EXEC USP_BajaTipoVisitante 1;
SELECT * FROM Turismo.Visitante;
*/

CREATE OR ALTER PROCEDURE USP_BajaTipoVisitante
    @IdTipoVisitante INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Turismo.TipoVisitante WHERE IdTipoVisitante = @IdTipoVisitante)
        THROW 50000, 'El tipo de visitante no existe.', 1

    IF EXISTS (SELECT 1 FROM Turismo.Visitante WHERE IdTipoVisitante = @IdTipoVisitante)
        THROW 50000, 'No se puede eliminar: el tipo de visitante tiene visitantes asociados.', 1

    DELETE FROM Turismo.TipoVisitante WHERE IdTipoVisitante = @IdTipoVisitante;
END
GO

--------------------------------------------------------------------------------
-- TURNO
--------------------------------------------------------------------------------

-- =============================================
-- USP_AltaTurno
-- Dar de alta un turno para una actividad
-- =============================================
/*
DROP PROCEDURE USP_AltaTurno
*/
CREATE OR ALTER PROCEDURE USP_AltaTurno
@IdActividad INT,
@HoraInicio TIME(0),
@HoraFin TIME(0),
@DiaDeSemana TINYINT
AS
BEGIN
    SET NOCOUNT ON
    SET XACT_ABORT ON;

    DECLARE @IdTurno INT

    IF NOT EXISTS(
        SELECT 1
        FROM Turismo.Actividad
        WHERE IdActividad = @IdActividad
    )
        THROW 50000, 'La actividad indicada no existe, no se dará de alta ningún turno',1

    BEGIN TRANSACTION
    BEGIN TRY
        
        INSERT INTO Turismo.Turno(IdActividad, HoraInicio, HoraFin, DiaDeSemana)
        VALUES(@IdActividad, @HoraInicio, @HoraFin, @DiaDeSemana)
        SELECT @IdTurno = SCOPE_IDENTITY()
        
        COMMIT TRANSACTION
        PRINT 'El turno ' + CAST(@IdTurno AS VARCHAR) + ' fue creado con éxito'

    END TRY
    BEGIN CATCH
        PRINT 'Error: ' + ERROR_MESSAGE()
        ROLLBACK TRANSACTION
        THROW
    END CATCH
END
GO

-- =============================================
-- USP_ModificacionTurno
-- Cambiar el costo, la hora de inicio, la hora de fin o el día de semana de un turno para una actividad
-- =============================================
/*
DROP PROCEDURE USP_ModificacionTurno
*/
CREATE OR ALTER PROCEDURE USP_ModificacionTurno
@IdTurno INT,
@HoraInicio TIME(0) = NULL,
@HoraFin TIME(0) = NULL,
@DiaDeSemana TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON
    SET XACT_ABORT ON

    IF NOT EXISTS(
    SELECT 1
    FROM Turismo.Turno
    WHERE IdTurno = @IdTurno
    )
        THROW 50000, 'El turno indicado no existe, no se hará ninguna modificación',1

    BEGIN TRANSACTION
    BEGIN TRY

        UPDATE Turismo.Turno
        SET
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
        THROW
    END CATCH

    END
    GO  

-- =============================================
-- USP_BajaTurno
-- Dar de baja un turno de una actividad
-- =============================================
/*
DROP PROCEDURE USP_BajaTurno
*/
CREATE OR ALTER PROCEDURE USP_BajaTurno
@IdTurno INT
AS
BEGIN
    SET NOCOUNT ON
    SET XACT_ABORT ON

    IF NOT EXISTS(
        SELECT 1
        FROM Turismo.Turno
        WHERE IdTurno = @IdTurno
    )
        THROW 50000,'El turno indicado no existe, no se hará ningún cambio', 1

    BEGIN TRANSACTION
    BEGIN TRY
        DELETE FROM Turismo.Turno WHERE IdTurno = @IdTurno

        COMMIT TRANSACTION
        PRINT 'El turno ' + CAST(@IdTurno AS VARCHAR) + ' fue eliminado con éxito'

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION
        PRINT 'Error: ' + ERROR_MESSAGE();
        THROW
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
DROP PROCEDURE USP_AltaActividad
*/

CREATE OR ALTER PROCEDURE USP_AltaActividad
    @Nombre VARCHAR(50),
    @Costo DECIMAL(10,2),
    @DuracionMinutos INT,
    @Tipo VARCHAR(9),
    @CupoMaximo INT,
    @IdParque INT
AS
BEGIN
    SET NOCOUNT ON

    --Validamos que el parque exista
    IF NOT EXISTS (SELECT 1 FROM Parques.Parque WHERE IdParque = @IdParque)
        THROW 50000, 'El Parque indicado no existe', 1

    --Validamos que no exista la misma actividad dentro del mismo parque
    IF EXISTS (SELECT 1 FROM Turismo.Actividad A WHERE Nombre = @Nombre AND IdParque = @IdParque)
        THROW 50000, 'La actividad ya existe dentro del parque', 1

    INSERT INTO Turismo.Actividad (Nombre, Costo, DuracionMinutos, Tipo, CupoMaximo, IdParque)
    VALUES (@Nombre, @Costo, @DuracionMinutos, @Tipo, @CupoMaximo, @IdParque);

    PRINT 'La actividad se creo correctamente.'
END;
GO

----------------------------------------
-- MODIFICACION
----------------------------------------

/*
DROP PROCEDURE USP_ModificacionActividad
*/

CREATE OR ALTER PROCEDURE USP_ModificacionActividad
    @IdActividad INT,
    @Nombre VARCHAR(50) = NULL,
    @Costo DECIMAL(10,2) = NULL,
    @DuracionMinutos INT = NULL,
    @Tipo VARCHAR(9) = NULL,
    @CupoMaximo INT = NULL
AS
BEGIN
    SET NOCOUNT ON

    --Verficamos que la actividad exista
    IF NOT EXISTS (SELECT 1 FROM Turismo.Actividad WHERE IdActividad = @IdActividad)
        THROW 50000, 'La actividad que se quiere modificar no existe', 1

    UPDATE Turismo.Actividad
    SET Nombre            = ISNULL(@Nombre, Nombre),
        Costo             = ISNULL(@Costo, Costo),
        DuracionMinutos   = ISNULL(@DuracionMinutos, DuracionMinutos),
        Tipo              = ISNULL(@Tipo, Tipo),
        CupoMaximo        = ISNULL(@CupoMaximo, CupoMaximo)
    WHERE IdActividad = @IdActividad;

    PRINT 'Actividad actualizada correctamente.';
END;
GO

----------------------------------------
-- BAJA 
----------------------------------------

/*
DROP PROCEDURE USP_BajaActividad
*/

CREATE OR ALTER PROCEDURE USP_BajaActividad
    @IdActividad INT
AS
BEGIN
    SET NOCOUNT ON

    --Verificamos que exista la actividad
    IF NOT EXISTS (SELECT 1 FROM Turismo.Actividad WHERE IdActividad = @IdActividad)
        THROW 50000, 'La actividad que se quiere eliminar no existe.', 1

    BEGIN TRY
        DELETE FROM Turismo.Actividad WHERE IdActividad = @IdActividad;
        PRINT 'La actividad se elimino correctamente.'
    END TRY
    BEGIN CATCH
        THROW 50000, 'No se puede eliminar la actividad: tiene registros relacionados (parques, entradas, personal asignado, etc.).', 1
    END CATCH
END;
GO
--------------------------------------------------------------------------------
-- EntradaParque
--------------------------------------------------------------------------------
    
----------------------------------------
-- CREACION 
----------------------------------------

CREATE OR ALTER PROCEDURE USP_AltaEntradaParque
    @Costo DECIMAL(10,2),
    @FechaAcceso DATE,
    @IdParque INT
AS
BEGIN
    SET NOCOUNT ON

    --Validamos que el parque exista
    IF NOT EXISTS (SELECT 1 FROM Parques.Parque WHERE IdParque = @IdParque)
        THROW 50000, 'El Parque indicado no existe', 1

    INSERT INTO Turismo.EntradaParque (Costo, FechaAcceso, IdParque) 
    VALUES (@Costo, @FechaAcceso, @IdParque)

    PRINT 'La entrada se creo correctamente.'
END;
GO

----------------------------------------
-- MODIFICACION
----------------------------------------

CREATE OR ALTER PROCEDURE USP_ModificacionEntradaParque
    @IdEntradaParque INT,
    @Costo DECIMAL(10,2) = NULL,
    @FechaAcceso DATE = NULL,
    @IdParque INT = NULL
AS
BEGIN
    SET NOCOUNT ON

    --Validamos que el parque exista si es que se ingreso alguno
    IF @IdParque IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Parques.Parque WHERE IdParque = @IdParque)
        THROW 50000, 'El Parque indicado no existe', 1

    --Validamos que la entrada exista
    IF NOT EXISTS (SELECT 1 FROM Turismo.EntradaParque WHERE IdEntradaParque = @IdEntradaParque)
        THROW 50000, 'La entrada que se quiere modificar no existe.', 1

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

CREATE OR ALTER PROCEDURE USP_BajaEntradaParque
    @IdEntradaParque INT
AS
BEGIN
    SET NOCOUNT ON

    --Validamos que la entrada exista
    IF NOT EXISTS (SELECT 1 FROM Turismo.EntradaParque WHERE IdEntradaParque = @IdEntradaParque)
        THROW 50000, 'la entrada que se quiere eliminar no existe.', 1

    BEGIN TRY
        DELETE FROM Turismo.EntradaParque WHERE IdEntradaParque = @IdEntradaParque;
        PRINT 'la entrada se elimino correctamente.'
    END TRY
    BEGIN CATCH
        THROW 50000, 'No se puede eliminar la entrada al parque: tiene lineas de entrada a parque asociadas.', 1
    END CATCH
END;
GO