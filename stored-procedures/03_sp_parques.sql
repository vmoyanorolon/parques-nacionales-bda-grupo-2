-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Fecha: 04/07/2026
-- Descripción: Stored Procedures del esquema Parque

USE ParquesNacionales
GO

----------------------------------------
-- CREACION 
----------------------------------------

/*
EXEC USP_AltaParque 'Parque Nacional Iguazú', '18:00', '08:00', 67620.00, 'Misiones', 1, 'Puerto Iguazú', 'Parque Nacional';
SELECT * FROM Parques.Parque
*/

CREATE OR ALTER PROCEDURE USP_AltaParque
    @Nombre VARCHAR(50),
    @HorarioCierre TIME,
    @HorarioApertura TIME,
    @Superficie DECIMAL(10,2),
    @CostoHectarea DECIMAL(10,2),
    @Provincia VARCHAR(50),
    @Numero INT,
    @Localidad VARCHAR(50),
    @TipoParque VARCHAR(50),
    @IdParque INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @errores VARCHAR(2048) = ''

    IF EXISTS (SELECT 1 FROM Parques.Parque WHERE Nombre = @Nombre)
        SET @errores += '- Ya existe un parque con ese nombre.' + CHAR(13)
    
    IF @CostoHectarea IS NOT NULL AND @CostoHectarea <= 0
        SET @errores += '- El costo por hectárea debe ser mayor a cero.' + CHAR(13)


    IF @errores <> ''
    BEGIN
        SET @errores = 'No se pudo dar de alta el parque:' + CHAR(13) + @errores;
        THROW 50000, @errores, 1
    END

    INSERT INTO Parques.Parque
        (Nombre, HorarioCierre, HorarioApertura, Superficie, CostoHectarea, Provincia, Numero, Localidad, TipoParque)
    VALUES
        (@Nombre, @HorarioCierre, @HorarioApertura, @Superficie, @CostoHectarea, @Provincia, @Numero, @Localidad, @TipoParque)
    
    SET @IdParque = SCOPE_IDENTITY();
END
GO

----------------------------------------
-- MODIFICACION
----------------------------------------

/*
EXEC USP_ModificacionParque 1, NULL, '20:00', NULL, NULL, NULL, 123;
SELECT * FROM Parques.Parque
*/

CREATE OR ALTER PROCEDURE USP_ModificacionParque
    @IdParque INT,
    @Nombre VARCHAR(50) = NULL,
    @HorarioCierre TIME = NULL,
    @HorarioApertura TIME = NULL,
    @Superficie DECIMAL(10,2) = NULL,
    @CostoHectarea DECIMAL(10,2) = NULL,
    @Provincia VARCHAR(50) = NULL,
    @Numero INT = NULL,
    @Localidad VARCHAR(50) = NULL,
    @TipoParque VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores VARCHAR(2048) = ''

    IF NOT EXISTS (SELECT 1 FROM Parques.Parque WHERE IdParque = @IdParque)
    THROW 50000, 'El parque indicado no existe.',1 

    IF @Nombre IS NOT NULL AND EXISTS (SELECT 1 FROM Parques.Parque WHERE Nombre = @Nombre AND IdParque <> @IdParque)
    SET @errores += '- Ya existe otro parque con ese nombre.' + CHAR(13)

    IF @CostoHectarea IS NOT NULL AND @CostoHectarea <= 0
    SET @errores += '- El costo por hectárea debe ser mayor a cero.' + CHAR(13)

    IF @errores <> ''
    BEGIN
        SET @errores = 'No se pudo modificar el parque:' + CHAR(13) + @errores;
        THROW 50000, @errores, 1
    END

    UPDATE Parques.Parque
    SET Nombre = COALESCE(@Nombre, Nombre),
        HorarioCierre = COALESCE(@HorarioCierre, HorarioCierre),
        HorarioApertura = COALESCE(@HorarioApertura, HorarioApertura),
        Superficie = COALESCE(@Superficie, Superficie),
        CostoHectarea = COALESCE(@CostoHectarea, CostoHectarea),
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
EXEC USP_BajaParque 1;
SELECT * FROM Parques.Parque
*/

CREATE OR ALTER PROCEDURE USP_BajaParque
    @IdParque INT
AS
BEGIN
    SET NOCOUNT ON;

    -- No se usa variable de error concatenado porque es un único error posible. El resto de errores son detectados en el catch

    IF NOT EXISTS (SELECT 1 FROM Parques.Parque WHERE IdParque = @IdParque)
        THROW 50000, 'El parque indicado no existe.', 1;

    BEGIN TRY
        DELETE FROM Parques.Parque WHERE IdParque = @IdParque;
    END TRY
    BEGIN CATCH
        THROW 50000, 'No se puede eliminar el parque: tiene registros relacionados (actividades, entradas, concesiones, personal asignado, etc.).', 1;
    END CATCH
END