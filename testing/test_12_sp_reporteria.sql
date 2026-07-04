-- Universidad: UNLaM
-- Materia: 3641 
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamin Velazquez (46.641.239), Valentin Moyano Rolon (46.292.248)
-- Descripcion: Testing de los SP de reporteria (Entrega 7).

USE ParquesNacionales
GO

SET NOCOUNT ON;
GO

PRINT '=========================================================='
PRINT ' TESTING SP DE REPORTERIA (Entrega 7)'
PRINT '=========================================================='
GO

BEGIN TRANSACTION TestReportes;

----------------------------------------------------------------------
-- SIEMBRA DE DATOS DETERMINISTA
----------------------------------------------------------------------
-- Se crean 2 parques, 1 tipo de visitante, 1 visitante, actividades,
-- entradas, ventas con lineas, una concesion con pagos parciales.
-- Todos los montos y fechas se eligen para que los totales sean faciles de verificar.
----------------------------------------------------------------------
PRINT ''
PRINT '--- Sembrando datos de prueba (se revierten al final) ---'

-- Parques
INSERT INTO Parques.Parque (Nombre, HorarioCierre, HorarioApertura, Superficie, Provincia, Numero, Localidad, TipoParque)
VALUES ('PARQUE_TEST_A', '18:00', '08:00', 1000.00, 'Neuquen', 1, 'LocA', 'Parque Nacional'),
       ('PARQUE_TEST_B', '18:00', '08:00', 2000.00, 'Salta',   2, 'LocB', 'Reserva Nacional');

DECLARE @IdParqueA INT = (SELECT IdParque FROM Parques.Parque WHERE Nombre = 'PARQUE_TEST_A');
DECLARE @IdParqueB INT = (SELECT IdParque FROM Parques.Parque WHERE Nombre = 'PARQUE_TEST_B');

-- Tipo de visitante y visitante
INSERT INTO Turismo.TipoVisitante (Descripcion, Descuento) VALUES ('TEST_General', 0);
DECLARE @IdTipoVis INT = SCOPE_IDENTITY();

INSERT INTO Turismo.Visitante (Telefono, CorreoVisitante, NumeroDocumento, TipoDocumento, CUIT, Edad, Nombre, Apellido, IdTipoVisitante)
VALUES ('123', 'test@test.com', 'DOC_TEST_1', 'DNI', 'CUIT_TEST_1', 30, 'Test', 'Visitante', @IdTipoVis);
DECLARE @IdVisitante INT = SCOPE_IDENTITY();

-- Actividad (tour) en parque A: costo 100
INSERT INTO Turismo.Actividad (Nombre, Tipo, Costo, DuracionMinutos, CupoMaximo, IdParque)
VALUES ('TOUR_TEST_A', 'Tour', 100.00, 60, 20, @IdParqueA);
DECLARE @IdActividadA INT = SCOPE_IDENTITY();

-- Entradas al parque A (2 fechas) y parque B (1 fecha), costo 50 c/u
-- Fechas elegidas en 2026: enero (mes 1) y febrero (mes 2)
INSERT INTO Turismo.EntradaParque (Costo, FechaAcceso, IdParque)
VALUES (50.00, '2026-01-10', @IdParqueA),   -- enero
       (50.00, '2026-02-15', @IdParqueA),   -- febrero
       (50.00, '2026-01-20', @IdParqueB);   -- enero
DECLARE @IdEntA_Ene INT = (SELECT IdEntradaParque FROM Turismo.EntradaParque WHERE IdParque=@IdParqueA AND FechaAcceso='2026-01-10');
DECLARE @IdEntA_Feb INT = (SELECT IdEntradaParque FROM Turismo.EntradaParque WHERE IdParque=@IdParqueA AND FechaAcceso='2026-02-15');
DECLARE @IdEntB_Ene INT = (SELECT IdEntradaParque FROM Turismo.EntradaParque WHERE IdParque=@IdParqueB AND FechaAcceso='2026-01-20');

-- Ventas
INSERT INTO Ventas.Venta (Fecha, Monto, MetodoDePago, PuntoDeVenta, IdVisitante)
VALUES ('2026-01-10', 0, 'Efectivo', 'POS1', @IdVisitante);
DECLARE @IdVenta1 INT = SCOPE_IDENTITY();
INSERT INTO Ventas.Venta (Fecha, Monto, MetodoDePago, PuntoDeVenta, IdVisitante)
VALUES ('2026-02-15', 0, 'Efectivo', 'POS1', @IdVisitante);
DECLARE @IdVenta2 INT = SCOPE_IDENTITY();

-- Lineas de entrada al parque:
--   Parque A enero: 10 entradas x 50 = 500
--   Parque A febrero: 4 entradas x 50 = 200
--   Parque B enero: 6 entradas x 50 = 300
INSERT INTO Ventas.LineaDeEntradaParque (PrecioUnitario, Cantidad, NumeroDeItem, IdVenta, IdEntradaParque)
VALUES (50.00, 10, 1, @IdVenta1, @IdEntA_Ene),
       (50.00,  6, 2, @IdVenta1, @IdEntB_Ene),
       (50.00,  4, 1, @IdVenta2, @IdEntA_Feb);

-- Linea de actividad (tour parque A, enero): 3 x 100 = 300
INSERT INTO Ventas.LineaDeEntradaActividad (PrecioUnitario, Cantidad, NumeroDeItem, FechaHoraAsistencia, IdVenta, IdActividad)
VALUES (100.00, 3, 3, '2026-01-10', @IdVenta1, @IdActividadA);

-- Concesion en parque A: canon 1000/mes, inicio 2026-01-01, activa, con 1 pago hecho
INSERT INTO Concesiones.OrganizacionConcesionaria (Nombre, TipoActividad, Cuit, CorreoContacto)
VALUES ('ORG_TEST', 'Restaurante', '20304050607', 'org@test.com');
DECLARE @IdOrg INT = SCOPE_IDENTITY();

INSERT INTO Concesiones.Concesion (IdParque, IdOrganizacionConcesionaria, CanonMensual, ExtensionConcedida, EstadoConcesion, FechaInicio, FechaFin)
VALUES (@IdParqueA, @IdOrg, 1000.00, 50.00, 'Activo', '2026-01-01', NULL);
DECLARE @IdConcesion INT = SCOPE_IDENTITY();

-- Un unico pago de canon: 1000 en enero
INSERT INTO Concesiones.PagoConcesion (IdConcesion, Fecha, Monto)
VALUES (@IdConcesion, '2026-01-05', 1000.00);

PRINT 'Datos sembrados OK.'
GO

----------------------------------------------------------------------
-- PRUEBA 1: USP_ReporteVisitasPorParque (XML)
----------------------------------------------------------------------
-- Datos: Parque A -> 10 (ene) + 4 (feb) = 14 visitas anuales 2026.
--        Parque B -> 6 (ene)           = 6  visitas anuales 2026.
-- Resultado esperado: XML valido con ROOT('ReporteVisitas'), un nodo <Parque>
-- por cada parque/anio, con TotalAnual=14 para A y 6 para B, y sub-nodos
-- <PorMes> y <PorSemana> con los desgloses.
----------------------------------------------------------------------
PRINT ''
PRINT '--- PRUEBA 1: USP_ReporteVisitasPorParque 2026 ---'
PRINT 'Esperado: XML con PARQUE_TEST_A TotalAnual=14, PARQUE_TEST_B TotalAnual=6.'
EXEC Turismo.USP_ReporteVisitasPorParque 2026;
GO

----------------------------------------------------------------------
-- PRUEBA 2a: USP_ReporteIngresosPorParque - granularidad valida (MES)
----------------------------------------------------------------------
-- Ingresos esperados Parque A:
--   Entradas: ene 10*50=500, feb 4*50=200
--   Tours:    ene 3*100=300
--   Concesiones: pago de 1000 en enero (PagoConcesion.Fecha='2026-01-05')
--   -> Enero A: Entradas=500, Tours=300, Concesiones=1000, Total=1800
--   -> Febrero A: Entradas=200, Tours=0,  Concesiones=0,    Total=200
-- Ingresos esperados Parque B:
--   -> Enero B: Entradas=300, resto 0, Total=300
----------------------------------------------------------------------
PRINT ''
PRINT '--- PRUEBA 2a: USP_ReporteIngresosPorParque MES (valida) ---'
PRINT 'Esperado A ene: Ent=500 Tours=300 Conc=1000 Total=1800 | A feb: Ent=200 Total=200 | B ene: Ent=300 Total=300'
EXEC Ventas.USP_ReporteIngresosPorParque 'MES';
GO

----------------------------------------------------------------------
-- PRUEBA 2b (VALIDACION): granularidad invalida debe fallar
----------------------------------------------------------------------
-- El SP valida @Granularidad IN ('SEMANA','MES','ANIO') y hace RAISERROR.
-- Resultado esperado: error nivel 16 "Granularidad invalida..." y NO retorna filas.
----------------------------------------------------------------------
PRINT ''
PRINT '--- PRUEBA 2b: USP_ReporteIngresosPorParque con valor invalido (debe fallar) ---'
PRINT 'Esperado: RAISERROR "Granularidad invalida. Use SEMANA, MES o ANIO."'
BEGIN TRY
    EXEC Ventas.USP_ReporteIngresosPorParque 'DIARIO';
    PRINT '>> FALLO DE LA PRUEBA: se esperaba un error y no se produjo.'
END TRY
BEGIN CATCH
    PRINT '>> OK: se capturo el error esperado -> ' + ERROR_MESSAGE();
END CATCH
GO

----------------------------------------------------------------------
-- PRUEBA 2c: granularidad ANIO (Periodo debe ser NULL)
----------------------------------------------------------------------
-- Con 'ANIO', el CASE deja Periodo = NULL y agrupa por parque/anio.
-- Esperado A 2026: Entradas=700, Tours=300, Concesiones=1000, Total=2000.
--          B 2026: Entradas=300, Total=300.
----------------------------------------------------------------------
PRINT ''
PRINT '--- PRUEBA 2c: USP_ReporteIngresosPorParque ANIO ---'
PRINT 'Esperado A 2026: Ent=700 Tours=300 Conc=1000 Total=2000 | B 2026: Ent=300 Total=300'
EXEC Ventas.USP_ReporteIngresosPorParque 'ANIO';
GO

----------------------------------------------------------------------
-- PRUEBA 3: USP_ReporteDeudores
----------------------------------------------------------------------
-- Concesion activa, inicio 2026-01-01, sin FechaFin -> meses esperados =
--   DATEDIFF(MONTH, '2026-01-01', HOY) + 1.
-- Pagos realizados: 1 (1000). MontoAdeudado = MesesEsperados*1000 - 1000.
-- Resultado esperado: 1 fila para ORG_TEST con MesesPagados=1 y MesesAtrasados > 0
-- (el numero exacto depende de la fecha de ejecucion, por eso se valida el signo).
-- NOTA: si corres esto en enero 2026, MesesEsperados=1 y MesesAtrasados=0 -> NO
-- apareceria en el reporte (filtro > 0). En cualquier mes posterior debe aparecer.
----------------------------------------------------------------------
PRINT ''
PRINT '--- PRUEBA 3: USP_ReporteDeudores ---'
PRINT 'Esperado: ORG_TEST con MesesPagados=1 y MesesAtrasados>0 (si HOY > ene-2026).'
EXEC Concesiones.USP_ReporteDeudores;
GO

----------------------------------------------------------------------
-- PRUEBA 4: USP_ReporteMatrizVisitas (PIVOT)
----------------------------------------------------------------------
-- Visitas por mes/parque en 2026:
--   PARQUE_TEST_A: Ene=10, Feb=4, resto NULL
--   PARQUE_TEST_B: Ene=6,  resto NULL
-- Resultado esperado: 2 filas, columnas Ene..Dic. Ene(A)=10, Feb(A)=4, Ene(B)=6.
----------------------------------------------------------------------
PRINT ''
PRINT '--- PRUEBA 4: USP_ReporteMatrizVisitas 2026 ---'
PRINT 'Esperado: A -> Ene=10 Feb=4 (resto NULL) | B -> Ene=6 (resto NULL)'
EXEC Turismo.USP_ReporteMatrizVisitas 2026;
GO

----------------------------------------------------------------------
-- PRUEBA 5: USP_ReporteParquesYConcesiones (XML anidado)
----------------------------------------------------------------------
-- Resultado esperado: XML ROOT('ReporteParquesConcesiones') con un <Parque> por
-- cada parque. PARQUE_TEST_A debe contener un nodo <Concesiones> con la concesion
-- de ORG_TEST (Titular=ORG_TEST, ServicioPrestado=Restaurante, CanonMensual=1000,
-- estado=Activo). PARQUE_TEST_B no debe tener concesiones (nodo vacio/ausente).
----------------------------------------------------------------------
PRINT ''
PRINT '--- PRUEBA 5: USP_ReporteParquesYConcesiones ---'
PRINT 'Esperado: XML; PARQUE_TEST_A con concesion ORG_TEST (canon 1000, Activo); B sin concesiones.'
EXEC Parques.USP_ReporteParquesYConcesiones;
GO

----------------------------------------------------------------------
-- REVERSION
----------------------------------------------------------------------
-- Se descartan todos los datos sembrados para no alterar la base.
----------------------------------------------------------------------
PRINT ''
PRINT '--- Revirtiendo datos de prueba (ROLLBACK) ---'
IF @@TRANCOUNT > 0
    ROLLBACK TRANSACTION TestReportes;
PRINT 'Base restaurada al estado previo al testing.'
GO

PRINT ''
PRINT '=========================================================='
PRINT ' FIN TESTING SP DE REPORTERIA'
PRINT '=========================================================='
GO