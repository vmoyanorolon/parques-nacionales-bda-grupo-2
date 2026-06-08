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