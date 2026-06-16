-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: Stored Procedures del esquema Parque

USE ParquesNacionales
GO

----------------------------------------
-- CREACION 
----------------------------------------

/*
EXEC SP_AltaParque 'Parque Nacional Iguazú', '18:00', '08:00', 67620.00, 'Misiones', 1, 'Puerto Iguazú', 'Parque Nacional';
SELECT * FROM Parques.Parque
*/

CREATE OR ALTER PROCEDURE SP_AltaParque
    @Nombre VARCHAR(50),
    @HorarioCierre TIME,
    @HorarioApertura TIME,
    @Superficie DECIMAL(10,2),
    @Provincia VARCHAR(50),
    @Numero INT,
    @Localidad VARCHAR(50),
    @TipoParque VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM Parques.Parque WHERE Nombre = @Nombre)
    BEGIN
        RAISERROR('Ya existe un parque con ese nombre.', 16, 1);
        RETURN;
    END

    INSERT INTO Parques.Parque
        (Nombre, HorarioCierre, HorarioApertura, Superficie, Provincia, Numero, Localidad, TipoParque)
    VALUES
        (@Nombre, @HorarioCierre, @HorarioApertura, @Superficie, @Provincia, @Numero, @Localidad, @TipoParque);
END
GO

----------------------------------------
-- MODIFICACION
----------------------------------------

/*
EXEC SP_ModificacionParque 1, NULL, '20:00', NULL, NULL, NULL, 123;
SELECT * FROM Parques.Parque
*/

CREATE OR ALTER PROCEDURE SP_ModificacionParque
    @IdParque INT,
    @Nombre VARCHAR(50) = NULL,
    @HorarioCierre TIME = NULL,
    @HorarioApertura TIME = NULL,
    @Superficie DECIMAL(10,2) = NULL,
    @Provincia VARCHAR(50) = NULL,
    @Numero INT = NULL,
    @Localidad VARCHAR(50) = NULL,
    @TipoParque VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Parques.Parque WHERE IdParque = @IdParque)
    BEGIN
        RAISERROR('El parque no existe.', 16, 1);
        RETURN;
    END

    IF @Nombre IS NOT NULL AND EXISTS (SELECT 1 FROM Parques.Parque WHERE Nombre = @Nombre AND IdParque <> @IdParque)
    BEGIN
        RAISERROR('Ya existe otro parque con ese nombre.', 16, 1);
        RETURN;
    END

    UPDATE Parques.Parque
    SET Nombre = COALESCE(@Nombre, Nombre),
        HorarioCierre = COALESCE(@HorarioCierre, HorarioCierre),
        HorarioApertura = COALESCE(@HorarioApertura, HorarioApertura),
        Superficie = COALESCE(@Superficie, Superficie),
        Provincia = COALESCE(@Provincia, Provincia),
        Numero = COALESCE(@Numero, Numero),
        Localidad = COALESCE(@Localidad, Localidad),
        TipoParque = COALESCE(@TipoParque, TipoParque)
    WHERE IdParque = @IdParque;
END
GO

----------------------------------------
-- BAJA 
----------------------------------------

/*
EXEC SP_BajaParque 1;
SELECT * FROM Parques.Parque
*/

CREATE OR ALTER PROCEDURE SP_BajaParque
    @IdParque INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Parques.Parque WHERE IdParque = @IdParque)
    BEGIN
        RAISERROR('El parque no existe.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        DELETE FROM Parques.Parque WHERE IdParque = @IdParque;
    END TRY
    BEGIN CATCH
        RAISERROR('No se puede eliminar el parque: tiene registros relacionados (actividades, entradas, concesiones, personal asignado, etc.).', 16, 1);
    END CATCH
END