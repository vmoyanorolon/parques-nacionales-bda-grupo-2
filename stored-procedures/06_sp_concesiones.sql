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
/*
DROP PROCEDURE SP_AltaOrganizacionConcesionaria
*/
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
    
    DECLARE @IdOrganizacionConcesionaria INT

    IF EXISTS(
        SELECT 1
        FROM Concesiones.OrganizacionConcesionaria oc
        WHERE oc.Cuit = @Cuit
    )
    BEGIN
        RAISERROR('El Cuit ingresado ya existe, no se creará ninguna nueva organización concesionaria',16,1)
        RETURN
    END

    BEGIN TRANSACTION
    BEGIN TRY
        
        INSERT INTO Concesiones.OrganizacionConcesionaria(Nombre,TipoActividad,Cuit,CorreoContacto,TelefonoContacto,DomicilioRegistrado)
        VALUES(
            @Nombre,
            @TipoActividad,
            @Cuit,
            @CorreoContacto,
            @TelefonoContacto,
            @DomicilioRegistrado
        )
        SELECT @IdOrganizacionConcesionaria = SCOPE_IDENTITY()
        COMMIT TRANSACTION
        PRINT 'La organización concesionaria ' + CAST(@IdOrganizacionConcesionaria AS VARCHAR) + ' fue creada con éxito'

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION
		PRINT 'Error: ' + ERROR_MESSAGE()
    END CATCH
END
GO

-- =============================================
-- SP_ModificacionOrganizacionConcesionaria
-- =============================================
/*
DROP PROCEDURE SP_ModificacionOrganizacionConcesionaria
*/
CREATE OR ALTER PROCEDURE SP_ModificacionOrganizacionConcesionaria
-- @VariableParametro TIPODATO
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

    DECLARE @CambioValidoCuit BIT = 0

    IF NOT EXISTS(
        SELECT 1
        FROM Concesiones.OrganizacionConcesionaria
        WHERE IdOrganizacionConcesionaria = @IdOrganizacionConcesionaria
    )
    BEGIN
        RAISERROR('La organización concesionaria indicada no existe, no se realizará ningún cambio',16,1)
        RETURN
    END

    IF @Cuit IS NOT NULL
    BEGIN
        IF EXISTS(
            SELECT 1
            FROM Concesiones.OrganizacionConcesionaria
            WHERE Cuit = @Cuit
        )
        BEGIN
            PRINT 'El CUIT ingresado ya existe, por lo que no se cambiará dicho campo'
        END
        ELSE
        BEGIN
            SET @CambioValidoCuit = 1
        END
    END

    BEGIN TRANSACTION
    BEGIN TRY
        
        UPDATE Concesiones.OrganizacionConcesionaria
        SET
            Cuit = IIF(@CambioValidoCuit = 0, Cuit, @Cuit),
	        Nombre = ISNULL(@Nombre, Nombre),
	        TipoActividad = ISNULL(@TipoActividad, TipoActividad),
	        CorreoContacto = ISNULL(@CorreoContacto, CorreoContacto),
	        TelefonoContacto = ISNULL(@TelefonoContacto, TelefonoContacto),
	        DomicilioRegistrado = ISNULL(@DomicilioRegistrado, DomicilioRegistrado)
        WHERE IdOrganizacionConcesionaria = @IdOrganizacionConcesionaria

        COMMIT TRANSACTION
        PRINT 'La organización concesionaria ' + CAST(@IdOrganizacionConcesionaria AS VARCHAR) + ' fue actualizada con éxito'

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION
		PRINT 'Error: ' + ERROR_MESSAGE()
    END CATCH
END
GO

-- =============================================
-- SP_BajaOrganizacionConcesionaria
-- =============================================
/*
DROP PROCEDURE SP_BajaOrganizacionConcesionaria
*/
CREATE OR ALTER PROCEDURE SP_BajaOrganizacionConcesionaria
    @IdOrganizacionConcesionaria INT
AS
BEGIN
    SET NOCOUNT ON

    IF NOT EXISTS(
        SELECT 1
        FROM Concesiones.OrganizacionConcesionaria
        WHERE IdOrganizacionConcesionaria = @IdOrganizacionConcesionaria
    )
    BEGIN
        RAISERROR('La organización concesionaria indicada no existe, no se realizará ningún cambio',16,1)
        RETURN
    END

    IF EXISTS(
        SELECT 1
        FROM Concesiones.Concesion
        WHERE IdOrganizacionConcesionaria = @IdOrganizacionConcesionaria
    )
    BEGIN
        RAISERROR('La organización concesionaria indicada cuenta con concesiones, no será eliminada',16,1)
        RETURN
    END

    BEGIN TRANSACTION
    BEGIN TRY
        
        DELETE FROM Concesiones.OrganizacionConcesionaria
        WHERE IdOrganizacionConcesionaria = @IdOrganizacionConcesionaria

        COMMIT TRANSACTION
        PRINT 'La organización concesionaria ' + CAST(@IdOrganizacionConcesionaria AS VARCHAR) + ' fue eliminada con éxito'

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION
		PRINT 'Error: ' + ERROR_MESSAGE()
    END CATCH
END
GO

-- =============================================
-- SP_AltaConcesion
-- =============================================
/*
DROP PROCEDURE SP_AltaConcesion
*/
CREATE OR ALTER PROCEDURE SP_AltaConcesion
@IdParque INT,
@IdOrganizacionConcesionaria INT,
@CanonMensual DECIMAL(10,2),
@ExtensionConcedida DECIMAL(10,2),
@FechaInicio DATE = NULL
AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE @IdConcesion INT
    DECLARE @EstadoConcesion VARCHAR(8) = 'Activo'

    IF NOT EXISTS(
        SELECT 1
        FROM Parques.Parque
        WHERE IdParque = @IdParque
    )
    BEGIN
        RAISERROR('El parque ingresado no existe, no se dará de alta la concesión',16,1)
        RETURN
    END

    IF NOT EXISTS(
        SELECT 1
        FROM Concesiones.OrganizacionConcesionaria
        WHERE IdOrganizacionConcesionaria = @IdOrganizacionConcesionaria
    )
    BEGIN
        RAISERROR('La organización concesionaria ingresada no existe, no se dará de alta la concesión',16,1)
        RETURN
    END

    SELECT @FechaInicio = ISNULL(@FechaInicio, GETDATE())

    BEGIN TRANSACTION
    BEGIN TRY
        
        INSERT INTO Concesiones.Concesion(IdParque,IdOrganizacionConcesionaria,CanonMensual,ExtensionConcedida,EstadoConcesion,FechaInicio)
        VALUES(@IdParque,@IdOrganizacionConcesionaria,@CanonMensual,@ExtensionConcedida,@EstadoConcesion,@FechaInicio)
        SELECT @IdConcesion = SCOPE_IDENTITY()

        COMMIT TRANSACTION
        PRINT 'La concesión ' + CAST(@IdConcesion AS VARCHAR) + ' fue creada con éxito'

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION
		PRINT 'Error: ' + ERROR_MESSAGE()
    END CATCH
END
GO

-- =============================================
-- SP_ModificacionConcesion
-- =============================================
/*
DROP PROCEDURE SP_ModificacionConcesion
*/
CREATE OR ALTER PROCEDURE SP_ModificacionConcesion
@IdConcesion INT,
@CanonMensual DECIMAL(10,2) = NULL,
@ExtensionConcedida DECIMAL(10,2) = NULL
AS
BEGIN
    SET NOCOUNT ON
    
    IF NOT EXISTS(
        SELECT 1
        FROM Concesiones.Concesion
        WHERE IdConcesion = @IdConcesion
    )
    BEGIN
        RAISERROR('La concesión indicada no existe, no se realizará ningún cambio',16,1)
        RETURN
    END

    BEGIN TRANSACTION
    BEGIN TRY
        
        UPDATE Concesiones.Concesion
        SET
            CanonMensual = ISNULL(@CanonMensual, CanonMensual),
            ExtensionConcedida = ISNULL(@ExtensionConcedida, ExtensionConcedida)
        WHERE IdConcesion = @IdConcesion

        COMMIT TRANSACTION
        PRINT 'La concesión ' + CAST(@IdConcesion AS VARCHAR) + ' fue modificada con éxito'

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION
		PRINT 'Error: ' + ERROR_MESSAGE()
    END CATCH
END
GO

-- =============================================
-- SP_BajaConcesion
-- =============================================
/*
DROP PROCEDURE SP_BajaConcesion
*/
CREATE OR ALTER PROCEDURE SP_BajaConcesion
@IdConcesion INT
AS
BEGIN
    SET NOCOUNT ON
    
    IF NOT EXISTS(
        SELECT 1
        FROM Concesiones.Concesion
        WHERE IdConcesion = @IdConcesion
    )
    BEGIN
        RAISERROR('La concesión indicada no existe, no se dará de baja ningún registro',16,1)
        RETURN
    END

    IF EXISTS(
        SELECT 1
        FROM Concesiones.Concesion
        WHERE IdConcesion = @IdConcesion
        AND   EstadoConcesion = 'Inactivo'
    )
    BEGIN
        RAISERROR('La concesión indicada ya está inactiva, no se realizará ningún cambio',16,1)
        RETURN
    END

    BEGIN TRANSACTION
    BEGIN TRY
        
        UPDATE Concesiones.Concesion
        SET EstadoConcesion = 'Inactivo'
        WHERE IdConcesion = @IdConcesion

        COMMIT TRANSACTION
        PRINT 'La concesión ' + CAST(@IdConcesion AS VARCHAR) + ' fue dada de baja con éxito'

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION
		PRINT 'Error: ' + ERROR_MESSAGE()
    END CATCH
END
GO

-- =============================================
-- SP_AltaPagoConcesion
-- =============================================
/*
DROP PROCEDURE SP_AltaPagoConcesion
*/
CREATE OR ALTER PROCEDURE SP_AltaPagoConcesion
@IdConcesion INT,
@Fecha DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE @IdPagoConcesion INT
    DECLARE @Monto DECIMAL(10,2)
    DECLARE @EstadoConcesion VARCHAR(8)

    SELECT  @Monto = CanonMensual,
            @EstadoConcesion = EstadoConcesion
    FROM Concesiones.Concesion
    WHERE IdConcesion = @IdConcesion

    IF @Monto IS NULL
    BEGIN
        RAISERROR('La concesión indicada no existe, no se dará de alta el pago', 16, 1)
        RETURN
    END

    IF @EstadoConcesion = 'Inactivo'
    BEGIN
        RAISERROR('La concesión indicada está inactiva, no se dará de alta el pago', 16, 1)
        RETURN
    END

    SELECT @Fecha = ISNULL(@Fecha,GETDATE())

    BEGIN TRANSACTION
    BEGIN TRY
        
        INSERT INTO Concesiones.PagoConcesion(IdConcesion,Fecha,Monto)
        VALUES(@IdConcesion,@Fecha,@Monto)
        SELECT @IdPagoConcesion = SCOPE_IDENTITY()

        COMMIT TRANSACTION
        PRINT 'El pago de concesión ' + CAST(@IdPagoConcesion AS VARCHAR) + ' fue creado con éxito'

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION
		PRINT 'Error: ' + ERROR_MESSAGE()
    END CATCH
END
GO

-- =============================================
-- SP_RegistrarPagoConcesion
-- =============================================

/*
DROP PROCEDURE SP_RegistrarPagoConcesion
*/

CREATE OR ALTER PROCEDURE SP_RegistrarPagoConcesion
    @IdConcesion INT,
    @Monto DECIMAL(10,2),
    @Fecha DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Fecha IS NULL SET @Fecha = GETDATE();

    BEGIN TRY
        DECLARE @Estado VARCHAR(8), @Canon DECIMAL(10,2),
                @FechaInicio DATE, @FechaFin DATE;

        SELECT @Estado = EstadoConcesion,
               @Canon = CanonMensual,
               @FechaInicio = FechaInicio,
               @FechaFin = FechaFin
        FROM Concesiones.Concesion
        WHERE IdConcesion = @IdConcesion;

        IF @Estado IS NULL
        BEGIN
            RAISERROR('La concesión indicada no existe.', 16, 1);
            RETURN;
        END

        IF @Estado <> 'Activo'
        BEGIN
            RAISERROR('La concesión no está activa. No se puede registrar el pago.', 16, 1);
            RETURN;
        END

        IF @Monto <= 0
        BEGIN
            RAISERROR('El monto debe ser mayor a cero.', 16, 1);
            RETURN;
        END

        BEGIN TRANSACTION;

        INSERT INTO Concesiones.PagoConcesion (IdConcesion, Fecha, Monto)
        VALUES (@IdConcesion, @Fecha, @Monto);

        /*
            Cálculo de pagos atrasados:
            meses transcurridos desde el inicio (acotado a la fecha fin si existe)
            vs. cantidad de pagos ya registrados.
        */

        DECLARE @FechaCorte DATE = CASE
            WHEN @FechaFin IS NOT NULL AND @FechaFin < CAST(@Fecha AS DATE)
            THEN @FechaFin ELSE CAST(@Fecha AS DATE) END;

        DECLARE @MesesEsperados INT =
            DATEDIFF(MONTH, @FechaInicio, @FechaCorte) + 1;

        DECLARE @PagosRealizados INT =
            (SELECT COUNT(*) FROM Concesiones.PagoConcesion WHERE IdConcesion = @IdConcesion);

        DECLARE @PagosAtrasados INT =
            CASE WHEN @MesesEsperados - @PagosRealizados > 0
                 THEN @MesesEsperados - @PagosRealizados ELSE 0 END;

        COMMIT TRANSACTION;

        PRINT 'Pago registrado correctamente.';

        IF @PagosAtrasados > 0
            PRINT 'La concesión tiene ' + CAST(@PagosAtrasados AS VARCHAR(10)) + ' pago(s) mensual(es) atrasado(s).';
        ELSE
            PRINT 'La concesión se encuentra al día.';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        DECLARE @Msg NVARCHAR(2048) = ERROR_MESSAGE();
        RAISERROR(@Msg, 16, 1);
    END CATCH
END
GO