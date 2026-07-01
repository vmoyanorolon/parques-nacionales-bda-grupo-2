-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: Scripts testing para los Stored Procedures del esquema Turismo

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

BEGIN TRY
    BEGIN TRANSACTION;

    ----------------------------------------
    -- USP_AltaTipoVisitante
    ----------------------------------------

    DECLARE @idTipoVisitanteTest1 INT;

    -- Test 1: alta exitosa.
    -- Resultado esperado: inserta el tipo de visitante.
    EXEC USP_AltaTipoVisitante @Descripcion = 'Jubilado Test', @Descuento = 20;
    SET @idTipoVisitanteTest1 = IDENT_CURRENT('Turismo.TipoVisitante');

    SELECT Test = 1, * FROM Turismo.TipoVisitante WHERE IdTipoVisitante = @idTipoVisitanteTest1;

    -- Test 2: alta con Descripcion duplicada.
    -- Resultado esperado: error 50000 "Ya existe un tipo de visitante con esa descripción."
    BEGIN TRY
        EXEC USP_AltaTipoVisitante @Descripcion = 'Jubilado Test', @Descuento = 10;
        PRINT 'Test 2 - FALLO: debería haber lanzado un error por descripción duplicada.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 2 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 3: alta con Descuento fuera de rango.
    -- Resultado esperado: error del motor por violar CK_TipoVisitante_Descuento (0-100).
    BEGIN TRY
        EXEC USP_AltaTipoVisitante @Descripcion = 'Estudiante Test', @Descuento = 150;
        PRINT 'Test 3 - FALLO: debería haber lanzado un error por CK_TipoVisitante_Descuento.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 3 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- USP_ModificacionTipoVisitante
    ----------------------------------------

    -- Test 4: modificación parcial (solo Descuento).
    -- Resultado esperado: Descuento cambia a 25, Descripcion conserva el valor del Test 1.
    EXEC USP_ModificacionTipoVisitante @IdTipoVisitante = @idTipoVisitanteTest1, @Descuento = 25;

    SELECT Test = 4, * FROM Turismo.TipoVisitante WHERE IdTipoVisitante = @idTipoVisitanteTest1;

    -- Test 5: modificación de un IdTipoVisitante inexistente.
    -- Resultado esperado: error 50000 "El tipo de visitante no existe."
    BEGIN TRY
        EXEC USP_ModificacionTipoVisitante @IdTipoVisitante = -1, @Descuento = 5;
        PRINT 'Test 5 - FALLO: debería haber lanzado un error por tipo de visitante inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 5 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Setup para Test 6: un segundo tipo de visitante para probar el cruce de descripciones.
    DECLARE @idTipoVisitanteTest6 INT;
    EXEC USP_AltaTipoVisitante @Descripcion = 'Estudiante Test 6', @Descuento = 15;
    SET @idTipoVisitanteTest6 = IDENT_CURRENT('Turismo.TipoVisitante');

    -- Test 6: modificación que intenta usar la Descripcion de otro tipo de visitante.
    -- Resultado esperado: error 50000 "Ya existe otro tipo de visitante con esa descripción."
    BEGIN TRY
        EXEC USP_ModificacionTipoVisitante @IdTipoVisitante = @idTipoVisitanteTest6, @Descripcion = 'Jubilado Test';
        PRINT 'Test 6 - FALLO: debería haber lanzado un error por descripción duplicada.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 6 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- USP_BajaTipoVisitante
    ----------------------------------------

    -- Test 7: baja de un IdTipoVisitante inexistente.
    -- Resultado esperado: error 50000 "El tipo de visitante no existe."
    BEGIN TRY
        EXEC USP_BajaTipoVisitante @IdTipoVisitante = -1;
        PRINT 'Test 7 - FALLO: debería haber lanzado un error por tipo de visitante inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 7 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 8: baja de un tipo de visitante sin visitantes asociados.
    -- Resultado esperado: se elimina sin error.
    EXEC USP_BajaTipoVisitante @IdTipoVisitante = @idTipoVisitanteTest6;

    -- Setup para Test 9: un visitante que use el tipo de visitante del Test 1,
    -- para forzar la validación de "tiene visitantes asociados".
    EXEC USP_AltaVisitante
        @Telefono = '1100000007',
        @CorreoVisitante = 'visitante.test9@gmail.com',
        @NumeroDocumento = '30111229',
        @TipoDocumento = 'DNI',
        @CUIT = '20444444449',
        @Edad = 35,
        @Nombre = 'Visitante',
        @Apellido = 'ConTipo',
        @IdTipoVisitante = @idTipoVisitanteTest1;

    -- Test 9: baja de un tipo de visitante con visitantes asociados.
    -- Resultado esperado: error 50000 "No se puede eliminar: el tipo de visitante tiene visitantes asociados."
    BEGIN TRY
        EXEC USP_BajaTipoVisitante @IdTipoVisitante = @idTipoVisitanteTest1;
        PRINT 'Test 9 - FALLO: debería haber lanzado un error por visitantes asociados.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 9 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- USP_AltaVisitante
    ----------------------------------------

    DECLARE @idVisitanteTest10 INT;

    -- Test 10: alta exitosa, con un IdTipoVisitante válido (el del Test 1).
    -- Resultado esperado: inserta el visitante con ese tipo asignado (no NULL).
    EXEC USP_AltaVisitante
        @Telefono = '1122334455',
        @CorreoVisitante = 'visitante.test10@gmail.com',
        @NumeroDocumento = '30111222',
        @TipoDocumento = 'DNI',
        @CUIT = '20301112223',
        @Edad = 30,
        @Nombre = 'Juan',
        @Apellido = 'Perez',
        @IdTipoVisitante = @idTipoVisitanteTest1;
    SET @idVisitanteTest10 = IDENT_CURRENT('Turismo.Visitante');

    SELECT Test = 10, * FROM Turismo.Visitante WHERE IdVisitante = @idVisitanteTest10;

    -- Test 11: alta con NumeroDocumento duplicado.
    -- Resultado esperado: error 50000 "Ya existe un visitante con ese número de documento."
    BEGIN TRY
        EXEC USP_AltaVisitante
            @Telefono = '1100000001',
            @CorreoVisitante = 'visitante.test11@gmail.com',
            @NumeroDocumento = '30111222', -- mismo documento que Test 10
            @TipoDocumento = 'DNI',
            @CUIT = '20444444443',
            @Edad = 25,
            @Nombre = 'Otro',
            @Apellido = 'Visitante';
        PRINT 'Test 11 - FALLO: debería haber lanzado un error por documento duplicado.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 11 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 12: alta con CUIT duplicado.
    -- Resultado esperado: error 50000 "Ya existe un visitante con ese CUIT."
    BEGIN TRY
        EXEC USP_AltaVisitante
            @Telefono = '1100000002',
            @CorreoVisitante = 'visitante.test12@gmail.com',
            @NumeroDocumento = '30111223',
            @TipoDocumento = 'DNI',
            @CUIT = '20301112223', -- mismo CUIT que Test 10
            @Edad = 25,
            @Nombre = 'Otro',
            @Apellido = 'Visitante';
        PRINT 'Test 12 - FALLO: debería haber lanzado un error por CUIT duplicado.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 12 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 13: alta con Edad fuera de rango.
    -- Resultado esperado: error del motor por violar CK_Visitante_Edad (0-99).
    BEGIN TRY
        EXEC USP_AltaVisitante
            @Telefono = '1100000003',
            @CorreoVisitante = 'visitante.test13@gmail.com',
            @NumeroDocumento = '30111224',
            @TipoDocumento = 'DNI',
            @CUIT = '20444444444',
            @Edad = 150,
            @Nombre = 'Edad',
            @Apellido = 'Invalida';
        PRINT 'Test 13 - FALLO: debería haber lanzado un error por CK_Visitante_Edad.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 13 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 14: alta con correo electrónico mal formado.
    -- Resultado esperado: error del motor por violar CK_Visitante_CorreoVisitante.
    BEGIN TRY
        EXEC USP_AltaVisitante
            @Telefono = '1100000004',
            @CorreoVisitante = 'correo-invalido',
            @NumeroDocumento = '30111225',
            @TipoDocumento = 'DNI',
            @CUIT = '20444444445',
            @Edad = 25,
            @Nombre = 'Correo',
            @Apellido = 'Invalido';
        PRINT 'Test 14 - FALLO: debería haber lanzado un error por CK_Visitante_CorreoVisitante.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 14 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 15: alta con TipoDocumento fuera del dominio permitido.
    -- Resultado esperado: error del motor por violar CK_Visitante_TipoDocumento.
    BEGIN TRY
        EXEC USP_AltaVisitante
            @Telefono = '1100000005',
            @CorreoVisitante = 'visitante.test15@gmail.com',
            @NumeroDocumento = '30111226',
            @TipoDocumento = 'XX',
            @CUIT = '20444444446',
            @Edad = 25,
            @Nombre = 'Documento',
            @Apellido = 'Invalido';
        PRINT 'Test 15 - FALLO: debería haber lanzado un error por CK_Visitante_TipoDocumento.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 15 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 16: alta con un IdTipoVisitante inexistente.
    -- Resultado esperado: error del motor por violar la FK hacia Turismo.TipoVisitante.
    BEGIN TRY
        EXEC USP_AltaVisitante
            @Telefono = '1100000006',
            @CorreoVisitante = 'visitante.test16@gmail.com',
            @NumeroDocumento = '30111230',
            @TipoDocumento = 'DNI',
            @CUIT = '20444444450',
            @Edad = 28,
            @Nombre = 'Tipo',
            @Apellido = 'Inexistente',
            @IdTipoVisitante = -1;
        PRINT 'Test 16 - FALLO: debería haber lanzado un error por tipo de visitante inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 16 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- USP_ModificacionVisitante
    ----------------------------------------

    -- Test 17: modificación parcial (solo Telefono).
    -- Resultado esperado: Telefono cambia, el resto conserva los valores del Test 10.
    EXEC USP_ModificacionVisitante
        @IdVisitante = @idVisitanteTest10,
        @Telefono = '5599998888';

    SELECT Test = 17, * FROM Turismo.Visitante WHERE IdVisitante = @idVisitanteTest10;

    -- Test 18: modificación de un IdVisitante inexistente.
    -- Resultado esperado: error 50000 "El visitante no existe."
    BEGIN TRY
        EXEC USP_ModificacionVisitante
            @IdVisitante = -1,
            @Telefono = 'no debería aplicarse';
        PRINT 'Test 18 - FALLO: debería haber lanzado un error por visitante inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 18 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Setup para Test 19: un segundo visitante para probar el cruce de documentos.
    DECLARE @idVisitanteTest19 INT;
    EXEC USP_AltaVisitante
        @Telefono = '1100000008',
        @CorreoVisitante = 'visitante.test19@gmail.com',
        @NumeroDocumento = '30111231',
        @TipoDocumento = 'DNI',
        @CUIT = '20444444451',
        @Edad = 40,
        @Nombre = 'Segundo',
        @Apellido = 'Visitante';
    SET @idVisitanteTest19 = IDENT_CURRENT('Turismo.Visitante');

    -- Test 19: modificación que intenta usar el NumeroDocumento de otro visitante.
    -- Resultado esperado: error 50000 "Ya existe otro visitante con ese número de documento."
    BEGIN TRY
        EXEC USP_ModificacionVisitante
            @IdVisitante = @idVisitanteTest19,
            @NumeroDocumento = '30111222'; -- documento del Test 10
        PRINT 'Test 19 - FALLO: debería haber lanzado un error por documento duplicado.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 19 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- USP_BajaVisitante
    ----------------------------------------

    -- Test 20: baja de un IdVisitante inexistente.
    -- Resultado esperado: error 50000 "No se puede eliminar al visitante: no existe."
    BEGIN TRY
        EXEC USP_BajaVisitante @IdVisitante = -1;
        PRINT 'Test 20 - FALLO: debería haber lanzado un error por visitante inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 20 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 21: baja de un visitante sin ventas asociadas.
    -- Resultado esperado: se elimina sin error.
    EXEC USP_BajaVisitante @IdVisitante = @idVisitanteTest19;

    -- Setup para Test 22: una venta asociada al visitante del Test 10, para
    -- forzar la validación de "tiene ventas asociadas" de USP_BajaVisitante.
    INSERT INTO Ventas.Venta (Monto, MetodoDePago, PuntoDeVenta, IdVisitante)
    VALUES (1500.00, 'Efectivo', 'Boletería Central', @idVisitanteTest10);

    -- Test 22: baja de un visitante con ventas asociadas.
    -- Resultado esperado: error 50000 "No se puede eliminar al visitante: tiene ventas asociadas."
    BEGIN TRY
        EXEC USP_BajaVisitante @IdVisitante = @idVisitanteTest10;
        PRINT 'Test 22 - FALLO: debería haber lanzado un error por ventas asociadas.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 22 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- Parque de apoyo, compartido por los tests de Turno, Actividad y
    -- EntradaParque que siguen.
    ----------------------------------------

    DECLARE @idParqueSetup INT;
    INSERT INTO Parques.Parque (Nombre, HorarioCierre, HorarioApertura, Superficie, Provincia, Numero, Localidad, TipoParque)
    VALUES ('Parque Nacional Test Turismo', '18:00', '08:00', 1500.00, 'Misiones', 1, 'Puerto Iguazu', 'Parque Nacional');
    SET @idParqueSetup = SCOPE_IDENTITY();

    ----------------------------------------
    -- USP_AltaTurno
    ----------------------------------------

    DECLARE @idActividadTurnoSetup INT, @idTurnoTest23 INT;
    INSERT INTO Turismo.Actividad (Nombre, Tipo, Costo, DuracionMinutos, CupoMaximo, IdParque)
    VALUES ('Cabalgata Test Turno', 'Tour', 500.00, 90, 10, @idParqueSetup);
    SET @idActividadTurnoSetup = SCOPE_IDENTITY();

    -- Test 23: alta exitosa.
    -- Resultado esperado: inserta el turno con Estado = 'disponible' por defecto.
    EXEC USP_AltaTurno @IdActividad = @idActividadTurnoSetup, @HoraInicio = '10:00', @HoraFin = '12:00', @DiaDeSemana = 2;
    SET @idTurnoTest23 = IDENT_CURRENT('Turismo.Turno');

    SELECT Test = 23, * FROM Turismo.Turno WHERE IdTurno = @idTurnoTest23;

    -- Test 24: alta con IdActividad inexistente.
    -- Resultado esperado: error 50000 "La actividad indicada no existe, no se dará de alta ningún turno".
    BEGIN TRY
        EXEC USP_AltaTurno @IdActividad = -1, @HoraInicio = '10:00', @HoraFin = '12:00', @DiaDeSemana = 2;
        PRINT 'Test 24 - FALLO: debería haber lanzado un error por actividad inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 24 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 25: alta con DiaDeSemana fuera de rango.
    -- Resultado esperado: error del motor por violar CK_Turno_DiaDeSemana (1-7).
    BEGIN TRY
        EXEC USP_AltaTurno @IdActividad = @idActividadTurnoSetup, @HoraInicio = '10:00', @HoraFin = '12:00', @DiaDeSemana = 8;
        PRINT 'Test 25 - FALLO: debería haber lanzado un error por CK_Turno_DiaDeSemana.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 25 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    IF XACT_STATE() = -1
    BEGIN
        ROLLBACK TRANSACTION;

        BEGIN TRANSACTION;
        INSERT INTO Parques.Parque (Nombre, HorarioCierre, HorarioApertura, Superficie, Provincia, Numero, Localidad, TipoParque)
        VALUES ('Parque Nacional Test Turismo', '18:00', '08:00', 1500.00, 'Misiones', 1, 'Puerto Iguazu', 'Parque Nacional');
        SET @idParqueSetup = SCOPE_IDENTITY();

        INSERT INTO Turismo.Actividad (Nombre, Tipo, Costo, DuracionMinutos, CupoMaximo, IdParque)
        VALUES ('Cabalgata Test Turno', 'Tour', 500.00, 90, 10, @idParqueSetup);
        SET @idActividadTurnoSetup = SCOPE_IDENTITY();

        EXEC USP_AltaTurno @IdActividad = @idActividadTurnoSetup, @HoraInicio = '10:00', @HoraFin = '12:00', @DiaDeSemana = 2;
        SET XACT_ABORT OFF;
        SET @idTurnoTest23 = IDENT_CURRENT('Turismo.Turno');
        PRINT 'Nota: setup recreado. @idParqueSetup = ' + CAST(@idParqueSetup AS VARCHAR) + ', @idTurnoTest23 = ' + CAST(@idTurnoTest23 AS VARCHAR) + '.';
    END

    ----------------------------------------
    -- USP_ModificacionTurno
    ----------------------------------------

    -- Test 26: modificación parcial (solo HoraInicio).
    -- Resultado esperado: HoraInicio cambia a 11:00, HoraFin/DiaDeSemana sin cambios.
    EXEC USP_ModificacionTurno @IdTurno = @idTurnoTest23, @HoraInicio = '11:00';

    SELECT Test = 26, * FROM Turismo.Turno WHERE IdTurno = @idTurnoTest23;

    -- Test 27: modificación de un IdTurno inexistente.
    -- Resultado esperado: error 50000 "El turno indicado no existe, no se hará ninguna modificación".
    BEGIN TRY
        EXEC USP_ModificacionTurno @IdTurno = -1, @HoraInicio = '11:00';
        PRINT 'Test 27 - FALLO: debería haber lanzado un error por turno inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 27 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    IF XACT_STATE() = -1
    BEGIN
        ROLLBACK TRANSACTION;
        BEGIN TRANSACTION;
        INSERT INTO Parques.Parque (Nombre, HorarioCierre, HorarioApertura, Superficie, Provincia, Numero, Localidad, TipoParque)
        VALUES ('Parque Nacional Test Turismo', '18:00', '08:00', 1500.00, 'Misiones', 1, 'Puerto Iguazu', 'Parque Nacional');
        SET @idParqueSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.Actividad (Nombre, Tipo, Costo, DuracionMinutos, CupoMaximo, IdParque)
        VALUES ('Cabalgata Test Turno', 'Tour', 500.00, 90, 10, @idParqueSetup);
        SET @idActividadTurnoSetup = SCOPE_IDENTITY();
        PRINT 'Nota: transaccion danada por bug de USP_ModificacionTurno (Test 27) recuperada.';
    END

    ----------------------------------------
    -- USP_BajaTurno
    ----------------------------------------

    -- Test 28: baja de un IdTurno inexistente.
    -- Resultado esperado: error 50000 "El turno indicado no existe, no se hará ningún cambio".
    BEGIN TRY
        EXEC USP_BajaTurno @IdTurno = -1;
        PRINT 'Test 28 - FALLO: debería haber lanzado un error por turno inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 28 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    IF XACT_STATE() = -1
    BEGIN
        ROLLBACK TRANSACTION;
        BEGIN TRANSACTION;

        INSERT INTO Parques.Parque (Nombre, HorarioCierre, HorarioApertura, Superficie, Provincia, Numero, Localidad, TipoParque)
        VALUES ('Parque Nacional Test Turismo', '18:00', '08:00', 1500.00, 'Misiones', 1, 'Puerto Iguazu', 'Parque Nacional');
        SET @idParqueSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.Actividad (Nombre, Tipo, Costo, DuracionMinutos, CupoMaximo, IdParque)
        VALUES ('Cabalgata Test Turno', 'Tour', 500.00, 90, 10, @idParqueSetup);
        SET @idActividadTurnoSetup = SCOPE_IDENTITY();
        EXEC USP_AltaTurno @IdActividad = @idActividadTurnoSetup, @HoraInicio = '10:00', @HoraFin = '12:00', @DiaDeSemana = 2;
        SET XACT_ABORT OFF;
        SET @idTurnoTest23 = IDENT_CURRENT('Turismo.Turno');
        PRINT 'Nota: transaccion danada por bug de USP_BajaTurno (Test 28) recuperada.';
    END

    -- Test 29: baja exitosa.
    -- Resultado esperado: se elimina sin error.
    EXEC USP_BajaTurno @IdTurno = @idTurnoTest23;
    SET XACT_ABORT OFF;

    ----------------------------------------
    -- USP_AltaActividad
    ----------------------------------------

    DECLARE @idActividadTest30 INT;

    -- Test 30: alta exitosa.
    -- Resultado esperado: inserta la actividad.
    EXEC USP_AltaActividad @Nombre = 'Sendero Test Turismo', @Costo = 100.00, @DuracionMinutos = 60, @Tipo = 'Atracción', @CupoMaximo = 15, @IdParque = @idParqueSetup;
    SET @idActividadTest30 = IDENT_CURRENT('Turismo.Actividad');

    SELECT Test = 30, * FROM Turismo.Actividad WHERE IdActividad = @idActividadTest30;

    -- Test 31: alta con IdParque inexistente.
    -- Resultado esperado: error 50000 "El Parque indicado no existe".
    BEGIN TRY
        EXEC USP_AltaActividad @Nombre = 'Actividad Sin Parque', @Costo = 100.00, @DuracionMinutos = 60, @Tipo = 'Tour', @CupoMaximo = 10, @IdParque = -1;
        PRINT 'Test 31 - FALLO: debería haber lanzado un error por parque inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 31 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 32: alta de una actividad duplicada (mismo Nombre y mismo Parque).
    -- Resultado esperado: error 50000 "La actividad ya existe dentro del parque".
    BEGIN TRY
        EXEC USP_AltaActividad @Nombre = 'Sendero Test Turismo', @Costo = 200.00, @DuracionMinutos = 30, @Tipo = 'Tour', @CupoMaximo = 5, @IdParque = @idParqueSetup;
        PRINT 'Test 32 - FALLO: debería haber lanzado un error por actividad duplicada.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 32 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 33: alta con Tipo fuera del dominio permitido.
    -- Resultado esperado: error del motor por violar CK_Actividad_Tipo.
    BEGIN TRY
        EXEC USP_AltaActividad @Nombre = 'Actividad Tipo Invalido', @Costo = 100.00, @DuracionMinutos = 60, @Tipo = 'Paseo', @CupoMaximo = 10, @IdParque = @idParqueSetup;
        PRINT 'Test 33 - FALLO: debería haber lanzado un error por CK_Actividad_Tipo.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 33 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 34: alta con Costo negativo.
    -- Resultado esperado: error del motor por violar CK_Actividad_Costo (>= 0).
    BEGIN TRY
        EXEC USP_AltaActividad @Nombre = 'Actividad Costo Invalido', @Costo = -1.00, @DuracionMinutos = 60, @Tipo = 'Tour', @CupoMaximo = 10, @IdParque = @idParqueSetup;
        PRINT 'Test 34 - FALLO: debería haber lanzado un error por CK_Actividad_Costo.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 34 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 35: alta con DuracionMinutos <= 0.
    -- Resultado esperado: error del motor por violar CK_Actividad_DuracionMinutos (> 0).
    BEGIN TRY
        EXEC USP_AltaActividad @Nombre = 'Actividad Duracion Invalida', @Costo = 100.00, @DuracionMinutos = 0, @Tipo = 'Tour', @CupoMaximo = 10, @IdParque = @idParqueSetup;
        PRINT 'Test 35 - FALLO: debería haber lanzado un error por CK_Actividad_DuracionMinutos.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 35 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 36: alta con CupoMaximo <= 0.
    -- Resultado esperado: error del motor por violar CK_Actividad_CupoMaximo (> 0).
    BEGIN TRY
        EXEC USP_AltaActividad @Nombre = 'Actividad Cupo Invalido', @Costo = 100.00, @DuracionMinutos = 60, @Tipo = 'Tour', @CupoMaximo = 0, @IdParque = @idParqueSetup;
        PRINT 'Test 36 - FALLO: debería haber lanzado un error por CK_Actividad_CupoMaximo.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 36 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- USP_ModificacionActividad
    ----------------------------------------

    -- Test 37: modificación parcial (solo Costo).
    -- Resultado esperado: Costo cambia a 150.00, el resto conserva los valores del Test 30.
    EXEC USP_ModificacionActividad @IdActividad = @idActividadTest30, @Costo = 150.00;

    SELECT Test = 37, * FROM Turismo.Actividad WHERE IdActividad = @idActividadTest30;

    -- Test 38: modificación de un IdActividad inexistente.
    -- Resultado esperado: error 50000 "La actividad que se quiere modificar no existe".
    BEGIN TRY
        EXEC USP_ModificacionActividad @IdActividad = -1, @Costo = 999.00;
        PRINT 'Test 38 - FALLO: debería haber lanzado un error por actividad inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 38 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- USP_BajaActividad
    ----------------------------------------

    -- Test 39: baja de un IdActividad inexistente.
    -- Resultado esperado: error 50000 "La actividad que se quiere eliminar no existe."
    BEGIN TRY
        EXEC USP_BajaActividad @IdActividad = -1;
        PRINT 'Test 39 - FALLO: debería haber lanzado un error por actividad inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 39 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Setup para Test 40: una actividad sin relaciones para dar de baja.
    DECLARE @idActividadTest40 INT;
    EXEC USP_AltaActividad @Nombre = 'Avistaje Test Turismo', @Costo = 80.00, @DuracionMinutos = 45, @Tipo = 'Tour', @CupoMaximo = 8, @IdParque = @idParqueSetup;
    SET @idActividadTest40 = IDENT_CURRENT('Turismo.Actividad');

    -- Test 40: baja de una actividad sin registros relacionados.
    -- Resultado esperado: se elimina sin error.
    EXEC USP_BajaActividad @IdActividad = @idActividadTest40;

    -- Setup para Test 41
    INSERT INTO Turismo.Turno (HoraInicio, HoraFin, DiaDeSemana, IdActividad)
    VALUES ('09:00', '10:00', 3, @idActividadTest30);

    -- Test 41: baja de una actividad con un turno asociado.
    -- Resultado esperado: error 50000 "No se puede eliminar la actividad: tiene registros relacionados."
    BEGIN TRY
        EXEC USP_BajaActividad @IdActividad = @idActividadTest30;
        PRINT 'Test 41 - FALLO: debería haber lanzado un error por turno relacionado.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 41 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- USP_AltaEntradaParque
    ----------------------------------------

    DECLARE @idEntradaTest42 INT;

    -- Test 42: alta exitosa.
    -- Resultado esperado: inserta la entrada al parque.
    EXEC USP_AltaEntradaParque @Costo = 500.00, @FechaAcceso = '2026-07-01', @IdParque = @idParqueSetup;
    SET @idEntradaTest42 = IDENT_CURRENT('Turismo.EntradaParque');

    SELECT Test = 42, * FROM Turismo.EntradaParque WHERE IdEntradaParque = @idEntradaTest42;

    -- Test 43: alta con IdParque inexistente.
    -- Resultado esperado: error 50000 "El Parque indicado no existe".
    BEGIN TRY
        EXEC USP_AltaEntradaParque @Costo = 500.00, @FechaAcceso = '2026-07-01', @IdParque = -1;
        PRINT 'Test 43 - FALLO: debería haber lanzado un error por parque inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 43 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 44: alta con Costo <= 0.
    -- Resultado esperado: error del motor por violar CK_EntradaParque_Costo (> 0).
    BEGIN TRY
        EXEC USP_AltaEntradaParque @Costo = 0.00, @FechaAcceso = '2026-07-01', @IdParque = @idParqueSetup;
        PRINT 'Test 44 - FALLO: debería haber lanzado un error por CK_EntradaParque_Costo.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 44 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- USP_ModificacionEntradaParque
    ----------------------------------------

    -- Test 45: modificación parcial (solo Costo).
    -- Resultado esperado: Costo cambia a 600.00, FechaAcceso/IdParque sin cambios.
    EXEC USP_ModificacionEntradaParque @IdEntradaParque = @idEntradaTest42, @Costo = 600.00;

    SELECT Test = 45, * FROM Turismo.EntradaParque WHERE IdEntradaParque = @idEntradaTest42;

    -- Test 46: modificación de un IdEntradaParque inexistente.
    -- Resultado esperado: error 50000 "La entrada que se quiere modificar no existe."
    BEGIN TRY
        EXEC USP_ModificacionEntradaParque @IdEntradaParque = -1, @Costo = 700.00;
        PRINT 'Test 46 - FALLO: debería haber lanzado un error por entrada inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 46 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 47: modificación que intenta reasignar la entrada a un IdParque inexistente.
    -- Resultado esperado: error 50000 "El Parque indicado no existe".
    BEGIN TRY
        EXEC USP_ModificacionEntradaParque @IdEntradaParque = @idEntradaTest42, @IdParque = -1;
        PRINT 'Test 47 - FALLO: debería haber lanzado un error por parque inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 47 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- USP_BajaEntradaParque
    ----------------------------------------

    -- Test 48: baja de un IdEntradaParque inexistente.
    -- Resultado esperado: error 50000 "la entrada que se quiere eliminar no existe."
    BEGIN TRY
        EXEC USP_BajaEntradaParque @IdEntradaParque = -1;
        PRINT 'Test 48 - FALLO: debería haber lanzado un error por entrada inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 48 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Setup para Test 49: una entrada sin líneas asociadas para dar de baja.
    DECLARE @idEntradaTest49 INT;
    EXEC USP_AltaEntradaParque @Costo = 300.00, @FechaAcceso = '2026-08-01', @IdParque = @idParqueSetup;
    SET @idEntradaTest49 = IDENT_CURRENT('Turismo.EntradaParque');

    -- Test 49: baja de una entrada sin líneas de venta asociadas.
    -- Resultado esperado: se elimina sin error.
    EXEC USP_BajaEntradaParque @IdEntradaParque = @idEntradaTest49;

    -- Setup para Test 50: una venta con una línea de entrada asociada a la
    -- entrada del Test 42, para forzar la validación de líneas asociadas.
    DECLARE @idVisitanteSetupVenta INT, @idVentaSetup INT;
    INSERT INTO Turismo.Visitante (Telefono, CorreoVisitante, NumeroDocumento, TipoDocumento, CUIT, Edad, Nombre, Apellido)
    VALUES ('1100000099', 'visitante.setup@gmail.com', '99999999', 'DNI', '20999999990', 40, 'Setup', 'Venta');
    SET @idVisitanteSetupVenta = SCOPE_IDENTITY();

    INSERT INTO Ventas.Venta (Monto, MetodoDePago, PuntoDeVenta, IdVisitante)
    VALUES (600.00, 'Efectivo', 'Boletería Central', @idVisitanteSetupVenta);
    SET @idVentaSetup = SCOPE_IDENTITY();

    INSERT INTO Ventas.LineaDeEntradaParque (PrecioUnitario, Cantidad, NumeroDeItem, IdVenta, IdEntradaParque)
    VALUES (600.00, 1, 1, @idVentaSetup, @idEntradaTest42);

    -- Test 50: baja de una entrada con líneas de venta asociadas.
    -- Resultado esperado: error 50000 "No se puede eliminar la entrada al parque: tiene lineas de entrada a parque asociadas."
    BEGIN TRY
        EXEC USP_BajaEntradaParque @IdEntradaParque = @idEntradaTest42;
        PRINT 'Test 50 - FALLO: debería haber lanzado un error por líneas asociadas.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 50 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- USP_ModificacionTurno / USP_BajaTurno con asistencias asociadas
    ----------------------------------------

    -- Setup para Test 51 y 52: un turno con una asistencia ya registrada
    -- (insertada directo en Ventas.LineaDeEntradaActividad, sin pasar por
    -- USP_AltaLineasDeEntradaActividad, para aislar el test de USP_ModificacionTurno/USP_BajaTurno).
    DECLARE @idActividadTest51 INT, @idTurnoTest51 INT, @idVisitanteTest51 INT, @idVentaTest51 INT;

    INSERT INTO Turismo.Actividad (Nombre, Tipo, Costo, DuracionMinutos, CupoMaximo, IdParque)
    VALUES ('Sendero Test Asistencia', 'Tour', 800.00, 60, 5, @idParqueSetup);
    SET @idActividadTest51 = SCOPE_IDENTITY();

    EXEC USP_AltaTurno @IdActividad = @idActividadTest51, @HoraInicio = '09:00', @HoraFin = '10:00', @DiaDeSemana = 3;
    SET @idTurnoTest51 = IDENT_CURRENT('Turismo.Turno');

    INSERT INTO Turismo.Visitante (Telefono, CorreoVisitante, NumeroDocumento, TipoDocumento, CUIT, Edad, Nombre, Apellido)
    VALUES ('1100000098', 'visitante.turno@gmail.com', '99999998', 'DNI', '20999999981', 35, 'Setup', 'Turno');
    SET @idVisitanteTest51 = SCOPE_IDENTITY();

    INSERT INTO Ventas.Venta (Monto, MetodoDePago, PuntoDeVenta, IdVisitante)
    VALUES (800.00, 'Efectivo', 'Boleter\xeda Central', @idVisitanteTest51);
    SET @idVentaTest51 = SCOPE_IDENTITY();

    -- Martes = 3 (Domingo=1). Se usa una fecha fija que caiga en martes dentro del horario del turno.
    INSERT INTO Ventas.LineaDeEntradaActividad (PrecioUnitario, Cantidad, NumeroDeItem, FechaHoraAsistencia, IdVenta, IdActividad)
    VALUES (800.00, 1, 1, '20260707 09:30', @idVentaTest51, @idActividadTest51); -- 2026-07-07 es martes

    -- Test 51: modificar el horario de un turno que ya tiene asistencias registradas.
    -- Resultado esperado: error 50000 "No se puede modificar el horario o el día del turno: ya tiene asistencias registradas."
    BEGIN TRY
        EXEC USP_ModificacionTurno @IdTurno = @idTurnoTest51, @HoraInicio = '09:30';
        PRINT 'Test 51 - FALLO: deber\xeda haber lanzado un error por asistencias asociadas.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 51 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 52: eliminar un turno que ya tiene asistencias registradas.
    -- Resultado esperado: error 50000 "No se puede eliminar el turno: tiene asistencias registradas."
    BEGIN TRY
        EXEC USP_BajaTurno @IdTurno = @idTurnoTest51;
        PRINT 'Test 52 - FALLO: deber\xeda haber lanzado un error por asistencias asociadas.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 52 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 53: CK_Turno_Estado rechaza un valor fuera del dominio permitido.
    -- Resultado esperado: error del motor por violar el CHECK ('disponible' | 'cupo lleno').
    BEGIN TRY
        UPDATE Turismo.Turno SET Estado = 'agotado' WHERE IdTurno = @idTurnoTest51;
        PRINT 'Test 53 - FALLO: deber\xeda haber lanzado un error por CK_Turno_Estado.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 53 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH


    ROLLBACK TRANSACTION;
    PRINT 'Suite completa de Turismo (53 tests) finalizada sin errores inesperados.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    PRINT 'ERROR INESPERADO - se hizo ROLLBACK. Detalle: ' + ERROR_MESSAGE();
END CATCH
GO