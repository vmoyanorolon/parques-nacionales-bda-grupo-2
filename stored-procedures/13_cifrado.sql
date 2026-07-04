-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: Entrega 8 - Cifrado de datos sensibles con EncryptByPassPhrase/DecryptByPassPhrase
--   Se cifran los números de documento/CUIT de Visitante, Guia, Guardaparque y OrganizacionConcesionaria.
--   Script de MODIFICACIÓN, reejecutable: todos los pasos verifican existencia antes de aplicarse.

USE ParquesNacionales
GO

/*
====================================================================================
 DECISIÓN: qué se cifra y por qué
====================================================================================
 Se cifran los números de documento de identidad y CUIT/CUIT porque identifican
 unívocamente a una persona física (Visitante, Guia, Guardaparque) o a una organización
 (Ley 25.326 de Protección de Datos Personales). No se cifran Telefono/Correo/Domicilio:
 son datos de contacto de menor sensibilidad y necesarios en texto plano para operaciones
 cotidianas.

 Mecanismo: EncryptByPassPhrase/DecryptByPassPhrase (el visto en la materia), con autenticador = PK de la fila
====================================================================================
*/

-- ====================================================================
-- 1) Migración: Turismo.Visitante (NumeroDocumento, CUIT)
-- ====================================================================

IF NOT EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id WHERE c.object_id = OBJECT_ID('Turismo.Visitante') AND c.name = 'NumeroDocumento' AND t.name = 'varbinary')
   AND COL_LENGTH('Turismo.Visitante', 'NumeroDocumentoEnc') IS NULL
BEGIN
    ALTER TABLE Turismo.Visitante ADD NumeroDocumentoEnc VARBINARY(256) NULL;
    ALTER TABLE Turismo.Visitante ADD CUITEnc VARBINARY(256) NULL;
END
GO

/*
Procedure de un solo uso, parte de la migración: opera sobre NumeroDocumentoEnc/CUITEnc
mientras esas columnas existen (antes del rename más abajo en este mismo script). NO
volver a ejecutarlo después de correr todo este archivo: esas columnas ya no existen
bajo ese nombre y el UPDATE fallaría. El cifrado de datos nuevos, de ahora en más, lo
hacen USP_AltaVisitante/USP_ModificacionVisitante directamente.
*/
CREATE OR ALTER PROCEDURE USP_CifrarDatosSensibles_Turismo
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @FraseClave VARCHAR(128) = 'ParquesNacionales_Cifrado_TP';

    UPDATE Turismo.Visitante
    SET NumeroDocumentoEnc = EncryptByPassPhrase(@FraseClave, NumeroDocumento, 1, CONVERT(VARBINARY, IdVisitante)),
        CUITEnc = EncryptByPassPhrase(@FraseClave, CUIT, 1, CONVERT(VARBINARY, IdVisitante))
    WHERE NumeroDocumentoEnc IS NULL;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id WHERE c.object_id = OBJECT_ID('Turismo.Visitante') AND c.name = 'NumeroDocumento' AND t.name = 'varbinary')
    EXEC USP_CifrarDatosSensibles_Turismo;
GO

-- Elimina las UNIQUE inline (nombre autogenerado) sobre NumeroDocumento y CUIT en texto
-- plano: con el valor cifrado esas UNIQUE dejan de tener sentido, la
-- unicidad pasa a validarse en el SP desencriptando y comparando.
DECLARE @constraint SYSNAME, @sql NVARCHAR(300);

SELECT @constraint = kc.name
FROM sys.key_constraints kc
JOIN sys.index_columns ic ON ic.object_id = kc.parent_object_id AND ic.index_id = kc.unique_index_id
JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE kc.parent_object_id = OBJECT_ID('Turismo.Visitante') AND c.name = 'NumeroDocumento' AND kc.type = 'UQ';

IF @constraint IS NOT NULL
BEGIN
    SET @sql = N'ALTER TABLE Turismo.Visitante DROP CONSTRAINT ' + QUOTENAME(@constraint);
    EXEC sp_executesql @sql;
END

SELECT @constraint = kc.name
FROM sys.key_constraints kc
JOIN sys.index_columns ic ON ic.object_id = kc.parent_object_id AND ic.index_id = kc.unique_index_id
JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE kc.parent_object_id = OBJECT_ID('Turismo.Visitante') AND c.name = 'CUIT' AND kc.type = 'UQ';

IF @constraint IS NOT NULL
BEGIN
    SET @sql = N'ALTER TABLE Turismo.Visitante DROP CONSTRAINT ' + QUOTENAME(@constraint);
    EXEC sp_executesql @sql;
END
GO

IF COL_LENGTH('Turismo.Visitante', 'NumeroDocumentoEnc') IS NOT NULL
BEGIN
    ALTER TABLE Turismo.Visitante DROP COLUMN NumeroDocumento, CUIT;
    EXEC sp_rename 'Turismo.Visitante.NumeroDocumentoEnc', 'NumeroDocumento', 'COLUMN';
    EXEC sp_rename 'Turismo.Visitante.CUITEnc', 'CUIT', 'COLUMN';
END
GO

ALTER TABLE Turismo.Visitante ALTER COLUMN NumeroDocumento VARBINARY(256) NOT NULL;
ALTER TABLE Turismo.Visitante ALTER COLUMN CUIT VARBINARY(256) NOT NULL;
GO

-- ====================================================================
-- 2) Migración: Personal.Guia y Personal.Guardaparque (NumeroDocumento)
-- ====================================================================

IF NOT EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id WHERE c.object_id = OBJECT_ID('Personal.Guia') AND c.name = 'NumeroDocumento' AND t.name = 'varbinary')
   AND COL_LENGTH('Personal.Guia', 'NumeroDocumentoEnc') IS NULL
    ALTER TABLE Personal.Guia ADD NumeroDocumentoEnc VARBINARY(256) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id WHERE c.object_id = OBJECT_ID('Personal.Guardaparque') AND c.name = 'NumeroDocumento' AND t.name = 'varbinary')
   AND COL_LENGTH('Personal.Guardaparque', 'NumeroDocumentoEnc') IS NULL
    ALTER TABLE Personal.Guardaparque ADD NumeroDocumentoEnc VARBINARY(256) NULL;
GO

-- Un solo procedure para todo el esquema Personal: cifra los datos existentes de
-- las dos tablas sensibles que tiene (Guia y Guardaparque). Procedure de un solo uso,
-- parte de la migración: opera sobre NumeroDocumentoEnc mientras esa columna existe
-- (antes del rename más abajo).
/*
EXEC USP_CifrarDatosSensibles_Personal;
*/
CREATE OR ALTER PROCEDURE USP_CifrarDatosSensibles_Personal
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @FraseClave VARCHAR(128) = 'ParquesNacionales_Cifrado_TP';
    DECLARE @sql NVARCHAR(500);

    -- SQL dinámico acá es necesario: Guia y Guardaparque pueden quedar en estados de
    -- migración distintos (una ya renombrada a su nombre final, la otra todavía con
    -- la columna *Enc) si el archivo se corrió parcialmente antes. Un UPDATE estático
    -- que referencie NumeroDocumentoEnc en una tabla donde esa columna ya no existe
    -- rompe todo el procedure, aunque la otra tabla sí la necesite.
    IF COL_LENGTH('Personal.Guia', 'NumeroDocumentoEnc') IS NOT NULL
    BEGIN
        SET @sql = N'UPDATE Personal.Guia SET NumeroDocumentoEnc = EncryptByPassPhrase(@Frase, NumeroDocumento, 1, CONVERT(VARBINARY, IdGuia)) WHERE NumeroDocumentoEnc IS NULL';
        EXEC sp_executesql @sql, N'@Frase VARCHAR(128)', @Frase = @FraseClave;
    END

    IF COL_LENGTH('Personal.Guardaparque', 'NumeroDocumentoEnc') IS NOT NULL
    BEGIN
        SET @sql = N'UPDATE Personal.Guardaparque SET NumeroDocumentoEnc = EncryptByPassPhrase(@Frase, NumeroDocumento, 1, CONVERT(VARBINARY, IdGuardaparque)) WHERE NumeroDocumentoEnc IS NULL';
        EXEC sp_executesql @sql, N'@Frase VARCHAR(128)', @Frase = @FraseClave;
    END
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id WHERE c.object_id = OBJECT_ID('Personal.Guia') AND c.name = 'NumeroDocumento' AND t.name = 'varbinary')
   OR NOT EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id WHERE c.object_id = OBJECT_ID('Personal.Guardaparque') AND c.name = 'NumeroDocumento' AND t.name = 'varbinary')
    EXEC USP_CifrarDatosSensibles_Personal;
GO

DECLARE @constraint SYSNAME, @sql NVARCHAR(300);

SELECT @constraint = kc.name
FROM sys.key_constraints kc
JOIN sys.index_columns ic ON ic.object_id = kc.parent_object_id AND ic.index_id = kc.unique_index_id
JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE kc.parent_object_id = OBJECT_ID('Personal.Guia') AND c.name = 'NumeroDocumento' AND kc.type = 'UQ';

IF @constraint IS NOT NULL
BEGIN
    SET @sql = N'ALTER TABLE Personal.Guia DROP CONSTRAINT ' + QUOTENAME(@constraint);
    EXEC sp_executesql @sql;
END

SELECT @constraint = kc.name
FROM sys.key_constraints kc
JOIN sys.index_columns ic ON ic.object_id = kc.parent_object_id AND ic.index_id = kc.unique_index_id
JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE kc.parent_object_id = OBJECT_ID('Personal.Guardaparque') AND c.name = 'NumeroDocumento' AND kc.type = 'UQ';

IF @constraint IS NOT NULL
BEGIN
    SET @sql = N'ALTER TABLE Personal.Guardaparque DROP CONSTRAINT ' + QUOTENAME(@constraint);
    EXEC sp_executesql @sql;
END
GO

IF COL_LENGTH('Personal.Guia', 'NumeroDocumentoEnc') IS NOT NULL
BEGIN
    ALTER TABLE Personal.Guia DROP COLUMN NumeroDocumento;
    EXEC sp_rename 'Personal.Guia.NumeroDocumentoEnc', 'NumeroDocumento', 'COLUMN';
END
GO

IF COL_LENGTH('Personal.Guardaparque', 'NumeroDocumentoEnc') IS NOT NULL
BEGIN
    ALTER TABLE Personal.Guardaparque DROP COLUMN NumeroDocumento;
    EXEC sp_rename 'Personal.Guardaparque.NumeroDocumentoEnc', 'NumeroDocumento', 'COLUMN';
END
GO

ALTER TABLE Personal.Guia ALTER COLUMN NumeroDocumento VARBINARY(256) NOT NULL;
ALTER TABLE Personal.Guardaparque ALTER COLUMN NumeroDocumento VARBINARY(256) NOT NULL;
GO

-- ====================================================================
-- 3) Migración: Concesiones.OrganizacionConcesionaria (Cuit)
-- ====================================================================

IF NOT EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id WHERE c.object_id = OBJECT_ID('Concesiones.OrganizacionConcesionaria') AND c.name = 'Cuit' AND t.name = 'varbinary')
   AND COL_LENGTH('Concesiones.OrganizacionConcesionaria', 'CuitEnc') IS NULL
    ALTER TABLE Concesiones.OrganizacionConcesionaria ADD CuitEnc VARBINARY(256) NULL;
GO

/*
Procedure de un solo uso, parte de la migración: opera sobre CuitEnc mientras esa
columna existe (antes del rename más abajo).
EXEC USP_CifrarDatosSensibles_Concesiones;
*/
CREATE OR ALTER PROCEDURE USP_CifrarDatosSensibles_Concesiones
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @FraseClave VARCHAR(128) = 'ParquesNacionales_Cifrado_TP';

    UPDATE Concesiones.OrganizacionConcesionaria
    SET CuitEnc = EncryptByPassPhrase(@FraseClave, Cuit, 1, CONVERT(VARBINARY, IdOrganizacionConcesionaria))
    WHERE CuitEnc IS NULL;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id WHERE c.object_id = OBJECT_ID('Concesiones.OrganizacionConcesionaria') AND c.name = 'Cuit' AND t.name = 'varbinary')
    EXEC USP_CifrarDatosSensibles_Concesiones;
GO

IF COL_LENGTH('Concesiones.OrganizacionConcesionaria', 'CuitEnc') IS NOT NULL
BEGIN
    ALTER TABLE Concesiones.OrganizacionConcesionaria DROP COLUMN Cuit;
    EXEC sp_rename 'Concesiones.OrganizacionConcesionaria.CuitEnc', 'Cuit', 'COLUMN';
END
GO

ALTER TABLE Concesiones.OrganizacionConcesionaria ALTER COLUMN Cuit VARBINARY(256) NOT NULL;
GO

-- ====================================================================
-- 4) SP de ABM actualizados: Turismo.Visitante
-- ====================================================================

/*
EXEC USP_AltaVisitante '1122334455', 'visitante@gmail.com', '123123123', 'DNI', '201231231233', 30, 'Juan', 'Perez';
EXEC USP_AltaVisitante '1122334455', 'otro@gmail.com', '123123123', 'DNI', '201231231299', 30, 'Juan', 'Perez'; -- debe fallar (documento repetido)
*/
CREATE OR ALTER PROCEDURE USP_AltaVisitante
    @Telefono VARCHAR(20),
    @CorreoVisitante VARCHAR(100),
    @NumeroDocumento VARCHAR(15),
    @TipoDocumento VARCHAR(15),
    @CUIT VARCHAR(15),
    @Edad TINYINT,
    @Nombre VARCHAR(50),
    @Apellido VARCHAR(50),
    @IdTipoVisitante INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores VARCHAR(2048) = ''
    DECLARE @FraseClave VARCHAR(128) = 'ParquesNacionales_Cifrado_TP'
    DECLARE @IdVisitante INT

    IF EXISTS (
        SELECT 1 FROM Turismo.Visitante
        WHERE CONVERT(VARCHAR(15), DecryptByPassPhrase(@FraseClave, NumeroDocumento, 1, CONVERT(VARBINARY, IdVisitante))) = @NumeroDocumento
    )
        SET @errores += 'Ya existe un visitante con ese número de documento.' + CHAR(13)

    IF EXISTS (
        SELECT 1 FROM Turismo.Visitante
        WHERE CONVERT(VARCHAR(15), DecryptByPassPhrase(@FraseClave, CUIT, 1, CONVERT(VARBINARY, IdVisitante))) = @CUIT
    )
        SET @errores += 'Ya existe un visitante con ese CUIT.' + CHAR(13)

    IF @errores <> ''
    BEGIN
        SET @errores = 'No se pudo dar de alta al visitante:' + CHAR(13) + @errores;
        THROW 50000, @errores, 1
    END

    BEGIN TRANSACTION
        -- El Id no existe todavía: se inserta con un valor temporal y se cifra recién
        -- después, ya con el Id real como autenticador
        INSERT INTO Turismo.Visitante
            (Telefono, CorreoVisitante, NumeroDocumento, TipoDocumento, CUIT, Edad, Nombre, Apellido, IdTipoVisitante)
        VALUES
            (@Telefono, @CorreoVisitante, CONVERT(VARBINARY(256), @NumeroDocumento), @TipoDocumento, CONVERT(VARBINARY(256), @CUIT), @Edad, @Nombre, @Apellido, @IdTipoVisitante);

        SET @IdVisitante = SCOPE_IDENTITY();

        UPDATE Turismo.Visitante
        SET NumeroDocumento = EncryptByPassPhrase(@FraseClave, @NumeroDocumento, 1, CONVERT(VARBINARY, @IdVisitante)),
            CUIT = EncryptByPassPhrase(@FraseClave, @CUIT, 1, CONVERT(VARBINARY, @IdVisitante))
        WHERE IdVisitante = @IdVisitante;
    COMMIT TRANSACTION
END
GO

CREATE OR ALTER PROCEDURE USP_ModificacionVisitante
    @IdVisitante INT,
    @Telefono VARCHAR(20) = NULL,
    @CorreoVisitante VARCHAR(100) = NULL,
    @NumeroDocumento VARCHAR(15) = NULL,
    @TipoDocumento VARCHAR(15) = NULL,
    @CUIT VARCHAR(15) = NULL,
    @Edad TINYINT = NULL,
    @Nombre VARCHAR(50) = NULL,
    @Apellido VARCHAR(50) = NULL,
    @IdTipoVisitante INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores VARCHAR(2048) = ''
    DECLARE @FraseClave VARCHAR(128) = 'ParquesNacionales_Cifrado_TP'

    IF NOT EXISTS (SELECT 1 FROM Turismo.Visitante WHERE IdVisitante = @IdVisitante)
        SET @errores += 'El visitante no existe.' + CHAR(13)

    IF @NumeroDocumento IS NOT NULL AND EXISTS (
        SELECT 1 FROM Turismo.Visitante
        WHERE IdVisitante <> @IdVisitante
          AND CONVERT(VARCHAR(15), DecryptByPassPhrase(@FraseClave, NumeroDocumento, 1, CONVERT(VARBINARY, IdVisitante))) = @NumeroDocumento
    )
        SET @errores += 'Ya existe otro visitante con ese número de documento.' + CHAR(13)

    IF @CUIT IS NOT NULL AND EXISTS (
        SELECT 1 FROM Turismo.Visitante
        WHERE IdVisitante <> @IdVisitante
          AND CONVERT(VARCHAR(15), DecryptByPassPhrase(@FraseClave, CUIT, 1, CONVERT(VARBINARY, IdVisitante))) = @CUIT
    )
        SET @errores += 'Ya existe otro visitante con ese CUIT.' + CHAR(13)

    IF @errores <> ''
    BEGIN
        SET @errores = 'No se pudo modificar al visitante:' + CHAR(13) + @errores;
        THROW 50000, @errores, 1
    END

    UPDATE Turismo.Visitante
    SET Telefono = COALESCE(@Telefono, Telefono),
        CorreoVisitante = COALESCE(@CorreoVisitante, CorreoVisitante),
        NumeroDocumento = COALESCE(EncryptByPassPhrase(@FraseClave, @NumeroDocumento, 1, CONVERT(VARBINARY, @IdVisitante)), NumeroDocumento),
        TipoDocumento = COALESCE(@TipoDocumento, TipoDocumento),
        CUIT = COALESCE(EncryptByPassPhrase(@FraseClave, @CUIT, 1, CONVERT(VARBINARY, @IdVisitante)), CUIT),
        Edad = COALESCE(@Edad, Edad),
        Nombre = COALESCE(@Nombre, Nombre),
        Apellido = COALESCE(@Apellido, Apellido),
        IdTipoVisitante = COALESCE(@IdTipoVisitante, IdTipoVisitante)
    WHERE IdVisitante = @IdVisitante;
END
GO

-- ====================================================================
-- 5) SP de ABM actualizados: Personal.Guia
-- ====================================================================

CREATE OR ALTER PROCEDURE USP_AltaGuia
    @Telefono VARCHAR(20),
    @CorreoGuia VARCHAR(100),
    @NumeroDocumento VARCHAR(15),
    @TipoDocumento VARCHAR(15),
    @Edad TINYINT,
    @Apellido VARCHAR(50),
    @Nombre VARCHAR(50),
    @Titulo VARCHAR(50),
    @Especialidad VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @errores VARCHAR(2048) = ''
    DECLARE @FraseClave VARCHAR(128) = 'ParquesNacionales_Cifrado_TP'
    DECLARE @IdGuia INT

    IF EXISTS (
        SELECT 1 FROM Personal.Guia
        WHERE CONVERT(VARCHAR(15), DecryptByPassPhrase(@FraseClave, NumeroDocumento, 1, CONVERT(VARBINARY, IdGuia))) = @NumeroDocumento
    )
        SET @errores += '- El guía con documento ' + @NumeroDocumento + ' ya existe.' + CHAR(13)

    IF EXISTS (SELECT 1 FROM Personal.Guia WHERE CorreoGuia = @CorreoGuia)
        SET @errores += '- El correo ' + @CorreoGuia + ' ya existe.' + CHAR(13)

    IF @errores <> ''
    BEGIN
        SET @errores = 'No se pudo dar de alta el guía:' + CHAR(13) + @errores;
        THROW 50000, @errores, 1
    END

    BEGIN TRANSACTION
        INSERT INTO Personal.Guia (Telefono, CorreoGuia, NumeroDocumento, TipoDocumento, Edad, Apellido, Nombre, Titulo, Especialidad)
        VALUES (@Telefono, @CorreoGuia, CONVERT(VARBINARY(256), @NumeroDocumento), @TipoDocumento, @Edad, @Apellido, @Nombre, @Titulo, @Especialidad);

        SET @IdGuia = SCOPE_IDENTITY();

        UPDATE Personal.Guia
        SET NumeroDocumento = EncryptByPassPhrase(@FraseClave, @NumeroDocumento, 1, CONVERT(VARBINARY, @IdGuia))
        WHERE IdGuia = @IdGuia;
    COMMIT TRANSACTION

    PRINT 'Guia creado correctamente.'
END;
GO

CREATE OR ALTER PROCEDURE USP_ModificacionGuia
    @IdGuia INT,
    @Telefono VARCHAR(20) = NULL,
    @CorreoGuia VARCHAR(100) = NULL,
    @NumeroDocumento VARCHAR(15) = NULL,
    @TipoDocumento VARCHAR(15) = NULL,
    @Edad TINYINT = NULL,
    @Apellido VARCHAR(50) = NULL,
    @Nombre VARCHAR(50) = NULL,
    @Titulo VARCHAR(50) = NULL,
    @Especialidad VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @errores VARCHAR(2048) = ''
    DECLARE @FraseClave VARCHAR(128) = 'ParquesNacionales_Cifrado_TP'

    IF NOT EXISTS (SELECT 1 FROM Personal.Guia WHERE IdGuia = @IdGuia)
        SET @errores += '- El guía con id ' + CAST(@IdGuia AS VARCHAR) + ' no existe.' + CHAR(13)

    IF @NumeroDocumento IS NOT NULL AND EXISTS (
        SELECT 1 FROM Personal.Guia
        WHERE IdGuia <> @IdGuia
          AND CONVERT(VARCHAR(15), DecryptByPassPhrase(@FraseClave, NumeroDocumento, 1, CONVERT(VARBINARY, IdGuia))) = @NumeroDocumento
    )
        SET @errores += '- El guía con documento ' + @NumeroDocumento + ' ya existe.' + CHAR(13)

    IF @errores <> ''
    BEGIN
        SET @errores = 'No se pudo modificar el guía:' + CHAR(13) + @errores;
        THROW 50000, @errores, 1
    END

    UPDATE Personal.Guia
    SET Telefono       = ISNULL(@Telefono, Telefono),
        CorreoGuia      = ISNULL(@CorreoGuia, CorreoGuia),
        NumeroDocumento = ISNULL(EncryptByPassPhrase(@FraseClave, @NumeroDocumento, 1, CONVERT(VARBINARY, @IdGuia)), NumeroDocumento),
        TipoDocumento   = ISNULL(@TipoDocumento, TipoDocumento),
        Edad            = ISNULL(@Edad, Edad),
        Apellido        = ISNULL(@Apellido, Apellido),
        Nombre          = ISNULL(@Nombre, Nombre),
        Titulo          = ISNULL(@Titulo, Titulo),
        Especialidad    = ISNULL(@Especialidad, Especialidad)
    WHERE IdGuia = @IdGuia

    PRINT 'Guia actualizado correctamente.'
END;
GO

-- ====================================================================
-- 6) SP de ABM actualizados: Personal.Guardaparque
-- ====================================================================

CREATE OR ALTER PROCEDURE USP_AltaGuardaparque
    @Telefono VARCHAR(20),
    @CorreoGuardaparque VARCHAR(100),
    @NumeroDocumento VARCHAR(15),
    @TipoDocumento VARCHAR(15),
    @Edad TINYINT,
    @Apellido VARCHAR(50),
    @Nombre VARCHAR(50),
    @Estado VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @errores VARCHAR(2048) = ''
    DECLARE @FraseClave VARCHAR(128) = 'ParquesNacionales_Cifrado_TP'
    DECLARE @IdGuardaparque INT

    IF EXISTS (
        SELECT 1 FROM Personal.Guardaparque
        WHERE CONVERT(VARCHAR(15), DecryptByPassPhrase(@FraseClave, NumeroDocumento, 1, CONVERT(VARBINARY, IdGuardaparque))) = @NumeroDocumento
    )
        SET @errores += '- El guardaparque con documento ' + @NumeroDocumento + ' ya existe.' + CHAR(13)

    IF EXISTS (SELECT 1 FROM Personal.Guardaparque WHERE CorreoGuardaparque = @CorreoGuardaparque)
        SET @errores += '- El guardaparque con correo ' + @CorreoGuardaparque + ' ya existe.' + CHAR(13)

    IF @errores <> ''
    BEGIN
        SET @errores = 'No se pudo dar de alta el guardaparque:' + CHAR(13) + @errores;
        THROW 50000, @errores, 1
    END

    BEGIN TRANSACTION
        INSERT INTO Personal.Guardaparque (Telefono, CorreoGuardaparque, NumeroDocumento, TipoDocumento, Edad, Apellido, Nombre, Estado)
        VALUES (@Telefono, @CorreoGuardaparque, CONVERT(VARBINARY(256), @NumeroDocumento), @TipoDocumento, @Edad, @Apellido, @Nombre, @Estado)

        SET @IdGuardaparque = SCOPE_IDENTITY();

        UPDATE Personal.Guardaparque
        SET NumeroDocumento = EncryptByPassPhrase(@FraseClave, @NumeroDocumento, 1, CONVERT(VARBINARY, @IdGuardaparque))
        WHERE IdGuardaparque = @IdGuardaparque;
    COMMIT TRANSACTION

    PRINT 'Guardaparque creado correctamente.'
END;
GO

CREATE OR ALTER PROCEDURE USP_ModificacionGuardaparque
    @IdGuardaparque INT,
    @Telefono VARCHAR(20) = NULL,
    @CorreoGuardaparque VARCHAR(100) = NULL,
    @NumeroDocumento VARCHAR(15) = NULL,
    @TipoDocumento VARCHAR(15) = NULL,
    @Edad TINYINT = NULL,
    @Apellido VARCHAR(50) = NULL,
    @Nombre VARCHAR(50) = NULL,
    @Estado VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @errores VARCHAR(2048) = ''
    DECLARE @FraseClave VARCHAR(128) = 'ParquesNacionales_Cifrado_TP'

    IF NOT EXISTS (SELECT 1 FROM Personal.Guardaparque WHERE IdGuardaparque = @IdGuardaparque)
        SET @errores += '- El guardaparque con id ' + CAST(@IdGuardaparque AS VARCHAR) + ' no existe.' + CHAR(13)

    IF @NumeroDocumento IS NOT NULL AND EXISTS (
        SELECT 1 FROM Personal.Guardaparque
        WHERE IdGuardaparque <> @IdGuardaparque
          AND CONVERT(VARCHAR(15), DecryptByPassPhrase(@FraseClave, NumeroDocumento, 1, CONVERT(VARBINARY, IdGuardaparque))) = @NumeroDocumento
    )
        SET @errores += '- El guardaparque con documento ' + @NumeroDocumento + ' ya existe.' + CHAR(13)

    IF @errores <> ''
    BEGIN
        SET @errores = 'No se pudo modificar el guardaparque:' + CHAR(13) + @errores;
        THROW 50000, @errores, 1
    END

    UPDATE Personal.Guardaparque
    SET Telefono            = ISNULL(@Telefono, Telefono),
        CorreoGuardaparque  = ISNULL(@CorreoGuardaparque, CorreoGuardaparque),
        NumeroDocumento     = ISNULL(EncryptByPassPhrase(@FraseClave, @NumeroDocumento, 1, CONVERT(VARBINARY, @IdGuardaparque)), NumeroDocumento),
        TipoDocumento       = ISNULL(@TipoDocumento, TipoDocumento),
        Edad                = ISNULL(@Edad, Edad),
        Apellido            = ISNULL(@Apellido, Apellido),
        Nombre              = ISNULL(@Nombre, Nombre),
        Estado              = ISNULL(@Estado, Estado)
    WHERE IdGuardaparque = @IdGuardaparque

    PRINT 'Guardaparque modificado correctamente.'
END;
GO

-- ====================================================================
-- 7) SP de ABM actualizados: Concesiones.OrganizacionConcesionaria
-- ====================================================================

CREATE OR ALTER PROCEDURE USP_AltaOrganizacionConcesionaria
    @Nombre VARCHAR(50),
    @TipoActividad VARCHAR(50),
    @Cuit CHAR(11),
    @CorreoContacto VARCHAR(100) = NULL,
    @TelefonoContacto VARCHAR(20) = NULL,
    @DomicilioRegistrado VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON
    SET XACT_ABORT ON

    DECLARE @IdOrganizacionConcesionaria INT
    DECLARE @errores VARCHAR(2048) = ''
    DECLARE @FraseClave VARCHAR(128) = 'ParquesNacionales_Cifrado_TP'

    IF EXISTS (
        SELECT 1 FROM Concesiones.OrganizacionConcesionaria
        WHERE CONVERT(VARCHAR(11), DecryptByPassPhrase(@FraseClave, Cuit, 1, CONVERT(VARBINARY, IdOrganizacionConcesionaria))) = @Cuit
    )
        SET @errores += '- El CUIT ingresado ya existe.' + CHAR(13)

    IF @errores <> ''
    BEGIN
        SET @errores = 'No se pudo dar de alta la organización concesionaria:' + CHAR(13) + @errores;
        THROW 50000, @errores, 1
    END

    BEGIN TRANSACTION
        INSERT INTO Concesiones.OrganizacionConcesionaria
            (Nombre, TipoActividad, Cuit, CorreoContacto, TelefonoContacto, DomicilioRegistrado)
        VALUES
            (@Nombre, @TipoActividad, CONVERT(VARBINARY(256), @Cuit), @CorreoContacto, @TelefonoContacto, @DomicilioRegistrado)
        SELECT @IdOrganizacionConcesionaria = SCOPE_IDENTITY()

        UPDATE Concesiones.OrganizacionConcesionaria
        SET Cuit = EncryptByPassPhrase(@FraseClave, @Cuit, 1, CONVERT(VARBINARY, @IdOrganizacionConcesionaria))
        WHERE IdOrganizacionConcesionaria = @IdOrganizacionConcesionaria
    COMMIT TRANSACTION

    PRINT 'La organización concesionaria ' + CAST(@IdOrganizacionConcesionaria AS VARCHAR) + ' fue creada con éxito'
END
GO

CREATE OR ALTER PROCEDURE USP_ModificacionOrganizacionConcesionaria
    @IdOrganizacionConcesionaria INT,
    @Cuit CHAR(11) = NULL,
    @Nombre VARCHAR(50) = NULL,
    @TipoActividad VARCHAR(50) = NULL,
    @CorreoContacto VARCHAR(100) = NULL,
    @TelefonoContacto VARCHAR(20) = NULL,
    @DomicilioRegistrado VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON
    SET XACT_ABORT ON

    DECLARE @CambioValidoCuit BIT = 0
    DECLARE @errores VARCHAR(2048) = ''
    DECLARE @FraseClave VARCHAR(128) = 'ParquesNacionales_Cifrado_TP'

    IF NOT EXISTS (SELECT 1 FROM Concesiones.OrganizacionConcesionaria WHERE IdOrganizacionConcesionaria = @IdOrganizacionConcesionaria)
        SET @errores += '- La organización concesionaria indicada no existe.' + CHAR(13)

    IF @errores <> ''
    BEGIN
        SET @errores = 'No se pudo modificar la organización concesionaria:' + CHAR(13) + @errores;
        THROW 50000, @errores, 1
    END

    IF @Cuit IS NOT NULL
    BEGIN
        IF EXISTS (
            SELECT 1 FROM Concesiones.OrganizacionConcesionaria
            WHERE IdOrganizacionConcesionaria <> @IdOrganizacionConcesionaria
              AND CONVERT(VARCHAR(11), DecryptByPassPhrase(@FraseClave, Cuit, 1, CONVERT(VARBINARY, IdOrganizacionConcesionaria))) = @Cuit
        )
            PRINT 'El CUIT ingresado ya existe, por lo que no se cambiará dicho campo'
        ELSE
            SET @CambioValidoCuit = 1
    END

    BEGIN TRANSACTION
        UPDATE Concesiones.OrganizacionConcesionaria
        SET
            Cuit                = IIF(@CambioValidoCuit = 0, Cuit, EncryptByPassPhrase(@FraseClave, @Cuit, 1, CONVERT(VARBINARY, @IdOrganizacionConcesionaria))),
            Nombre              = ISNULL(@Nombre, Nombre),
            TipoActividad       = ISNULL(@TipoActividad, TipoActividad),
            CorreoContacto      = ISNULL(@CorreoContacto, CorreoContacto),
            TelefonoContacto    = ISNULL(@TelefonoContacto, TelefonoContacto),
            DomicilioRegistrado = ISNULL(@DomicilioRegistrado, DomicilioRegistrado)
        WHERE IdOrganizacionConcesionaria = @IdOrganizacionConcesionaria
    COMMIT TRANSACTION

    PRINT 'La organización concesionaria ' + CAST(@IdOrganizacionConcesionaria AS VARCHAR) + ' fue actualizada con éxito'
END
GO

-- ====================================================================
-- 8) SP de consulta (descifrado) - solo para rol_admin
-- ====================================================================

/*
EXEC USP_ConsultaVisitantePorId 1;
*/
CREATE OR ALTER PROCEDURE USP_ConsultaVisitantePorId
    @IdVisitante INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FraseClave VARCHAR(128) = 'ParquesNacionales_Cifrado_TP'

    SELECT
        IdVisitante,
        Nombre,
        Apellido,
        CONVERT(VARCHAR(15), DecryptByPassPhrase(@FraseClave, NumeroDocumento, 1, CONVERT(VARBINARY, IdVisitante))) AS NumeroDocumento,
        TipoDocumento,
        CONVERT(VARCHAR(15), DecryptByPassPhrase(@FraseClave, CUIT, 1, CONVERT(VARBINARY, IdVisitante))) AS CUIT,
        Telefono,
        CorreoVisitante,
        Edad,
        IdTipoVisitante
    FROM Turismo.Visitante
    WHERE IdVisitante = @IdVisitante;
END
GO

/*
EXEC USP_ConsultaGuiaPorId 1;
*/
CREATE OR ALTER PROCEDURE USP_ConsultaGuiaPorId
    @IdGuia INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FraseClave VARCHAR(128) = 'ParquesNacionales_Cifrado_TP'

    SELECT
        IdGuia,
        Nombre,
        Apellido,
        CONVERT(VARCHAR(15), DecryptByPassPhrase(@FraseClave, NumeroDocumento, 1, CONVERT(VARBINARY, IdGuia))) AS NumeroDocumento,
        TipoDocumento,
        Telefono,
        CorreoGuia,
        Edad,
        Titulo,
        Especialidad
    FROM Personal.Guia
    WHERE IdGuia = @IdGuia;
END
GO

/*
EXEC USP_ConsultaGuardaparquePorId 1;
*/
CREATE OR ALTER PROCEDURE USP_ConsultaGuardaparquePorId
    @IdGuardaparque INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FraseClave VARCHAR(128) = 'ParquesNacionales_Cifrado_TP'

    SELECT
        IdGuardaparque,
        Nombre,
        Apellido,
        CONVERT(VARCHAR(15), DecryptByPassPhrase(@FraseClave, NumeroDocumento, 1, CONVERT(VARBINARY, IdGuardaparque))) AS NumeroDocumento,
        TipoDocumento,
        Telefono,
        CorreoGuardaparque,
        Edad,
        Estado
    FROM Personal.Guardaparque
    WHERE IdGuardaparque = @IdGuardaparque;
END
GO

/*
EXEC USP_ConsultaOrganizacionConcesionariaPorId 1;
*/
CREATE OR ALTER PROCEDURE USP_ConsultaOrganizacionConcesionariaPorId
    @IdOrganizacionConcesionaria INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FraseClave VARCHAR(128) = 'ParquesNacionales_Cifrado_TP'

    SELECT
        IdOrganizacionConcesionaria,
        Nombre,
        TipoActividad,
        CONVERT(VARCHAR(11), DecryptByPassPhrase(@FraseClave, Cuit, 1, CONVERT(VARBINARY, IdOrganizacionConcesionaria))) AS Cuit,
        CorreoContacto,
        TelefonoContacto,
        DomicilioRegistrado
    FROM Concesiones.OrganizacionConcesionaria
    WHERE IdOrganizacionConcesionaria = @IdOrganizacionConcesionaria;
END
GO

-- ====================================================================
-- 9) SP de importación actualizado: USP_ImportarOrganizacionConcesionaria
-- ====================================================================

------------------------------------------------------------------
-- USP_ImportarOrganizacionConcesionaria
------------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_ImportarOrganizacionConcesionaria
    @rutaArchivo VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    ------------------------------------------------------------------
    -- 0) Staging: carga cruda desde el Excel, tal cual viene
    ------------------------------------------------------------------
    CREATE TABLE #StagingConcesionXlsx (
        NroFila  INT IDENTITY(1,1) PRIMARY KEY,
        TipoFila VARCHAR(20),
        Col1     VARCHAR(200),
        Col2     VARCHAR(200),
        Col3     VARCHAR(200),
        Col4     VARCHAR(200),
        Col5     VARCHAR(300),
        Col6     VARCHAR(50),
        Col7     VARCHAR(50),
        NombreParqueOrigen VARCHAR(200) NULL
    );

    INSERT INTO #StagingConcesionXlsx (Col1, Col2, Col3, Col4, Col5, Col6, Col7)
    EXEC('
        SELECT *
        FROM OPENROWSET(''Microsoft.ACE.OLEDB.16.0'',
            ''Excel 12.0;Database=' + @rutaArchivo + ';HDR=NO'',
            ''SELECT * FROM [Hoja1$]'')');

    UPDATE #StagingConcesionXlsx
    SET TipoFila =
        CASE
            WHEN TRIM(Col1) = 'RAZON SOCIAL' THEN 'ENCABEZADO_COL'
            WHEN Col1 IS NOT NULL AND Col2 IS NULL AND Col3 IS NULL THEN 'NOMBRE_PARQUE'
            WHEN Col3 IS NOT NULL THEN 'DATO'
            ELSE 'DESCONOCIDA'
        END;

    -- Cada fila DATO hereda el NOMBRE_PARQUE más reciente por encima de ella
    -- (arrastre hacia adelante por NroFila). El archivo agrupa por secciones:
    -- una fila NOMBRE_PARQUE, seguida de su ENCABEZADO_COL, seguida de N filas DATO.
    UPDATE s
    SET s.NombreParqueOrigen = pq.NombreParqueMasReciente
    FROM #StagingConcesionXlsx s
    CROSS APPLY (
        SELECT TOP(1) Col1 AS NombreParqueMasReciente
        FROM #StagingConcesionXlsx anterior
        WHERE anterior.TipoFila = 'NOMBRE_PARQUE'
          AND anterior.NroFila < s.NroFila
        ORDER BY anterior.NroFila DESC
    ) pq
    WHERE s.TipoFila = 'DATO';

    -- log para esta ejecución (se persiste al final, también se devuelve como resultado)
    CREATE TABLE #LogEjecucionActual (
        TipoEvento        VARCHAR(30),
        CuitOrigen        VARCHAR(50),
        RazonSocialOrigen VARCHAR(200),
        Motivo            VARCHAR(500)
    );

    ------------------------------------------------------------------
    -- 0.2) Cifrado: Concesiones.OrganizacionConcesionaria.Cuit es
    --      VARBINARY (cifrado con EncryptByPassPhrase). Como no es
    --      determinístico, no se puede comparar cifrado contra el CUIT
    --      en texto plano del archivo; se descifra una sola vez acá y
    --      se compara/joinea por ese valor en el resto del SP.
    ------------------------------------------------------------------
    DECLARE @FraseClave VARCHAR(128) = 'ParquesNacionales_Cifrado_TP';

    SELECT
        IdOrganizacionConcesionaria + 0 AS IdOrganizacionConcesionaria, -- rompe la herencia de IDENTITY (ver Test 14/nota más abajo)
        CONVERT(VARCHAR(11), DecryptByPassPhrase(@FraseClave, Cuit, 1, CONVERT(VARBINARY, IdOrganizacionConcesionaria))) AS CuitDescifrado
    INTO #OrgConcesionariaDescifrado
    FROM Concesiones.OrganizacionConcesionaria;

    ------------------------------------------------------------------
    -- 1) Deduplicar dentro del archivo: por Cuit, gana la primera aparición
    ------------------------------------------------------------------
    SELECT
        TRIM(Col1) AS RazonSocial,
        TRIM(Col3) AS Cuit,
        TRIM(Col5) AS TipoActividad,
        Concesiones.FN_NormalizarNombreParque(NombreParqueOrigen) AS NombreParqueNormalizado,
        TRY_CAST(TRIM(Col6) AS DATE) AS FechaInicio,
        TRY_CAST(TRIM(Col7) AS DATE) AS FechaFin,
        ROW_NUMBER() OVER (PARTITION BY TRIM(Col3) ORDER BY NroFila) AS Orden
    INTO #OrganizacionesLimpias
    FROM #StagingConcesionXlsx
    WHERE TipoFila = 'DATO';

    INSERT INTO #LogEjecucionActual (TipoEvento, CuitOrigen, RazonSocialOrigen, Motivo)
    SELECT 'DUPLICADO', Cuit, RazonSocial,
           'CUIT repetido en el archivo; se utilizó la primera aparición.'
    FROM #OrganizacionesLimpias
    WHERE Orden > 1;

    ------------------------------------------------------------------
    -- 2) Validar y acumular motivos de rechazo por fila
    --    (contra los NOT NULL / largos de OrganizacionConcesionaria)
    ------------------------------------------------------------------
    SELECT
        ol.*,
        LTRIM(RTRIM(
            ISNULL(CASE WHEN LTRIM(RTRIM(ISNULL(ol.Cuit,''))) = '' THEN 'CUIT vacío. ' END,'') +
            ISNULL(CASE WHEN LTRIM(RTRIM(ISNULL(ol.Cuit,''))) <> '' AND LEN(LTRIM(RTRIM(ol.Cuit))) <> 11 THEN 'CUIT debe tener 11 caracteres. ' END,'') +
            ISNULL(CASE WHEN LTRIM(RTRIM(ISNULL(ol.Cuit,''))) <> '' AND LTRIM(RTRIM(ol.Cuit)) LIKE '%[^0-9]%' THEN 'CUIT contiene caracteres no numéricos. ' END,'') +
            ISNULL(CASE WHEN LTRIM(RTRIM(ISNULL(ol.RazonSocial,''))) = '' THEN 'Razón social vacía. ' END,'') +
            ISNULL(CASE WHEN LEN(LTRIM(RTRIM(ISNULL(ol.RazonSocial,'')))) > 50 THEN 'Razón social excede 50 caracteres. ' END,'') +
            ISNULL(CASE WHEN LTRIM(RTRIM(ISNULL(ol.TipoActividad,''))) = '' THEN 'Tipo de actividad vacío. ' END,'') +
            ISNULL(CASE WHEN LEN(LTRIM(RTRIM(ISNULL(ol.TipoActividad,'')))) > 200 THEN 'Tipo de actividad excede 200 caracteres. ' END,'')
        )) AS Motivo
    INTO #Validacion
    FROM #OrganizacionesLimpias ol
    WHERE ol.Orden = 1;

    INSERT INTO #LogEjecucionActual (TipoEvento, CuitOrigen, RazonSocialOrigen, Motivo)
    SELECT 'ERROR_VALIDACION', Cuit, RazonSocial, Motivo
    FROM #Validacion
    WHERE Motivo <> '';

    SELECT Cuit, RazonSocial, TipoActividad
    INTO #Validos
    FROM #Validacion
    WHERE Motivo = '';

    -- contador de nuevos ANTES del upsert
    DECLARE @aInsertar INT = (
        SELECT COUNT(*) FROM #Validos v
        WHERE NOT EXISTS (
            SELECT 1 FROM #OrgConcesionariaDescifrado ocd
            WHERE ocd.CuitDescifrado = v.Cuit COLLATE DATABASE_DEFAULT
        )
    );

    ------------------------------------------------------------------
    -- 3) Upsert contra Concesiones.OrganizacionConcesionaria por Cuit
    ------------------------------------------------------------------
    SET XACT_ABORT ON;
    DECLARE @maxIdOrgPrevio INT = ISNULL((SELECT MAX(IdOrganizacionConcesionaria) FROM Concesiones.OrganizacionConcesionaria), 0);

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE oc
            SET oc.Nombre        = v.RazonSocial,
                oc.TipoActividad = v.TipoActividad
        FROM Concesiones.OrganizacionConcesionaria oc
        INNER JOIN #OrgConcesionariaDescifrado ocd ON ocd.IdOrganizacionConcesionaria = oc.IdOrganizacionConcesionaria
        INNER JOIN #Validos v ON ocd.CuitDescifrado = v.Cuit COLLATE DATABASE_DEFAULT;

        -- Igual que en 0.2: se inserta con el CUIT en bytes crudos y se cifra en el
        -- UPDATE siguiente, ya con el Id real como autenticador, dentro de la misma
        -- transacción (nadie fuera de ella ve el CUIT en texto plano en la tabla).
        INSERT INTO Concesiones.OrganizacionConcesionaria (Cuit, Nombre, TipoActividad)
        SELECT CONVERT(VARBINARY(256), v.Cuit), v.RazonSocial, v.TipoActividad
        FROM #Validos v
        WHERE NOT EXISTS (
            SELECT 1 FROM #OrgConcesionariaDescifrado ocd
            WHERE ocd.CuitDescifrado = v.Cuit COLLATE DATABASE_DEFAULT
        );

        UPDATE oc
        SET oc.Cuit = EncryptByPassPhrase(@FraseClave, CONVERT(VARCHAR(11), oc.Cuit), 1, CONVERT(VARBINARY, oc.IdOrganizacionConcesionaria))
        FROM Concesiones.OrganizacionConcesionaria oc
        WHERE oc.IdOrganizacionConcesionaria > @maxIdOrgPrevio;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO #LogEjecucionActual (TipoEvento, Motivo)
        VALUES ('ERROR_VALIDACION', 'Error inesperado al aplicar el upsert: ' + ERROR_MESSAGE());
    END CATCH

    -- La tabla de CUIT descifrados quedó desactualizada por el upsert recién hecho
    -- (organizaciones nuevas, y las existentes no cambiaron su Cuit). Se recarga para
    -- que los pasos 5 y 7 (que también resuelven por Cuit) vean el estado actual.
    -- Este INSERT explícito de IdOrganizacionConcesionaria solo funciona porque la
    -- columna se creó con "+ 0" más arriba (si no, al heredar IDENTITY de la tabla
    -- original, este INSERT pediría SET IDENTITY_INSERT ON).
    TRUNCATE TABLE #OrgConcesionariaDescifrado;
    INSERT INTO #OrgConcesionariaDescifrado (IdOrganizacionConcesionaria, CuitDescifrado)
    SELECT
        IdOrganizacionConcesionaria,
        CONVERT(VARCHAR(11), DecryptByPassPhrase(@FraseClave, Cuit, 1, CONVERT(VARBINARY, IdOrganizacionConcesionaria)))
    FROM Concesiones.OrganizacionConcesionaria;

    ------------------------------------------------------------------
    -- 4) Agrupar por organización distinta dentro de cada parque:
    --    una Concesion por combinación (Parque, Cuit), sin importar
    --    cuántas filas/actividades tenga esa organización en el
    --    archivo para ese parque. Solo entran organizaciones que ya
    --    pasaron la validación del paso 2 (#Validos)
    ------------------------------------------------------------------
    SELECT
        ol.NombreParqueNormalizado,
        ol.Cuit,
        MIN(ol.FechaInicio) AS FechaInicio,
        MAX(ol.FechaFin)    AS FechaFin,
        COUNT(*)            AS CantidadActividadesEnArchivo
    INTO #OrganizacionesPorParque
    FROM #OrganizacionesLimpias ol
    INNER JOIN #Validos v ON v.Cuit = ol.Cuit COLLATE DATABASE_DEFAULT
    WHERE ol.NombreParqueNormalizado IS NOT NULL
    GROUP BY ol.NombreParqueNormalizado, ol.Cuit;

    -- Fechas inválidas: Desde/Hasta no parseables, o Hasta anterior a Desde.
    INSERT INTO #LogEjecucionActual (TipoEvento, CuitOrigen, RazonSocialOrigen, Motivo)
    SELECT 'ERROR_VALIDACION', opp.Cuit, v.RazonSocial,
           CASE
               WHEN opp.FechaInicio IS NULL THEN 'Fecha de inicio (Desde) no pudo interpretarse como fecha válida.'
               WHEN opp.FechaFin IS NULL THEN 'Fecha de fin (Hasta) no pudo interpretarse como fecha válida.'
               ELSE 'Fecha de fin (Hasta) es anterior a la fecha de inicio.'
           END
    FROM #OrganizacionesPorParque opp
    INNER JOIN #Validos v ON v.Cuit = opp.Cuit COLLATE DATABASE_DEFAULT
    WHERE opp.FechaInicio IS NULL
       OR opp.FechaFin IS NULL
       OR opp.FechaFin < opp.FechaInicio;

    DELETE FROM #OrganizacionesPorParque
    WHERE FechaInicio IS NULL
       OR FechaFin IS NULL
       OR FechaFin < FechaInicio;

    ------------------------------------------------------------------
    -- 5) Resolver IdParque contra Parques.Parque (comparación sin
    --    tildes/mayúsculas) y calcular ExtensionConcedida: 10% de la
    --    Superficie del parque, menos lo ya concedido, repartido entre
    --    las organizaciones NUEVAS de ese parque (las que ya tienen
    --    Concesion ahí no cuentan ni consumen cupo de nuevo).
    ------------------------------------------------------------------
    SELECT
        opp.NombreParqueNormalizado,
        opp.Cuit,
        opp.FechaInicio,
        opp.FechaFin,
        p.IdParque,
        CASE WHEN EXISTS (
            SELECT 1 FROM Concesiones.Concesion c
            INNER JOIN #OrgConcesionariaDescifrado ocd ON ocd.IdOrganizacionConcesionaria = c.IdOrganizacionConcesionaria
            WHERE c.IdParque = p.IdParque AND ocd.CuitDescifrado = opp.Cuit COLLATE DATABASE_DEFAULT
        ) THEN 1 ELSE 0 END AS YaTieneConcesion
    INTO #OrganizacionesConParque
    FROM #OrganizacionesPorParque opp
    LEFT JOIN Parques.Parque p
        ON UPPER(TRANSLATE(p.Nombre, 'ÁÉÍÓÚáéíóú', 'AEIOUaeiou'))
         = UPPER(TRANSLATE(opp.NombreParqueNormalizado, 'ÁÉÍÓÚáéíóú', 'AEIOUaeiou'));

    -- Sin match de parque: la organización ya se creó/actualizó en el paso 3,
    -- acá solo dejamos constancia de que no hay concesión posible para ella.
    INSERT INTO #LogEjecucionActual (TipoEvento, CuitOrigen, RazonSocialOrigen, Motivo)
    SELECT 'SIN_MATCH_PARQUE', ocp.Cuit, v.RazonSocial,
           CONCAT('No se encontró el parque ''', ocp.NombreParqueNormalizado, ''' en Parques.Parque; se creó/actualizó solo la organización.')
    FROM #OrganizacionesConParque ocp
    INNER JOIN #Validos v ON v.Cuit = ocp.Cuit COLLATE DATABASE_DEFAULT
    WHERE ocp.IdParque IS NULL;

    -- Parques con al menos una organización nueva (matcheada, sin Concesion previa).
    SELECT DISTINCT ocp.IdParque
    INTO #ParquesConNuevas
    FROM #OrganizacionesConParque ocp
    WHERE ocp.IdParque IS NOT NULL AND ocp.YaTieneConcesion = 0;

    SELECT
        pcn.IdParque,
        p.Superficie * 0.10 AS LimiteHectareas,
        ISNULL((SELECT SUM(c.ExtensionConcedida) FROM Concesiones.Concesion c WHERE c.IdParque = pcn.IdParque), 0) AS YaConcedidas,
        (SELECT COUNT(*) FROM #OrganizacionesConParque x WHERE x.IdParque = pcn.IdParque AND x.YaTieneConcesion = 0) AS CantidadOrgsNuevas
    INTO #ResumenPorParque
    FROM #ParquesConNuevas pcn
    INNER JOIN Parques.Parque p ON p.IdParque = pcn.IdParque;

    ALTER TABLE #ResumenPorParque ADD Disponible DECIMAL(10,2), ExtensionPorConcesion DECIMAL(10,2);

    UPDATE #ResumenPorParque SET Disponible = LimiteHectareas - YaConcedidas;

    UPDATE #ResumenPorParque
    SET ExtensionPorConcesion = CASE WHEN Disponible > 0 AND CantidadOrgsNuevas > 0
                                      THEN Disponible / CantidadOrgsNuevas END;

    INSERT INTO #LogEjecucionActual (TipoEvento, Motivo)
    SELECT 'LIMITE_HECTAREAS_ALCANZADO',
           CONCAT('IdParque=', IdParque, ' sin cupo disponible (límite 10%: ', LimiteHectareas,
                  ' ha, ya concedidas: ', YaConcedidas, ' ha) para ', CantidadOrgsNuevas, ' organización(es) nueva(s).')
    FROM #ResumenPorParque
    WHERE Disponible <= 0;

    ALTER TABLE #OrganizacionesConParque ADD ExtensionConcedida DECIMAL(10,2);

    UPDATE ocp
    SET ocp.ExtensionConcedida = rp.ExtensionPorConcesion
    FROM #OrganizacionesConParque ocp
    INNER JOIN #ResumenPorParque rp ON rp.IdParque = ocp.IdParque
    WHERE ocp.YaTieneConcesion = 0;

    ------------------------------------------------------------------
    -- 6) CanonMensual = ExtensionConcedida × CostoHectarea × (1 + feriados exactos en el rango Desde-Hasta / días del contrato)
    ------------------------------------------------------------------
    ALTER TABLE #OrganizacionesConParque ADD CanonMensual DECIMAL(10,2), CantidadFeriados INT, Procesado BIT NOT NULL DEFAULT(0);

    UPDATE #OrganizacionesConParque
    SET Procesado = 1
    WHERE YaTieneConcesion = 1 OR ExtensionConcedida IS NULL;
    -- ya tienen concesión o no tienen cupo: no calculan canon, quedan marcadas para no entrar al loop

    DECLARE @cuitActual VARCHAR(11), @idParqueActual INT, @fechaInicioActual DATE, @fechaFinActual DATE;
    DECLARE @feriadosContrato INT, @diasContrato INT, @extensionActual DECIMAL(10,2), @costoHectareaActual DECIMAL(10,2);

    WHILE EXISTS (SELECT 1 FROM #OrganizacionesConParque WHERE Procesado = 0)
    BEGIN
        SELECT TOP(1)
            @cuitActual = ocp.Cuit, @idParqueActual = ocp.IdParque,
            @fechaInicioActual = ocp.FechaInicio, @fechaFinActual = ocp.FechaFin,
            @extensionActual = ocp.ExtensionConcedida, @costoHectareaActual = p.CostoHectarea
        FROM #OrganizacionesConParque ocp
        INNER JOIN Parques.Parque p ON p.IdParque = ocp.IdParque
        WHERE ocp.Procesado = 0;

        SET @feriadosContrato = NULL;

        BEGIN TRY
            EXEC USP_ObtenerFeriadosEnRango @fechaInicioActual, @fechaFinActual, @feriadosContrato OUTPUT;
        END TRY
        BEGIN CATCH
            INSERT INTO #LogEjecucionActual (TipoEvento, CuitOrigen, Motivo)
            VALUES ('ERROR_FERIADOS', @cuitActual, 'Falló el cálculo de feriados para el canon: ' + ERROR_MESSAGE());
        END CATCH

        SET @feriadosContrato = ISNULL(@feriadosContrato, 0);
        SET @diasContrato = DATEDIFF(DAY, @fechaInicioActual, @fechaFinActual) + 1;

        UPDATE #OrganizacionesConParque
        SET CantidadFeriados = @feriadosContrato,
            CanonMensual = @extensionActual * @costoHectareaActual
                * (1 + CAST(@feriadosContrato AS DECIMAL(10,4)) / @diasContrato),
            Procesado = 1
        WHERE Cuit = @cuitActual COLLATE DATABASE_DEFAULT AND IdParque = @idParqueActual;
    END

    ------------------------------------------------------------------
    -- 7) INSERT final a Concesiones.Concesion: solo organizaciones
    --    nuevas que efectivamente calcularon ExtensionConcedida y
    --    CanonMensual. Las sin match de parque, sin cupo, o que ya
    --    tenían Concesion, quedan afuera (ya logueadas en pasos 5/6).
    ------------------------------------------------------------------
    BEGIN TRY
        INSERT INTO Concesiones.Concesion
            (IdParque, IdOrganizacionConcesionaria, CanonMensual, ExtensionConcedida, EstadoConcesion, FechaInicio, FechaFin)
        SELECT
            ocp.IdParque,
            org.IdOrganizacionConcesionaria,
            ocp.CanonMensual,
            ocp.ExtensionConcedida,
            'Activo',
            ocp.FechaInicio,
            ocp.FechaFin
        FROM #OrganizacionesConParque ocp
        INNER JOIN #OrgConcesionariaDescifrado ocd ON ocd.CuitDescifrado = ocp.Cuit COLLATE DATABASE_DEFAULT
        INNER JOIN Concesiones.OrganizacionConcesionaria org ON org.IdOrganizacionConcesionaria = ocd.IdOrganizacionConcesionaria
        WHERE ocp.YaTieneConcesion = 0
          AND ocp.ExtensionConcedida IS NOT NULL
          AND ocp.CanonMensual IS NOT NULL;

        INSERT INTO #LogEjecucionActual (TipoEvento, CuitOrigen, RazonSocialOrigen, Motivo)
        SELECT 'CONCESION_CREADA', ocp.Cuit, v.RazonSocial,
               CONCAT('Concesión creada en IdParque=', ocp.IdParque, ': ', ocp.ExtensionConcedida,
                      ' ha, canon $', ocp.CanonMensual, '/mes (', ocp.CantidadFeriados, ' feriados en el contrato).')
        FROM #OrganizacionesConParque ocp
        INNER JOIN #Validos v ON v.Cuit = ocp.Cuit COLLATE DATABASE_DEFAULT
        WHERE ocp.YaTieneConcesion = 0
          AND ocp.ExtensionConcedida IS NOT NULL
          AND ocp.CanonMensual IS NOT NULL;
    END TRY
    BEGIN CATCH
        INSERT INTO #LogEjecucionActual (TipoEvento, Motivo)
        VALUES ('ERROR_VALIDACION', 'Error inesperado al crear las concesiones: ' + ERROR_MESSAGE());
    END CATCH

    ------------------------------------------------------------------
    -- 8) Persistir el log de esta ejecución + devolver resumen y detalle.
    --    Va al final a propósito: tiene que correr después de TODOS los
    --    pasos que insertan en #LogEjecucionActual (4 a 7), si no los
    --    eventos posteriores a este punto nunca llegan a la tabla real.
    ------------------------------------------------------------------
    INSERT INTO Concesiones.LogImportacionConcesionaria (NombreArchivo, TipoEvento, CuitOrigen, RazonSocialOrigen, Motivo)
    SELECT @rutaArchivo, TipoEvento, CuitOrigen, RazonSocialOrigen, Motivo
    FROM #LogEjecucionActual;

    SELECT
        (SELECT COUNT(*) FROM #OrganizacionesLimpias)                 AS TotalFilasLeidas,
        (SELECT COUNT(*) FROM #OrganizacionesLimpias WHERE Orden > 1) AS DuplicadosIntraArchivo,
        (SELECT COUNT(*) FROM #Validacion WHERE Motivo <> '')         AS RechazadosPorValidacion,
        @aInsertar                                                    AS InsertadosEnEstaEjecucion,
        (SELECT COUNT(*) FROM #Validos)                               AS TotalValidosProcesados,
        (SELECT COUNT(*) FROM #OrganizacionesConParque
         WHERE YaTieneConcesion = 0 AND ExtensionConcedida IS NOT NULL AND CanonMensual IS NOT NULL) AS ConcesionesCreadas;

    SELECT TipoEvento, CuitOrigen, RazonSocialOrigen, Motivo
    FROM #LogEjecucionActual
    ORDER BY TipoEvento, CuitOrigen;
END
GO
-- ====================================================================
-- 11) SP de importación actualizado: USP_ImportarGuiasCsv
-- ====================================================================

CREATE OR ALTER PROCEDURE USP_ImportarGuiasCsv
    @rutaArchivo VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    ------------------------------------------------------------------
    -- 0) Staging: carga cruda, tal cual viene el archivo
    ------------------------------------------------------------------
    
    CREATE TABLE #StagingGuia (
        Legajo          VARCHAR(50)  NULL,
        ApellidoNombre  VARCHAR(200) NULL,
        Domicilio       VARCHAR(200) NULL,
        Localidad       VARCHAR(100) NULL,
        Telefonos       VARCHAR(100) NULL,
        Titulo          VARCHAR(200) NULL,   --esto en realidad mapea a Especialidad
        Documento       VARCHAR(50)  NULL,
        Resolucion      VARCHAR(50)  NULL,
        Actualizacion   VARCHAR(50)  NULL,
        AnioInscripcion VARCHAR(50)  NULL,
        ResolReinscrip  VARCHAR(50)  NULL,
        Email           VARCHAR(200) NULL
    );

    DECLARE @rutaSegura VARCHAR(500) = REPLACE(@rutaArchivo, '''', '''''');
    DECLARE @sql NVARCHAR(MAX) = N'
        BULK INSERT #StagingGuia
        FROM ''' + @rutaSegura + N'''
        WITH (
            FORMAT          = ''CSV'',
            FIRSTROW        = 2,
            FIELDTERMINATOR = '';'',
            ROWTERMINATOR   = ''0x0d0a'',
            FIELDQUOTE      = ''"'',
            CODEPAGE        = ''850'',
            KEEPNULLS
        );';
    EXEC SP_executesql @sql;


    -- log para esta corrida (se persiste al final, tambin se devuelve como resultado)
    
    CREATE TABLE #LogCorridaActual (
        TipoEvento         VARCHAR(30),
        NumeroLegajoOrigen VARCHAR(50),
        NumeroDocumento    VARCHAR(15),
        Motivo             VARCHAR(500)
    );

    ------------------------------------------------------------------
    -- 0.1) Cifrado: Personal.Guia.NumeroDocumento es VARBINARY (cifrado
    --      con EncryptByPassPhrase).
    ------------------------------------------------------------------
    DECLARE @FraseClave VARCHAR(128) = 'ParquesNacionales_Cifrado_TP';

    SELECT
        IdGuia + 0 AS IdGuia, -- rompe la herencia de IDENTITY por si en el futuro se necesita un INSERT explícito
        CONVERT(VARCHAR(15), DecryptByPassPhrase(@FraseClave, NumeroDocumento, 1, CONVERT(VARBINARY, IdGuia))) AS NumeroDocumentoDescifrado
    INTO #GuiaDescifrado
    FROM Personal.Guia;

    ------------------------------------------------------------------
    -- 1) Deduplicar dentro del archivo: por Documento, gana el legajo
    --    ms alto (registro ms reciente)
    ------------------------------------------------------------------

    SELECT
        s.*,
        LTRIM(RTRIM(ISNULL(s.ApellidoNombre,''))) AS NombreCompleto, --Armado de la columna 'NombreCompleto' totalmente limpia
        ROW_NUMBER() OVER (
            PARTITION BY LTRIM(RTRIM(ISNULL(s.Documento,''))) COLLATE DATABASE_DEFAULT
            ORDER BY TRY_CAST(LTRIM(RTRIM(s.Legajo)) AS INT) DESC --Convierte el led a int pero sin explotar si por algun motivo no es numerico.
        ) AS Orden --window function que agrupa ("particiona") todas las filas que comparten el mismo Documento y, dentro de cada grupo, les asigna un nmero de orden (1, 2, 3...) segn el criterio del ORDER BY
    INTO #Dedup
    FROM #StagingGuia s
    WHERE NOT (s.Legajo IS NULL AND s.ApellidoNombre IS NULL AND s.Documento IS NULL); -- descarta filas en blanco (ej. CRLF final)

    INSERT INTO #LogCorridaActual (TipoEvento, NumeroLegajoOrigen, NumeroDocumento, Motivo)
    SELECT 'DUPLICADO_INTRAARCHIVO', LTRIM(RTRIM(Legajo)), LTRIM(RTRIM(Documento)),
           'Documento repetido en el archivo; se utiliz el registro con legajo ms reciente.'
    FROM #Dedup
    WHERE Orden > 1;

    ------------------------------------------------------------------
    -- 2) Parsear Apellido/Nombre sobre los candidatos (Orden = 1)
    ------------------------------------------------------------------

    --En este bloque de codigo se extrae el Nombre y Apellido de aquellos guias que su numero de orden es 1
    SELECT
        d.*,
        CASE
            WHEN RIGHT(ApellidoCrudo,1) = '.' THEN LEFT(ApellidoCrudo, LEN(ApellidoCrudo)-1) --Te devuelve el apellido real limpio
            ELSE ApellidoCrudo
        END AS Apellido,
        NombreCrudo AS Nombre
    INTO #CandidatosLimpios
    FROM (
        SELECT
            d.*,
            CASE WHEN CHARINDEX(',', d.NombreCompleto) > 0 --Pregunto si el nombre completo tiene una coma: Perez, Juan.     
                 THEN LTRIM(RTRIM(LEFT(d.NombreCompleto, CHARINDEX(',', d.NombreCompleto) - 1)))
                 ELSE LTRIM(RTRIM(LEFT(d.NombreCompleto, CHARINDEX(' ', d.NombreCompleto + ' ') - 1)))
            END AS ApellidoCrudo,
            CASE WHEN CHARINDEX(',', d.NombreCompleto) > 0
                 THEN LTRIM(RTRIM(SUBSTRING(d.NombreCompleto, CHARINDEX(',', d.NombreCompleto) + 1, 200)))
                 ELSE LTRIM(RTRIM(SUBSTRING(d.NombreCompleto, CHARINDEX(' ', d.NombreCompleto + ' ') + 1, 200)))
            END AS NombreCrudo
        FROM #Dedup d
        WHERE d.Orden = 1
    ) d;

    ------------------------------------------------------------------
    -- 3) Validar y acumular motivos de rechazo por fila
    --    (el patrn de email debe quedar igual al CHECK de la tabla)
    ------------------------------------------------------------------

    SELECT
        cl.*,
        LTRIM(RTRIM(
            ISNULL(CASE WHEN LTRIM(RTRIM(ISNULL(cl.Documento,''))) = '' THEN 'Documento vaco. ' END,'') +
            ISNULL(CASE WHEN LEN(LTRIM(RTRIM(ISNULL(cl.Documento,'')))) > 15 THEN 'Documento excede 15 caracteres. ' END,'') +
            ISNULL(CASE WHEN ISNULL(cl.Apellido,'') = '' THEN 'No se pudo determinar el apellido. ' END,'') +
            ISNULL(CASE WHEN ISNULL(cl.Nombre,'')   = '' THEN 'No se pudo determinar el nombre. ' END,'') +
            ISNULL(CASE WHEN LEN(cl.Apellido) > 50 THEN 'Apellido excede 50 caracteres. ' END,'') +
            ISNULL(CASE WHEN LEN(cl.Nombre)   > 50 THEN 'Nombre excede 50 caracteres. ' END,'') +
            ISNULL(CASE WHEN LTRIM(RTRIM(ISNULL(cl.Telefonos,''))) = '' THEN 'Telfono vaco. ' END,'') +
            ISNULL(CASE WHEN LEN(LTRIM(RTRIM(ISNULL(cl.Telefonos,'')))) > 20 THEN 'Telfono excede 20 caracteres. ' END,'') +
            ISNULL(CASE WHEN LTRIM(RTRIM(ISNULL(cl.Titulo,''))) = '' THEN 'Especialidad vaca. ' END,'') +
            ISNULL(CASE WHEN LEN(LTRIM(RTRIM(ISNULL(cl.Titulo,'')))) > 50 THEN 'Especialidad excede 50 caracteres. ' END,'') +
            ISNULL(CASE WHEN LTRIM(RTRIM(ISNULL(cl.Email,''))) = '' THEN 'Email vaco. ' END,'') +
            ISNULL(CASE WHEN LTRIM(RTRIM(ISNULL(cl.Email,''))) <> '' AND LTRIM(RTRIM(cl.Email)) NOT LIKE '%_@__%.__%' THEN 'Email con formato invlido. ' END,'') +
            ISNULL(CASE WHEN LEN(LTRIM(RTRIM(ISNULL(cl.Email,'')))) > 100 THEN 'Email excede 100 caracteres. ' END,'')
        )) AS Motivo --Acumulo los motivos de error de validacion por fila
    INTO #Validacion
    FROM #CandidatosLimpios cl;

    INSERT INTO #LogCorridaActual (TipoEvento, NumeroLegajoOrigen, NumeroDocumento, Motivo)
    SELECT 'ERROR_VALIDACION', LTRIM(RTRIM(Legajo)), LTRIM(RTRIM(Documento)), Motivo
    FROM #Validacion
    WHERE Motivo <> ''; --Insertamos aquellos registros que tengan al menos un mensaje registrado .

    
    SELECT
        LTRIM(RTRIM(Documento)) AS NumeroDocumento,
        Apellido,
        Nombre,
        LTRIM(RTRIM(Telefonos)) AS Telefono,
        LTRIM(RTRIM(Email))     AS CorreoGuia,
        LTRIM(RTRIM(Titulo))    AS Especialidad,
        'DNI'                   AS TipoDocumento,  -- fijo, sin dato de origen
        1                       AS Edad            -- fijo, sin dato de origen
    INTO #Validos
    FROM #Validacion
    WHERE Motivo = ''; --Insertamos en Validos aquellos donde no tengan motivos de error. Son los verdaderos clean

    ------------------------------------------------------------------
    -- 4) Upsert contra Personal.Guia por NumeroDocumento
    ------------------------------------------------------------------
    SET XACT_ABORT ON;
    
    DECLARE @insertados INT = 0;
    DECLARE @maxIdGuiaPrevio INT = ISNULL((SELECT MAX(IdGuia) FROM Personal.Guia), 0);
    
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE g
            SET g.Telefono       = v.Telefono,
                g.CorreoGuia     = v.CorreoGuia,
                g.TipoDocumento  = v.TipoDocumento,
                g.Edad           = v.Edad,
                g.Apellido       = v.Apellido,
                g.Nombre         = v.Nombre,
                g.Titulo         = NULL,
                g.Especialidad   = v.Especialidad
        FROM Personal.Guia g
        INNER JOIN #GuiaDescifrado gd ON gd.IdGuia = g.IdGuia
        INNER JOIN #Validos v ON gd.NumeroDocumentoDescifrado = v.NumeroDocumento COLLATE DATABASE_DEFAULT;

        -- Se inserta con el documento en bytes crudos (todavía sin cifrar, porque el
        -- Id -usado como autenticador- no existe hasta después del INSERT) y se cifra
        -- en el UPDATE siguiente, dentro de la misma transacción: nadie fuera de esta
        -- transacción llega a ver el documento en texto plano en la tabla.
        INSERT INTO Personal.Guia
            (Telefono, CorreoGuia, NumeroDocumento, TipoDocumento, Edad, Apellido, Nombre, Titulo, Especialidad)
        SELECT
            v.Telefono, v.CorreoGuia, CONVERT(VARBINARY(256), v.NumeroDocumento), v.TipoDocumento, v.Edad, v.Apellido, v.Nombre, NULL, v.Especialidad
        FROM #Validos v
        WHERE NOT EXISTS (
            SELECT 1 FROM #GuiaDescifrado gd WHERE gd.NumeroDocumentoDescifrado = v.NumeroDocumento COLLATE DATABASE_DEFAULT
        );

        SET @insertados = @@ROWCOUNT;

        UPDATE g
        SET g.NumeroDocumento = EncryptByPassPhrase(@FraseClave, CONVERT(VARCHAR(15), g.NumeroDocumento), 1, CONVERT(VARBINARY, g.IdGuia))
        FROM Personal.Guia g
        WHERE g.IdGuia > @maxIdGuiaPrevio;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO #LogCorridaActual (TipoEvento, Motivo)
        VALUES ('ERROR_VALIDACION', 'Error inesperado al aplicar el upsert: ' + ERROR_MESSAGE());
    END CATCH

    ------------------------------------------------------------------
    -- 5) Persistir el log de esta corrida + devolver resumen y detalle
    ------------------------------------------------------------------
    INSERT INTO Personal.LogImportacionGuia (NombreArchivo, TipoEvento, NumeroLegajoOrigen, NumeroDocumento, Motivo)
    SELECT @rutaArchivo, TipoEvento, NumeroLegajoOrigen, NumeroDocumento, Motivo
    FROM #LogCorridaActual;

    SELECT
        (SELECT COUNT(*) FROM #StagingGuia) AS TotalFilasLeidas,
        (SELECT COUNT(*) FROM #Dedup WHERE Orden > 1) AS DuplicadosIntraArchivo,
        (SELECT COUNT(*) FROM #Validacion WHERE Motivo <> '') AS RechazadosPorValidacion,
         @insertados AS InsertadosEnEstaCorrida,
        (SELECT COUNT(*) FROM #Validos) AS TotalValidosProcesados;

    SELECT TipoEvento, NumeroLegajoOrigen, NumeroDocumento, Motivo
    FROM #LogCorridaActual
    ORDER BY TipoEvento, NumeroLegajoOrigen;
END
GO