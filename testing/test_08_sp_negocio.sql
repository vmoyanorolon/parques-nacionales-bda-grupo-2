-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: Scripts testing para los Stored Procedures de lógica de negocio

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

    -- Setup compartido: estructuras necesarias para los cuatro SPs del archivo.
    DECLARE @idParqueSetup            INT,
            @idEntradaSetup           INT,
            @idActividadTourSetup     INT,
            @idActividadAtraccionSetup INT,
            @idVisitanteSinDesc       INT,
            @idVisitanteConDesc       INT,
            @idTipoVisitanteGeneral   INT,
            @idTipoVisitanteSetup     INT,
            @idGuiaSetup              INT,
            @idGuiaSinParque          INT,
            @idOrgConcesionSetup      INT,
            @idConcesionActiva        INT,
            @idConcesionInactiva      INT,
            @idParqueSinEntradas      INT;

    INSERT INTO Parques.Parque (Nombre, HorarioCierre, HorarioApertura, Superficie, Provincia, Numero, Localidad, TipoParque)
    VALUES ('Parque Nacional Test Negocio', '18:00', '08:00', 5000.00, 'Río Negro', 1, 'Bariloche', 'Parque Nacional');
    SET @idParqueSetup = SCOPE_IDENTITY();

    -- Parque sin entradas, para el test de USP_ActualizarPrecioEntrada.
    INSERT INTO Parques.Parque (Nombre, HorarioCierre, HorarioApertura, Superficie, Provincia, Numero, Localidad, TipoParque)
    VALUES ('Parque Nacional Test Sin Entradas', '18:00', '08:00', 100.00, 'Mendoza', 2, 'Malargüe', 'Parque Nacional');
    SET @idParqueSinEntradas = SCOPE_IDENTITY();

    INSERT INTO Turismo.EntradaParque (Costo, FechaAcceso, IdParque)
    VALUES (1000.00, '2026-07-01', @idParqueSetup);
    SET @idEntradaSetup = SCOPE_IDENTITY();

    -- Actividad de tipo Tour (CupoMaximo generoso para no interferir entre tests).
    INSERT INTO Turismo.Actividad (Nombre, Tipo, Costo, DuracionMinutos, CupoMaximo, IdParque)
    VALUES ('Trekking Test Negocio', 'Tour', 2000.00, 180, 50, @idParqueSetup);
    SET @idActividadTourSetup = SCOPE_IDENTITY();

    -- Actividad de tipo Atracción (para el test de actividad-no-es-Tour).
    INSERT INTO Turismo.Actividad (Nombre, Tipo, Costo, DuracionMinutos, CupoMaximo, IdParque)
    VALUES ('Mirador Test Negocio', 'Atracción', 0.00, 30, 100, @idParqueSetup);
    SET @idActividadAtraccionSetup = SCOPE_IDENTITY();

    -- TipoVisitante sin descuento para el visitante base.
    INSERT INTO Turismo.TipoVisitante (Descripcion, Descuento) VALUES ('General Test Negocio', 0);
    SET @idTipoVisitanteGeneral = SCOPE_IDENTITY();

    -- Visitante con tipo general (0% descuento).
    INSERT INTO Turismo.Visitante (Telefono, CorreoVisitante, NumeroDocumento, TipoDocumento, CUIT, Edad, Nombre, Apellido, IdTipoVisitante)
    VALUES ('1100000001', 'visitante.sindesc@gmail.com', '41111001', 'DNI', '20411110010', 28, 'Sin', 'Descuento', @idTipoVisitanteGeneral);
    SET @idVisitanteSinDesc = SCOPE_IDENTITY();

    -- TipoVisitante con 50% de descuento.
    INSERT INTO Turismo.TipoVisitante (Descripcion, Descuento) VALUES ('Jubilado Test Negocio', 50);
    SET @idTipoVisitanteSetup = SCOPE_IDENTITY();

    -- Visitante con tipo jubilado (50% descuento).
    INSERT INTO Turismo.Visitante (Telefono, CorreoVisitante, NumeroDocumento, TipoDocumento, CUIT, Edad, Nombre, Apellido, IdTipoVisitante)
    VALUES ('1100000002', 'visitante.condesc@gmail.com', '41111002', 'DNI', '20411110020', 68, 'Con', 'Descuento', @idTipoVisitanteSetup);
    SET @idVisitanteConDesc = SCOPE_IDENTITY();

    -- Guía habilitado para trabajar en el parque.
    INSERT INTO Personal.Guia (Telefono, CorreoGuia, NumeroDocumento, TipoDocumento, Edad, Apellido, Nombre, Titulo, Especialidad)
    VALUES ('1100000003', 'guia.negocio@gmail.com', '29111001', 'DNI', 40, 'Martinez', 'Pedro', 'Guía de Montaña', 'Flora');
    SET @idGuiaSetup = SCOPE_IDENTITY();

    INSERT INTO Personal.GuiaTrabajaEnParque (IdGuia, IdParque) VALUES (@idGuiaSetup, @idParqueSetup);

    -- Guía sin registro en el parque (para el test de guia-no-trabaja-en-parque).
    INSERT INTO Personal.Guia (Telefono, CorreoGuia, NumeroDocumento, TipoDocumento, Edad, Apellido, Nombre, Titulo, Especialidad)
    VALUES ('1100000004', 'guia.sinparque@gmail.com', '29111002', 'DNI', 35, 'Gomez', 'Ana', 'Guía de Naturaleza', 'Fauna');
    SET @idGuiaSinParque = SCOPE_IDENTITY();

    -- Organización concesionaria y sus concesiones (activa e inactiva).
    INSERT INTO Concesiones.OrganizacionConcesionaria (Nombre, TipoActividad, Cuit, CorreoContacto)
    VALUES ('Concesionaria Test Negocio', 'Gastronomía', '30999888771', 'concesion@test.com');
    SET @idOrgConcesionSetup = SCOPE_IDENTITY();

    INSERT INTO Concesiones.Concesion (IdParque, IdOrganizacionConcesionaria, CanonMensual, ExtensionConcedida, EstadoConcesion, FechaInicio)
    VALUES (@idParqueSetup, @idOrgConcesionSetup, 5000.00, 50.00, 'Activo', '2026-01-01');
    SET @idConcesionActiva = SCOPE_IDENTITY();

    INSERT INTO Concesiones.Concesion (IdParque, IdOrganizacionConcesionaria, CanonMensual, ExtensionConcedida, EstadoConcesion, FechaInicio)
    VALUES (@idParqueSetup, @idOrgConcesionSetup, 3000.00, 30.00, 'Inactivo', '2025-01-01');
    SET @idConcesionInactiva = SCOPE_IDENTITY();

    ----------------------------------------
    -- USP_RegistrarVentaEntradaMasiva
    ----------------------------------------

    -- Test 1: venta exitosa con solo líneas de parque (sin descuento).
    -- Resultado esperado: inserta la venta con Monto = EntradaParque.Costo * Cantidad = 1000.00 * 2 = 2000.00.
    DECLARE @idVentaTest1 INT;
    DECLARE @lineasParqueTest1 Ventas.TVP_LineaParque;
    DECLARE @lineasActividadVacias Ventas.TVP_LineaActividad; -- TVP vacío reutilizable

    INSERT INTO @lineasParqueTest1 (IdEntradaParque, Cantidad) VALUES (@idEntradaSetup, 2);

    EXEC USP_RegistrarVentaEntradaMasiva
        @IdVisitante     = @idVisitanteSinDesc,
        @MetodoDePago    = 'Efectivo',
        @PuntoDeVenta    = 'Boletería',
        @LineasParque    = @lineasParqueTest1,
        @LineasActividad = @lineasActividadVacias,
        @IdVenta         = @idVentaTest1 OUTPUT;
    SET XACT_ABORT OFF;

    SELECT Test = 1, * FROM Ventas.Venta WHERE IdVenta = @idVentaTest1;
    SELECT Test = 1, * FROM Ventas.LineaDeEntradaParque WHERE IdVenta = @idVentaTest1;

    -- Test 2: venta exitosa con solo líneas de actividad (sin descuento).
    -- Resultado esperado: inserta la venta con Monto = Actividad.Costo * Cantidad = 2000.00 * 1 = 2000.00.
    DECLARE @idVentaTest2 INT;
    DECLARE @lineasParqueVacias Ventas.TVP_LineaParque; -- TVP vacío reutilizable
    DECLARE @lineasActividadTest2 Ventas.TVP_LineaActividad;

    INSERT INTO @lineasActividadTest2 (IdActividad, Cantidad) VALUES (@idActividadTourSetup, 1);

    EXEC USP_RegistrarVentaEntradaMasiva
        @IdVisitante     = @idVisitanteSinDesc,
        @MetodoDePago    = 'Débito',
        @PuntoDeVenta    = 'Online',
        @LineasParque    = @lineasParqueVacias,
        @LineasActividad = @lineasActividadTest2,
        @IdVenta         = @idVentaTest2 OUTPUT;
    SET XACT_ABORT OFF;

    SELECT Test = 2, * FROM Ventas.Venta WHERE IdVenta = @idVentaTest2;

    -- Test 3: venta exitosa con ambas líneas y descuento del 50%.
    -- Resultado esperado: Monto = (1000.00 + 2000.00) * 0.5 = 1500.00.
    DECLARE @idVentaTest3 INT;
    DECLARE @lineasParqueTest3 Ventas.TVP_LineaParque;
    DECLARE @lineasActividadTest3 Ventas.TVP_LineaActividad;

    INSERT INTO @lineasParqueTest3    (IdEntradaParque, Cantidad) VALUES (@idEntradaSetup, 1);
    INSERT INTO @lineasActividadTest3 (IdActividad, Cantidad)     VALUES (@idActividadTourSetup, 1);

    EXEC USP_RegistrarVentaEntradaMasiva
        @IdVisitante     = @idVisitanteConDesc, -- 50% de descuento
        @MetodoDePago    = 'Tarjeta',
        @PuntoDeVenta    = 'Boletería',
        @LineasParque    = @lineasParqueTest3,
        @LineasActividad = @lineasActividadTest3,
        @IdVenta         = @idVentaTest3 OUTPUT;
    SET XACT_ABORT OFF;

    SELECT Test = 3, * FROM Ventas.Venta WHERE IdVenta = @idVentaTest3;
    -- Verificar: Monto = 1500.00 (descuento del 50% aplicado a ambas líneas).

    ----------------------------------------
    -- USP_AsignarGuiaATour
    ----------------------------------------

    -- Test 4: alta exitosa.
    -- Resultado esperado: inserta la habilitación del guía para la actividad Tour.
    EXEC USP_AsignarGuiaATour
        @IdGuia      = @idGuiaSetup,
        @IdActividad = @idActividadTourSetup,
        @DiasVigentes = 365;

    SELECT Test = 4, * FROM Personal.Habilitacion
    WHERE IdGuia = @idGuiaSetup AND IdActividad = @idActividadTourSetup;

    -- Test 5: IdGuia inexistente.
    -- Resultado esperado: error 50000 "El guía indicado no existe."
    BEGIN TRY
        EXEC USP_AsignarGuiaATour @IdGuia = -1, @IdActividad = @idActividadTourSetup, @DiasVigentes = 365;
        PRINT 'Test 5 - FALLO: debería haber lanzado un error por guía inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 5 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 6: DiasVigentes <= 0.
    -- Resultado esperado: error 50000 "Los días vigentes deben ser mayores a 0."
    BEGIN TRY
        EXEC USP_AsignarGuiaATour @IdGuia = @idGuiaSetup, @IdActividad = @idActividadTourSetup, @DiasVigentes = 0;
        PRINT 'Test 6 - FALLO: debería haber lanzado un error por DiasVigentes inválido.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 6 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 7: IdActividad inexistente.
    -- Resultado esperado: error 50000 "La actividad indicada no existe."
    BEGIN TRY
        EXEC USP_AsignarGuiaATour @IdGuia = @idGuiaSetup, @IdActividad = -1, @DiasVigentes = 365;
        PRINT 'Test 7 - FALLO: debería haber lanzado un error por actividad inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 7 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 8: actividad de tipo Atracción (no Tour).
    -- Resultado esperado: error 50000 "La actividad no es de tipo Tour."
    BEGIN TRY
        EXEC USP_AsignarGuiaATour @IdGuia = @idGuiaSetup, @IdActividad = @idActividadAtraccionSetup, @DiasVigentes = 365;
        PRINT 'Test 8 - FALLO: debería haber lanzado un error por actividad no es Tour.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 8 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 9: guía que no trabaja en el parque de la actividad.
    -- Resultado esperado: error 50000 "El guía no trabaja en el parque de esta actividad."
    BEGIN TRY
        EXEC USP_AsignarGuiaATour @IdGuia = @idGuiaSinParque, @IdActividad = @idActividadTourSetup, @DiasVigentes = 365;
        PRINT 'Test 9 - FALLO: debería haber lanzado un error por guía no trabaja en el parque.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 9 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 10: habilitación vigente duplicada para el mismo guía y actividad.
    -- El Test 4 ya creó una habilitación de 365 días; esta sigue vigente.
    -- Resultado esperado: error 50000 "El guía ya tiene una habilitación vigente para esta actividad."
    BEGIN TRY
        EXEC USP_AsignarGuiaATour @IdGuia = @idGuiaSetup, @IdActividad = @idActividadTourSetup, @DiasVigentes = 90;
        PRINT 'Test 10 - FALLO: debería haber lanzado un error por habilitación vigente duplicada.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 10 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- USP_RegistrarPagoConcesion
    ----------------------------------------

    -- Test 11: pago exitoso de una concesión activa.
    -- Resultado esperado: inserta el pago e informa si hay pagos atrasados.
    -- (La concesión inició el 2026-01-01; a la fecha de ejecución pueden
    -- haberse acumulado meses sin pagar — el SP lo calcula y lo imprime).
    EXEC USP_RegistrarPagoConcesion
        @IdConcesion = @idConcesionActiva,
        @Monto       = 5000.00;

    SELECT Test = 11, * FROM Concesiones.PagoConcesion WHERE IdConcesion = @idConcesionActiva;

    -- Test 12: concesión inexistente.
    -- Resultado esperado: error 50000 "La concesión indicada no existe."
    BEGIN TRY
        EXEC USP_RegistrarPagoConcesion @IdConcesion = -1, @Monto = 5000.00;
        PRINT 'Test 12 - FALLO: debería haber lanzado un error por concesión inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 12 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 13: concesión inactiva.
    -- Resultado esperado: error 50000 "La concesión no está activa. No se puede registrar el pago."
    BEGIN TRY
        EXEC USP_RegistrarPagoConcesion @IdConcesion = @idConcesionInactiva, @Monto = 3000.00;
        PRINT 'Test 13 - FALLO: debería haber lanzado un error por concesión inactiva.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 13 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 14: monto <= 0.
    -- Resultado esperado: error 50000 "El monto debe ser mayor a cero."
    BEGIN TRY
        EXEC USP_RegistrarPagoConcesion @IdConcesion = @idConcesionActiva, @Monto = 0.00;
        PRINT 'Test 14 - FALLO: debería haber lanzado un error por monto inválido.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 14 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ----------------------------------------
    -- USP_ActualizarPrecioEntrada
    ----------------------------------------

    -- Test 15: actualización exitosa.
    -- Resultado esperado: todas las EntradaParque del parque cambian a 1200.00.
    EXEC USP_ActualizarPrecioEntrada @IdParque = @idParqueSetup, @NuevoCosto = 1200.00;

    SELECT Test = 15, * FROM Turismo.EntradaParque WHERE IdParque = @idParqueSetup;
    -- Verificar: Costo = 1200.00.

    -- Test 16: parque inexistente.
    -- Resultado esperado: error 50000 "El parque indicado no existe."
    BEGIN TRY
        EXEC USP_ActualizarPrecioEntrada @IdParque = -1, @NuevoCosto = 500.00;
        PRINT 'Test 16 - FALLO: debería haber lanzado un error por parque inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 16 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 17: nuevo costo <= 0.
    -- Resultado esperado: error 50000 "El nuevo costo debe ser mayor a cero."
    BEGIN TRY
        EXEC USP_ActualizarPrecioEntrada @IdParque = @idParqueSetup, @NuevoCosto = 0.00;
        PRINT 'Test 17 - FALLO: debería haber lanzado un error por costo inválido.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 17 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    -- Test 18: parque sin entradas registradas.
    -- Resultado esperado: error 50000 "El parque no tiene entradas registradas para actualizar."
    BEGIN TRY
        EXEC USP_ActualizarPrecioEntrada @IdParque = @idParqueSinEntradas, @NuevoCosto = 800.00;
        PRINT 'Test 18 - FALLO: debería haber lanzado un error por parque sin entradas.';
    END TRY
    BEGIN CATCH
        PRINT 'Test 18 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
    END CATCH

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    PRINT 'ERROR INESPERADO - se hizo ROLLBACK. Detalle: ' + ERROR_MESSAGE();
END CATCH

-- Test 19: IdVisitante inexistente.
-- Resultado esperado: error 50000 "El ID de visitante indicado no existe."
BEGIN TRY
    DECLARE @idVentaTest19 INT;
    DECLARE @lineasParqueTest19 Ventas.TVP_LineaParque;
    INSERT INTO @lineasParqueTest19 (IdEntradaParque, Cantidad) VALUES (1, 1);
    EXEC USP_RegistrarVentaEntradaMasiva
        @IdVisitante     = -1,
        @MetodoDePago    = 'Efectivo',
        @PuntoDeVenta    = 'Boletería',
        @LineasParque    = @lineasParqueTest19,
        @LineasActividad = @lineasActividadVacias,
        @IdVenta         = @idVentaTest19 OUTPUT;
    PRINT 'Test 19 - FALLO: debería haber lanzado un error por visitante inexistente.';
END TRY
BEGIN CATCH
    PRINT 'Test 19 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
END CATCH
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

-- Test 20: ambos TVPs vacíos.
-- Resultado esperado: error 50000 "La venta debe incluir al menos una línea de entrada."
BEGIN TRY
    DECLARE @idVentaTest20 INT;
    DECLARE @lineasParqueVaciasT20   Ventas.TVP_LineaParque;
    DECLARE @lineasActividadVaciasT20 Ventas.TVP_LineaActividad;
    EXEC USP_RegistrarVentaEntradaMasiva
        @IdVisitante     = -1,
        @MetodoDePago    = 'Efectivo',
        @PuntoDeVenta    = 'Boletería',
        @LineasParque    = @lineasParqueVaciasT20,
        @LineasActividad = @lineasActividadVaciasT20,
        @IdVenta         = @idVentaTest20 OUTPUT;
    PRINT 'Test 20 - FALLO: debería haber lanzado un error por TVPs vacíos.';
END TRY
BEGIN CATCH
    PRINT 'Test 20 - OK. Error esperado capturado: ' + ERROR_MESSAGE();
END CATCH
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

GO