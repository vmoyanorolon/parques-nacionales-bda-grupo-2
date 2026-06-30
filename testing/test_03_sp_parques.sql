-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: Scripts testing para los Stored Procedures del esquema Parque

USE ParquesNacionales
GO

SET NOCOUNT ON;
SET XACT_ABORT OFF;

-- Si una ejecución anterior se cortó antes de llegar al ROLLBACK final (por
-- ejemplo por un error no contemplado), la transacción queda abierta en esta
-- misma sesión y arrastra datos de prueba "fantasma" a la siguiente.
-- Por eso, antes de arrancar, nos aseguramos de partir de una sesión limpia.
IF @@TRANCOUNT > 0
BEGIN
    PRINT 'Se detectó una transacción abierta de una corrida anterior. Se hace ROLLBACK antes de continuar.';
    WHILE @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
END


BEGIN TRY
    BEGIN TRANSACTION;

----------------------------------------
-- USP_AltaParque
----------------------------------------

DECLARE @idParqueTest1 INT;

-- Test 1: alta exitosa con datos válidos.
-- Resultado esperado: se inserta el registro
EXEC USP_AltaParque
    @Nombre = 'Parque Nacional Test Iguazu',
    @HorarioCierre = '18:00',
    @HorarioApertura = '08:00',
    @Superficie = 67620.00,
    @Provincia = 'Misiones',
    @Numero = 1,
    @Localidad = 'Puerto Iguazu',
    @TipoParque = 'Parque Nacional',
    @IdParque = @idParqueTest1 OUTPUT;

PRINT 'Test 1 - Alta exitosa. IdParque generado: ' + CAST(@idParqueTest1 AS VARCHAR);
SELECT Test = 1, * FROM Parques.Parque WHERE IdParque = @idParqueTest1;

-- Test 2: alta con nombre duplicado.
-- Resultado esperado: No se pudo dar de alta el parque porque ya existe otro con ese nombre.
BEGIN TRY
    DECLARE @idParqueTest2 INT;
    EXEC USP_AltaParque
        @Nombre = 'Parque Nacional Test Iguazu', -- mismo nombre que Test 1
        @HorarioCierre = '19:00',
        @HorarioApertura = '07:00',
        @Superficie = 100.00,
        @Provincia = 'Misiones',
        @Numero = 2,
        @Localidad = 'Puerto Iguazu',
        @TipoParque = 'Parque Nacional',
        @IdParque = @idParqueTest2 OUTPUT;
    PRINT 'Test 2 - FALLO: debería haber lanzado un error por nombre duplicado.';
END TRY
BEGIN CATCH
    PRINT 'Test 2 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
END CATCH

-- Test 3: alta con Superficie <= 0.
-- Resultado esperado: error del motor por violar CK_Parque_Superficie
BEGIN TRY
    DECLARE @idParqueTest3 INT;
    EXEC USP_AltaParque
        @Nombre = 'Parque Nacional Test Superficie Invalida',
        @HorarioCierre = '18:00',
        @HorarioApertura = '08:00',
        @Superficie = 0.00,
        @Provincia = 'Misiones',
        @Numero = 1,
        @Localidad = 'Puerto Iguazu',
        @TipoParque = 'Parque Nacional',
        @IdParque = @idParqueTest3 OUTPUT;
    PRINT 'Test 3 - FALLO: debería haber lanzado un error por CK_Parque_Superficie.';
END TRY
BEGIN CATCH
    PRINT 'Test 3 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
END CATCH

-- Test 4: alta con TipoParque fuera del dominio permitido.
-- Resultado esperado: error del motor por violar CK_Parque_TipoParque.
BEGIN TRY
    DECLARE @idParqueTest4 INT;
    EXEC USP_AltaParque
        @Nombre = 'Parque Nacional Test Tipo Invalido',
        @HorarioCierre = '18:00',
        @HorarioApertura = '08:00',
        @Superficie = 500.00,
        @Provincia = 'Misiones',
        @Numero = 1,
        @Localidad = 'Puerto Iguazu',
        @TipoParque = 'Parque Inventado',
        @IdParque = @idParqueTest4 OUTPUT;
    PRINT 'Test 4 - FALLO: debería haber lanzado un error por CK_Parque_TipoParque.';
END TRY
BEGIN CATCH
    PRINT 'Test 4 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
END CATCH

----------------------------------------
-- USP_ModificacionParque
----------------------------------------

-- Test 5: modificación parcial (se modifica HorarioCierre).
-- Resultado esperado: HorarioCierre pasa a 20:00 y el resto de las columnas conserva los valores del Test 1
EXEC USP_ModificacionParque
    @IdParque = @idParqueTest1,
    @HorarioCierre = '20:00';

SELECT Test = 5, * FROM Parques.Parque WHERE IdParque = @idParqueTest1;

-- Test 6: modificación de un IdParque inexistente.
-- Resultado esperado: no se puede modificar porque el parque indicado no existe
BEGIN TRY
    EXEC USP_ModificacionParque
        @IdParque = -1,
        @Nombre = 'No debería aplicarse';
    PRINT 'Test 6 - FALLO: debería haber lanzado un error por parque inexistente.';
END TRY
BEGIN CATCH
    PRINT 'Test 6 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
END CATCH

-- Setup para Test 7/8: un segundo parque para probar el cruce de nombres en la modificación.
DECLARE @idParqueTest7 INT;
EXEC USP_AltaParque
    @Nombre = 'Parque Nacional Test Secundario',
    @HorarioCierre = '18:00',
    @HorarioApertura = '08:00',
    @Superficie = 200.00,
    @Provincia = 'Chubut',
    @Numero = 1,
    @Localidad = 'Esquel',
    @TipoParque = 'Reserva Nacional',
    @IdParque = @idParqueTest7 OUTPUT;

-- Test 7: modificación que intenta renombrar el parque del Test 7 con el nombre que ya usa el parque del Test 1.
-- Resultado esperado: no se puede modificar el parque porque ya existe otro parque con ese nombre
BEGIN TRY
    EXEC USP_ModificacionParque
        @IdParque = @idParqueTest7,
        @Nombre = 'Parque Nacional Test Iguazu';
    PRINT 'Test 7 - FALLO: debería haber lanzado un error por nombre duplicado.';
END TRY
BEGIN CATCH
    PRINT 'Test 7 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
END CATCH

-- Test 8: modificación que reenvía el mismo nombre que ya tiene el propio parque
-- Resultado esperado: NO lanza error, y Localidad se actualiza
EXEC USP_ModificacionParque
    @IdParque = @idParqueTest7,
    @Nombre = 'Parque Nacional Test Secundario',
    @Localidad = 'Trevelin';

SELECT Test = 8, * FROM Parques.Parque WHERE IdParque = @idParqueTest7;

----------------------------------------
-- USP_BajaParque
----------------------------------------

-- Test 9: baja de un IdParque inexistente.
-- Resultado esperado: no se da ninguna baja porque el parque indicado no existe
BEGIN TRY
    EXEC USP_BajaParque @IdParque = -1;
    PRINT 'Test 9 - FALLO: debería haber lanzado un error por parque inexistente.';
END TRY
BEGIN CATCH
    PRINT 'Test 9 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
END CATCH

-- Test 10: baja de un parque sin registros relacionados.
-- Resultado esperado: el parque se elimina sin error.
EXEC USP_BajaParque @IdParque = @idParqueTest7;

SELECT * FROM Parques.Parque WHERE IdParque = @idParqueTest7;

-- Setup para Test 11: una actividad asociada al parque del Test 1, para forzar la violación de FK que captura el CATCH de USP_BajaParque.
INSERT INTO Turismo.Actividad (Nombre, Tipo, Costo, DuracionMinutos, CupoMaximo, IdParque)
VALUES ('Sendero Test', 'Atracción', 0.00, 60, 20, @idParqueTest1);

-- Test 11: baja de un parque con registros relacionados (Actividad).
-- Resultado esperado: no se puede eliminar el parque porque tiene registros relacionados
BEGIN TRY
    EXEC USP_BajaParque @IdParque = @idParqueTest1;
    PRINT 'Test 11 - FALLO: debería haber lanzado un error por FK relacionada.';
END TRY
BEGIN CATCH
    PRINT 'Test 11 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
END CATCH

----------------------------------------
-- Cierre
----------------------------------------
-- Se descartan todos los datos de prueba (parques y la actividad del Test 11)
-- para que el script sea re-ejecutable sin residuos.
    ROLLBACK TRANSACTION;
    PRINT 'Suite de USP_AltaParque / USP_ModificacionParque / USP_BajaParque finalizada sin errores inesperados.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    PRINT 'ERROR INESPERADO - se hizo ROLLBACK. Detalle: ' + ERROR_MESSAGE();
END CATCH
GO