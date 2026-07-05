-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Fecha: 04/07/2026
-- Descripción: Scripts testing para los Stored Procedures del esquema Ventas

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

-- Limpieza previa: elimina datos de test que hayan quedado confirmados en la
-- base por una ejecución anterior que se cortó antes del ROLLBACK final.
-- Se identifica por el NumeroDocumento del visitante de setup.
IF EXISTS (SELECT 1 FROM Turismo.Visitante WHERE NumeroDocumento = '40111222')
BEGIN
    DECLARE @idVentaPrevia INT;
    SELECT @idVentaPrevia = IdVenta FROM Ventas.Venta
    WHERE IdVisitante = (SELECT IdVisitante FROM Turismo.Visitante WHERE NumeroDocumento = '40111222');

    IF @idVentaPrevia IS NOT NULL
    BEGIN
        DELETE FROM Ventas.LineaDeEntradaParque    WHERE IdVenta = @idVentaPrevia;
        DELETE FROM Ventas.LineaDeEntradaActividad WHERE IdVenta = @idVentaPrevia;
        DELETE FROM Ventas.Venta                   WHERE IdVenta = @idVentaPrevia;
    END

    DECLARE @idParquePrevio INT;
    SELECT @idParquePrevio = IdParque FROM Parques.Parque WHERE Nombre = 'Parque Nacional Test Ventas';

    IF @idParquePrevio IS NOT NULL
    BEGIN
        DELETE FROM Turismo.EntradaParque WHERE IdParque = @idParquePrevio;
        DELETE FROM Turismo.Actividad     WHERE IdParque = @idParquePrevio;
        DELETE FROM Parques.Parque        WHERE IdParque = @idParquePrevio;
    END

    DELETE FROM Turismo.Visitante WHERE NumeroDocumento = '40111222';
    PRINT 'Limpieza previa ejecutada.';
END

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @idVisitanteSetup INT, @idParqueSetup INT,
            @idEntradaSetup   INT, @idActividadSetup INT,
            @idVentaTest1     INT, @idTurnoSetup INT;

    INSERT INTO Turismo.Visitante (Telefono, CorreoVisitante, NumeroDocumento, TipoDocumento, CUIT, Edad, Nombre, Apellido)
    VALUES ('1100000001', 'visitante.ventas@gmail.com', '40111222', 'DNI', '20401112220', 30, 'Visitante', 'Ventas');
    SET @idVisitanteSetup = SCOPE_IDENTITY();
    INSERT INTO Parques.Parque (Nombre, HorarioCierre, HorarioApertura, Superficie, CostoHectarea, Provincia, Numero, Localidad, TipoParque)
    VALUES ('Parque Nacional Test Ventas', '18:00', '08:00', 500.00, 700.00, 'Salta', 1, 'Cafayate', 'Parque Nacional');

    SET @idParqueSetup = SCOPE_IDENTITY();

    INSERT INTO Turismo.EntradaParque (Costo, FechaAcceso, IdParque)
    VALUES (800.00, '2026-07-01', @idParqueSetup);
    SET @idEntradaSetup = SCOPE_IDENTITY();

    -- CupoMaximo = 2: el Test 8 consume 1 lugar (Cantidad=1). El Test 9
    -- intenta sumar 2 más (1+2=3 > 2), lo que provoca el error de cupo.
    INSERT INTO Turismo.Actividad (Nombre, Tipo, Costo, DuracionMinutos, CupoMaximo, IdParque)
    VALUES ('Kayak Test Ventas', 'Tour', 1500.00, 90, 2, @idParqueSetup);
    SET @idActividadSetup = SCOPE_IDENTITY();

    -- Turno Lunes 09:00-11:00 (DiaDeSemana=2, Domingo=1). Todas las
    -- l\xedneas de actividad de este archivo usan fechas dentro de esta ventana,
    -- salvo el Test 14 que la usa a prop\xf3sito fuera de rango.
    INSERT INTO Turismo.Turno (HoraInicio, HoraFin, DiaDeSemana, IdActividad)
    VALUES ('09:00', '11:00', 2, @idActividadSetup);
    SET @idTurnoSetup = SCOPE_IDENTITY();

    ----------------------------------------
    -- USP_AltaVenta
    ----------------------------------------

    -- Test 1: alta exitosa.
    -- Resultado esperado: inserta la venta con Monto = 0 (se actualiza al agregar líneas).
    EXEC USP_AltaVenta
        @IdVisitante  = @idVisitanteSetup,
        @MetodoDePago = 'Efectivo',
        @PuntoDeVenta = 'Boletería',
        @IdVenta      = @idVentaTest1 OUTPUT;
    SET XACT_ABORT OFF;

    SELECT Test = 1, * FROM Ventas.Venta WHERE IdVenta = @idVentaTest1;

    -- Test 2: alta con IdVisitante inexistente.
    -- Resultado esperado: error 50000 "El ID de visitante indicado no existe."
    BEGIN TRY
        DECLARE @idVentaTest2 INT;
        EXEC USP_AltaVenta
            @IdVisitante  = -1,
            @MetodoDePago = 'Efectivo',
            @PuntoDeVenta = 'Boletería',
            @IdVenta      = @idVentaTest2 OUTPUT;
        PRINT 'Test 2 - FALLO: debería haber lanzado un error por visitante inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 2 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    IF XACT_STATE() = -1  -- Recovery #1
    BEGIN
        ROLLBACK TRANSACTION; BEGIN TRANSACTION;
        INSERT INTO Turismo.Visitante (Telefono, CorreoVisitante, NumeroDocumento, TipoDocumento, CUIT, Edad, Nombre, Apellido)
        VALUES ('1100000001', 'visitante.ventas@gmail.com', '40111222', 'DNI', '20401112220', 30, 'Visitante', 'Ventas');
        SET @idVisitanteSetup = SCOPE_IDENTITY();
        INSERT INTO Parques.Parque (Nombre, HorarioCierre, HorarioApertura, Superficie, CostoHectarea, Provincia, Numero, Localidad, TipoParque)
        VALUES ('Parque Nacional Test Ventas', '18:00', '08:00', 500.00, 700.00, 'Salta', 1, 'Cafayate', 'Parque Nacional');
        SET @idParqueSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.EntradaParque (Costo, FechaAcceso, IdParque) VALUES (800.00, '2026-07-01', @idParqueSetup);
        SET @idEntradaSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.Actividad (Nombre, Tipo, Costo, DuracionMinutos, CupoMaximo, IdParque)
        VALUES ('Kayak Test Ventas', 'Tour', 1500.00, 90, 2, @idParqueSetup);
        SET @idActividadSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.Turno (HoraInicio, HoraFin, DiaDeSemana, IdActividad)
        VALUES ('09:00', '11:00', 2, @idActividadSetup);
        SET @idTurnoSetup = SCOPE_IDENTITY();
        EXEC USP_AltaVenta @IdVisitante=@idVisitanteSetup, @MetodoDePago='Efectivo', @PuntoDeVenta='Boletería', @IdVenta=@idVentaTest1 OUTPUT;
        SET XACT_ABORT OFF;
    END

    ----------------------------------------
    -- USP_AltaLineasDeEntradaParque
    ----------------------------------------

    -- Test 3: alta exitosa con una línea de entrada a parque.
    -- Resultado esperado: inserta la línea y acumula el subtotal en Venta.Monto (Monto = 800.00 * 2 = 1600.00).
    DECLARE @lineasParqueTest3 Ventas.TVP_LineaParque;
    INSERT INTO @lineasParqueTest3 (IdEntradaParque, Cantidad) VALUES (@idEntradaSetup, 2);

    EXEC USP_AltaLineasDeEntradaParque @IdVenta = @idVentaTest1, @Lineas = @lineasParqueTest3;
    SET XACT_ABORT OFF;

    SELECT Test = 3, * FROM Ventas.Venta WHERE IdVenta = @idVentaTest1;
    SELECT Test = 3, * FROM Ventas.LineaDeEntradaParque WHERE IdVenta = @idVentaTest1;

    -- Test 4: TVP vacío.
    -- Resultado esperado: no se insertar nada.
    DECLARE @lineasParqueTest4 Ventas.TVP_LineaParque; -- sin filas
    EXEC USP_AltaLineasDeEntradaParque @IdVenta = @idVentaTest1, @Lineas = @lineasParqueTest4;
    PRINT 'Test 4 - OK. TVP vacío no generó error.';

    SELECT Test = 4, * FROM Ventas.LineaDeEntradaParque WHERE IdVenta = @idVentaTest1;

    -- Test 5: alta con IdVenta inexistente.
    -- Resultado esperado: error 50000 "La venta indicada no existe."
    BEGIN TRY
        DECLARE @lineasParqueTest5 Ventas.TVP_LineaParque;
        INSERT INTO @lineasParqueTest5 (IdEntradaParque, Cantidad) VALUES (@idEntradaSetup, 1);
        EXEC USP_AltaLineasDeEntradaParque @IdVenta = -1, @Lineas = @lineasParqueTest5;
        PRINT 'Test 5 - FALLO: debería haber lanzado un error por venta inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 5 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    IF XACT_STATE() = -1  -- Recovery #2
    BEGIN
        ROLLBACK TRANSACTION; BEGIN TRANSACTION;
        INSERT INTO Turismo.Visitante (Telefono, CorreoVisitante, NumeroDocumento, TipoDocumento, CUIT, Edad, Nombre, Apellido)
        VALUES ('1100000001', 'visitante.ventas@gmail.com', '40111222', 'DNI', '20401112220', 30, 'Visitante', 'Ventas');
        SET @idVisitanteSetup = SCOPE_IDENTITY();
        INSERT INTO Parques.Parque (Nombre, HorarioCierre, HorarioApertura, Superficie, CostoHectarea, Provincia, Numero, Localidad, TipoParque)
        VALUES ('Parque Nacional Test Ventas', '18:00', '08:00', 500.00, 700.00, 'Salta', 1, 'Cafayate', 'Parque Nacional');
        SET @idParqueSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.EntradaParque (Costo, FechaAcceso, IdParque) VALUES (800.00, '2026-07-01', @idParqueSetup);
        SET @idEntradaSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.Actividad (Nombre, Tipo, Costo, DuracionMinutos, CupoMaximo, IdParque)
        VALUES ('Kayak Test Ventas', 'Tour', 1500.00, 90, 2, @idParqueSetup);
        SET @idActividadSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.Turno (HoraInicio, HoraFin, DiaDeSemana, IdActividad)
        VALUES ('09:00', '11:00', 2, @idActividadSetup);
        SET @idTurnoSetup = SCOPE_IDENTITY();
        EXEC USP_AltaVenta @IdVisitante=@idVisitanteSetup, @MetodoDePago='Efectivo', @PuntoDeVenta='Boletería', @IdVenta=@idVentaTest1 OUTPUT;
        SET XACT_ABORT OFF;
    END

    -- Test 6: alta con Cantidad = 0.
    -- Resultado esperado: error 50000 "Hay líneas de parque con cantidad menor o igual a cero."
    BEGIN TRY
        DECLARE @lineasParqueTest6 Ventas.TVP_LineaParque;
        INSERT INTO @lineasParqueTest6 (IdEntradaParque, Cantidad) VALUES (@idEntradaSetup, 0);
        EXEC USP_AltaLineasDeEntradaParque @IdVenta = @idVentaTest1, @Lineas = @lineasParqueTest6;
        PRINT 'Test 6 - FALLO: debería haber lanzado un error por cantidad inválida.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 6 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    IF XACT_STATE() = -1  -- Recovery #3
    BEGIN
        ROLLBACK TRANSACTION; BEGIN TRANSACTION;
        INSERT INTO Turismo.Visitante (Telefono, CorreoVisitante, NumeroDocumento, TipoDocumento, CUIT, Edad, Nombre, Apellido)
        VALUES ('1100000001', 'visitante.ventas@gmail.com', '40111222', 'DNI', '20401112220', 30, 'Visitante', 'Ventas');
        SET @idVisitanteSetup = SCOPE_IDENTITY();
        INSERT INTO Parques.Parque (Nombre, HorarioCierre, HorarioApertura, Superficie, CostoHectarea, Provincia, Numero, Localidad, TipoParque)
        VALUES ('Parque Nacional Test Ventas', '18:00', '08:00', 500.00, 700.00, 'Salta', 1, 'Cafayate', 'Parque Nacional');
        SET @idParqueSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.EntradaParque (Costo, FechaAcceso, IdParque) VALUES (800.00, '2026-07-01', @idParqueSetup);
        SET @idEntradaSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.Actividad (Nombre, Tipo, Costo, DuracionMinutos, CupoMaximo, IdParque)
        VALUES ('Kayak Test Ventas', 'Tour', 1500.00, 90, 2, @idParqueSetup);
        SET @idActividadSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.Turno (HoraInicio, HoraFin, DiaDeSemana, IdActividad)
        VALUES ('09:00', '11:00', 2, @idActividadSetup);
        SET @idTurnoSetup = SCOPE_IDENTITY();
        EXEC USP_AltaVenta @IdVisitante=@idVisitanteSetup, @MetodoDePago='Efectivo', @PuntoDeVenta='Boletería', @IdVenta=@idVentaTest1 OUTPUT;
        SET XACT_ABORT OFF;
    END

    -- Test 7: alta con IdEntradaParque inexistente.
    -- Resultado esperado: error 50000 "Alguna entrada de parque indicada no existe."
    BEGIN TRY
        DECLARE @lineasParqueTest7 Ventas.TVP_LineaParque;
        INSERT INTO @lineasParqueTest7 (IdEntradaParque, Cantidad) VALUES (-1, 1);
        EXEC USP_AltaLineasDeEntradaParque @IdVenta = @idVentaTest1, @Lineas = @lineasParqueTest7;
        PRINT 'Test 7 - FALLO: debería haber lanzado un error por entrada inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 7 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    IF XACT_STATE() = -1  -- Recovery #4
    BEGIN
        ROLLBACK TRANSACTION; BEGIN TRANSACTION;
        INSERT INTO Turismo.Visitante (Telefono, CorreoVisitante, NumeroDocumento, TipoDocumento, CUIT, Edad, Nombre, Apellido)
        VALUES ('1100000001', 'visitante.ventas@gmail.com', '40111222', 'DNI', '20401112220', 30, 'Visitante', 'Ventas');
        SET @idVisitanteSetup = SCOPE_IDENTITY();
        INSERT INTO Parques.Parque (Nombre, HorarioCierre, HorarioApertura, Superficie, CostoHectarea, Provincia, Numero, Localidad, TipoParque)
        VALUES ('Parque Nacional Test Ventas', '18:00', '08:00', 500.00, 700.00, 'Salta', 1, 'Cafayate', 'Parque Nacional');
        SET @idParqueSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.EntradaParque (Costo, FechaAcceso, IdParque) VALUES (800.00, '2026-07-01', @idParqueSetup);
        SET @idEntradaSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.Actividad (Nombre, Tipo, Costo, DuracionMinutos, CupoMaximo, IdParque)
        VALUES ('Kayak Test Ventas', 'Tour', 1500.00, 90, 2, @idParqueSetup);
        SET @idActividadSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.Turno (HoraInicio, HoraFin, DiaDeSemana, IdActividad)
        VALUES ('09:00', '11:00', 2, @idActividadSetup);
        SET @idTurnoSetup = SCOPE_IDENTITY();
        EXEC USP_AltaVenta @IdVisitante=@idVisitanteSetup, @MetodoDePago='Efectivo', @PuntoDeVenta='Boletería', @IdVenta=@idVentaTest1 OUTPUT;
        SET XACT_ABORT OFF;
    END

    ----------------------------------------
    -- USP_AltaLineasDeEntradaActividad
    ----------------------------------------

    -- Test 8: alta exitosa con una línea de actividad.
    -- Resultado esperado: inserta la línea y acumula el subtotal en Venta.Monto (Monto = 1500.00 * 1 = 1500.00; no hay líneas de parque tras las recuperaciones).
    DECLARE @lineasActividadTest8 Ventas.TVP_LineaActividad;
    INSERT INTO @lineasActividadTest8 (IdActividad, Cantidad, FechaHoraAsistencia) VALUES (@idActividadSetup, 1, '20260706 09:30');

    EXEC USP_AltaLineasDeEntradaActividad @IdVenta = @idVentaTest1, @Lineas = @lineasActividadTest8;
    SET XACT_ABORT OFF;

    SELECT Test = 8, * FROM Ventas.Venta WHERE IdVenta = @idVentaTest1;
    SELECT Test = 8, * FROM Ventas.LineaDeEntradaActividad WHERE IdVenta = @idVentaTest1;

    -- Test 9: cupo del turno excedido para la misma fecha del Test 8 (2026-07-06).
    -- El Test 8 ya vendi\xf3 1 lugar en esa fecha; intentamos vender 2 m\xe1s (1+2=3 > CupoMaximo=2).
    -- Resultado esperado: error 50000 "Alg\xfan turno supera la cantidad de cupos disponibles para la fecha indicada."
    -- Este test se ejecuta inmediatamente después del Test 8 (antes de los demás tests
    -- de error) para que el cupo consumido en Test 8 esté disponible.
    BEGIN TRY
        DECLARE @lineasActividadTest9 Ventas.TVP_LineaActividad;
        INSERT INTO @lineasActividadTest9 (IdActividad, Cantidad, FechaHoraAsistencia) VALUES (@idActividadSetup, 2, '20260706 09:45');
        EXEC USP_AltaLineasDeEntradaActividad @IdVenta = @idVentaTest1, @Lineas = @lineasActividadTest9;
        PRINT 'Test 9 - FALLO: debería haber lanzado un error por cupo excedido.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 9 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    IF XACT_STATE() = -1  -- Recovery #5
    BEGIN
        ROLLBACK TRANSACTION; BEGIN TRANSACTION;
        INSERT INTO Turismo.Visitante (Telefono, CorreoVisitante, NumeroDocumento, TipoDocumento, CUIT, Edad, Nombre, Apellido)
        VALUES ('1100000001', 'visitante.ventas@gmail.com', '40111222', 'DNI', '20401112220', 30, 'Visitante', 'Ventas');
        SET @idVisitanteSetup = SCOPE_IDENTITY();
        INSERT INTO Parques.Parque (Nombre, HorarioCierre, HorarioApertura, Superficie, CostoHectarea, Provincia, Numero, Localidad, TipoParque)
        VALUES ('Parque Nacional Test Ventas', '18:00', '08:00', 500.00, 700.00, 'Salta', 1, 'Cafayate', 'Parque Nacional');
        SET @idParqueSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.EntradaParque (Costo, FechaAcceso, IdParque) VALUES (800.00, '2026-07-01', @idParqueSetup);
        SET @idEntradaSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.Actividad (Nombre, Tipo, Costo, DuracionMinutos, CupoMaximo, IdParque)
        VALUES ('Kayak Test Ventas', 'Tour', 1500.00, 90, 2, @idParqueSetup);
        SET @idActividadSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.Turno (HoraInicio, HoraFin, DiaDeSemana, IdActividad)
        VALUES ('09:00', '11:00', 2, @idActividadSetup);
        SET @idTurnoSetup = SCOPE_IDENTITY();
        EXEC USP_AltaVenta @IdVisitante=@idVisitanteSetup, @MetodoDePago='Efectivo', @PuntoDeVenta='Boletería', @IdVenta=@idVentaTest1 OUTPUT;
        SET XACT_ABORT OFF;
    END

    -- Test 10: alta con IdVenta inexistente.
    -- Resultado esperado: error 50000 "La venta indicada no existe."
    BEGIN TRY
        DECLARE @lineasActividadTest10 Ventas.TVP_LineaActividad;
        INSERT INTO @lineasActividadTest10 (IdActividad, Cantidad, FechaHoraAsistencia) VALUES (@idActividadSetup, 1, '20260706 09:30');
        EXEC USP_AltaLineasDeEntradaActividad @IdVenta = -1, @Lineas = @lineasActividadTest10;
        PRINT 'Test 10 - FALLO: debería haber lanzado un error por venta inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 10 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    IF XACT_STATE() = -1  -- Recovery #6
    BEGIN
        ROLLBACK TRANSACTION; BEGIN TRANSACTION;
        INSERT INTO Turismo.Visitante (Telefono, CorreoVisitante, NumeroDocumento, TipoDocumento, CUIT, Edad, Nombre, Apellido)
        VALUES ('1100000001', 'visitante.ventas@gmail.com', '40111222', 'DNI', '20401112220', 30, 'Visitante', 'Ventas');
        SET @idVisitanteSetup = SCOPE_IDENTITY();
        INSERT INTO Parques.Parque (Nombre, HorarioCierre, HorarioApertura, Superficie, CostoHectarea, Provincia, Numero, Localidad, TipoParque)
        VALUES ('Parque Nacional Test Ventas', '18:00', '08:00', 500.00, 700.00, 'Salta', 1, 'Cafayate', 'Parque Nacional');
        SET @idParqueSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.EntradaParque (Costo, FechaAcceso, IdParque) VALUES (800.00, '2026-07-01', @idParqueSetup);
        SET @idEntradaSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.Actividad (Nombre, Tipo, Costo, DuracionMinutos, CupoMaximo, IdParque)
        VALUES ('Kayak Test Ventas', 'Tour', 1500.00, 90, 2, @idParqueSetup);
        SET @idActividadSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.Turno (HoraInicio, HoraFin, DiaDeSemana, IdActividad)
        VALUES ('09:00', '11:00', 2, @idActividadSetup);
        SET @idTurnoSetup = SCOPE_IDENTITY();
        EXEC USP_AltaVenta @IdVisitante=@idVisitanteSetup, @MetodoDePago='Efectivo', @PuntoDeVenta='Boletería', @IdVenta=@idVentaTest1 OUTPUT;
        SET XACT_ABORT OFF;
    END

    -- Test 11: alta con Cantidad = 0.
    -- Resultado esperado: error 50000 "Hay líneas de actividad con cantidad menor o igual a cero."
    BEGIN TRY
        DECLARE @lineasActividadTest11 Ventas.TVP_LineaActividad;
        INSERT INTO @lineasActividadTest11 (IdActividad, Cantidad, FechaHoraAsistencia) VALUES (@idActividadSetup, 0, '20260706 09:30');
        EXEC USP_AltaLineasDeEntradaActividad @IdVenta = @idVentaTest1, @Lineas = @lineasActividadTest11;
        PRINT 'Test 11 - FALLO: debería haber lanzado un error por cantidad inválida.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 11 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    IF XACT_STATE() = -1  -- Recovery #7
    BEGIN
        ROLLBACK TRANSACTION; BEGIN TRANSACTION;
        INSERT INTO Turismo.Visitante (Telefono, CorreoVisitante, NumeroDocumento, TipoDocumento, CUIT, Edad, Nombre, Apellido)
        VALUES ('1100000001', 'visitante.ventas@gmail.com', '40111222', 'DNI', '20401112220', 30, 'Visitante', 'Ventas');
        SET @idVisitanteSetup = SCOPE_IDENTITY();
        INSERT INTO Parques.Parque (Nombre, HorarioCierre, HorarioApertura, Superficie, CostoHectarea, Provincia, Numero, Localidad, TipoParque)
        VALUES ('Parque Nacional Test Ventas', '18:00', '08:00', 500.00, 700.00, 'Salta', 1, 'Cafayate', 'Parque Nacional');
        SET @idParqueSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.EntradaParque (Costo, FechaAcceso, IdParque) VALUES (800.00, '2026-07-01', @idParqueSetup);
        SET @idEntradaSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.Actividad (Nombre, Tipo, Costo, DuracionMinutos, CupoMaximo, IdParque)
        VALUES ('Kayak Test Ventas', 'Tour', 1500.00, 90, 2, @idParqueSetup);
        SET @idActividadSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.Turno (HoraInicio, HoraFin, DiaDeSemana, IdActividad)
        VALUES ('09:00', '11:00', 2, @idActividadSetup);
        SET @idTurnoSetup = SCOPE_IDENTITY();
        EXEC USP_AltaVenta @IdVisitante=@idVisitanteSetup, @MetodoDePago='Efectivo', @PuntoDeVenta='Boletería', @IdVenta=@idVentaTest1 OUTPUT;
        SET XACT_ABORT OFF;
    END

    -- Test 12: alta con IdActividad inexistente.
    -- Resultado esperado: error 50000 "Alguna actividad indicada no existe."
    BEGIN TRY
        DECLARE @lineasActividadTest12 Ventas.TVP_LineaActividad;
        INSERT INTO @lineasActividadTest12 (IdActividad, Cantidad, FechaHoraAsistencia) VALUES (-1, 1, '20260706 09:30');
        EXEC USP_AltaLineasDeEntradaActividad @IdVenta = @idVentaTest1, @Lineas = @lineasActividadTest12;
        PRINT 'Test 12 - FALLO: debería haber lanzado un error por actividad inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 12 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    IF XACT_STATE() = -1  -- Recovery #8
    BEGIN
        ROLLBACK TRANSACTION; BEGIN TRANSACTION;
        INSERT INTO Turismo.Visitante (Telefono, CorreoVisitante, NumeroDocumento, TipoDocumento, CUIT, Edad, Nombre, Apellido)
        VALUES ('1100000001', 'visitante.ventas@gmail.com', '40111222', 'DNI', '20401112220', 30, 'Visitante', 'Ventas');
        SET @idVisitanteSetup = SCOPE_IDENTITY();
        INSERT INTO Parques.Parque (Nombre, HorarioCierre, HorarioApertura, Superficie, CostoHectarea, Provincia, Numero, Localidad, TipoParque)
        VALUES ('Parque Nacional Test Ventas', '18:00', '08:00', 500.00, 700.00, 'Salta', 1, 'Cafayate', 'Parque Nacional');
        SET @idParqueSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.EntradaParque (Costo, FechaAcceso, IdParque) VALUES (800.00, '2026-07-01', @idParqueSetup);
        SET @idEntradaSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.Actividad (Nombre, Tipo, Costo, DuracionMinutos, CupoMaximo, IdParque)
        VALUES ('Kayak Test Ventas', 'Tour', 1500.00, 90, 2, @idParqueSetup);
        SET @idActividadSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.Turno (HoraInicio, HoraFin, DiaDeSemana, IdActividad)
        VALUES ('09:00', '11:00', 2, @idActividadSetup);
        SET @idTurnoSetup = SCOPE_IDENTITY();
        EXEC USP_AltaVenta @IdVisitante=@idVisitanteSetup, @MetodoDePago='Efectivo', @PuntoDeVenta='Boletería', @IdVenta=@idVentaTest1 OUTPUT;
        SET XACT_ABORT OFF;
    END

    -- Test 13: TVP vacío.
    -- Resultado esperado: retorno silencioso sin insertar nada ni lanzar error.
    DECLARE @lineasActividadTest13 Ventas.TVP_LineaActividad; -- sin filas
    EXEC USP_AltaLineasDeEntradaActividad @IdVenta = @idVentaTest1, @Lineas = @lineasActividadTest13;
    PRINT 'Test 13 - OK. TVP vacío no generó error (retorno silencioso esperado).';

    SELECT Test = 13, * FROM Ventas.LineaDeEntradaActividad WHERE IdVenta = @idVentaTest1;
    -- Verificar: 0 filas (las recuperaciones anteriores revirtieron la línea del Test 8).

     -- Test 14: FechaHoraAsistencia fuera del horario de cualquier turno de la actividad
    -- (el turno de @idActividadSetup es Lunes 09:00-11:00; 15:00 queda fuera de rango).
    -- Resultado esperado: error 50000 "Alguna l\xednea de actividad no corresponde a ning\xfan turno."
    BEGIN TRY
        DECLARE @lineasActividadTest14 Ventas.TVP_LineaActividad;
        INSERT INTO @lineasActividadTest14 (IdActividad, Cantidad, FechaHoraAsistencia) VALUES (@idActividadSetup, 1, '20260706 15:00');
        EXEC USP_AltaLineasDeEntradaActividad @IdVenta = @idVentaTest1, @Lineas = @lineasActividadTest14;
        PRINT 'Test 14 - FALLO: deber\xeda haber lanzado un error por fecha/horario sin turno.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 14 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    IF XACT_STATE() = -1  -- Recovery #9
    BEGIN
        ROLLBACK TRANSACTION; BEGIN TRANSACTION;
        INSERT INTO Turismo.Visitante (Telefono, CorreoVisitante, NumeroDocumento, TipoDocumento, CUIT, Edad, Nombre, Apellido)
        VALUES ('1100000001', 'visitante.ventas@gmail.com', '40111222', 'DNI', '20401112220', 30, 'Visitante', 'Ventas');
        SET @idVisitanteSetup = SCOPE_IDENTITY();
        INSERT INTO Parques.Parque (Nombre, HorarioCierre, HorarioApertura, Superficie, CostoHectarea, Provincia, Numero, Localidad, TipoParque)
        VALUES ('Parque Nacional Test Ventas', '18:00', '08:00', 500.00, 700.00, 'Salta', 1, 'Cafayate', 'Parque Nacional');
        SET @idParqueSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.EntradaParque (Costo, FechaAcceso, IdParque) VALUES (800.00, '2026-07-01', @idParqueSetup);
        SET @idEntradaSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.Actividad (Nombre, Tipo, Costo, DuracionMinutos, CupoMaximo, IdParque)
        VALUES ('Kayak Test Ventas', 'Tour', 1500.00, 90, 2, @idParqueSetup);
        SET @idActividadSetup = SCOPE_IDENTITY();
        INSERT INTO Turismo.Turno (HoraInicio, HoraFin, DiaDeSemana, IdActividad) VALUES ('09:00', '11:00', 2, @idActividadSetup);
        SET @idTurnoSetup = SCOPE_IDENTITY();
        EXEC USP_AltaVenta @IdVisitante=@idVisitanteSetup, @MetodoDePago='Efectivo', @PuntoDeVenta='Boleter\xeda', @IdVenta=@idVentaTest1 OUTPUT;
        SET XACT_ABORT OFF;
    END

    -- Test 15: cupo independiente por fecha. El Test 8 llen\xf3 1/2 del turno para 2026-07-06;
    -- ac\xe1 se vende para 2026-07-13 (mismo turno, otra fecha), CupoMaximo=2, no deber\xeda verse
    -- afectado por lo consumido en la otra fecha.
    -- Resultado esperado: inserta sin error y deja el turno en Estado = 'cupo lleno' para esa fecha.
    DECLARE @lineasActividadTest15 Ventas.TVP_LineaActividad;
    INSERT INTO @lineasActividadTest15 (IdActividad, Cantidad, FechaHoraAsistencia) VALUES (@idActividadSetup, 2, '20260713 09:30');
    EXEC USP_AltaLineasDeEntradaActividad @IdVenta = @idVentaTest1, @Lineas = @lineasActividadTest15;
    SET XACT_ABORT OFF;

    SELECT Test = 15, * FROM Ventas.LineaDeEntradaActividad WHERE IdVenta = @idVentaTest1 AND CAST(FechaHoraAsistencia AS DATE) = '2026-07-13';

    -- Test 16: Turno.Estado pasa a 'cupo lleno' tras el Test 15.
    -- Resultado esperado: 1 fila con Estado = 'cupo lleno'.
    SELECT Test = 16, IdTurno, Estado FROM Turismo.Turno WHERE IdTurno = @idTurnoSetup;

    -- Test 17: reventa sobre un turno ya lleno para esa misma fecha (2026-07-13).
    -- Resultado esperado: error 50000 "Alg\xfan turno supera la cantidad de cupos disponibles para la fecha indicada."
    BEGIN TRY
        DECLARE @lineasActividadTest17 Ventas.TVP_LineaActividad;
        INSERT INTO @lineasActividadTest17 (IdActividad, Cantidad, FechaHoraAsistencia) VALUES (@idActividadSetup, 1, '20260713 10:00');
        EXEC USP_AltaLineasDeEntradaActividad @IdVenta = @idVentaTest1, @Lineas = @lineasActividadTest17;
        PRINT 'Test 17 - FALLO: deber\xeda haber lanzado un error por cupo excedido.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 17 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH


    ROLLBACK TRANSACTION;
    PRINT 'Suite completa de Ventas (17 tests) finalizada sin errores inesperados.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    PRINT 'ERROR INESPERADO - se hizo ROLLBACK. Detalle: ' + ERROR_MESSAGE();
END CATCH
GO