-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: Stored Procedure para importar Organizaciones Concesionarias

USE ParquesNacionales
GO

CREATE OR ALTER PROCEDURE SP_ImportarOrganizacionConcesionaria
    @rutaArchivo VARCHAR(500)
AS
BEGIN
    
    SET NOCOUNT ON

    CREATE TABLE #StagingConcesionXlsx (
        NroFila    INT IDENTITY(1,1) PRIMARY KEY,
        TipoFila   VARCHAR(20),
        Col1       VARCHAR(200),
        Col2       VARCHAR(200),
        Col3       VARCHAR(200),
        Col4       VARCHAR(200),
        Col5       VARCHAR(300),
        Col6       VARCHAR(50),
        Col7       VARCHAR(50)
    );

    INSERT INTO #StagingConcesionXlsx (Col1, Col2, Col3, Col4, Col5, Col6, Col7)
    EXEC('
        SELECT *
        FROM OPENROWSET(''Microsoft.ACE.OLEDB.16.0'',
            ''Excel 12.0;Database=' + @rutaArchivo + ';HDR=NO'',
            ''SELECT * FROM [Hoja1$]'')')

    UPDATE #StagingConcesionXlsx
    SET TipoFila =
        CASE
            WHEN TRIM(Col1) = 'RAZON SOCIAL' THEN 'ENCABEZADO_COL'
            WHEN Col1 IS NOT NULL AND Col2 IS NULL AND Col3 IS NULL THEN 'NOMBRE_PARQUE'
            WHEN Col3 IS NOT NULL THEN 'DATO'
            ELSE 'DESCONOCIDA'
        END;


    SELECT
        TRIM(Col1) AS RazonSocial,
        TRIM(Col3) AS Cuit,
        TRIM(Col5) AS TipoActividad,
        ROW_NUMBER() OVER (PARTITION BY TRIM(Col3) ORDER BY NroFila) AS Orden
    INTO #OrganizacionesLimpias
    FROM #StagingConcesionXlsx
    WHERE TipoFila = 'DATO'
    
    UPDATE oc
        SET oc.Nombre = ol.RazonSocial,
            oc.TipoActividad = ol.TipoActividad
        FROM Concesiones.OrganizacionConcesionaria oc
        INNER JOIN #OrganizacionesLimpias ol
        ON oc.CUIT = ol.Cuit COLLATE DATABASE_DEFAULT
        WHERE ol.Orden = 1;

    INSERT INTO Concesiones.OrganizacionConcesionaria (CUIT, Nombre, TipoActividad)
    SELECT ol.Cuit, ol.RazonSocial, ol.TipoActividad
    FROM #OrganizacionesLimpias ol
    WHERE ol.Orden = 1
        AND NOT EXISTS (
        SELECT 1 FROM Concesiones.OrganizacionConcesionaria oc
        WHERE oc.CUIT = ol.Cuit
        COLLATE DATABASE_DEFAULT
    )

END
GO