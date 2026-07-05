-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Fecha: 04/07/2026
-- Descripción: Scripts testing para los Stored Procedures del esquema Concesiones

USE ParquesNacionales
GO

SET NOCOUNT ON;
SET XACT_ABORT OFF;

IF @@TRANCOUNT > 0
BEGIN
    PRINT 'Se detectó una transacción abierta de una ejecución anterior. Se hace ROLLBACK antes de continuar.';
    WHILE @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
END

DECLARE @idParqueSetup INT;
DECLARE @idOrgTest1 INT, @idOrgTest6 INT;
DECLARE @idConcesionSetup INT, @idConcesionTest10 INT;
DECLARE @idPagoTest22 INT, @idPagoTest23 INT;

-- Limpieza previa
BEGIN TRY
    DELETE pc
    FROM Concesiones.PagoConcesion pc
    JOIN Concesiones.Concesion c ON c.IdConcesion = pc.IdConcesion
    JOIN Parques.Parque p ON p.IdParque = c.IdParque
    WHERE p.Nombre = 'Parque Nacional Test Concesiones';

    DELETE c
    FROM Concesiones.Concesion c
    JOIN Parques.Parque p ON p.IdParque = c.IdParque
    WHERE p.Nombre = 'Parque Nacional Test Concesiones';

    DELETE FROM Concesiones.OrganizacionConcesionaria
    WHERE Cuit IN ('30711222339', '30711222340', '30711222341');

    DELETE FROM Parques.Parque
    WHERE Nombre = 'Parque Nacional Test Concesiones';

    PRINT 'Limpieza previa OK (se eliminaron residuos de una corrida anterior, si los había).';
END TRY
BEGIN CATCH
    PRINT 'ERROR EN LIMPIEZA PREVIA - revisar datos manualmente antes de reintentar. Detalle: ' + ERROR_MESSAGE();
END CATCH

BEGIN TRY

    -- Setup compartido: parque necesario para las concesiones (Superficie = 1000.00,
    -- por lo que el límite legal del 10% -Art. 12, Ley 22.351- es 100.00).
    -- Se inserta directamente para no depender de SPs de otros módulos dentro de este script.
    INSERT INTO Parques.Parque (Nombre, HorarioCierre, HorarioApertura, Superficie, CostoHectarea, Provincia, Numero, Localidad, TipoParque)
    VALUES ('Parque Nacional Test Concesiones', '18:00', '08:00', 1000.00, 1000.00, 'Chubut', 1, 'Esquel', 'Parque Nacional');

    SET @idParqueSetup = SCOPE_IDENTITY();

    ----------------------------------------
    -- USP_AltaOrganizacionConcesionaria
    ----------------------------------------

    -- Test 1: alta exitosa.
    -- Resultado esperado: inserta la organización concesionaria correctamente.
    EXEC USP_AltaOrganizacionConcesionaria
        @Nombre               = 'Concesionaria Patagonia SA',
        @TipoActividad        = 'Gastronomía',
        @Cuit                 = '30711222339',
        @CorreoContacto       = 'contacto@patagonia-sa.com',
        @TelefonoContacto     = '2945400000',
        @DomicilioRegistrado  = 'Av. San Martín 100, Esquel';
    SET @idOrgTest1 = IDENT_CURRENT('Concesiones.OrganizacionConcesionaria');

    SELECT Test = 1, * FROM Concesiones.OrganizacionConcesionaria WHERE IdOrganizacionConcesionaria = @idOrgTest1;

    -- Test 2: alta con Cuit duplicado.
    -- Resultado esperado: error 50000 "El CUIT ingresado ya existe."
    BEGIN TRY
        EXEC USP_AltaOrganizacionConcesionaria
            @Nombre        = 'Otra Concesionaria SRL',
            @TipoActividad = 'Hotelería',
            @Cuit          = '30711222339'; -- mismo CUIT que Test 1
        PRINT 'Test 2 - FALLO: debería haber lanzado un error por CUIT duplicado.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 2 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
    END CATCH

    -- Test 3: alta con CorreoContacto de formato inválido.
    -- Resultado esperado: error del motor por violar CK_OrganizacionConcesionaria_CorreoContacto.
    BEGIN TRY
        EXEC USP_AltaOrganizacionConcesionaria
            @Nombre         = 'Concesionaria Correo Invalido',
            @TipoActividad  = 'Transporte',
            @Cuit           = '30711222340',
            @CorreoContacto = 'correo-sin-arroba.com';
        PRINT 'Test 3 - FALLO: debería haber lanzado un error por CK_OrganizacionConcesionaria_CorreoContacto.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 3 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
    END CATCH

    ----------------------------------------
    -- USP_ModificacionOrganizacionConcesionaria
    ----------------------------------------

    -- Test 4: modificación parcial (solo Nombre).
    -- Resultado esperado: Nombre cambia, el resto conserva los valores del Test 1.
    EXEC USP_ModificacionOrganizacionConcesionaria @IdOrganizacionConcesionaria = @idOrgTest1, @Nombre = 'Concesionaria Patagonia SA (renombrada)';

    SELECT Test = 4, * FROM Concesiones.OrganizacionConcesionaria WHERE IdOrganizacionConcesionaria = @idOrgTest1;

    -- Test 5: modificación de un IdOrganizacionConcesionaria inexistente.
    -- Resultado esperado: error 50000 "La organización concesionaria indicada no existe."
    BEGIN TRY
        EXEC USP_ModificacionOrganizacionConcesionaria @IdOrganizacionConcesionaria = -1, @Nombre = 'No Existe';
        PRINT 'Test 5 - FALLO: debería haber lanzado un error por organización inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 5 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
    END CATCH

    -- Setup para Test 6: una segunda organización concesionaria para probar el cruce de CUIT.
    EXEC USP_AltaOrganizacionConcesionaria
        @Nombre        = 'Concesionaria Segunda SA',
        @TipoActividad = 'Excursiones',
        @Cuit          = '30711222341';
    SET @idOrgTest6 = IDENT_CURRENT('Concesiones.OrganizacionConcesionaria');

    -- Test 6: modificación que intenta usar el Cuit de otra organización.
    -- Resultado esperado: SP emite un PRINT, sin fallar, pero el
    -- Cuit de @idOrgTest6 NO debe cambiar (sigue siendo '30711222341').
    EXEC USP_ModificacionOrganizacionConcesionaria @IdOrganizacionConcesionaria = @idOrgTest6, @Cuit = '30711222339'; -- CUIT de @idOrgTest1

    SELECT Test = 6, * FROM Concesiones.OrganizacionConcesionaria WHERE IdOrganizacionConcesionaria = @idOrgTest6;

    ----------------------------------------
    -- USP_BajaOrganizacionConcesionaria
    ----------------------------------------

    -- Test 7: baja de un IdOrganizacionConcesionaria inexistente.
    -- Resultado esperado: error 50000 "La organización concesionaria indicada no existe."
    BEGIN TRY
        EXEC USP_BajaOrganizacionConcesionaria @IdOrganizacionConcesionaria = -1;
        PRINT 'Test 7 - FALLO: debería haber lanzado un error por organización inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 7 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
    END CATCH

    -- Setup para Test 8: una concesión asociada a @idOrgTest1 para forzar la FK al intentar darla de baja.
    INSERT INTO Concesiones.Concesion (IdParque, IdOrganizacionConcesionaria, CanonMensual, ExtensionConcedida, EstadoConcesion, FechaInicio)
    VALUES (@idParqueSetup, @idOrgTest1, 500.00, 20.00, 'Activo', '2026-01-01');
    SET @idConcesionSetup = SCOPE_IDENTITY();

    -- Test 8: baja de una organización con concesiones asociadas.
    -- Resultado esperado: error 50000 "La organización concesionaria cuenta con concesiones asociadas."
    BEGIN TRY
        EXEC USP_BajaOrganizacionConcesionaria @IdOrganizacionConcesionaria = @idOrgTest1;
        PRINT 'Test 8 - FALLO: debería haber lanzado un error por concesiones asociadas.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 8 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
    END CATCH

    -- Test 9: baja exitosa de una organización sin concesiones asociadas.
    -- Resultado esperado: se elimina @idOrgTest6 sin error.
    EXEC USP_BajaOrganizacionConcesionaria @IdOrganizacionConcesionaria = @idOrgTest6;

    ----------------------------------------
    -- USP_AltaConcesion
    ----------------------------------------

    -- El parque de Setup tiene Superficie = 1000.00, por lo que el límite legal
    -- (10%, Art. 12 Ley 22.351) es 100.00. La concesión de Setup ya ocupa 20.00.

    -- Test 10: alta exitosa (20.00 de Setup + 30.00 nuevos = 50.00, dentro del límite).
    -- Resultado esperado: inserta la concesión con EstadoConcesion = 'Activo'.
    EXEC USP_AltaConcesion
        @IdParque                    = @idParqueSetup,
        @IdOrganizacionConcesionaria = @idOrgTest1,
        @CanonMensual                = 800.00,
        @ExtensionConcedida          = 30.00,
        @FechaInicio                 = '2026-02-01';
    SET @idConcesionTest10 = IDENT_CURRENT('Concesiones.Concesion');

    SELECT Test = 10, * FROM Concesiones.Concesion WHERE IdConcesion = @idConcesionTest10;

    -- Test 11: alta con IdParque inexistente.
    -- Resultado esperado: error 50000 "El parque ingresado no existe."
    BEGIN TRY
        EXEC USP_AltaConcesion
            @IdParque                    = -1,
            @IdOrganizacionConcesionaria = @idOrgTest1,
            @CanonMensual                = 500.00,
            @ExtensionConcedida          = 10.00;
        PRINT 'Test 11 - FALLO: debería haber lanzado un error por parque inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 11 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
    END CATCH

    -- Test 12: alta con IdOrganizacionConcesionaria inexistente.
    -- Resultado esperado: error 50000 "La organización concesionaria ingresada no existe."
    BEGIN TRY
        EXEC USP_AltaConcesion
            @IdParque                    = @idParqueSetup,
            @IdOrganizacionConcesionaria = -1,
            @CanonMensual                = 500.00,
            @ExtensionConcedida          = 10.00;
        PRINT 'Test 12 - FALLO: debería haber lanzado un error por organización inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 12 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
    END CATCH

    -- Test 13: alta que supera el límite legal de superficie concedida.
    -- Total activo actual = 20.00 (Setup) + 30.00 (Test 10) = 50.00. Se pide 60.00 más
    -- (total 110.00), lo que supera el límite de 100.00.
    -- Resultado esperado: error 50000 "La extensión que se desea conceder supera el límite
    -- establecido por ley (Art. 12, Ley 22.351)."
    BEGIN TRY
        EXEC USP_AltaConcesion
            @IdParque                    = @idParqueSetup,
            @IdOrganizacionConcesionaria = @idOrgTest1,
            @CanonMensual                = 500.00,
            @ExtensionConcedida          = 60.00;
        PRINT 'Test 13 - FALLO: debería haber lanzado un error por exceder el límite legal.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 13 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
    END CATCH

    ----------------------------------------
    -- USP_ModificacionConcesion
    ----------------------------------------

    -- Test 14: modificación parcial exitosa (solo CanonMensual).
    -- Resultado esperado: CanonMensual cambia, ExtensionConcedida conserva el valor del Test 10.
    EXEC USP_ModificacionConcesion @IdConcesion = @idConcesionTest10, @CanonMensual = 950.00;

    SELECT Test = 14, * FROM Concesiones.Concesion WHERE IdConcesion = @idConcesionTest10;

    -- Test 15: modificación de un IdConcesion inexistente.
    -- Resultado esperado: error 50000 "La concesión indicada no existe."
    BEGIN TRY
        EXEC USP_ModificacionConcesion @IdConcesion = -1, @CanonMensual = 100.00;
        PRINT 'Test 15 - FALLO: debería haber lanzado un error por concesión inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 15 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
    END CATCH

    -- Test 16: modificación de ExtensionConcedida que supera el límite legal.
    -- Total activo excluyendo la propia concesión = 20.00 (Setup). Se pide llevar
    -- Test 10 a 90.00 (total 110.00), lo que supera el límite de 100.00.
    -- Resultado esperado: error 50000 por exceder el límite legal.
    BEGIN TRY
        EXEC USP_ModificacionConcesion @IdConcesion = @idConcesionTest10, @ExtensionConcedida = 90.00;
        PRINT 'Test 16 - FALLO: debería haber lanzado un error por exceder el límite legal.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 16 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
    END CATCH

    ----------------------------------------
    -- USP_BajaConcesion
    ----------------------------------------

    -- Test 17: baja de un IdConcesion inexistente.
    -- Resultado esperado: error 50000 "La concesión indicada no existe."
    BEGIN TRY
        EXEC USP_BajaConcesion @IdConcesion = -1;
        PRINT 'Test 17 - FALLO: debería haber lanzado un error por concesión inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 17 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
    END CATCH

    -- Test 18: baja exitosa de la concesión del Test 10.
    -- Resultado esperado: EstadoConcesion pasa a 'Inactivo'.
    EXEC USP_BajaConcesion @IdConcesion = @idConcesionTest10;

    SELECT Test = 18, * FROM Concesiones.Concesion WHERE IdConcesion = @idConcesionTest10;

    -- Test 19: baja de una concesión que ya está inactiva.
    -- Resultado esperado: error 50000 "La concesión indicada ya está inactiva."
    BEGIN TRY
        EXEC USP_BajaConcesion @IdConcesion = @idConcesionTest10;
        PRINT 'Test 19 - FALLO: debería haber lanzado un error por concesión ya inactiva.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 19 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
    END CATCH

    ----------------------------------------
    -- USP_AltaPagoConcesion
    ----------------------------------------

    -- Test 20: alta de pago para un IdConcesion inexistente.
    -- Resultado esperado: error 50000 "La concesión indicada no existe."
    BEGIN TRY
        EXEC USP_AltaPagoConcesion @IdConcesion = -1;
        PRINT 'Test 20 - FALLO: debería haber lanzado un error por concesión inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 20 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
    END CATCH

    -- Test 21: alta de pago para una concesión inactiva (la del Test 10/18).
    -- Resultado esperado: error 50000 "La concesión indicada está inactiva."
    BEGIN TRY
        EXEC USP_AltaPagoConcesion @IdConcesion = @idConcesionTest10;
        PRINT 'Test 21 - FALLO: debería haber lanzado un error por concesión inactiva.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 21 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
    END CATCH

    -- Test 22: alta exitosa de pago sobre la concesión de Setup (activa, CanonMensual = 500.00).
    -- Resultado esperado: inserta el pago con Monto = 500.00 y Fecha = GETDATE().
    EXEC USP_AltaPagoConcesion @IdConcesion = @idConcesionSetup;
    SET @idPagoTest22 = IDENT_CURRENT('Concesiones.PagoConcesion');

    SELECT Test = 22, * FROM Concesiones.PagoConcesion WHERE IdPagoConcesion = @idPagoTest22;

    -- Test 23: alta exitosa de pago con Fecha explícita.
    -- Resultado esperado: inserta el pago respetando la Fecha indicada en lugar de GETDATE().
    EXEC USP_AltaPagoConcesion @IdConcesion = @idConcesionSetup, @Fecha = '20260315';
    SET @idPagoTest23 = IDENT_CURRENT('Concesiones.PagoConcesion');

    SELECT Test = 23, * FROM Concesiones.PagoConcesion WHERE IdPagoConcesion = @idPagoTest23;

    PRINT 'Suite completa de Concesiones (23 tests) finalizada sin errores inesperados.';
END TRY
BEGIN CATCH
    PRINT 'ERROR INESPERADO durante la suite. Detalle: ' + ERROR_MESSAGE();
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
END CATCH


-- Limpieza post-ejecución

BEGIN TRY
    DELETE FROM Concesiones.PagoConcesion WHERE IdConcesion IN (@idConcesionSetup, @idConcesionTest10);
    DELETE FROM Concesiones.Concesion WHERE IdConcesion IN (@idConcesionSetup, @idConcesionTest10);
    DELETE FROM Concesiones.OrganizacionConcesionaria WHERE IdOrganizacionConcesionaria IN (@idOrgTest1, @idOrgTest6);
    DELETE FROM Parques.Parque WHERE IdParque = @idParqueSetup;
    PRINT 'Datos de prueba eliminados.';
END TRY
BEGIN CATCH
    PRINT 'ERROR AL INTENTAR ELIMINAR DATOS DE PRUEBA: ' + ERROR_MESSAGE();
END CATCH
GO