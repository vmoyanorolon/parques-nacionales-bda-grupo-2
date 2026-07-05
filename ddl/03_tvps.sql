-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Fecha: 04/07/2026
-- Descripción: creación de TVPS para stored procedures

USE ParquesNacionales
GO

IF TYPE_ID('Ventas.TVP_LineaParque') IS NULL
    CREATE TYPE Ventas.TVP_LineaParque AS TABLE (
        IdEntradaParque INT NOT NULL,
        Cantidad TINYINT NOT NULL
    )
GO

IF TYPE_ID('Ventas.TVP_LineaActividad') IS NULL
CREATE TYPE Ventas.TVP_LineaActividad AS TABLE (
	IdActividad INT NOT NULL,
	Cantidad TINYINT NOT NULL,
	FechaHoraAsistencia DATETIME NOT NULL
)
GO
