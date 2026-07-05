-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Fecha: 04/07/2026
-- Descripción: Testing de Entrega 8 (Seguridad) - SOLO procedures. Cubre los
--   procedures agregados (USP_CifrarDatosSensibles_*, USP_Consulta*PorId) y los
--   modificados por el cifrado (USP_Alta*/USP_Modificacion* de Visitante, Guia,
--   Guardaparque y OrganizacionConcesionaria, y los SP de importación).

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

DECLARE @idVisTest2 INT, @idVisTest6 INT;
DECLARE @idGuiaTest8 INT;
DECLARE @idGuardaTest9 INT;
DECLARE @idOrgTest10 INT, @idOrgTest10b INT;

-- Limpieza previa (por marcadores en Apellido/Nombre, no por las columnas cifradas)
BEGIN TRY
    DELETE FROM Turismo.Visitante WHERE Apellido IN ('CifradoUno', 'CifradoDos');
    DELETE FROM Personal.Guia WHERE Apellido = 'CifradoGuia';
    DELETE FROM Personal.Guardaparque WHERE Apellido = 'CifradoGuarda';
    DELETE FROM Concesiones.OrganizacionConcesionaria WHERE Nombre IN ('Concesionaria Test Cifrado Uno', 'Concesionaria Test Cifrado Dos');
    PRINT 'Limpieza previa OK (se eliminaron residuos de una corrida anterior, si los había).';
END TRY
BEGIN CATCH
    PRINT 'ERROR EN LIMPIEZA PREVIA - revisar datos manualmente antes de reintentar. Detalle: ' + ERROR_MESSAGE();
END CATCH

BEGIN TRY

    ----------------------------------------
    -- USP_CifrarDatosSensibles_* (un procedure por esquema)
    ----------------------------------------

    -- Test 1: los tres procedures de cifrado existen. NO se ejecutan de nuevo acá:
    -- son de un solo uso
    SELECT Test = 1, name FROM sys.procedures
    WHERE name IN ('USP_CifrarDatosSensibles_Turismo', 'USP_CifrarDatosSensibles_Personal', 'USP_CifrarDatosSensibles_Concesiones');

    ----------------------------------------
    -- USP_AltaVisitante / USP_ModificacionVisitante
    ----------------------------------------

    -- Test 2: alta exitosa.
    -- Resultado esperado: inserta el visitante correctamente.
    EXEC USP_AltaVisitante
        @Telefono = '1111111111', @CorreoVisitante = 'testcifrado1@mail.com',
        @NumeroDocumento = '88811100', @TipoDocumento = 'DNI', @CUIT = '20888111003',
        @Edad = 30, @Nombre = 'Test', @Apellido = 'CifradoUno';
    SET @idVisTest2 = IDENT_CURRENT('Turismo.Visitante');

    SELECT Test = 2, IdVisitante, Nombre, Apellido, DATALENGTH(NumeroDocumento) AS BytesNumeroDocumentoCifrado
    FROM Turismo.Visitante WHERE IdVisitante = @idVisTest2;

    -- Test 2b: el documento no debe quedar legible en la tabla.
    -- Resultado esperado: el valor crudo de la columna NO es igual al texto plano
    -- ingresado (está cifrado con EncryptByPassPhrase, no es el mismo byte a byte).
    IF EXISTS (SELECT 1 FROM Turismo.Visitante WHERE IdVisitante = @idVisTest2 AND CONVERT(VARCHAR(15), NumeroDocumento) = '88811100')
        PRINT 'Test 2b - FALLO: el documento está en texto plano en la tabla.';
    ELSE
        PRINT 'Test 2b - OK: el documento no es legible directamente en la tabla (está cifrado).';

    -- Test 3: alta con NumeroDocumento duplicado (mismo documento que Test 2, CUIT distinto).
    -- Resultado esperado: error 50000 "Ya existe un visitante con ese número de documento."
    BEGIN TRY
        EXEC USP_AltaVisitante
            @Telefono = '1111111112', @CorreoVisitante = 'otro@mail.com',
            @NumeroDocumento = '88811100', @TipoDocumento = 'DNI', @CUIT = '20888111199',
            @Edad = 31, @Nombre = 'Test', @Apellido = 'Duplicado';
        PRINT 'Test 3 - FALLO: debería haber lanzado un error por documento duplicado.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 3 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    END CATCH

    -- Test 4: alta con CUIT duplicado (mismo CUIT que Test 2, documento distinto).
    -- Resultado esperado: error 50000 "Ya existe un visitante con ese CUIT."
    BEGIN TRY
        EXEC USP_AltaVisitante
            @Telefono = '1111111113', @CorreoVisitante = 'otro2@mail.com',
            @NumeroDocumento = '88811198', @TipoDocumento = 'DNI', @CUIT = '20888111003',
            @Edad = 32, @Nombre = 'Test', @Apellido = 'Duplicado';
        PRINT 'Test 4 - FALLO: debería haber lanzado un error por CUIT duplicado.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 4 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    END CATCH

    -- Test 5: USP_ConsultaVisitantePorId descifra correctamente.
    -- Resultado esperado: NumeroDocumento = '88811100' y CUIT = '20888111003'.
    PRINT 'Test 5 - ver resultado de USP_ConsultaVisitantePorId a continuación (debe mostrar NumeroDocumento=88811100, CUIT=20888111003):';
    EXEC USP_ConsultaVisitantePorId @IdVisitante = @idVisTest2;

    -- Setup para Test 6/7: un segundo visitante, para probar cruce de documento en la Modificación.
    EXEC USP_AltaVisitante
        @Telefono = '1111111114', @CorreoVisitante = 'testcifrado2@mail.com',
        @NumeroDocumento = '88811101', @TipoDocumento = 'DNI', @CUIT = '20888111102',
        @Edad = 33, @Nombre = 'Test', @Apellido = 'CifradoDos';
    SET @idVisTest6 = IDENT_CURRENT('Turismo.Visitante');

    -- Test 6: modificación que intenta usar el documento del Test 2 (de otro visitante).
    -- Resultado esperado: error 50000 "Ya existe otro visitante con ese número de documento."
    BEGIN TRY
        EXEC USP_ModificacionVisitante @IdVisitante = @idVisTest6, @NumeroDocumento = '88811100';
        PRINT 'Test 6 - FALLO: debería haber lanzado un error por documento de otro visitante.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 6 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    END CATCH

    -- Test 7: modificación de documento a un valor nuevo y válido.
    -- Resultado esperado: la modificación se aplica; USP_ConsultaVisitantePorId debe
    -- devolver el documento nuevo ('88811199'), no el original.
    EXEC USP_ModificacionVisitante @IdVisitante = @idVisTest6, @NumeroDocumento = '88811199';
    PRINT 'Test 7 - ver resultado a continuación (debe mostrar NumeroDocumento=88811199):';
    EXEC USP_ConsultaVisitantePorId @IdVisitante = @idVisTest6;

    ----------------------------------------
    -- USP_AltaGuia + USP_ConsultaGuiaPorId
    ----------------------------------------

    -- Test 8: alta exitosa y validación de duplicado por documento.
    -- Resultado esperado: alta OK; el segundo alta con mismo documento falla.
    EXEC USP_AltaGuia
        @Telefono = '1111111115', @CorreoGuia = 'guiatestcifrado@mail.com',
        @NumeroDocumento = '88822200', @TipoDocumento = 'DNI', @Edad = 35,
        @Apellido = 'CifradoGuia', @Nombre = 'Test', @Titulo = NULL, @Especialidad = 'Trekking';
    SET @idGuiaTest8 = IDENT_CURRENT('Personal.Guia');

    BEGIN TRY
        EXEC USP_AltaGuia
            @Telefono = '1111111116', @CorreoGuia = 'otroguia@mail.com',
            @NumeroDocumento = '88822200', @TipoDocumento = 'DNI', @Edad = 36,
            @Apellido = 'Duplicado', @Nombre = 'Test', @Titulo = NULL, @Especialidad = 'Buceo';
        PRINT 'Test 8 - FALLO: debería haber lanzado un error por documento duplicado.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 8 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    END CATCH

    PRINT 'Test 8b - ver resultado de USP_ConsultaGuiaPorId (debe mostrar NumeroDocumento=88822200):';
    EXEC USP_ConsultaGuiaPorId @IdGuia = @idGuiaTest8;

    ----------------------------------------
    -- USP_AltaGuardaparque + USP_ConsultaGuardaparquePorId
    ----------------------------------------

    -- Test 9: alta exitosa y validación de duplicado por documento.
    EXEC USP_AltaGuardaparque
        @Telefono = '1111111117', @CorreoGuardaparque = 'guardatestcifrado@mail.com',
        @NumeroDocumento = '88833300', @TipoDocumento = 'DNI', @Edad = 40,
        @Apellido = 'CifradoGuarda', @Nombre = 'Test', @Estado = 'Activo';
    SET @idGuardaTest9 = IDENT_CURRENT('Personal.Guardaparque');

    BEGIN TRY
        EXEC USP_AltaGuardaparque
            @Telefono = '1111111118', @CorreoGuardaparque = 'otroguarda@mail.com',
            @NumeroDocumento = '88833300', @TipoDocumento = 'DNI', @Edad = 41,
            @Apellido = 'Duplicado', @Nombre = 'Test', @Estado = 'Activo';
        PRINT 'Test 9 - FALLO: debería haber lanzado un error por documento duplicado.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 9 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    END CATCH

    PRINT 'Test 9b - ver resultado de USP_ConsultaGuardaparquePorId (debe mostrar NumeroDocumento=88833300):';
    EXEC USP_ConsultaGuardaparquePorId @IdGuardaparque = @idGuardaTest9;

    ----------------------------------------
    -- USP_AltaOrganizacionConcesionaria / USP_ModificacionOrganizacionConcesionaria
    -- + USP_ConsultaOrganizacionConcesionariaPorId
    ----------------------------------------

    -- Test 10: alta exitosa y validación de duplicado por Cuit (mismo patrón de
    -- test_06, pero comparando ahora contra el Cuit descifrado, no en texto plano).
    EXEC USP_AltaOrganizacionConcesionaria
        @Nombre = 'Concesionaria Test Cifrado Uno', @TipoActividad = 'Gastronomía',
        @Cuit = '30888111223', @CorreoContacto = 'orgtestcifrado1@mail.com';
    SET @idOrgTest10 = IDENT_CURRENT('Concesiones.OrganizacionConcesionaria');

    BEGIN TRY
        EXEC USP_AltaOrganizacionConcesionaria
            @Nombre = 'Otra Concesionaria', @TipoActividad = 'Hotelería',
            @Cuit = '30888111223'; -- mismo Cuit que Test 10
        PRINT 'Test 10 - FALLO: debería haber lanzado un error por CUIT duplicado.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 10 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    END CATCH

    -- Setup para Test 10b: segunda organización, para probar el cruce de Cuit en la Modificación.
    EXEC USP_AltaOrganizacionConcesionaria
        @Nombre = 'Concesionaria Test Cifrado Dos', @TipoActividad = 'Excursiones',
        @Cuit = '30888111224';
    SET @idOrgTest10b = IDENT_CURRENT('Concesiones.OrganizacionConcesionaria');

    -- Test 10b: modificación que intenta usar el Cuit de la organización del Test 10.
    -- Resultado esperado: el SP emite un PRINT, sin fallar, pero el Cuit de
    -- @idOrgTest10b NO debe cambiar (sigue siendo '30888111224').
    EXEC USP_ModificacionOrganizacionConcesionaria @IdOrganizacionConcesionaria = @idOrgTest10b, @Cuit = '30888111223';
    PRINT 'Test 10b - ver resultado a continuación (Cuit debe seguir siendo 30888111224, sin cambios):';
    EXEC USP_ConsultaOrganizacionConcesionariaPorId @IdOrganizacionConcesionaria = @idOrgTest10b;

    ----------------------------------------
    -- (Roles y vistas: ver testing/test_13_roles.sql, archivo dedicado)
    ----------------------------------------

    PRINT 'Suite de seguridad (10 tests) finalizada sin errores inesperados.';
END TRY
BEGIN CATCH
    PRINT 'ERROR INESPERADO durante la suite. Detalle: ' + ERROR_MESSAGE();
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
END CATCH


----------------------------------------------------------------------------------
-- Importaciones: USP_ImportarOrganizacionConcesionaria / USP_ImportarGuiasCsv
----------------------------------------------------------------------------------

DECLARE @FraseClaveTest VARCHAR(128) = 'ParquesNacionales_Cifrado_TP';
DECLARE @rutaArchivoConcesiones VARCHAR(2048) = '';
DECLARE @rutaArchivoGuias VARCHAR(500) = '';

BEGIN TRY
    DELETE FROM Concesiones.PagoConcesion;
    DELETE FROM Concesiones.Concesion;
    DELETE FROM Concesiones.OrganizacionConcesionaria;
    DELETE FROM Personal.Habilitacion;
    DELETE FROM Personal.GuiaTrabajaEnParque;
    DELETE FROM Personal.LogImportacionGuia;
    DELETE FROM Personal.Guia;

    -- Test 11 (equivalente al Test 3/8 de test_09, roto por el cifrado): tras
    -- importar, el CUIT 30506949471 (TURISUR SRL) se recupera desencriptando.
    -- Resultado esperado: existe al menos 1 fila.
    EXEC USP_ImportarOrganizacionConcesionaria @rutaArchivo = @rutaArchivoConcesiones;

    IF EXISTS (
        SELECT 1 FROM Concesiones.OrganizacionConcesionaria
        WHERE CONVERT(VARCHAR(11), DecryptByPassPhrase(@FraseClaveTest, Cuit, 1, CONVERT(VARBINARY, IdOrganizacionConcesionaria))) = '30506949471'
    )
        PRINT 'Test 11 - OK: el CUIT 30506949471 se importó y se recupera desencriptando.';
    ELSE
        PRINT 'Test 11 - FALLO: no se encontró el CUIT 30506949471 tras desencriptar.';

    -- Test 12 (equivalente al Test 4 de test_09, que ahora "pasa" siempre sin
    -- verificar nada real): ningún CUIT quedó duplicado, comparando por el valor
    -- DESENCRIPTADO en vez de por los bytes cifrados.
    -- Resultado esperado: 0 filas.
    IF EXISTS (
        SELECT CuitDescifrado
        FROM (
            SELECT CONVERT(VARCHAR(11), DecryptByPassPhrase(@FraseClaveTest, Cuit, 1, CONVERT(VARBINARY, IdOrganizacionConcesionaria))) AS CuitDescifrado
            FROM Concesiones.OrganizacionConcesionaria
        ) x
        WHERE CuitDescifrado IS NOT NULL -- excluye fallos de descifrado (no son "el mismo CUIT", son datos corruptos/ajenos a este SP)
        GROUP BY CuitDescifrado
        HAVING COUNT(*) > 1
    )
        PRINT 'Test 12 - FALLO: hay CUIT duplicados tras desencriptar.';
    ELSE
        PRINT 'Test 12 - OK: ningún CUIT quedó duplicado (verificado desencriptando, no por bytes cifrados).';

    -- Test 13 (equivalente al Test 4/6/7 de test_10, roto por el cifrado): tras
    -- importar, el documento 13608130 (ARAMBURU, BELEN) se recupera desencriptando.
    -- Resultado esperado: existe al menos 1 fila.
    EXEC USP_ImportarGuiasCsv @rutaArchivo = @rutaArchivoGuias;

    IF EXISTS (
        SELECT 1 FROM Personal.Guia
        WHERE CONVERT(VARCHAR(15), DecryptByPassPhrase(@FraseClaveTest, NumeroDocumento, 1, CONVERT(VARBINARY, IdGuia))) = '13608130'
    )
        PRINT 'Test 13 - OK: el documento 13608130 se importó y se recupera desencriptando.';
    ELSE
        PRINT 'Test 13 - FALLO: no se encontró el documento 13608130 tras desencriptar.';

    -- Test 14: ningún documento quedó duplicado, comparando por el
    -- valor DESENCRIPTADO.
    -- Resultado esperado: 0 filas.
    IF EXISTS (
        SELECT DocumentoDescifrado
        FROM (
            SELECT CONVERT(VARCHAR(15), DecryptByPassPhrase(@FraseClaveTest, NumeroDocumento, 1, CONVERT(VARBINARY, IdGuia))) AS DocumentoDescifrado
            FROM Personal.Guia
        ) x
        WHERE DocumentoDescifrado IS NOT NULL
        GROUP BY DocumentoDescifrado
        HAVING COUNT(*) > 1
    )
        PRINT 'Test 14 - FALLO: hay documentos duplicados tras desencriptar.';
    ELSE
        PRINT 'Test 14 - OK: ningún documento quedó duplicado (verificado desencriptando, no por bytes cifrados).';

    PRINT 'Suite de importaciones (Test 11-14) finalizada sin errores inesperados.';
END TRY
BEGIN CATCH
    PRINT 'ERROR EN LA SUITE DE IMPORTACIONES (revisar que @rutaArchivoConcesiones y @rutaArchivoGuias apunten a archivos válidos). Detalle: ' + ERROR_MESSAGE();
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
END CATCH


-- Limpieza post-ejecución

BEGIN TRY
    DELETE FROM Turismo.Visitante WHERE IdVisitante IN (@idVisTest2, @idVisTest6);
    DELETE FROM Personal.Guardaparque WHERE IdGuardaparque = @idGuardaTest9;
    PRINT 'Datos de prueba eliminados.';
END TRY
BEGIN CATCH
    PRINT 'ERROR AL INTENTAR ELIMINAR DATOS DE PRUEBA: ' + ERROR_MESSAGE();
END CATCH
GO