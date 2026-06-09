-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: creación de la base de datos y de los esquemas

----------------------------------------
-- BASE DE DATOS
----------------------------------------

-- DROP DATABASE ParquesNacionales
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'ParquesNacionales')
BEGIN
	CREATE DATABASE ParquesNacionales
	COLLATE Latin1_General_CI_AS
END
GO

USE ParquesNacionales
GO

----------------------------------------
-- ESQUEMAS
----------------------------------------

-- DROP SCHEMA Ventas
IF NOT EXISTS (SELECT name FROM sys.schemas WHERE name = 'Ventas')
BEGIN
	-- La creación del esquema debe ser la primera instrucción de un batch. Para que sea compatible con el if, se usa el exec
	EXEC('CREATE SCHEMA Ventas')
END

-- DROP SCHEMA Turismo
IF NOT EXISTS (SELECT name FROM sys.schemas WHERE name = 'Turismo')
BEGIN
	EXEC('CREATE SCHEMA Turismo')
END

-- DROP SCHEMA Personal
IF NOT EXISTS (SELECT name FROM sys.schemas WHERE name = 'Personal')
BEGIN
	EXEC('CREATE SCHEMA Personal')
END

-- DROP SCHEMA Concesiones
IF NOT EXISTS (SELECT name FROM sys.schemas WHERE name = 'Concesiones')
BEGIN
	EXEC('CREATE SCHEMA Concesiones')
END

-- DROP SCHEMA Parques
IF NOT EXISTS (SELECT name FROM sys.schemas WHERE name = 'Parques')
BEGIN
	EXEC('CREATE SCHEMA Parques')
END