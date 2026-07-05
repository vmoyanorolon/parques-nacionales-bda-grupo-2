-- ============================================================================
-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi, Benjamin Velazquez, Valentin Moyano Rolon
-- Descripcion: Entrega 9 - Punto 2. Vistas para la plataforma BI (Metabase / Power BI).
--              Alimentan: mapa de parques, grafico de visitas y grafico de ingresos.
-- ============================================================================

USE ParquesNacionales
GO

-- ----------------------------------------------------------------------------
-- VW_MapaParques: una fila por parque con geolocalizacion (para el mapa)
-- ----------------------------------------------------------------------------
IF OBJECT_ID('VW_MapaParques', 'V') IS NOT NULL DROP VIEW VW_MapaParques
GO
CREATE VIEW VW_MapaParques AS
SELECT
    p.IdParque,
    p.Nombre,
    p.TipoParque,
    p.Provincia,
    p.Superficie,
    p.Latitud,
    p.Longitud
FROM Parques.Parque p
WHERE p.Latitud IS NOT NULL AND p.Longitud IS NOT NULL;
GO

-- ----------------------------------------------------------------------------
-- VW_VisitasPorParque: cantidad de entradas vendidas por parque y periodo
-- (grafico de barras: visitas por parque)
-- ----------------------------------------------------------------------------
IF OBJECT_ID('VW_VisitasPorParque', 'V') IS NOT NULL DROP VIEW VW_VisitasPorParque
GO
CREATE VIEW VW_VisitasPorParque AS
SELECT
    Parque   = p.Nombre,
    p.Provincia,
    Anio     = YEAR(v.Fecha),
    Mes      = MONTH(v.Fecha),
    Semana   = DATEPART(WEEK, v.Fecha),
    Fecha    = CAST(v.Fecha AS DATE),
    CantidadVisitantes = SUM(lp.Cantidad)
FROM Ventas.Venta v
JOIN Ventas.LineaDeEntradaParque lp ON lp.IdVenta = v.IdVenta
JOIN Turismo.EntradaParque ep       ON ep.IdEntradaParque = lp.IdEntradaParque
JOIN Parques.Parque p               ON p.IdParque = ep.IdParque
GROUP BY p.Nombre, p.Provincia, YEAR(v.Fecha), MONTH(v.Fecha),
         DATEPART(WEEK, v.Fecha), CAST(v.Fecha AS DATE);
GO

-- ----------------------------------------------------------------------------
-- VW_IngresosPorParque: ingresos por entradas, actividades y concesiones
-- (grafico de torta/barras apiladas: composicion de ingresos por parque)
-- ----------------------------------------------------------------------------
IF OBJECT_ID('VW_IngresosPorParque', 'V') IS NOT NULL DROP VIEW VW_IngresosPorParque
GO
CREATE VIEW VW_IngresosPorParque AS
WITH Entradas AS (
    SELECT p.IdParque, Anio = YEAR(v.Fecha), Mes = MONTH(v.Fecha),
           Monto = SUM(lp.Subtotal)
    FROM Ventas.Venta v
    JOIN Ventas.LineaDeEntradaParque lp ON lp.IdVenta = v.IdVenta
    JOIN Turismo.EntradaParque ep       ON ep.IdEntradaParque = lp.IdEntradaParque
    JOIN Parques.Parque p               ON p.IdParque = ep.IdParque
    GROUP BY p.IdParque, YEAR(v.Fecha), MONTH(v.Fecha)
),
Actividades AS (
    SELECT a.IdParque, Anio = YEAR(v.Fecha), Mes = MONTH(v.Fecha),
           Monto = SUM(la.Subtotal)
    FROM Ventas.Venta v
    JOIN Ventas.LineaDeEntradaActividad la ON la.IdVenta = v.IdVenta
    JOIN Turismo.Actividad a               ON a.IdActividad = la.IdActividad
    GROUP BY a.IdParque, YEAR(v.Fecha), MONTH(v.Fecha)
),
Concesiones AS (
    SELECT c.IdParque, Anio = YEAR(pc.Fecha), Mes = MONTH(pc.Fecha),
           Monto = SUM(pc.Monto)
    FROM Concesiones.PagoConcesion pc
    JOIN Concesiones.Concesion c ON c.IdConcesion = pc.IdConcesion
    GROUP BY c.IdParque, YEAR(pc.Fecha), MONTH(pc.Fecha)
)
SELECT
    Parque = p.Nombre,
    x.Anio, x.Mes,
    IngresoEntradas    = SUM(CASE WHEN x.Origen = 'Entradas'    THEN x.Monto ELSE 0 END),
    IngresoActividades = SUM(CASE WHEN x.Origen = 'Actividades' THEN x.Monto ELSE 0 END),
    IngresoConcesiones = SUM(CASE WHEN x.Origen = 'Concesiones' THEN x.Monto ELSE 0 END),
    IngresoTotal       = SUM(x.Monto)
FROM (
    SELECT IdParque, Anio, Mes, Monto, Origen = 'Entradas'    FROM Entradas
    UNION ALL
    SELECT IdParque, Anio, Mes, Monto, Origen = 'Actividades' FROM Actividades
    UNION ALL
    SELECT IdParque, Anio, Mes, Monto, Origen = 'Concesiones' FROM Concesiones
) x
JOIN Parques.Parque p ON p.IdParque = x.IdParque
GROUP BY p.Nombre, x.Anio, x.Mes;
GO