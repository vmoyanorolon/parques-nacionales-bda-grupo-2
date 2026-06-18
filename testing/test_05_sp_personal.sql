-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: Scripts testing para los Stored Procedures del esquema Personal

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

    -- Setup compartido: parque y actividad necesarios para los tests de
    -- Habilitacion y GuiaTrabajaEnParque. Se insertan directamente para no
    -- depender de SPs de otros módulos dentro de este script.
    DECLARE @idParqueSetup INT, @idActividadSetup INT;

    INSERT INTO Parques.Parque (Nombre, HorarioCierre, HorarioApertura, Superficie, Provincia, Numero, Localidad, TipoParque)
    VALUES ('Parque Nacional Test Personal', '18:00', '08:00', 1000.00, 'Neuquén', 1, 'San Martín de los Andes', 'Parque Nacional');
    SET @idParqueSetup = SCOPE_IDENTITY();

    INSERT INTO Turismo.Actividad (Nombre, Tipo, Costo, DuracionMinutos, CupoMaximo, IdParque)
    VALUES ('Tour Test Personal', 'Tour', 200.00, 120, 10, @idParqueSetup);
    SET @idActividadSetup = SCOPE_IDENTITY();

    ----------------------------------------
    -- SP_AltaGuia
    ----------------------------------------

    DECLARE @idGuiaTest1 INT;

    -- Test 1: alta exitosa.
    -- Resultado esperado: inserta el guía correctamente.
    EXEC SP_AltaGuia
        @Telefono        = '1122334455',
        @CorreoGuia      = 'guia.test1@gmail.com',
        @NumeroDocumento = '28111222',
        @TipoDocumento   = 'DNI',
        @Edad            = 35,
        @Apellido        = 'Lopez',
        @Nombre          = 'Carlos',
        @Titulo          = 'Guía de Naturaleza',
        @Especialidad    = 'Flora';
    SET @idGuiaTest1 = IDENT_CURRENT('Personal.Guia');

    SELECT Test = 1, * FROM Personal.Guia WHERE IdGuia = @idGuiaTest1;

    -- Test 2: alta con NumeroDocumento duplicado.
    -- Resultado esperado: error 50000 "El guía con documento 28111222 ya existe."
    BEGIN TRY
        EXEC SP_AltaGuia
            @Telefono        = '1100000001',
            @CorreoGuia      = 'guia.test2@gmail.com',
            @NumeroDocumento = '28111222', -- mismo documento que Test 1
            @TipoDocumento   = 'DNI',
            @Edad            = 28,
            @Apellido        = 'Otro',
            @Nombre          = 'Guia',
            @Titulo          = 'Guía',
            @Especialidad    = 'Fauna';
        PRINT 'Test 2 - FALLO: debería haber lanzado un error por documento duplicado.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 2 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 3: alta con CorreoGuia duplicado.
    -- Resultado esperado: error 50000 "El correo guia.test1@gmail.com ya existe."
    BEGIN TRY
        EXEC SP_AltaGuia
            @Telefono        = '1100000002',
            @CorreoGuia      = 'guia.test1@gmail.com', -- mismo correo que Test 1
            @NumeroDocumento = '28111223',
            @TipoDocumento   = 'DNI',
            @Edad            = 28,
            @Apellido        = 'Otro',
            @Nombre          = 'Guia',
            @Titulo          = 'Guía',
            @Especialidad    = 'Fauna';
        PRINT 'Test 3 - FALLO: debería haber lanzado un error por correo duplicado.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 3 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 4: alta con Edad fuera de rango.
    -- Resultado esperado: error del motor por violar CK_Guia_Edad (0-99).
    BEGIN TRY
        EXEC SP_AltaGuia
            @Telefono        = '1100000003',
            @CorreoGuia      = 'guia.test4@gmail.com',
            @NumeroDocumento = '28111224',
            @TipoDocumento   = 'DNI',
            @Edad            = 150,
            @Apellido        = 'Edad',
            @Nombre          = 'Invalida',
            @Titulo          = 'Guía',
            @Especialidad    = 'Fauna';
        PRINT 'Test 4 - FALLO: debería haber lanzado un error por CK_Guia_Edad.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 4 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 5: alta con TipoDocumento fuera del dominio permitido.
    -- Resultado esperado: error del motor por violar CK_Guia_TipoDocumento.
    BEGIN TRY
        EXEC SP_AltaGuia
            @Telefono        = '1100000004',
            @CorreoGuia      = 'guia.test5@gmail.com',
            @NumeroDocumento = '28111225',
            @TipoDocumento   = 'XX',
            @Edad            = 30,
            @Apellido        = 'Tipo',
            @Nombre          = 'Invalido',
            @Titulo          = 'Guía',
            @Especialidad    = 'Fauna';
        PRINT 'Test 5 - FALLO: debería haber lanzado un error por CK_Guia_TipoDocumento.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 5 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- SP_ModificacionGuia
    ----------------------------------------

    -- Test 6: modificación parcial (solo Telefono).
    -- Resultado esperado: Telefono cambia, el resto conserva los valores del Test 1.
    EXEC SP_ModificacionGuia @IdGuia = @idGuiaTest1, @Telefono = '5500001111';

    SELECT Test = 6, * FROM Personal.Guia WHERE IdGuia = @idGuiaTest1;

    -- Test 7: modificación de un IdGuia inexistente.
    -- Resultado esperado: error 50000 "El guía con id -1 no existe."
    BEGIN TRY
        EXEC SP_ModificacionGuia @IdGuia = -1, @Telefono = '0000000000';
        PRINT 'Test 7 - FALLO: debería haber lanzado un error por guía inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 7 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Setup para Test 8: un segundo guía para probar el cruce de documentos.
    DECLARE @idGuiaTest8 INT;
    EXEC SP_AltaGuia
        @Telefono        = '1100000005',
        @CorreoGuia      = 'guia.test8@gmail.com',
        @NumeroDocumento = '28111226',
        @TipoDocumento   = 'DNI',
        @Edad            = 40,
        @Apellido        = 'Segundo',
        @Nombre          = 'Guia',
        @Titulo          = 'Guía de Naturaleza',
        @Especialidad    = 'Fauna';
    SET @idGuiaTest8 = IDENT_CURRENT('Personal.Guia');

    -- Test 8: modificación que intenta usar el NumeroDocumento de otro guía.
    -- Resultado esperado: error 50000 "El guía con documento 28111222 ya existe."
    BEGIN TRY
        EXEC SP_ModificacionGuia @IdGuia = @idGuiaTest8, @NumeroDocumento = '28111222';
        PRINT 'Test 8 - FALLO: debería haber lanzado un error por documento duplicado.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 8 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- SP_BajaGuia
    ----------------------------------------

    -- Test 9: baja de un IdGuia inexistente.
    -- Resultado esperado: error 50000 "El guía con id -1 no existe."
    BEGIN TRY
        EXEC SP_BajaGuia @IdGuia = -1;
        PRINT 'Test 9 - FALLO: debería haber lanzado un error por guía inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 9 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 10: baja exitosa de un guía sin relaciones.
    -- Resultado esperado: se elimina sin error.
    EXEC SP_BajaGuia @IdGuia = @idGuiaTest8;

    -- Setup para Test 11: registrar al guía del Test 1 en el parque de setup,
    -- para forzar la FK al intentar darlo de baja.
    INSERT INTO Personal.GuiaTrabajaEnParque (IdGuia, IdParque)
    VALUES (@idGuiaTest1, @idParqueSetup);

    -- Test 11: baja de un guía con registros relacionados (GuiaTrabajaEnParque).
    -- Resultado esperado: error 50000 "No se puede eliminar el Guia: Tiene registros de Habilitaciones asociadas y Parques donde trabaja asociados"
    BEGIN TRY
        EXEC SP_BajaGuia @IdGuia = @idGuiaTest1;
        PRINT 'Test 11 - FALLO: debería haber lanzado un error por registros relacionados.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 11 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- SP_AltaGuiaTrabajaEnParque
    ----------------------------------------

    -- Setup para Test 12: un tercer guía para los tests de GuiaTrabajaEnParque.
    DECLARE @idGuiaTest12 INT;
    EXEC SP_AltaGuia
        @Telefono        = '1100000006',
        @CorreoGuia      = 'guia.test12@gmail.com',
        @NumeroDocumento = '28111227',
        @TipoDocumento   = 'DNI',
        @Edad            = 45,
        @Apellido        = 'Tercer',
        @Nombre          = 'Guia',
        @Titulo          = 'Guía de Naturaleza',
        @Especialidad    = 'Geología';
    SET @idGuiaTest12 = IDENT_CURRENT('Personal.Guia');

    -- Test 12: alta exitosa.
    -- Resultado esperado: se registra la relación guía-parque correctamente.
    EXEC SP_AltaGuiaTrabajaEnParque @IdGuia = @idGuiaTest12, @IdParque = @idParqueSetup;

    SELECT Test = 12, * FROM Personal.GuiaTrabajaEnParque WHERE IdGuia = @idGuiaTest12;

    -- Test 13: alta con IdGuia inexistente.
    -- Resultado esperado: error 50000 "El guía con id -1 no existe."
    BEGIN TRY
        EXEC SP_AltaGuiaTrabajaEnParque @IdGuia = -1, @IdParque = @idParqueSetup;
        PRINT 'Test 13 - FALLO: debería haber lanzado un error por guía inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 13 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 14: alta con IdParque inexistente.
    -- Resultado esperado: error 50000 "El parque con id -1 no existe."
    BEGIN TRY
        EXEC SP_AltaGuiaTrabajaEnParque @IdGuia = @idGuiaTest12, @IdParque = -1;
        PRINT 'Test 14 - FALLO: debería haber lanzado un error por parque inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 14 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 15: alta de una combinación guía-parque duplicada.
    -- Resultado esperado: error 50000 "El guía con id X ya trabaja en el parque con id Y."
    BEGIN TRY
        EXEC SP_AltaGuiaTrabajaEnParque @IdGuia = @idGuiaTest12, @IdParque = @idParqueSetup;
        PRINT 'Test 15 - FALLO: debería haber lanzado un error por combinación duplicada.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 15 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- SP_BajaGuiaTrabajaEnParque
    ----------------------------------------

    -- Test 16: baja de un par guía-parque que no existe.
    -- Resultado esperado: error 50000 "No existe un guía con id -1 que trabaje en el parque con id -1."
    BEGIN TRY
        EXEC SP_BajaGuiaTrabajaEnParque @IdGuia = -1, @IdParque = -1;
        PRINT 'Test 16 - FALLO: debería haber lanzado un error por par inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 16 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 17: baja exitosa.
    -- Resultado esperado: se elimina la relación sin error.
    EXEC SP_BajaGuiaTrabajaEnParque @IdGuia = @idGuiaTest12, @IdParque = @idParqueSetup;

    ----------------------------------------
    -- SP_AltaHabilitacion
    ----------------------------------------

    -- Test 18: alta exitosa. Como el guía del Test 12 ya NO trabaja en el
    -- parque (lo dimos de baja en Test 17), SP_AltaHabilitacion también debe
    -- insertar automáticamente en GuiaTrabajaEnParque.
    -- Resultado esperado: se inserta la habilitación y el registro en GuiaTrabajaEnParque.
    DECLARE @idHabilitacionTest18 INT;
    EXEC SP_AltaHabilitacion
        @IdGuia       = @idGuiaTest12,
        @IdActividad  = @idActividadSetup,
        @DiasVigentes = 365;
    SET @idHabilitacionTest18 = IDENT_CURRENT('Personal.Habilitacion');

    SELECT Test = 18, * FROM Personal.Habilitacion WHERE IdHabilitacion = @idHabilitacionTest18;
    SELECT Test = 18, 'GuiaTrabajaEnParque', * FROM Personal.GuiaTrabajaEnParque WHERE IdGuia = @idGuiaTest12;

    -- Test 19: alta con IdActividad inexistente.
    -- Resultado esperado: error 50000 "La actividad indicada no existe."
    BEGIN TRY
        EXEC SP_AltaHabilitacion @IdGuia = @idGuiaTest12, @IdActividad = -1, @DiasVigentes = 100;
        PRINT 'Test 19 - FALLO: debería haber lanzado un error por actividad inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 19 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 20: alta con IdGuia inexistente.
    -- Resultado esperado: error 50000 "El guía indicado no existe."
    BEGIN TRY
        EXEC SP_AltaHabilitacion @IdGuia = -1, @IdActividad = @idActividadSetup, @DiasVigentes = 100;
        PRINT 'Test 20 - FALLO: debería haber lanzado un error por guía inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 20 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 21: alta con DiasVigentes <= 0.
    -- Resultado esperado: error 50000 "Los días vigentes deben ser mayores a 0."
    BEGIN TRY
        EXEC SP_AltaHabilitacion @IdGuia = @idGuiaTest12, @IdActividad = @idActividadSetup, @DiasVigentes = 0;
        PRINT 'Test 21 - FALLO: debería haber lanzado un error por DiasVigentes inválido.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 21 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- SP_ModificacionHabilitacion
    ----------------------------------------

    -- Test 22: modificación exitosa.
    -- Resultado esperado: DiasVigentes cambia a 180.
    EXEC SP_ModificacionHabilitacion @IdHabilitacion = @idHabilitacionTest18, @DiasVigentes = 180;

    SELECT Test = 22, * FROM Personal.Habilitacion WHERE IdHabilitacion = @idHabilitacionTest18;

    -- Test 23: modificación de una IdHabilitacion inexistente.
    -- Resultado esperado: error 50000 "La habilitación indicada no existe."
    BEGIN TRY
        EXEC SP_ModificacionHabilitacion @IdHabilitacion = -1, @DiasVigentes = 100;
        PRINT 'Test 23 - FALLO: debería haber lanzado un error por habilitación inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 23 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 24: modificación con DiasVigentes <= 0.
    -- Resultado esperado: error 50000 "Los días vigentes deben ser mayores a 0."
    BEGIN TRY
        EXEC SP_ModificacionHabilitacion @IdHabilitacion = @idHabilitacionTest18, @DiasVigentes = -1;
        PRINT 'Test 24 - FALLO: debería haber lanzado un error por DiasVigentes inválido.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 24 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- SP_BajaHabilitacion
    ----------------------------------------

    -- Test 25: baja de una IdHabilitacion inexistente.
    -- Resultado esperado: error 50000 "La habilitación indicada no existe."
    BEGIN TRY
        EXEC SP_BajaHabilitacion @IdHabilitacion = -1;
        PRINT 'Test 25 - FALLO: debería haber lanzado un error por habilitación inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 25 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 26: baja exitosa.
    -- Resultado esperado: se elimina la habilitación sin error.
    EXEC SP_BajaHabilitacion @IdHabilitacion = @idHabilitacionTest18;

    ----------------------------------------
    -- SP_AltaGuardaparque
    ----------------------------------------

    DECLARE @idGuardaparqueTest27 INT;

    -- Test 27: alta exitosa.
    -- Resultado esperado: inserta el guardaparque correctamente.
    EXEC SP_AltaGuardaparque
        @Telefono             = '1133445566',
        @CorreoGuardaparque   = 'guardaparque.test27@gmail.com',
        @NumeroDocumento      = '32111222',
        @TipoDocumento        = 'DNI',
        @Edad                 = 40,
        @Apellido             = 'Garcia',
        @Nombre               = 'Maria',
        @Estado               = 'Activo';
    SET @idGuardaparqueTest27 = IDENT_CURRENT('Personal.Guardaparque');

    SELECT Test = 27, * FROM Personal.Guardaparque WHERE IdGuardaparque = @idGuardaparqueTest27;

    -- Test 28: alta con NumeroDocumento duplicado.
    -- Resultado esperado: error 50000 "El guardaparque con documento 32111222 ya existe."
    BEGIN TRY
        EXEC SP_AltaGuardaparque
            @Telefono             = '1100000007',
            @CorreoGuardaparque   = 'guardaparque.test28@gmail.com',
            @NumeroDocumento      = '32111222', -- mismo documento que Test 27
            @TipoDocumento        = 'DNI',
            @Edad                 = 30,
            @Apellido             = 'Otro',
            @Nombre               = 'Guardaparque',
            @Estado               = 'Activo';
        PRINT 'Test 28 - FALLO: debería haber lanzado un error por documento duplicado.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 28 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 29: alta con CorreoGuardaparque duplicado.
    -- Resultado esperado: error 50000 "El guardaparque con correo guardaparque.test27@gmail.com ya existe."
    BEGIN TRY
        EXEC SP_AltaGuardaparque
            @Telefono             = '1100000008',
            @CorreoGuardaparque   = 'guardaparque.test27@gmail.com', -- mismo correo que Test 27
            @NumeroDocumento      = '32111223',
            @TipoDocumento        = 'DNI',
            @Edad                 = 30,
            @Apellido             = 'Otro',
            @Nombre               = 'Guardaparque',
            @Estado               = 'Activo';
        PRINT 'Test 29 - FALLO: debería haber lanzado un error por correo duplicado.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 29 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 30: alta con Estado fuera del dominio permitido.
    -- Resultado esperado: error del motor por violar CK_Guardaparque_Estado.
    BEGIN TRY
        EXEC SP_AltaGuardaparque
            @Telefono             = '1100000009',
            @CorreoGuardaparque   = 'guardaparque.test30@gmail.com',
            @NumeroDocumento      = '32111224',
            @TipoDocumento        = 'DNI',
            @Edad                 = 30,
            @Apellido             = 'Estado',
            @Nombre               = 'Invalido',
            @Estado               = 'Suspendido';
        PRINT 'Test 30 - FALLO: debería haber lanzado un error por CK_Guardaparque_Estado.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 30 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 31: alta con Edad fuera de rango.
    -- Resultado esperado: error del motor por violar CK_Guardaparque_Edad (0-99).
    BEGIN TRY
        EXEC SP_AltaGuardaparque
            @Telefono             = '1100000010',
            @CorreoGuardaparque   = 'guardaparque.test31@gmail.com',
            @NumeroDocumento      = '32111225',
            @TipoDocumento        = 'DNI',
            @Edad                 = 150,
            @Apellido             = 'Edad',
            @Nombre               = 'Invalida',
            @Estado               = 'Activo';
        PRINT 'Test 31 - FALLO: debería haber lanzado un error por CK_Guardaparque_Edad.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 31 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- SP_ModificacionGuardaparque
    ----------------------------------------

    -- Test 32: modificación parcial (solo Telefono).
    -- Resultado esperado: Telefono cambia, el resto conserva los valores del Test 27.
    EXEC SP_ModificacionGuardaparque @IdGuardaparque = @idGuardaparqueTest27, @Telefono = '5500002222';

    SELECT Test = 32, * FROM Personal.Guardaparque WHERE IdGuardaparque = @idGuardaparqueTest27;

    -- Test 33: modificación de un IdGuardaparque inexistente.
    -- Resultado esperado: error 50000 "El guardaparque con id -1 no existe."
    BEGIN TRY
        EXEC SP_ModificacionGuardaparque @IdGuardaparque = -1, @Telefono = '0000000000';
        PRINT 'Test 33 - FALLO: debería haber lanzado un error por guardaparque inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 33 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Setup para Test 34: un segundo guardaparque para probar el cruce de documentos.
    DECLARE @idGuardaparqueTest34 INT;
    EXEC SP_AltaGuardaparque
        @Telefono             = '1100000011',
        @CorreoGuardaparque   = 'guardaparque.test34@gmail.com',
        @NumeroDocumento      = '32111226',
        @TipoDocumento        = 'DNI',
        @Edad                 = 38,
        @Apellido             = 'Segundo',
        @Nombre               = 'Guardaparque',
        @Estado               = 'Activo';
    SET @idGuardaparqueTest34 = IDENT_CURRENT('Personal.Guardaparque');

    -- Test 34: modificación que intenta usar el NumeroDocumento de otro guardaparque.
    -- Resultado esperado: error 50000 "El guardaparque con documento 32111222 ya existe."
    BEGIN TRY
        EXEC SP_ModificacionGuardaparque @IdGuardaparque = @idGuardaparqueTest34, @NumeroDocumento = '32111222';
        PRINT 'Test 34 - FALLO: debería haber lanzado un error por documento duplicado.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 34 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- SP_BajaGuardaparque
    ----------------------------------------

    -- Test 35: baja de un IdGuardaparque inexistente.
    -- Resultado esperado: error 50000 "El guardaparque con id -1 no existe."
    BEGIN TRY
        EXEC SP_BajaGuardaparque @IdGuardaparque = -1;
        PRINT 'Test 35 - FALLO: debería haber lanzado un error por guardaparque inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 35 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 36: baja exitosa de un guardaparque sin relaciones.
    -- Resultado esperado: se elimina sin error.
    EXEC SP_BajaGuardaparque @IdGuardaparque = @idGuardaparqueTest34;

    -- Setup para Test 37: una asignación activa para el guardaparque del Test 27,
    -- que forzará la FK al intentar darlo de baja.
    INSERT INTO Personal.Asignacion (FechaIngreso, FechaEgreso, Motivo, IdParque, IdGuardaparque)
    VALUES (GETDATE(), NULL, NULL, @idParqueSetup, @idGuardaparqueTest27);

    -- Test 37: baja de un guardaparque con asignación asociada.
    -- Resultado esperado: error 50000 "No se puede eliminar el Guardaparque:
    -- Tiene una Asignacion asociada"
    BEGIN TRY
        EXEC SP_BajaGuardaparque @IdGuardaparque = @idGuardaparqueTest27;
        PRINT 'Test 37 - FALLO: debería haber lanzado un error por asignación asociada.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 37 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- SP_AltaAsignacion
    ----------------------------------------

    -- La asignación del Test 37 ya cerró la asignación activa del guardaparque del
    -- Test 27 (FechaEgreso = NULL), así que primero la cerramos antes de crear una nueva con SP_AltaAsignacion.
    DECLARE @idAsignacionSetup INT;
    SET @idAsignacionSetup = IDENT_CURRENT('Personal.Asignacion');

    -- Test 38: alta exitosa (asignación abierta, FechaEgreso NULL).
    -- Resultado esperado: inserta la asignación y actualiza Estado del guardaparque a 'Activo'.
    -- Nota: primero cerramos la asignación existente para cumplir la validación de "no tiene asignación activa".
    UPDATE Personal.Asignacion
    SET FechaEgreso = GETDATE()
    WHERE IdAsignacion = @idAsignacionSetup;

    DECLARE @idAsignacionTest38 INT;
    EXEC SP_AltaAsignacion
        @FechaIngreso    = '2026-01-01',
        @IdParque        = @idParqueSetup,
        @IdGuardaparque  = @idGuardaparqueTest27;
    SET @idAsignacionTest38 = IDENT_CURRENT('Personal.Asignacion');

    SELECT Test = 38, * FROM Personal.Asignacion WHERE IdAsignacion = @idAsignacionTest38;

    -- Test 39: alta con IdParque inexistente.
    -- Resultado esperado: error 50000 "El parque con id -1 no existe."
    BEGIN TRY
        EXEC SP_AltaAsignacion
            @FechaIngreso   = '2026-01-01',
            @IdParque       = -1,
            @IdGuardaparque = @idGuardaparqueTest27;
        PRINT 'Test 39 - FALLO: debería haber lanzado un error por parque inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 39 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 40: alta con IdGuardaparque inexistente.
    -- Resultado esperado: error 50000 "El guardaparque con id -1 no existe."
    BEGIN TRY
        EXEC SP_AltaAsignacion
            @FechaIngreso   = '2026-01-01',
            @IdParque       = @idParqueSetup,
            @IdGuardaparque = -1;
        PRINT 'Test 40 - FALLO: debería haber lanzado un error por guardaparque inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 40 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 41: alta cuando el guardaparque ya tiene una asignación activa.
    -- Resultado esperado: error 50000 "El guardaparque con id X tiene una asignación activa. Para dar de alta..."
    BEGIN TRY
        EXEC SP_AltaAsignacion
            @FechaIngreso   = '2026-06-01',
            @IdParque       = @idParqueSetup,
            @IdGuardaparque = @idGuardaparqueTest27; -- ya tiene la asignación del Test 38 activa
        PRINT 'Test 41 - FALLO: debería haber lanzado un error por asignación activa existente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 41 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- SP_ModificacionAsignacion
    ----------------------------------------

    -- Test 42: modificación exitosa (registra fecha de egreso del Test 38).
    -- Resultado esperado: FechaEgreso se establece con la fecha actual y el guardaparque pasa a Estado 'Inactivo'.
    EXEC SP_ModificacionAsignacion @IdAsignacion = @idAsignacionTest38;

    SELECT Test = 42, * FROM Personal.Asignacion WHERE IdAsignacion = @idAsignacionTest38;
    SELECT Test = 42, 'Estado Guardaparque', * FROM Personal.Guardaparque WHERE IdGuardaparque = @idGuardaparqueTest27;

    -- Test 43: modificación de una IdAsignacion inexistente.
    -- Resultado esperado: error 50000 "La asignación referenciada no existe."
    BEGIN TRY
        EXEC SP_ModificacionAsignacion @IdAsignacion = -1;
        PRINT 'Test 43 - FALLO: debería haber lanzado un error por asignación inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 43 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 44: modificación de una asignación que ya tiene fecha de egreso registrada.
    -- Resultado esperado: error 50000 "La asignación ya tiene fecha de egreso registrada."
    BEGIN TRY
        EXEC SP_ModificacionAsignacion @IdAsignacion = @idAsignacionTest38; -- ya cerrada en Test 42
        PRINT 'Test 44 - FALLO: debería haber lanzado un error por asignación ya cerrada.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 44 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ROLLBACK TRANSACTION;
    PRINT 'Suite completa de Personal (44 tests) finalizada sin errores inesperados.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    PRINT 'ERROR INESPERADO - se hizo ROLLBACK. Detalle: ' + ERROR_MESSAGE();
END CATCH
GO