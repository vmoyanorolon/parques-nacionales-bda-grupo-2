-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Fecha: 04/07/2026
-- Descripción: Script de carga de datos (seed data) para cumplir los Criterios de Aceptación

USE ParquesNacionales
GO

SET NOCOUNT ON
SET XACT_ABORT ON
SET DATEFIRST 7 -- Domingo = 1

--------------------------------------------------------------------------------
-- RUTAS DE ARCHIVOS PARA IMPORTACIÓN (usadas en la sección 9, al final)
-- Se declaran acá arriba de todo para que sea el único lugar a ajustar antes
-- de correr el script en otra máquina. Se guardan en una tabla temporal (y no
-- en variables) porque las variables locales no sobreviven a los GO que
-- separan los lotes del resto del script.
-- IMPORTANTE: las rutas deben ser visibles para el SERVICIO de SQL Server,
-- no solo para la máquina/cliente desde donde se lanza el script.
--------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#RutasImportacion') IS NOT NULL DROP TABLE #RutasImportacion
CREATE TABLE #RutasImportacion (Clave VARCHAR(20) PRIMARY KEY, Ruta VARCHAR(2048) NOT NULL)

INSERT INTO #RutasImportacion (Clave, Ruta) VALUES
    ('Parques',     ''),
    ('Concesiones', ''),
    ('Guias',       '')

IF EXISTS (SELECT 1 FROM #RutasImportacion WHERE ISNULL(LTRIM(RTRIM(Ruta)), '') = '')
BEGIN
    ;THROW 50000, 'Definir las 3 rutas de archivos de importación (Parques, Concesiones, Guías) en #RutasImportacion antes de continuar la ejecución.', 1
END

-- Destrabar cualquier transacción abierta de una ejecución anterior fallida
IF @@TRANCOUNT > 0
BEGIN
    PRINT 'Se detectó una transacción abierta de una ejecución anterior. Se hace ROLLBACK antes de continuar.'
    WHILE @@TRANCOUNT > 0
        ROLLBACK TRANSACTION
END
GO

USE ParquesNacionales
GO

PRINT '=============================================================='
PRINT ' SEED DATA - Sistema de Gestión de Parques Nacionales - Grupo 2'
PRINT '=============================================================='
GO

--------------------------------------------------------------------------------
-- 0) LIMPIEZA INICIAL
-- Deja la base en el mismo estado que una BD recién creada, para que el script
-- sea re-ejecutable sin depender de un DROP/CREATE manual de la base.
-- Orden de borrado: hijos antes que padres (respetando las FKs de 02_tablas.sql).
--------------------------------------------------------------------------------

PRINT 'Limpiando datos de una ejecución anterior...'

DELETE FROM Ventas.LineaDeEntradaActividad
DELETE FROM Ventas.LineaDeEntradaParque
DELETE FROM Ventas.Venta

DELETE FROM Personal.Habilitacion
DELETE FROM Personal.GuiaTrabajaEnParque
DELETE FROM Personal.Asignacion

DELETE FROM Turismo.EntradaParque
DELETE FROM Turismo.Turno
DELETE FROM Turismo.Actividad

DELETE FROM Concesiones.PagoConcesion
DELETE FROM Concesiones.Concesion
DELETE FROM Concesiones.LogImportacionConcesionaria

DELETE FROM Parques.LogImportacionParque
DELETE FROM Personal.LogImportacionGuia

DELETE FROM Turismo.Visitante
DELETE FROM Turismo.TipoVisitante

DELETE FROM Personal.Guia
DELETE FROM Personal.Guardaparque
DELETE FROM Concesiones.OrganizacionConcesionaria
DELETE FROM Parques.Parque
PRINT 'Limpieza finalizada. Arrancando carga desde cero.'
GO

--------------------------------------------------------------------------------
-- 1) PARQUES
--------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#Parques') IS NOT NULL DROP TABLE #Parques
CREATE TABLE #Parques (Orden INT PRIMARY KEY, IdParque INT NOT NULL, Nombre VARCHAR(100), Superficie DECIMAL(10,2))
GO

DECLARE @IdParque INT

EXEC USP_AltaParque 'Parque Nacional Iguazú', '18:00', '08:00', 67620.00, 500.00, 'Misiones', 1, 'Puerto Iguazú', 'Parque Nacional', @IdParque = @IdParque OUTPUT
INSERT INTO #Parques VALUES (1, @IdParque, 'Parque Nacional Iguazú', 67620.00)

EXEC USP_AltaParque 'Parque Nacional Nahuel Huapi', '19:00', '08:00', 717261.00, 500.00, 'Río Negro', 2, 'San Carlos de Bariloche', 'Parque Nacional', @IdParque = @IdParque OUTPUT
INSERT INTO #Parques VALUES (2, @IdParque, 'Parque Nacional Nahuel Huapi', 717261.00)

EXEC USP_AltaParque 'Parque Nacional Los Glaciares', '18:00', '08:00', 726927.00, 500.00, 'Santa Cruz', 3, 'El Calafate', 'Parque Nacional', @IdParque = @IdParque OUTPUT
INSERT INTO #Parques VALUES (3, @IdParque, 'Parque Nacional Los Glaciares', 726927.00)

EXEC USP_AltaParque 'Monumento Natural Talampaya', '17:00', '08:00', 215000.00, 500.00, 'La Rioja', 4, 'Villa Unión', 'Monumento Natural', @IdParque = @IdParque OUTPUT
INSERT INTO #Parques VALUES (4, @IdParque, 'Monumento Natural Talampaya', 215000.00)

EXEC USP_AltaParque 'Parque Nacional El Palmar', '18:00', '08:00', 8500.00, 500.00, 'Entre Ríos', 5, 'Colón', 'Parque Nacional', @IdParque = @IdParque OUTPUT
INSERT INTO #Parques VALUES (5, @IdParque, 'Parque Nacional El Palmar', 8500.00)

EXEC USP_AltaParque 'Parque Nacional Lanín', '18:00', '08:00', 412013.00, 500.00, 'Neuquén', 6, 'San Martín de los Andes', 'Parque Nacional', @IdParque = @IdParque OUTPUT
INSERT INTO #Parques VALUES (6, @IdParque, 'Parque Nacional Lanín', 412013.00)

EXEC USP_AltaParque 'Parque Nacional Los Alerces', '18:00', '08:00', 263000.00, 500.00, 'Chubut', 7, 'Esquel', 'Parque Nacional', @IdParque = @IdParque OUTPUT
INSERT INTO #Parques VALUES (7, @IdParque, 'Parque Nacional Los Alerces', 263000.00)

EXEC USP_AltaParque 'Parque Nacional Calilegua', '17:00', '07:00', 76320.00, 500.00, 'Jujuy', 8, 'Libertador General San Martín', 'Parque Nacional', @IdParque = @IdParque OUTPUT
INSERT INTO #Parques VALUES (8, @IdParque, 'Parque Nacional Calilegua', 76320.00)

EXEC USP_AltaParque 'Parque Nacional Tierra del Fuego', '19:00', '09:00', 68909.00, 500.00, 'Tierra del Fuego', 9, 'Ushuaia', 'Parque Nacional', @IdParque = @IdParque OUTPUT
INSERT INTO #Parques VALUES (9, @IdParque, 'Parque Nacional Tierra del Fuego', 68909.00)

EXEC USP_AltaParque 'Parque Nacional Chaco', '17:00', '07:00', 15000.00, 500.00, 'Chaco', 10, 'Capitán Solari', 'Parque Nacional', @IdParque = @IdParque OUTPUT
INSERT INTO #Parques VALUES (10, @IdParque, 'Parque Nacional Chaco', 15000.00)

EXEC USP_AltaParque 'Parque Nacional Sierra de las Quijadas', '18:00', '08:00', 150000.00, 500.00, 'San Luis', 11, 'Hualtarán', 'Parque Nacional', @IdParque = @IdParque OUTPUT
INSERT INTO #Parques VALUES (11, @IdParque, 'Parque Nacional Sierra de las Quijadas', 150000.00)

EXEC USP_AltaParque 'Reserva Nacional Baritú', '17:00', '07:00', 72439.00, 500.00, 'Salta', 12, 'Los Toldos', 'Reserva Nacional', @IdParque = @IdParque OUTPUT
INSERT INTO #Parques VALUES (12, @IdParque, 'Reserva Nacional Baritú', 72439.00)

DECLARE @CantParques VARCHAR(10) = CAST((SELECT COUNT(*) FROM #Parques) AS VARCHAR)
PRINT 'Parques cargados: ' + @CantParques
GO

--------------------------------------------------------------------------------
-- 2) TIPOS DE VISITANTE Y VISITANTES
--------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#TiposVisitante') IS NOT NULL DROP TABLE #TiposVisitante
CREATE TABLE #TiposVisitante (Descripcion VARCHAR(50) PRIMARY KEY, IdTipoVisitante INT NOT NULL)
GO

DECLARE @IdTipoVisitante INT

EXEC USP_AltaTipoVisitante 'Residente', 20
SELECT @IdTipoVisitante = CAST(IDENT_CURRENT('Turismo.TipoVisitante') AS INT)
INSERT INTO #TiposVisitante VALUES ('Residente', @IdTipoVisitante)

EXEC USP_AltaTipoVisitante 'Extranjero', 0
SELECT @IdTipoVisitante = CAST(IDENT_CURRENT('Turismo.TipoVisitante') AS INT)
INSERT INTO #TiposVisitante VALUES ('Extranjero', @IdTipoVisitante)

EXEC USP_AltaTipoVisitante 'Estudiante', 30
SELECT @IdTipoVisitante = CAST(IDENT_CURRENT('Turismo.TipoVisitante') AS INT)
INSERT INTO #TiposVisitante VALUES ('Estudiante', @IdTipoVisitante)

EXEC USP_AltaTipoVisitante 'Jubilado', 40
SELECT @IdTipoVisitante = CAST(IDENT_CURRENT('Turismo.TipoVisitante') AS INT)
INSERT INTO #TiposVisitante VALUES ('Jubilado', @IdTipoVisitante)

DECLARE @CantTipos VARCHAR(10) = CAST((SELECT COUNT(*) FROM #TiposVisitante) AS VARCHAR)
PRINT 'Tipos de visitante cargados: ' + @CantTipos
GO

IF OBJECT_ID('tempdb..#Visitantes') IS NOT NULL DROP TABLE #Visitantes
CREATE TABLE #Visitantes (Orden INT PRIMARY KEY, IdVisitante INT NOT NULL)
GO

DECLARE @i INT = 1
DECLARE @IdVisitante INT
DECLARE @IdsTipoVisitante TABLE (Pos INT IDENTITY(1,1), IdTipoVisitante INT)
INSERT INTO @IdsTipoVisitante (IdTipoVisitante) SELECT IdTipoVisitante FROM #TiposVisitante ORDER BY Descripcion

WHILE @i <= 30
BEGIN
    DECLARE @IdTipoVisitanteRot INT = (SELECT IdTipoVisitante FROM @IdsTipoVisitante WHERE Pos = ((@i - 1) % 4) + 1)
    DECLARE @Doc VARCHAR(15) = CAST(20000000 + @i AS VARCHAR)
    DECLARE @Cuit VARCHAR(15) = '20' + CAST(30000000 + @i AS VARCHAR) + '0'
    DECLARE @Tel VARCHAR(20) = '1140000' + RIGHT('000' + CAST(@i AS VARCHAR), 3)
    DECLARE @Mail VARCHAR(100) = 'visitante' + CAST(@i AS VARCHAR) + '@mail.com'
    DECLARE @Nom VARCHAR(50) = 'Visitante' + CAST(@i AS VARCHAR)
    DECLARE @Ape VARCHAR(50) = 'ApellidoV' + CAST(@i AS VARCHAR)
    DECLARE @EdadInt INT = 18 + (@i % 60)

    EXEC USP_AltaVisitante
        @Telefono = @Tel,
        @CorreoVisitante = @Mail,
        @NumeroDocumento = @Doc,
        @TipoDocumento = 'DNI',
        @CUIT = @Cuit,
        @Edad = @EdadInt,
        @Nombre = @Nom,
        @Apellido = @Ape,
        @IdTipoVisitante = @IdTipoVisitanteRot

    SELECT @IdVisitante = CAST(IDENT_CURRENT('Turismo.Visitante') AS INT)
    INSERT INTO #Visitantes VALUES (@i, @IdVisitante)

    SET @i += 1
END

DECLARE @CantVis VARCHAR(10) = CAST((SELECT COUNT(*) FROM #Visitantes) AS VARCHAR)
PRINT 'Visitantes cargados: ' + @CantVis
GO

--------------------------------------------------------------------------------
-- 3) ACTIVIDADES Y TURNOS
--------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#Actividades') IS NOT NULL DROP TABLE #Actividades
CREATE TABLE #Actividades (Clave VARCHAR(50) PRIMARY KEY, IdActividad INT NOT NULL, IdParque INT NOT NULL, Tipo VARCHAR(9))

IF OBJECT_ID('tempdb..#Turnos') IS NOT NULL DROP TABLE #Turnos
CREATE TABLE #Turnos (IdTurno INT PRIMARY KEY, IdActividad INT NOT NULL, DiaDeSemana TINYINT, HoraInicio TIME, HoraFin TIME)
GO

DECLARE @IdActividad INT, @IdTurno INT, @IdParqueIguazu INT
SELECT @IdParqueIguazu = IdParque FROM #Parques WHERE Orden = 1

-- --- Iguazú: 4 actividades SIMULTÁNEAS ---------------------
EXEC USP_AltaActividad 'Cataratas - Circuito Superior', 5000.00, 120, 'Atracción', 200, @IdParqueIguazu
SELECT @IdActividad = CAST(IDENT_CURRENT('Turismo.Actividad') AS INT)
INSERT INTO #Actividades VALUES ('IGUAZU_SIMUL_1', @IdActividad, @IdParqueIguazu, 'Atracción')
EXEC USP_AltaTurno @IdActividad, '10:00', '12:00', 7 
SELECT @IdTurno = CAST(IDENT_CURRENT('Turismo.Turno') AS INT)
INSERT INTO #Turnos VALUES (@IdTurno, @IdActividad, 7, '10:00', '12:00')

EXEC USP_AltaActividad 'Cataratas - Circuito Inferior', 4500.00, 90, 'Atracción', 200, @IdParqueIguazu
SELECT @IdActividad = CAST(IDENT_CURRENT('Turismo.Actividad') AS INT)
INSERT INTO #Actividades VALUES ('IGUAZU_SIMUL_2', @IdActividad, @IdParqueIguazu, 'Atracción')
EXEC USP_AltaTurno @IdActividad, '10:00', '12:00', 7
SELECT @IdTurno = CAST(IDENT_CURRENT('Turismo.Turno') AS INT)
INSERT INTO #Turnos VALUES (@IdTurno, @IdActividad, 7, '10:00', '12:00')

EXEC USP_AltaActividad 'Tren Ecológico de la Selva', 2000.00, 20, 'Atracción', 100, @IdParqueIguazu
SELECT @IdActividad = CAST(IDENT_CURRENT('Turismo.Actividad') AS INT)
INSERT INTO #Actividades VALUES ('IGUAZU_SIMUL_3', @IdActividad, @IdParqueIguazu, 'Atracción')
EXEC USP_AltaTurno @IdActividad, '10:00', '12:00', 7
SELECT @IdTurno = CAST(IDENT_CURRENT('Turismo.Turno') AS INT)
INSERT INTO #Turnos VALUES (@IdTurno, @IdActividad, 7, '10:00', '12:00')

EXEC USP_AltaActividad 'Avistaje Nocturno de Fauna', 9000.00, 150, 'Tour', 12, @IdParqueIguazu
SELECT @IdActividad = CAST(IDENT_CURRENT('Turismo.Actividad') AS INT)
INSERT INTO #Actividades VALUES ('IGUAZU_SIMUL_4', @IdActividad, @IdParqueIguazu, 'Tour')
EXEC USP_AltaTurno @IdActividad, '10:00', '12:00', 7
SELECT @IdTurno = CAST(IDENT_CURRENT('Turismo.Turno') AS INT)
INSERT INTO #Turnos VALUES (@IdTurno, @IdActividad, 7, '10:00', '12:00')

EXEC USP_AltaActividad 'Paseo Náutico Gran Aventura', 12000.00, 60, 'Tour', 30, @IdParqueIguazu
SELECT @IdActividad = CAST(IDENT_CURRENT('Turismo.Actividad') AS INT)
INSERT INTO #Actividades VALUES ('IGUAZU_5', @IdActividad, @IdParqueIguazu, 'Tour')
EXEC USP_AltaTurno @IdActividad, '09:00', '10:00', 1 
SELECT @IdTurno = CAST(IDENT_CURRENT('Turismo.Turno') AS INT)
INSERT INTO #Turnos VALUES (@IdTurno, @IdActividad, 1, '09:00', '10:00')

EXEC USP_AltaActividad 'Sendero Macuco', 8000.00, 180, 'Tour', 15, @IdParqueIguazu
SELECT @IdActividad = CAST(IDENT_CURRENT('Turismo.Actividad') AS INT)
INSERT INTO #Actividades VALUES ('IGUAZU_6', @IdActividad, @IdParqueIguazu, 'Tour')
EXEC USP_AltaTurno @IdActividad, '08:00', '11:00', 3 
SELECT @IdTurno = CAST(IDENT_CURRENT('Turismo.Turno') AS INT)
INSERT INTO #Turnos VALUES (@IdTurno, @IdActividad, 3, '08:00', '11:00')

PRINT 'Actividades de Iguazú cargadas (con el caso de simultaneidad).'
GO

-- --- Resto de parques: 3 actividades c/u -------------------------------
DECLARE @IdParqueActual INT, @NombreParqueActual VARCHAR(100), @OrdenParque INT = 2
DECLARE @j INT

WHILE @OrdenParque <= 12
BEGIN
    SELECT @IdParqueActual = IdParque, @NombreParqueActual = Nombre FROM #Parques WHERE Orden = @OrdenParque

    SET @j = 1
    WHILE @j <= 3
    BEGIN
        DECLARE @NombreActividad VARCHAR(50), @TipoActividad VARCHAR(9), @CupoActividad INT
        DECLARE @CostoActividad DECIMAL(10,2), @DuracionActividad INT, @DiaTurno TINYINT
        DECLARE @HoraInicioTurno TIME = '09:00', @HoraFinTurno TIME = '11:00', @ClaveActidad VARCHAR(50)

        SET @NombreActividad = LEFT('Actividad ' + CAST(@j AS VARCHAR) + ' - ' + @NombreParqueActual, 50)
        SET @TipoActividad = CASE WHEN @j = 2 THEN 'Tour' ELSE 'Atracción' END
        SET @CupoActividad = CASE WHEN @OrdenParque = 2 AND @j = 2 THEN 4 ELSE 20 + (@OrdenParque * @j) END
        SET @CostoActividad = 1000.00 + (@OrdenParque * 100) + (@j * 500)
        SET @DuracionActividad = 60 + (@j * 30)
        SET @DiaTurno = ((@OrdenParque + @j) % 7) + 1
        SET @ClaveActidad = CASE WHEN @OrdenParque = 2 AND @j = 2 THEN 'TOUR_CUPO_COMPLETO' ELSE 'P' + CAST(@OrdenParque AS VARCHAR) + '_A' + CAST(@j AS VARCHAR) END

        EXEC USP_AltaActividad @NombreActividad, @CostoActividad, @DuracionActividad, @TipoActividad, @CupoActividad, @IdParqueActual
        DECLARE @IdActividadNueva INT = CAST(IDENT_CURRENT('Turismo.Actividad') AS INT)

        INSERT INTO #Actividades VALUES (@ClaveActidad, @IdActividadNueva, @IdParqueActual, @TipoActividad)

        EXEC USP_AltaTurno @IdActividadNueva, @HoraInicioTurno, @HoraFinTurno, @DiaTurno
        DECLARE @IdTurnoNuevo INT = CAST(IDENT_CURRENT('Turismo.Turno') AS INT)
        INSERT INTO #Turnos VALUES (@IdTurnoNuevo, @IdActividadNueva, @DiaTurno, @HoraInicioTurno, @HoraFinTurno)

        SET @j += 1
    END

    SET @OrdenParque += 1
END

DECLARE @CantAct VARCHAR(10) = CAST((SELECT COUNT(*) FROM #Actividades) AS VARCHAR)
PRINT 'Total de actividades cargadas: ' + @CantAct
GO

--------------------------------------------------------------------------------
-- 4) ENTRADAS A PARQUE
--------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#EntradasParque') IS NOT NULL DROP TABLE #EntradasParque
CREATE TABLE #EntradasParque (IdEntradaParque INT PRIMARY KEY, IdParque INT NOT NULL, FechaAcceso DATE NOT NULL)
GO

DECLARE @OrdenEP INT = 1, @IdParqueEP INT, @k INT
DECLARE @IdEntradaParqueNueva INT

WHILE @OrdenEP <= 12
BEGIN
    SELECT @IdParqueEP = IdParque FROM #Parques WHERE Orden = @OrdenEP

    SET @k = 0
    WHILE @k <= 3
    BEGIN
        DECLARE @FechaAccesoEP DATE = DATEADD(DAY, -1 * (@k * 15), CAST(GETDATE() AS DATE))
        DECLARE @CostoEP DECIMAL(10,2) = 3000.00 + (@OrdenEP * 100)

        EXEC USP_AltaEntradaParque @CostoEP, @FechaAccesoEP, @IdParqueEP
        SELECT @IdEntradaParqueNueva = CAST(IDENT_CURRENT('Turismo.EntradaParque') AS INT)
        INSERT INTO #EntradasParque VALUES (@IdEntradaParqueNueva, @IdParqueEP, @FechaAccesoEP)

        SET @k += 1
    END

    SET @OrdenEP += 1
END

DECLARE @CantEnt VARCHAR(10) = CAST((SELECT COUNT(*) FROM #EntradasParque) AS VARCHAR)
PRINT 'Entradas a parque cargadas: ' + @CantEnt
GO

--------------------------------------------------------------------------------
-- 5) PERSONAL: GUÍAS
--------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#Guias') IS NOT NULL DROP TABLE #Guias
CREATE TABLE #Guias (Orden INT PRIMARY KEY, IdGuia INT NOT NULL)
GO

DECLARE @g INT = 1
DECLARE @IdGuiaNuevo INT
DECLARE @Especialidades TABLE (Pos INT IDENTITY(1,1), Nombre VARCHAR(50))
INSERT INTO @Especialidades (Nombre) VALUES ('Trekking'), ('Fauna Silvestre'), ('Flora Autóctona'), ('Historia Regional'), ('Navegación')

-- Contar tours de antemano para evitar división por cero si algo falla
DECLARE @CantToursDisponibles INT = (SELECT COUNT(*) FROM #Actividades WHERE Tipo = 'Tour')
IF ISNULL(@CantToursDisponibles, 0) = 0
    THROW 50000, 'No hay actividades de tipo Tour cargadas en #Actividades: revisar la carga de PARQUES/ACTIVIDADES antes de continuar.', 1

WHILE @g <= 22
BEGIN
    DECLARE @EspecialidadGuia VARCHAR(50) = (SELECT Nombre FROM @Especialidades WHERE Pos = ((@g - 1) % 5) + 1)
    DECLARE @TelG VARCHAR(20) = '1150000' + RIGHT('000' + CAST(@g AS VARCHAR), 3)
    DECLARE @MailG VARCHAR(100) = 'guia' + CAST(@g AS VARCHAR) + '@parquesnacionales.gob.ar'
    DECLARE @DocG VARCHAR(15) = CAST(31000000 + @g AS VARCHAR)
    DECLARE @EdadG INT = 25 + (@g % 40)
    DECLARE @ApeG VARCHAR(50) = 'ApellidoG' + CAST(@g AS VARCHAR)
    DECLARE @NomG VARCHAR(50) = 'Guia' + CAST(@g AS VARCHAR)

    EXEC USP_AltaGuia
        @Telefono = @TelG,
        @CorreoGuia = @MailG,
        @NumeroDocumento = @DocG,
        @TipoDocumento = 'DNI',
        @Edad = @EdadG,
        @Apellido = @ApeG,
        @Nombre = @NomG,
        @Titulo = 'Guía Nacional de Turismo',
        @Especialidad = @EspecialidadGuia

    SELECT @IdGuiaNuevo = CAST(IDENT_CURRENT('Personal.Guia') AS INT)
    INSERT INTO #Guias VALUES (@g, @IdGuiaNuevo)

    -- Rotación de actividades tipo Tour segura
    DECLARE @IdActividadTourRot INT, @DiasVigentesHab INT = 365
    DECLARE @PosRot INT = ((@g - 1) % @CantToursDisponibles) + 1
    
    SELECT @IdActividadTourRot = IdActividad
    FROM (SELECT IdActividad, ROW_NUMBER() OVER (ORDER BY IdActividad) AS Pos FROM #Actividades WHERE Tipo = 'Tour') t
    WHERE Pos = @PosRot

    EXEC USP_AltaHabilitacion @IdGuiaNuevo, @IdActividadTourRot, @DiasVigentesHab

    SET @g += 1
END

DECLARE @CantGuias VARCHAR(10) = CAST((SELECT COUNT(*) FROM #Guias) AS VARCHAR)
PRINT 'Guías cargados: ' + @CantGuias
GO

--------------------------------------------------------------------------------
-- 6) PERSONAL: GUARDAPARQUES
--------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#Guardaparques') IS NOT NULL DROP TABLE #Guardaparques
CREATE TABLE #Guardaparques (Orden INT PRIMARY KEY, IdGuardaparque INT NOT NULL)
GO

DECLARE @gp INT = 1
DECLARE @IdGuardaparqueNuevo INT

WHILE @gp <= 22
BEGIN
    DECLARE @TelGP VARCHAR(20) = '1160000' + RIGHT('000' + CAST(@gp AS VARCHAR), 3)
    DECLARE @MailGP VARCHAR(100) = 'guardaparque' + CAST(@gp AS VARCHAR) + '@parquesnacionales.gob.ar'
    DECLARE @DocGP VARCHAR(15) = CAST(32000000 + @gp AS VARCHAR)
    DECLARE @EdadGP INT = 22 + (@gp % 35)
    DECLARE @ApeGP VARCHAR(50) = 'ApellidoGP' + CAST(@gp AS VARCHAR)
    DECLARE @NomGP VARCHAR(50) = 'Guardaparque' + CAST(@gp AS VARCHAR)

    EXEC USP_AltaGuardaparque
        @Telefono = @TelGP,
        @CorreoGuardaparque = @MailGP,
        @NumeroDocumento = @DocGP,
        @TipoDocumento = 'DNI',
        @Edad = @EdadGP,
        @Apellido = @ApeGP,
        @Nombre = @NomGP,
        @Estado = 'Activo'

    SELECT @IdGuardaparqueNuevo = CAST(IDENT_CURRENT('Personal.Guardaparque') AS INT)
    INSERT INTO #Guardaparques VALUES (@gp, @IdGuardaparqueNuevo)

    DECLARE @IdParqueRotGP INT = (SELECT IdParque FROM #Parques WHERE Orden = ((@gp - 1) % 12) + 1)
    DECLARE @IdAsignacionNueva INT

    IF @gp <= 3
    BEGIN
        DECLARE @IdParqueAnterior INT = (SELECT IdParque FROM #Parques WHERE Orden = (@gp % 12) + 1)

        EXEC USP_AltaAsignacion
            @FechaIngreso = '2023-01-15',
            @FechaEgreso = NULL,
            @Motivo = NULL,
            @IdParque = @IdParqueAnterior,
            @IdGuardaparque = @IdGuardaparqueNuevo
        SELECT @IdAsignacionNueva = CAST(IDENT_CURRENT('Personal.Asignacion') AS INT)

        EXEC USP_ModificacionAsignacion @IdAsignacionNueva, 'Reasignación por necesidad operativa del área'

        EXEC USP_AltaAsignacion
            @FechaIngreso = '2024-03-01',
            @FechaEgreso = NULL,
            @Motivo = NULL,
            @IdParque = @IdParqueRotGP,
            @IdGuardaparque = @IdGuardaparqueNuevo
    END
    ELSE
    BEGIN
        EXEC USP_AltaAsignacion
            @FechaIngreso = '2023-06-01',
            @FechaEgreso = NULL,
            @Motivo = NULL,
            @IdParque = @IdParqueRotGP,
            @IdGuardaparque = @IdGuardaparqueNuevo
    END

    SET @gp += 1
END

DECLARE @CantGP VARCHAR(10) = CAST((SELECT COUNT(*) FROM #Guardaparques) AS VARCHAR)
PRINT 'Guardaparques cargados: ' + @CantGP
GO

--------------------------------------------------------------------------------
-- 7) CONCESIONES
--------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#Organizaciones') IS NOT NULL DROP TABLE #Organizaciones
CREATE TABLE #Organizaciones (Orden INT PRIMARY KEY, IdOrganizacionConcesionaria INT NOT NULL)

IF OBJECT_ID('tempdb..#Concesiones') IS NOT NULL DROP TABLE #Concesiones
CREATE TABLE #Concesiones (Orden INT PRIMARY KEY, IdConcesion INT NOT NULL, IdParque INT NOT NULL)
GO

DECLARE @c INT = 1
DECLARE @IdOrganizacionNueva INT

WHILE @c <= 12
BEGIN
    DECLARE @CuitOrg CHAR(11) = CAST(30500000000 + @c AS CHAR(11))
    DECLARE @TipoActividadOrg VARCHAR(50) = CASE WHEN @c % 2 = 0 THEN 'Gastronomía' ELSE 'Turismo Aventura' END
    DECLARE @NomOrg VARCHAR(100) = 'Concesionaria ' + CAST(@c AS VARCHAR) + ' S.A.'
    DECLARE @MailOrg VARCHAR(100) = 'contacto' + CAST(@c AS VARCHAR) + '@concesionaria.com.ar'
    DECLARE @TelOrg VARCHAR(20) = '1170000' + RIGHT('000' + CAST(@c AS VARCHAR), 3)
    DECLARE @DomOrg VARCHAR(100) = 'Av. Siempre Viva ' + CAST(100 + @c AS VARCHAR)

    EXEC USP_AltaOrganizacionConcesionaria
        @Nombre = @NomOrg,
        @TipoActividad = @TipoActividadOrg,
        @Cuit = @CuitOrg,
        @CorreoContacto = @MailOrg,
        @TelefonoContacto = @TelOrg,
        @DomicilioRegistrado = @DomOrg

    SELECT @IdOrganizacionNueva = CAST(IDENT_CURRENT('Concesiones.OrganizacionConcesionaria') AS INT)
    INSERT INTO #Organizaciones VALUES (@c, @IdOrganizacionNueva)

    DECLARE @IdParqueConcesion INT = (SELECT IdParque FROM #Parques WHERE Orden = @c)
    DECLARE @SuperficieParqueConcesion DECIMAL(10,2) = (SELECT Superficie FROM #Parques WHERE Orden = @c)
    DECLARE @ExtensionOtorgada DECIMAL(10,2) = @SuperficieParqueConcesion * 0.01
    DECLARE @CanonM DECIMAL(10,2) = 50000.00 + (@c * 1000)

    EXEC USP_AltaConcesion
        @IdParque = @IdParqueConcesion,
        @IdOrganizacionConcesionaria = @IdOrganizacionNueva,
        @CanonMensual = @CanonM,
        @ExtensionConcedida = @ExtensionOtorgada,
        @FechaInicio = '2024-01-01'

    DECLARE @IdConcesionNueva INT = CAST(IDENT_CURRENT('Concesiones.Concesion') AS INT)
    INSERT INTO #Concesiones VALUES (@c, @IdConcesionNueva, @IdParqueConcesion)

    EXEC USP_AltaPagoConcesion @IdConcesion = @IdConcesionNueva, @Fecha = '2024-01-10'

    SET @c += 1
END

DECLARE @IdConcesionVencida INT = (SELECT IdConcesion FROM #Concesiones WHERE Orden = 2)
EXEC USP_BajaConcesion @IdConcesionVencida

DECLARE @CantOrg VARCHAR(10) = CAST((SELECT COUNT(*) FROM #Organizaciones) AS VARCHAR)
DECLARE @CantConc VARCHAR(10) = CAST((SELECT COUNT(*) FROM #Concesiones) AS VARCHAR)
PRINT 'Organizaciones concesionarias cargadas: ' + @CantOrg
PRINT 'Concesiones cargadas: ' + @CantConc
GO

--------------------------------------------------------------------------------
-- 8) HISTORIAL DE VENTAS DE ENTRADAS
--------------------------------------------------------------------------------

DECLARE @IdVentaNueva INT

-- --- 8.a) Historial general: ventas de entrada a parque -----------------------
DECLARE @v INT = 1
WHILE @v <= 40
BEGIN
    DECLARE @OrdenEntrada INT = ((@v - 1) % 48) + 1
    DECLARE @IdEntradaParqueVenta INT, @FechaEntradaVenta DATE
    
    SELECT @IdEntradaParqueVenta = IdEntradaParque, @FechaEntradaVenta = FechaAcceso
    FROM (SELECT IdEntradaParque, FechaAcceso, ROW_NUMBER() OVER (ORDER BY IdEntradaParque) AS Pos FROM #EntradasParque) e
    WHERE Pos = @OrdenEntrada

    DECLARE @IdVisitanteVenta INT = (SELECT IdVisitante FROM #Visitantes WHERE Orden = ((@v - 1) % 30) + 1)
    DECLARE @MetodoPagoVenta VARCHAR(20) = (SELECT valor FROM (VALUES (1,'Efectivo'),(2,'Tarjeta de Débito'),(3,'Tarjeta de Crédito'),(4,'Transferencia')) AS t(pos,valor) WHERE pos = ((@v - 1) % 4) + 1)
    DECLARE @PuntoVentaVenta VARCHAR(20) = (SELECT valor FROM (VALUES (1,'Boletería Central'),(2,'Online'),(3,'Boletería Norte')) AS t(pos,valor) WHERE pos = ((@v - 1) % 3) + 1)

    DECLARE @LineasParqueVenta Ventas.TVP_LineaParque
    DELETE FROM @LineasParqueVenta
    INSERT INTO @LineasParqueVenta (IdEntradaParque, Cantidad) VALUES (@IdEntradaParqueVenta, 1 + (@v % 3))

    DECLARE @LineasActividadVacia Ventas.TVP_LineaActividad
    DELETE FROM @LineasActividadVacia

    EXEC USP_RegistrarVentaEntradaMasiva
        @IdVisitante = @IdVisitanteVenta,
        @MetodoDePago = @MetodoPagoVenta,
        @PuntoDeVenta = @PuntoVentaVenta,
        @LineasParque = @LineasParqueVenta,
        @LineasActividad = @LineasActividadVacia,
        @Fecha = @FechaEntradaVenta,
        @IdVenta = @IdVentaNueva OUTPUT

    SET @v += 1
END

PRINT 'Ventas de entrada a parque cargadas: 40'
GO

-- --- 8.b) Ventas con entrada a actividad -------------------------------------
IF OBJECT_ID('tempdb..#ActividadesParaVenta') IS NOT NULL DROP TABLE #ActividadesParaVenta
GO

SELECT a.IdActividad, a.IdParque, t.DiaDeSemana, t.HoraInicio, t.HoraFin,
       ROW_NUMBER() OVER (ORDER BY a.IdActividad) AS Pos
INTO #ActividadesParaVenta
FROM #Actividades a
INNER JOIN #Turnos t ON t.IdActividad = a.IdActividad
WHERE a.Clave <> 'TOUR_CUPO_COMPLETO'
GO

DECLARE @IdVentaNueva INT
DECLARE @TotalActividadesVenta INT = (SELECT COUNT(*) FROM #ActividadesParaVenta)
IF ISNULL(@TotalActividadesVenta, 0) = 0
    THROW 50000, 'No hay actividades con turno cargadas en #ActividadesParaVenta: revisar la carga de ACTIVIDADES/TURNOS antes de continuar.', 1
DECLARE @va INT = 1

WHILE @va <= 20
BEGIN
    DECLARE @PosActividad INT = ((@va - 1) % @TotalActividadesVenta) + 1
    DECLARE @IdActividadVenta INT, @DiaTurnoVenta TINYINT, @HoraInicioVenta TIME, @HoraFinVenta TIME
    
    SELECT @IdActividadVenta = IdActividad, @DiaTurnoVenta = DiaDeSemana, @HoraInicioVenta = HoraInicio, @HoraFinVenta = HoraFin
    FROM #ActividadesParaVenta WHERE Pos = @PosActividad

    DECLARE @FechaBaseVenta DATE = DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
    DECLARE @OffsetDia INT = (@DiaTurnoVenta - DATEPART(WEEKDAY, @FechaBaseVenta) + 7) % 7
    DECLARE @FechaAsistenciaVenta DATETIME = DATEADD(
        MINUTE,
        DATEDIFF(MINUTE, 0, @HoraInicioVenta) + 5,
        CAST(DATEADD(DAY, @OffsetDia, @FechaBaseVenta) AS DATETIME)
    )

    DECLARE @IdVisitanteVentaAct INT = (SELECT IdVisitante FROM #Visitantes WHERE Orden = ((@va - 1) % 30) + 1)
    DECLARE @MetodoPagoVentaAct VARCHAR(20) = (SELECT valor FROM (VALUES (1,'Efectivo'),(2,'Tarjeta de Débito'),(3,'Tarjeta de Crédito')) AS t(pos,valor) WHERE pos = ((@va - 1) % 3) + 1)

    DECLARE @LineasActividadVenta Ventas.TVP_LineaActividad
    DELETE FROM @LineasActividadVenta
    INSERT INTO @LineasActividadVenta (IdActividad, Cantidad, FechaHoraAsistencia) VALUES (@IdActividadVenta, 1 + (@va % 2), @FechaAsistenciaVenta)

    DECLARE @LineasParqueVacia Ventas.TVP_LineaParque
    DELETE FROM @LineasParqueVacia

    EXEC USP_RegistrarVentaEntradaMasiva
        @IdVisitante = @IdVisitanteVentaAct,
        @MetodoDePago = @MetodoPagoVentaAct,
        @PuntoDeVenta = 'Boletería Central',
        @LineasParque = @LineasParqueVacia,
        @LineasActividad = @LineasActividadVenta,
        @Fecha = @FechaAsistenciaVenta,
        @IdVenta = @IdVentaNueva OUTPUT

    SET @va += 1
END

PRINT 'Ventas de entrada a actividad cargadas: 20'
GO

-- --- 8.c) CASO OBLIGATORIO: "Un tour con cupo completo" ---------------------
DECLARE @IdVentaNueva INT
DECLARE @IdActividadCupoCompleto INT, @IdParqueCupoCompleto INT
SELECT @IdActividadCupoCompleto = IdActividad, @IdParqueCupoCompleto = IdParque
FROM #Actividades WHERE Clave = 'TOUR_CUPO_COMPLETO'

DECLARE @DiaTurnoCupoCompleto TINYINT, @HoraInicioCupoCompleto TIME
SELECT @DiaTurnoCupoCompleto = DiaDeSemana, @HoraInicioCupoCompleto = HoraInicio
FROM #Turnos WHERE IdActividad = @IdActividadCupoCompleto

DECLARE @FechaBaseCupo DATE = DATEADD(DAY, -14, CAST(GETDATE() AS DATE))
DECLARE @OffsetDiaCupo INT = (@DiaTurnoCupoCompleto - DATEPART(WEEKDAY, @FechaBaseCupo) + 7) % 7
DECLARE @FechaAsistenciaCupoCompleto DATETIME = DATEADD(
    MINUTE,
    DATEDIFF(MINUTE, 0, @HoraInicioCupoCompleto) + 10,
    CAST(DATEADD(DAY, @OffsetDiaCupo, @FechaBaseCupo) AS DATETIME)
)

DECLARE @IdVisitanteCupoCompleto INT = (SELECT IdVisitante FROM #Visitantes WHERE Orden = 1)

DECLARE @LineasActividadCupoCompleto Ventas.TVP_LineaActividad
DELETE FROM @LineasActividadCupoCompleto
INSERT INTO @LineasActividadCupoCompleto (IdActividad, Cantidad, FechaHoraAsistencia)
VALUES (@IdActividadCupoCompleto, 4, @FechaAsistenciaCupoCompleto) 

DECLARE @LineasParqueVaciaCupo Ventas.TVP_LineaParque
DELETE FROM @LineasParqueVaciaCupo

EXEC USP_RegistrarVentaEntradaMasiva
    @IdVisitante = @IdVisitanteCupoCompleto,
    @MetodoDePago = 'Tarjeta de Crédito',
    @PuntoDeVenta = 'Online',
    @LineasParque = @LineasParqueVaciaCupo,
    @LineasActividad = @LineasActividadCupoCompleto,
    @Fecha = @FechaAsistenciaCupoCompleto,
    @IdVenta = @IdVentaNueva OUTPUT

DECLARE @EstadoTurnoCupoCompleto VARCHAR(30) = (SELECT TOP 1 Estado FROM Turismo.Turno WHERE IdActividad = @IdActividadCupoCompleto)
PRINT 'Estado del turno con cupo completo tras la venta: ' + @EstadoTurnoCupoCompleto
IF @EstadoTurnoCupoCompleto <> 'cupo lleno'
    PRINT '*** ADVERTENCIA: el turno no quedó en cupo lleno como se esperaba. Revisar fechas/horarios. ***'
GO

--------------------------------------------------------------------------------
-- 9) IMPORTACIONES (dml/imports)
-- Orden: Parques -> Concesiones (USP_ImportarOrganizacionConcesionaria matchea
-- contra Parques.Parque por nombre, normalizando) -> Guías.
-- Los datasets reales de dml/imports ya traen errores (parques con campos
-- incompletos en el Excel, concesiones con el nombre de parque mal escrito),
-- por lo que esta importación cubre el caso obligatorio "Importación con
-- errores parciales" sin necesidad de armar un archivo ad-hoc.
--------------------------------------------------------------------------------

DECLARE @RutaParques VARCHAR(2048), @RutaConcesiones VARCHAR(2048), @RutaGuias VARCHAR(2048)
SELECT @RutaParques     = Ruta FROM #RutasImportacion WHERE Clave = 'Parques'
SELECT @RutaConcesiones = Ruta FROM #RutasImportacion WHERE Clave = 'Concesiones'
SELECT @RutaGuias       = Ruta FROM #RutasImportacion WHERE Clave = 'Guias'

-- USP_ImportarParque y USP_ImportarOrganizacionConcesionaria leen el .xlsx vía
-- OPENROWSET/ACE OLEDB; esta última además llama a la API de feriados vía OLE
-- Automation para calcular el canon. USP_ImportarGuiasCsv no requiere esto.
EXEC sp_configure 'show advanced options', 1
RECONFIGURE
EXEC sp_configure 'Ad Hoc Distributed Queries', 1
RECONFIGURE
EXEC sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.16.0', N'AllowInProcess', 1
EXEC sp_configure 'Ole Automation Procedures', 1
RECONFIGURE

PRINT '--- 9.a) Importación de Parques ---'
EXEC USP_ImportarParque @rutaArchivo = @RutaParques

PRINT '--- 9.b) Importación de Concesiones (Organización + Concesión) ---'
EXEC USP_ImportarOrganizacionConcesionaria @rutaArchivo = @RutaConcesiones

PRINT '--- 9.c) Importación de Guías ---'
EXEC USP_ImportarGuiasCsv @rutaArchivo = @RutaGuias
GO

--------------------------------------------------------------------------------
-- 10) VERIFICACIÓN FINAL CONTRA LOS CRITERIOS DE ACEPTACIÓN
--------------------------------------------------------------------------------

PRINT '=============================================================='
PRINT ' RESUMEN DE CANTIDADES CARGADAS'
PRINT '=============================================================='

SELECT 'Parques'                    AS Entidad, COUNT(*) AS Cantidad, 10 AS Minimo FROM Parques.Parque
UNION ALL
SELECT 'Actividades/Tours',            COUNT(*), 30 FROM Turismo.Actividad
UNION ALL
SELECT 'Guías',                        COUNT(*), 20 FROM Personal.Guia
UNION ALL
SELECT 'Guardaparques',                COUNT(*), 20 FROM Personal.Guardaparque
UNION ALL
SELECT 'Concesiones',                  COUNT(*), 10 FROM Concesiones.Concesion
UNION ALL
SELECT 'Ventas (historial)',           COUNT(*), 1  FROM Ventas.Venta

PRINT '=============================================================='
PRINT ' CASOS OBLIGATORIOS'
PRINT '=============================================================='

SELECT 'Caso 1: actividades simultáneas' AS Caso, p.Nombre AS Parque, COUNT(*) AS CantidadActividadesSimultaneas
FROM Turismo.Turno t
INNER JOIN Turismo.Actividad a ON a.IdActividad = t.IdActividad
INNER JOIN Parques.Parque p ON p.IdParque = a.IdParque
WHERE t.DiaDeSemana = 7 AND t.HoraInicio = '10:00' AND t.HoraFin = '12:00'
GROUP BY p.Nombre
HAVING COUNT(*) > 1

SELECT 'Caso 2: tour con cupo completo' AS Caso, a.Nombre AS Actividad, a.CupoMaximo, t.Estado
FROM Turismo.Turno t
INNER JOIN Turismo.Actividad a ON a.IdActividad = t.IdActividad
WHERE t.Estado = 'cupo lleno'

SELECT 'Caso 3: concesiones vigente/vencida' AS Caso, c.IdConcesion, c.EstadoConcesion, c.FechaInicio, c.FechaFin
FROM Concesiones.Concesion c
WHERE c.FechaInicio IS NOT NULL
ORDER BY c.IdConcesion

PRINT 'Caso 4: Importación con errores parciales (evidencia real en las tablas de log):'

SELECT 'Parques'     AS Importacion, TipoEvento, COUNT(*) AS Cantidad
FROM Parques.LogImportacionParque
GROUP BY TipoEvento
UNION ALL
SELECT 'Concesiones', TipoEvento, COUNT(*)
FROM Concesiones.LogImportacionConcesionaria
GROUP BY TipoEvento
UNION ALL
SELECT 'Guías',       TipoEvento, COUNT(*)
FROM Personal.LogImportacionGuia
GROUP BY TipoEvento

PRINT '=============================================================='
PRINT ' SEED DATA FINALIZADO'
PRINT '=============================================================='
GO

/*
SELECT * FROM Parques.Parque
SELECT * FROM Concesiones.Concesion
SELECT * FROM Personal.Guia
*/