-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: creación de las tablas

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'ParquesNacionales')
BEGIN
    PRINT 'ERROR: La base de datos ParquesNacionales no existe. Ejecutar primero 01_base_de_datos.sql'
    RETURN
END
GO

USE ParquesNacionales
GO

----------------------------------------
-- CONCESIONES
----------------------------------------

/*
DROP TABLE Concesiones.PagoConcesion
DROP TABLE Concesiones.Concesion
DROP TABLE Concesiones.OrganizacionConcesionaria
*/

IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = 'OrganizacionConcesionaria')
BEGIN
	CREATE TABLE Concesiones.OrganizacionConcesionaria(
		IdOrganizacionConcesionaria INT IDENTITY(1,1) PRIMARY KEY,
		Nombre VARCHAR(50) NOT NULL,
		TipoActividad VARCHAR(20) NOT NULL,
		Cuit CHAR(11),
		CorreoContacto VARCHAR(100) CONSTRAINT CK_CorreoContacto CHECK(CorreoContacto LIKE '%_@__%.__%'),
		TelefonoContacto VARCHAR(20),
		DomicilioRegistrado VARCHAR(100)
	)
END

IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = 'Concesion')
BEGIN
	CREATE TABLE Concesiones.Concesion(
		IdConcesion INT IDENTITY(1,1) PRIMARY KEY,
		IdParque INT NOT NULL FOREIGN KEY REFERENCES Parques.Parque(IdParque),
		IdOrganizacionConcesionaria INT NOT NULL FOREIGN KEY REFERENCES Concesiones.OrganizacionConcesionaria(IdOrganizacionConcesionaria),
		CanonMensual DECIMAL(10,2) NOT NULL CONSTRAINT CK_CanonMensual CHECK(CanonMensual > 0),
		ExtensionConcedida DECIMAL(10,2) NOT NULL CONSTRAINT CK_ExtensionConcedida CHECK(ExtensionConcedida > 0),
		EstadoConcesion VARCHAR(8) NOT NULL CONSTRAINT CK_EstadoConcesion CHECK(EstadoConcesion IN ('activo','inactivo')),
		FechaInicio DATE NOT NULL,
		FechaFin DATE
	)
END

IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = 'PagoConcesion')
BEGIN
	CREATE TABLE Concesiones.PagoConcesion(
		IdPagoConcesion INT IDENTITY(1,1) PRIMARY KEY,
		IdConcesion INT NOT NULL FOREIGN KEY REFERENCES Concesiones.Concesion(IdConcesion),
		Fecha DATETIME NOT NULL DEFAULT GETDATE(),
		Monto DECIMAL(10,2) NOT NULL
	)
END

----------------------------------------
-- PERSONAL 
----------------------------------------

/*
DROP TABLE Personal.Guia
DROP TABLE Personal.Guardaparque
DROP TABLE Personal.Asignacion
DROP TABLE Personal.Habilitacion
*/

IF NOT EXISTS (SELECT name FROM sys.table_types WHERE name = 'Guia')
BEGIN
	CREATE TABLE Personal.Guia(
		IdGuia INT IDENTITY(1,1) PRIMARY KEY,
		Telefono VARCHAR(20) NOT NULL,
		CorreoGuia VARCHAR(100) NOT NULL CONSTRAINT CK_CorreoGuia CHECK(CorreoGuia LIKE '%_@__%.__%'),
		NumeroDocumento VARCHAR(15) NOT NULL UNIQUE,
		TipoDocumento VARCHAR(15) NOT NULL CHECK( TipoDocumento IN('DNI','PAS', 'CUIT', 'LC', 'LE')),
		Edad TINYINT NOT NULL CHECK (Edad BETWEEN 0 AND 99),
		Apellido VARCHAR(50) NOT NULL,
		Titulo VARCHAR(50) NOT NULL
	)
END

IF NOT EXISTS (SELECT name FROM sys.table_types WHERE name = 'Guardaparque')
BEGIN
	CREATE TABLE Personal.Guardaparque(
		IdGuardaparque INT IDENTITY(1,1) PRIMARY KEY,
		Telefono VARCHAR(20) NOT NULL,
		CorreoGuardaparque VARCHAR(100) NOT NULL CONSTRAINT CK_CorreoGuardaparque CHECK(CorreoGuardaparque LIKE '%_@__%.__%'),
		NumeroDocumento VARCHAR(15) NOT NULL UNIQUE,
		TipoDocumento VARCHAR(15) NOT NULL CHECK(TipoDocumento IN('DNI','PAS', 'CUIT', 'LC', 'LE')),
		Edad TINYINT NOT NULL CHECK (Edad BETWEEN 0 AND 99),
		Apellido VARCHAR(50) NOT NULL,
		Estado VARCHAR(20) NOT NULL CHECK(Estado IN('Activo','Inactivo'))
	)
END

IF NOT EXISTS (SELECT name FROM sys.table_types WHERE name = 'Asignacion')
BEGIN
	CREATE TABLE Personal.Asignacion(
		IdAsignacion INT IDENTITY(1,1) PRIMARY KEY,
		FechaIngreso DATE NOT NULL,
		FechaEgreso DATE DEFAULT NULL,
		Motivo VARCHAR(200) DEFAULT NULL,
		IdParque INT NOT NULL UNIQUE,
		IdGuardaparque INT NOT NULL UNIQUE,

		FOREIGN KEY (IdParque) REFERENCES Parques.Parque(IdParque),
		FOREIGN KEY (IdGuardaparque) REFERENCES Personal.Guardaparque(IdGuardaparque)
	)
END

IF NOT EXISTS (SELECT name FROM sys.table_types WHERE name = 'Habilitacion')
BEGIN
	CREATE TABLE Personal.Habilitacion(
		IdHabilitacion INT IDENTITY(1,1) PRIMARY KEY,
		FechaInicio DATE NOT NULL,
		DiasVigentes INT NOT NULL CHECK(DiasVigentes > 0),
		IdGuia INT NOT NULL UNIQUE,
		IdActividad INT NOT NULL UNIQUE,

		FOREIGN KEY (IdGuia) REFERENCES Personal.Guia(IdGuia),
		FOREIGN KEY (IdActividad) REFERENCES Turismo.Actividad(IdActividad)
	)
END

----------------------------------------
-- PARQUES 
----------------------------------------

IF NOT EXISTS (SELECT name FROM sys.table_types WHERE name = 'Parque')
BEGIN
	CREATE TABLE Parques.Parque(
		IdParque INT IDENTITY(1,1) PRIMARY KEY,
		HorarioCierre TIME NOT NULL,
		HorarioApertura TIME NOT NULL,
		Superficie DECIMAL (10,2) NOT NULL CHECK(Superficie > 0),
		Provincia VARCHAR(50) NOT NULL,
		Numero INT NOT NULL,
		Localidad VARCHAR(50) NOT NULL,
		TipoParque VARCHAR(50) NOT NULL CHECK(TipoParque IN('Parque Nacional',
						'Monumento Natural','Reserva Nacional',
						'Reserva Natural Estricta','Reserva Natural Silvestre',
						'Reserva Natural Educativa'))
		)
END



		