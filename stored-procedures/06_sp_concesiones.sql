-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: Stored Procedures del esquema Concesiones

USE ParquesNacionales
GO

-- =============================================
-- SP_AltaOrganizacionConcesionaria
-- =============================================

--DROP PROCEDURE SP_AltaOrganizacionConcesionaria

CREATE OR ALTER PROCEDURE SP_AltaOrganizacionConcesionaria
    @Nombre VARCHAR(50),
    @TipoActividad VARCHAR(50),
    @Cuit CHAR(11),
    @CorreoContacto VARCHAR(100) = NULL,
    @TelefonoContacto VARCHAR(20) = NULL,
    @DomicilioRegistrado VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON
    SET XACT_ABORT ON

    DECLARE @IdOrganizacionConcesionaria INT
    DECLARE @errores VARCHAR(2048) = ''

    IF EXISTS(
        SELECT 1 FROM Concesiones.OrganizacionConcesionaria
        WHERE Cuit = @Cuit
    )
        SET @errores += '- El CUIT ingresado ya existe.' + CHAR(13)

    IF @errores <> ''
    BEGIN
        SET @errores = 'No se pudo dar de alta la organización concesionaria:' + CHAR(13) + @errores;
        THROW 50000, @errores, 1
    END

    BEGIN TRANSACTION
        INSERT INTO Concesiones.OrganizacionConcesionaria
            (Nombre, TipoActividad, Cuit, CorreoContacto, TelefonoContacto, DomicilioRegistrado)
        VALUES
            (@Nombre, @TipoActividad, @Cuit, @CorreoContacto, @TelefonoContacto, @DomicilioRegistrado)
        SELECT @IdOrganizacionConcesionaria = SCOPE_IDENTITY()
    COMMIT TRANSACTION

    PRINT 'La organización concesionaria ' + CAST(@IdOrganizacionConcesionaria AS VARCHAR) + ' fue creada con éxito'
END
GO

-- =============================================
-- SP_ModificacionOrganizacionConcesionaria
-- =============================================

--DROP PROCEDURE SP_ModificacionOrganizacionConcesionaria

CREATE OR ALTER PROCEDURE SP_ModificacionOrganizacionConcesionaria
    @IdOrganizacionConcesionaria INT,
    @Cuit CHAR(11) = NULL,
    @Nombre VARCHAR(50) = NULL,
    @TipoActividad VARCHAR(50) = NULL,
    @CorreoContacto VARCHAR(100) = NULL,
    @TelefonoContacto VARCHAR(20) = NULL,
    @DomicilioRegistrado VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON
    SET XACT_ABORT ON

    DECLARE @CambioValidoCuit BIT = 0
    DECLARE @errores VARCHAR(2048) = ''

    IF NOT EXISTS(
        SELECT 1 FROM Concesiones.OrganizacionConcesionaria
        WHERE IdOrganizacionConcesionaria = @IdOrganizacionConcesionaria
    )
        SET @errores += '- La organización concesionaria indicada no existe.' + CHAR(13)

    IF @errores <> ''
    BEGIN
        SET @errores = 'No se pudo modificar la organización concesionaria:' + CHAR(13) + @errores;
        THROW 50000, @errores, 1
    END

    IF @Cuit IS NOT NULL
    BEGIN
        IF EXISTS(
            SELECT 1 FROM Concesiones.OrganizacionConcesionaria
            WHERE Cuit = @Cuit
        )
            PRINT 'El CUIT ingresado ya existe, por lo que no se cambiará dicho campo'
        ELSE
            SET @CambioValidoCuit = 1
    END

    BEGIN TRANSACTION
        UPDATE Concesiones.OrganizacionConcesionaria
        SET
            Cuit               = IIF(@CambioValidoCuit = 0, Cuit, @Cuit),
            Nombre             = ISNULL(@Nombre, Nombre),
            TipoActividad      = ISNULL(@TipoActividad, TipoActividad),
            CorreoContacto     = ISNULL(@CorreoContacto, CorreoContacto),
            TelefonoContacto   = ISNULL(@TelefonoContacto, TelefonoContacto),
            DomicilioRegistrado = ISNULL(@DomicilioRegistrado, DomicilioRegistrado)
        WHERE IdOrganizacionConcesionaria = @IdOrganizacionConcesionaria
    COMMIT TRANSACTION

    PRINT 'La organización concesionaria ' + CAST(@IdOrganizacionConcesionaria AS VARCHAR) + ' fue actualizada con éxito'
END
GO

-- =============================================
-- SP_BajaOrganizacionConcesionaria
-- =============================================

--DROP PROCEDURE SP_BajaOrganizacionConcesionaria

CREATE OR ALTER PROCEDURE SP_BajaOrganizacionConcesionaria
    @IdOrganizacionConcesionaria INT
AS
BEGIN
    SET NOCOUNT ON
    SET XACT_ABORT ON

    DECLARE @errores VARCHAR(2048) = ''

    IF NOT EXISTS(
        SELECT 1 FROM Concesiones.OrganizacionConcesionaria
        WHERE IdOrganizacionConcesionaria = @IdOrganizacionConcesionaria
    )
        SET @errores += '- La organización concesionaria indicada no existe.' + CHAR(13)

    IF EXISTS(
        SELECT 1 FROM Concesiones.Concesion
        WHERE IdOrganizacionConcesionaria = @IdOrganizacionConcesionaria
    )
        SET @errores += '- La organización concesionaria cuenta con concesiones asociadas.' + CHAR(13)

    IF @errores <> ''
    BEGIN
        SET @errores = 'No se pudo dar de baja la organización concesionaria:' + CHAR(13) + @errores;
        THROW 50000, @errores, 1
    END

    BEGIN TRANSACTION
        DELETE FROM Concesiones.OrganizacionConcesionaria
        WHERE IdOrganizacionConcesionaria = @IdOrganizacionConcesionaria
    COMMIT TRANSACTION

    PRINT 'La organización concesionaria ' + CAST(@IdOrganizacionConcesionaria AS VARCHAR) + ' fue eliminada con éxito'
END
GO

-- =============================================
-- SP_AltaConcesion
-- =============================================

--DROP PROCEDURE SP_AltaConcesion

CREATE OR ALTER PROCEDURE SP_AltaConcesion
    @IdParque INT,
    @IdOrganizacionConcesionaria INT,
    @CanonMensual DECIMAL(10,2),
    @ExtensionConcedida DECIMAL(10,2),
    @FechaInicio DATE = NULL
AS
BEGIN
    SET NOCOUNT ON
    SET XACT_ABORT ON

    DECLARE @IdConcesion INT
    DECLARE @EstadoConcesion VARCHAR(8) = 'Activo'
    DECLARE @SuperficieParque DECIMAL(10,2)
    DECLARE @SuperficieConcedidaTotal DECIMAL(10,2)
    DECLARE @PorcentajeMaximoPermitido DECIMAL(10,2) = 0.1
    DECLARE @errores VARCHAR(2048) = ''

    SELECT @SuperficieParque = Superficie
    FROM Parques.Parque
    WHERE IdParque = @IdParque

    IF @SuperficieParque IS NULL
        SET @errores += '- El parque ingresado no existe.' + CHAR(13)

    IF NOT EXISTS(
        SELECT 1 FROM Concesiones.OrganizacionConcesionaria
        WHERE IdOrganizacionConcesionaria = @IdOrganizacionConcesionaria
    )
        SET @errores += '- La organización concesionaria ingresada no existe.' + CHAR(13)

    -- Solo validamos el límite de superficie si el parque existe
    IF @SuperficieParque IS NOT NULL
    BEGIN
        SELECT @SuperficieConcedidaTotal = ISNULL(SUM(ExtensionConcedida), 0)
        FROM Concesiones.Concesion
        WHERE IdParque = @IdParque
        AND EstadoConcesion = 'Activo'

        IF @SuperficieConcedidaTotal + @ExtensionConcedida > @SuperficieParque * @PorcentajeMaximoPermitido
            SET @errores += '- La extensión que se desea conceder supera el límite establecido por ley (Art. 12, Ley 22.351).' + CHAR(13)
    END

    IF @errores <> ''
    BEGIN
        SET @errores = 'No se pudo dar de alta la concesión:' + CHAR(13) + @errores;
        THROW 50000, @errores, 1
    END

    SELECT @FechaInicio = ISNULL(@FechaInicio, GETDATE())

    BEGIN TRANSACTION
        INSERT INTO Concesiones.Concesion
            (IdParque, IdOrganizacionConcesionaria, CanonMensual, ExtensionConcedida, EstadoConcesion, FechaInicio)
        VALUES
            (@IdParque, @IdOrganizacionConcesionaria, @CanonMensual, @ExtensionConcedida, @EstadoConcesion, @FechaInicio)
        SELECT @IdConcesion = SCOPE_IDENTITY()
    COMMIT TRANSACTION

    PRINT 'La concesión ' + CAST(@IdConcesion AS VARCHAR) + ' fue creada con éxito'
END
GO

-- =============================================
-- SP_ModificacionConcesion
-- =============================================

--DROP PROCEDURE SP_ModificacionConcesion

CREATE OR ALTER PROCEDURE SP_ModificacionConcesion
    @IdConcesion INT,
    @CanonMensual DECIMAL(10,2) = NULL,
    @ExtensionConcedida DECIMAL(10,2) = NULL
AS
BEGIN
    SET NOCOUNT ON
    SET XACT_ABORT ON

    DECLARE @IdParque INT
    DECLARE @SuperficieParque DECIMAL(10,2)
    DECLARE @SuperficieConcedidaTotal DECIMAL(10,2)
    DECLARE @PorcentajeMaximoPermitido DECIMAL(10,2) = 0.1
    DECLARE @errores VARCHAR(2048) = ''

    SELECT @IdParque = IdParque
    FROM Concesiones.Concesion
    WHERE IdConcesion = @IdConcesion

    IF @IdParque IS NULL
        SET @errores += '- La concesión indicada no existe.' + CHAR(13)

    IF @IdParque IS NOT NULL AND @ExtensionConcedida IS NOT NULL
    BEGIN
        SELECT @SuperficieParque = Superficie
        FROM Parques.Parque
        WHERE IdParque = @IdParque

        SELECT @SuperficieConcedidaTotal = ISNULL(SUM(ExtensionConcedida), 0)
        FROM Concesiones.Concesion
        WHERE IdParque = @IdParque
        AND EstadoConcesion = 'Activo'
        AND IdConcesion != @IdConcesion

        IF @SuperficieConcedidaTotal + @ExtensionConcedida > @SuperficieParque * @PorcentajeMaximoPermitido
            SET @errores += '- La extensión que se desea conceder supera el límite establecido por ley (Art. 12, Ley 22.351).' + CHAR(13)
    END

    IF @errores <> ''
    BEGIN
        SET @errores = 'No se pudo modificar la concesión:' + CHAR(13) + @errores;
        THROW 50000, @errores, 1
    END

    BEGIN TRANSACTION
        UPDATE Concesiones.Concesion
        SET
            CanonMensual        = ISNULL(@CanonMensual, CanonMensual),
            ExtensionConcedida  = ISNULL(@ExtensionConcedida, ExtensionConcedida)
        WHERE IdConcesion = @IdConcesion
    COMMIT TRANSACTION

    PRINT 'La concesión ' + CAST(@IdConcesion AS VARCHAR) + ' fue modificada con éxito'
END
GO

-- =============================================
-- SP_BajaConcesion
-- =============================================

--DROP PROCEDURE SP_BajaConcesion

CREATE OR ALTER PROCEDURE SP_BajaConcesion
    @IdConcesion INT
AS
BEGIN
    SET NOCOUNT ON
    SET XACT_ABORT ON

    DECLARE @errores VARCHAR(2048) = ''

    IF NOT EXISTS(
        SELECT 1 FROM Concesiones.Concesion
        WHERE IdConcesion = @IdConcesion
    )
        SET @errores += '- La concesión indicada no existe.' + CHAR(13)

    IF EXISTS(
        SELECT 1 FROM Concesiones.Concesion
        WHERE IdConcesion = @IdConcesion
        AND EstadoConcesion = 'Inactivo'
    )
        SET @errores += '- La concesión indicada ya está inactiva.' + CHAR(13)

    IF @errores <> ''
    BEGIN
        SET @errores = 'No se pudo dar de baja la concesión:' + CHAR(13) + @errores;
        THROW 50000, @errores, 1
    END

    BEGIN TRANSACTION
        UPDATE Concesiones.Concesion
        SET EstadoConcesion = 'Inactivo'
        WHERE IdConcesion = @IdConcesion
    COMMIT TRANSACTION

    PRINT 'La concesión ' + CAST(@IdConcesion AS VARCHAR) + ' fue dada de baja con éxito'
END
GO

-- =============================================
-- SP_AltaPagoConcesion
-- =============================================

--DROP PROCEDURE SP_AltaPagoConcesion

CREATE OR ALTER PROCEDURE SP_AltaPagoConcesion
    @IdConcesion INT,
    @Fecha DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON
    SET XACT_ABORT ON

    DECLARE @IdPagoConcesion INT
    DECLARE @Monto DECIMAL(10,2)
    DECLARE @EstadoConcesion VARCHAR(8)
    DECLARE @errores VARCHAR(2048) = ''

    SELECT @Monto = CanonMensual,
           @EstadoConcesion = EstadoConcesion
    FROM Concesiones.Concesion
    WHERE IdConcesion = @IdConcesion

    IF @Monto IS NULL
        SET @errores += '- La concesión indicada no existe.' + CHAR(13)

    IF @EstadoConcesion = 'Inactivo'
        SET @errores += '- La concesión indicada está inactiva.' + CHAR(13)

    IF @errores <> ''
    BEGIN
        SET @errores = 'No se pudo dar de alta el pago de concesión:' + CHAR(13) + @errores;
        THROW 50000, @errores, 1
    END

    SELECT @Fecha = ISNULL(@Fecha, GETDATE())

    BEGIN TRANSACTION
        INSERT INTO Concesiones.PagoConcesion (IdConcesion, Fecha, Monto)
        VALUES (@IdConcesion, @Fecha, @Monto)
        SELECT @IdPagoConcesion = SCOPE_IDENTITY()
    COMMIT TRANSACTION

    PRINT 'El pago de concesión ' + CAST(@IdPagoConcesion AS VARCHAR) + ' fue creado con éxito'
END
GO