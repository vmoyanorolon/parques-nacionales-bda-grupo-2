-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Descripción: creación de TVPS para stored procedures

IF TYPE_ID('Ventas.TVP_LineaParque') IS NOT NULL DROP TYPE Ventas.TVP_LineaParque
GO
CREATE TYPE Ventas.TVP_LineaParque AS TABLE (
	IdEntradaParque INT NOT NULL,
	Cantidad TINYINT NOT NULL
)
GO

IF TYPE_ID('Ventas.TVP_LineaActividad') IS NOT NULL DROP TYPE Ventas.TVP_LineaActividad
GO
CREATE TYPE Ventas.TVP_LineaActividad AS TABLE (
	IdEntradaActividad INT NOT NULL,
	Cantidad TINYINT NOT NULL
)
GO