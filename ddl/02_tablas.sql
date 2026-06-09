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
-- PARQUES 
----------------------------------------

/*
DROP TABLE Parques.Parque
*/

IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = 'Parque')
BEGIN
	CREATE TABLE Parques.Parque(
		IdParque INT IDENTITY(1,1) PRIMARY KEY,
		Nombre VARCHAR(50) NOT NULL,
		HorarioCierre TIME NOT NULL,
		HorarioApertura TIME NOT NULL,
		Superficie DECIMAL (10,2) NOT NULL CONSTRAINT CK_Parque_Superficie CHECK(Superficie > 0),
		Provincia VARCHAR(50) NOT NULL,
		Numero INT NOT NULL,
		Localidad VARCHAR(50) NOT NULL,
		TipoParque VARCHAR(50) NOT NULL CONSTRAINT CK_Parque_TipoParque CHECK(TipoParque IN('Parque Nacional',
						'Monumento Natural','Reserva Nacional',
						'Reserva Natural Estricta','Reserva Natural Silvestre',
						'Reserva Natural Educativa'))
		)
END

----------------------------------------
-- TURISMO 
----------------------------------------

/*
DROP TABLE Turismo.Actividad
DROP TABLE Turismo.Entrada
DROP TABLE Turismo.Visitante
DROP TABLE Turismo.TipoVisitante
*/

IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = 'Actividad')
BEGIN
	CREATE TABLE Turismo.Actividad(
		IdActividad INT IDENTITY(1,1) PRIMARY KEY,
		Nombre VARCHAR(50) NOT NULL,
		Tipo VARCHAR(9) CONSTRAINT CK_Actividad_Tipo CHECK(Tipo IN('Tour', 'Atracción')),
		Costo DECIMAL(10,2) CONSTRAINT CK_Actividad_Costo CHECK(Costo >= 0),
		CupoMaximo INT NOT NULL CONSTRAINT CK_Actividad_CupoMaximo CHECK(CupoMaximo > 0),
		Duracion INT NOT NULL CONSTRAINT CK_Actividad_Duracion CHECK(Duracion > 0),
		IdParque INT NOT NULL FOREIGN KEY REFERENCES Parques.Parque(IdParque)
	);
END

IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = 'Entrada')
BEGIN
	CREATE TABLE Turismo.Entrada(
		IdEntrada INT IDENTITY(1,1) PRIMARY KEY,
		Costo DECIMAL(10,2) NOT NULL CONSTRAINT CK_Entrada_Costo CHECK(Costo > 0),
		FechaAcceso DATE NOT NULL,
		IdParque INT NOT NULL FOREIGN KEY REFERENCES Parques.Parque(IdParque)
	);
END

IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = 'TipoVisitante')
BEGIN
	CREATE TABLE Turismo.TipoVisitante(
		IdTipoVisitante INT IDENTITY(1,1) PRIMARY KEY,
		Descripcion VARCHAR(50) NOT NULL,
		Descuento TINYINT NOT NULL CONSTRAINT CK_TipoVisitante_Descuento CHECK(Descuento BETWEEN 0 AND 100)
	);
END

IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = 'Visitante')
BEGIN
	CREATE TABLE Turismo.Visitante(
		IdVisitante INT IDENTITY(1,1) PRIMARY KEY,
		Telefono VARCHAR(20) NOT NULL,
		CorreoVisitante VARCHAR(100) NOT NULL CONSTRAINT CK_Visitante_CorreoVisitante CHECK(CorreoVisitante LIKE '%_@__%.__%'),
		NumeroDocumento VARCHAR(15) NOT NULL UNIQUE,
		TipoDocumento VARCHAR(15) NOT NULL CONSTRAINT CK_Visitante_TipoDocumento CHECK(TipoDocumento IN('DNI','PAS', 'CUIT', 'LC', 'LE')),
		CUIT VARCHAR(15) NOT NULL UNIQUE,
		Edad TINYINT NOT NULL CONSTRAINT CK_Visitante_Edad CHECK (Edad BETWEEN 0 AND 99),
		Nombre VARCHAR(50) NOT NULL,
		Apellido VARCHAR(50) NOT NULL,
		IdTipoVisitante INT FOREIGN KEY REFERENCES Turismo.TipoVisitante(IdTipoVisitante)
	);
END

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
		TipoActividad VARCHAR(50) NOT NULL,
		Cuit CHAR(11) NOT NULL,
		CorreoContacto VARCHAR(100) CONSTRAINT CK_OrganizacionConcesionaria_CorreoContacto CHECK(CorreoContacto LIKE '%_@__%.__%'),
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
		CanonMensual DECIMAL(10,2) NOT NULL CONSTRAINT CK_Concesion_CanonMensual CHECK(CanonMensual > 0),
		ExtensionConcedida DECIMAL(10,2) NOT NULL CONSTRAINT CK_Concesion_ExtensionConcedida CHECK(ExtensionConcedida > 0),
		EstadoConcesion VARCHAR(8) NOT NULL CONSTRAINT CK_Concesion_EstadoConcesion CHECK(EstadoConcesion IN ('Activo','Inactivo')),
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
		Monto DECIMAL(10,2) NOT NULL CONSTRAINT CK_PagoConcesion_Monto CHECK(Monto > 0)
	)
END

----------------------------------------
-- PERSONAL 
----------------------------------------

/*
DROP TABLE Personal.Asignacion
DROP TABLE Personal.Habilitacion
DROP TABLE Personal.GuiaTrabajaEnParque
DROP TABLE Personal.Guia
DROP TABLE Personal.Guardaparque
*/

IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = 'Guia')
BEGIN
	CREATE TABLE Personal.Guia(
		IdGuia INT IDENTITY(1,1) PRIMARY KEY,
		Telefono VARCHAR(20) NOT NULL,
		CorreoGuia VARCHAR(100) NOT NULL CONSTRAINT CK_Guia_CorreoGuia CHECK(CorreoGuia LIKE '%_@__%.__%'),
		NumeroDocumento VARCHAR(15) NOT NULL UNIQUE,
		TipoDocumento VARCHAR(15) NOT NULL CONSTRAINT CK_Guia_TipoDocumento CHECK( TipoDocumento IN('DNI','PAS', 'CUIT', 'LC', 'LE')),
		Edad TINYINT NOT NULL CHECK (Edad BETWEEN 0 AND 99),
		Apellido VARCHAR(50) NOT NULL,
		Nombre VARCHAR(50) NOT NULL,
		Titulo VARCHAR(50)
	)
END

IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = 'GuiaTrabajaEnParque')
BEGIN
    CREATE TABLE Personal.GuiaTrabajaEnParque(
        IdGuia INT NOT NULL FOREIGN KEY REFERENCES Personal.Guia(IdGuia),
        IdParque INT NOT NULL FOREIGN KEY REFERENCES Parques.Parque(IdParque),

        CONSTRAINT PK_GuiaTrabajaEnParque PRIMARY KEY (IdGuia, IdParque)
    )
END

IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = 'Guardaparque')
BEGIN
	CREATE TABLE Personal.Guardaparque(
		IdGuardaparque INT IDENTITY(1,1) PRIMARY KEY,
		Telefono VARCHAR(20) NOT NULL,
		CorreoGuardaparque VARCHAR(100) NOT NULL CONSTRAINT CK_Guardaparque_CorreoGuardaparque CHECK(CorreoGuardaparque LIKE '%_@__%.__%'),
		NumeroDocumento VARCHAR(15) NOT NULL UNIQUE,
		TipoDocumento VARCHAR(15) NOT NULL CONSTRAINT CK_Guardaparque_TipoDocumento CHECK(TipoDocumento IN('DNI','PAS', 'CUIT', 'LC', 'LE')),
		Edad TINYINT NOT NULL CONSTRAINT CK_Guardaparque_Edad CHECK (Edad BETWEEN 0 AND 99),
		Apellido VARCHAR(50) NOT NULL,
		Nombre VARCHAR(50) NOT NULL,
		Estado VARCHAR(20) NOT NULL CONSTRAINT CK_Guardaparque_Estado CHECK(Estado IN('Activo','Inactivo'))
	)
END

IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = 'Asignacion')
BEGIN
	CREATE TABLE Personal.Asignacion(
		IdAsignacion INT IDENTITY(1,1) PRIMARY KEY,
		FechaIngreso DATE NOT NULL DEFAULT GETDATE(),
		FechaEgreso DATE,
		Motivo VARCHAR(200),
		IdParque INT NOT NULL,
		IdGuardaparque INT NOT NULL,

		FOREIGN KEY (IdParque) REFERENCES Parques.Parque(IdParque),
		FOREIGN KEY (IdGuardaparque) REFERENCES Personal.Guardaparque(IdGuardaparque)
	)
END

IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = 'Habilitacion')
BEGIN
	CREATE TABLE Personal.Habilitacion(
		IdHabilitacion INT IDENTITY(1,1) PRIMARY KEY,
		FechaInicio DATE NOT NULL,
		DiasVigentes INT NOT NULL CONSTRAINT CK_Habilitacion_DiasVigentes CHECK(DiasVigentes > 0),
		IdGuia INT NOT NULL,
		IdActividad INT NOT NULL,

		FOREIGN KEY (IdGuia) REFERENCES Personal.Guia(IdGuia),
		FOREIGN KEY (IdActividad) REFERENCES Turismo.Actividad(IdActividad)
	)
END

----------------------------------------
-- VENTAS 
----------------------------------------

/*
DROP TABLE Ventas.LineaDeActividad
DROP TABLE Ventas.LineaDeEntrada
DROP TABLE Ventas.Venta
*/

IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = 'Venta')
BEGIN
	CREATE TABLE Ventas.Venta (
		IdVenta INT IDENTITY(1,1) PRIMARY KEY,
		Fecha DATETIME DEFAULT GETDATE() NOT NULL,
		Monto DECIMAL(10,2) NOT NULL CONSTRAINT CK_Venta_Monto CHECK(Monto > 0),
		MetodoDePago VARCHAR(20) NOT NULL,
		PuntoDeVenta VARCHAR(20) NOT NULL,
		IdVisitante INT NOT NULL FOREIGN KEY REFERENCES Turismo.Visitante(IdVisitante)
	);
END

IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = 'LineaDeActividad')
BEGIN
	CREATE TABLE Ventas.LineaDeActividad(
		PrecioUnitario DECIMAL(10,2) NOT NULL CONSTRAINT CK_LineaDeActividad_PrecioUnitario CHECK(PrecioUnitario > 0),
		Cantidad TINYINT NOT NULL CONSTRAINT CK_LineaDeActividad_Cantidad CHECK(Cantidad >0),
		Subtotal AS (PrecioUnitario * Cantidad) PERSISTED,
		NumeroDeItem TINYINT NOT NULL CONSTRAINT CK_LineaDeActividad_NumeroDeItem CHECK(NumeroDeItem >0),
		IdVenta INT NOT NULL FOREIGN KEY REFERENCES Ventas.Venta(IdVenta),
		IdActividad INT NOT NULL FOREIGN KEY REFERENCES Turismo.Actividad(IdActividad)

		CONSTRAINT PK_LineaDeActividad PRIMARY KEY (IdVenta,NumeroDeItem)
	);
END

IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = 'LineaDeEntrada')
BEGIN
	CREATE TABLE Ventas.LineaDeEntrada(
		PrecioUnitario DECIMAL(10,2) NOT NULL CONSTRAINT CK_LineaDeEntrada_PrecioUnitario CHECK(PrecioUnitario > 0),
		Cantidad TINYINT NOT NULL CONSTRAINT CK_LineaDeEntrada_Cantidad CHECK(Cantidad >0),
		Subtotal AS (PrecioUnitario * Cantidad) PERSISTED,
		NumeroDeItem TINYINT NOT NULL CONSTRAINT CK_LineaDeEntrada_NumeroDeItem CHECK(NumeroDeItem >0),
		IdVenta INT NOT NULL FOREIGN KEY REFERENCES Ventas.Venta(IdVenta),
		IdEntrada INT NOT NULL FOREIGN KEY REFERENCES Turismo.Entrada(IdEntrada)

		CONSTRAINT PK_LineaDeEntrada PRIMARY KEY (IdVenta,NumeroDeItem)
	);
END
