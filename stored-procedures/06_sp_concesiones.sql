-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: Stored Procedures del esquema Concesiones

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