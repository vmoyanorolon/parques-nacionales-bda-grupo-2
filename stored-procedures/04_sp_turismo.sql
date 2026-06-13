-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: Stored Procedures del esquema Turismo


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