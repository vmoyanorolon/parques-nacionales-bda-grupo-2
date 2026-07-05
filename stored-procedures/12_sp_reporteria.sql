-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Fecha: 04/07/2026
-- Descripción: Entrega 7 (Reportes)

USE ParquesNacionales
GO
----------------------------------------
-- 1. VISITAS POR SEMANA/MES/AÑO, POR PARQUE  (XML)
----------------------------------------
/*
EXEC USP_ReporteVisitasPorParque 2026
*/
CREATE OR ALTER PROCEDURE USP_ReporteVisitasPorParque
    @Anio INT = NULL   -- opcional: filtra un año
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Visitas AS (
        SELECT
            p.IdParque,
            p.Nombre                     AS Parque,
            YEAR(ep.FechaAcceso)         AS Anio,
            MONTH(ep.FechaAcceso)        AS Mes,
            DATEPART(ISO_WEEK, ep.FechaAcceso) AS Semana,
            l.Cantidad
        FROM Ventas.LineaDeEntradaParque l
        JOIN Turismo.EntradaParque ep ON ep.IdEntradaParque = l.IdEntradaParque
        JOIN Parques.Parque p         ON p.IdParque = ep.IdParque
        WHERE (@Anio IS NULL OR YEAR(ep.FechaAcceso) = @Anio)
    )
    SELECT
        Parque      AS '@nombre',
        Anio        AS '@anio',
        (SELECT SUM(Cantidad) FROM Visitas v2 WHERE v2.IdParque = v.IdParque AND v2.Anio = v.Anio) AS 'TotalAnual',
        (
            SELECT Mes AS '@mes', SUM(Cantidad) AS '@visitas'
            FROM Visitas v3
            WHERE v3.IdParque = v.IdParque AND v3.Anio = v.Anio
            GROUP BY Mes
            FOR XML PATH('PorMes'), TYPE
        ),
        (
            SELECT Semana AS '@semana', SUM(Cantidad) AS '@visitas'
            FROM Visitas v4
            WHERE v4.IdParque = v.IdParque AND v4.Anio = v.Anio
            GROUP BY Semana
            FOR XML PATH('PorSemana'), TYPE
        )
    FROM Visitas v
    GROUP BY IdParque, Parque, Anio
    ORDER BY Parque, Anio
    FOR XML PATH('Parque'), ROOT('ReporteVisitas');
END
GO

----------------------------------------
-- 2. INGRESOS POR PARQUE  (entradas + tours + concesiones)
----------------------------------------
/*
EXEC USP_ReporteIngresosPorParque 'MES'
*/
CREATE OR ALTER PROCEDURE USP_ReporteIngresosPorParque
    @Granularidad VARCHAR(10) = 'MES'   -- 'SEMANA' | 'MES' | 'ANIO'
AS
BEGIN
    SET NOCOUNT ON;

    IF @Granularidad NOT IN ('SEMANA','MES','ANIO')
    BEGIN
        RAISERROR('Granularidad inválida. Use SEMANA, MES o ANIO.', 16, 1);
        RETURN;
    END

    -- Ingresos por entradas al parque
    ;WITH Entradas AS (
        SELECT p.IdParque, p.Nombre AS Parque, ep.FechaAcceso AS Fecha,
               l.Subtotal AS Monto
        FROM Ventas.LineaDeEntradaParque l
        JOIN Turismo.EntradaParque ep ON ep.IdEntradaParque = l.IdEntradaParque
        JOIN Parques.Parque p         ON p.IdParque = ep.IdParque
    ),
    -- Ingresos por actividades/tours
    Tours AS (
        SELECT p.IdParque, p.Nombre AS Parque, la.FechaHoraAsistencia AS Fecha,
               la.Subtotal AS Monto
        FROM Ventas.LineaDeEntradaActividad la
        JOIN Turismo.Actividad a ON a.IdActividad = la.IdActividad
        JOIN Parques.Parque p    ON p.IdParque = a.IdParque
    ),
    -- Ingresos por concesiones cobradas
    Concesiones AS (
        SELECT p.IdParque, p.Nombre AS Parque, pc.Fecha AS Fecha,
               pc.Monto AS Monto
        FROM Concesiones.PagoConcesion pc
        JOIN Concesiones.Concesion c ON c.IdConcesion = pc.IdConcesion
        JOIN Parques.Parque p        ON p.IdParque = c.IdParque
    ),
    Todo AS (
        SELECT IdParque, Parque, Fecha, Monto, 'Entradas'    AS Concepto FROM Entradas
        UNION ALL
        SELECT IdParque, Parque, Fecha, Monto, 'Tours'       AS Concepto FROM Tours
        UNION ALL
        SELECT IdParque, Parque, Fecha, Monto, 'Concesiones' AS Concepto FROM Concesiones
    ),
    Periodizado AS (
        SELECT *,
            YEAR(Fecha) AS Anio,
            CASE @Granularidad
                WHEN 'SEMANA' THEN DATEPART(ISO_WEEK, Fecha)
                WHEN 'MES'    THEN MONTH(Fecha)
                ELSE NULL
            END AS Periodo
        FROM Todo
    )
    SELECT
        Parque,
        Anio,
        Periodo,   -- NULL cuando @Granularidad = 'ANIO'
        SUM(CASE WHEN Concepto = 'Entradas'    THEN Monto ELSE 0 END) AS IngresosEntradas,
        SUM(CASE WHEN Concepto = 'Tours'       THEN Monto ELSE 0 END) AS IngresosTours,
        SUM(CASE WHEN Concepto = 'Concesiones' THEN Monto ELSE 0 END) AS IngresosConcesiones,
        SUM(Monto) AS IngresoTotal
    FROM Periodizado
    GROUP BY Parque, Anio, Periodo
    ORDER BY Parque, Anio, Periodo;
END
GO

----------------------------------------
-- 3. DEUDORES: concesiones atrasadas en pagos
----------------------------------------
/*
EXEC USP_ReporteDeudores
*/
CREATE OR ALTER PROCEDURE USP_ReporteDeudores
AS
BEGIN
    SET NOCOUNT ON;

    -- Meses transcurridos desde inicio (o hasta FechaFin) que deberían estar pagos
    ;WITH MesesEsperados AS (
        SELECT
            c.IdConcesion,
            c.CanonMensual,
            DATEDIFF(MONTH, c.FechaInicio,
                     ISNULL(c.FechaFin, GETDATE())) + 1 AS CantMesesEsperados
        FROM Concesiones.Concesion c
        WHERE c.EstadoConcesion = 'Activo'
    ),
    Pagado AS (
        SELECT IdConcesion,
               COUNT(*)      AS CantPagos,
               SUM(Monto)    AS TotalPagado
        FROM Concesiones.PagoConcesion
        GROUP BY IdConcesion
    )
    SELECT
        o.Nombre                                   AS Concesionaria,
        o.Cuit,
        p.Nombre                                   AS Parque,
        c.CanonMensual,
        me.CantMesesEsperados,
        ISNULL(pg.CantPagos, 0)                    AS MesesPagados,
        me.CantMesesEsperados - ISNULL(pg.CantPagos, 0)          AS MesesAtrasados,
        (me.CantMesesEsperados * c.CanonMensual)
            - ISNULL(pg.TotalPagado, 0)            AS MontoAdeudado
    FROM Concesiones.Concesion c
    JOIN MesesEsperados me ON me.IdConcesion = c.IdConcesion
    JOIN Concesiones.OrganizacionConcesionaria o
                           ON o.IdOrganizacionConcesionaria = c.IdOrganizacionConcesionaria
    JOIN Parques.Parque p  ON p.IdParque = c.IdParque
    LEFT JOIN Pagado pg    ON pg.IdConcesion = c.IdConcesion
    WHERE me.CantMesesEsperados - ISNULL(pg.CantPagos, 0) > 0
    ORDER BY MontoAdeudado DESC;
END
GO

----------------------------------------
-- 4. MATRIZ DE VISITAS: pivot mes x parque
----------------------------------------
/*
EXEC USP_ReporteMatrizVisitas 2026
*/
CREATE OR ALTER PROCEDURE USP_ReporteMatrizVisitas
    @Anio INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Parque, [1] AS Ene, [2] AS Feb, [3] AS Mar, [4] AS Abr,
           [5] AS May, [6] AS Jun, [7] AS Jul, [8] AS Ago,
           [9] AS Sep, [10] AS Oct, [11] AS Nov, [12] AS Dic
    FROM (
        SELECT p.Nombre AS Parque,
               MONTH(ep.FechaAcceso) AS Mes,
               l.Cantidad
        FROM Ventas.LineaDeEntradaParque l
        JOIN Turismo.EntradaParque ep ON ep.IdEntradaParque = l.IdEntradaParque
        JOIN Parques.Parque p         ON p.IdParque = ep.IdParque
        WHERE YEAR(ep.FechaAcceso) = @Anio
    ) AS src
    PIVOT (
        SUM(Cantidad) FOR Mes IN
            ([1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12])
    ) AS pvt
    ORDER BY Parque;
END
GO

----------------------------------------
-- 5. PARQUES Y CONCESIONES: vector anidado  (XML)
----------------------------------------
/*
EXEC USP_ReporteParquesYConcesiones
*/
CREATE OR ALTER PROCEDURE USP_ReporteParquesYConcesiones
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.Nombre     AS '@nombre',
        p.Provincia  AS '@provincia',
        (
            SELECT
                c.FechaInicio            AS '@fechaInicio',
                c.FechaFin               AS '@fechaFin',
                c.EstadoConcesion        AS '@estado',
                o.Nombre                 AS 'Titular',
                o.TipoActividad          AS 'ServicioPrestado',
                c.CanonMensual           AS 'CanonMensual'
            FROM Concesiones.Concesion c
            JOIN Concesiones.OrganizacionConcesionaria o
                 ON o.IdOrganizacionConcesionaria = c.IdOrganizacionConcesionaria
            WHERE c.IdParque = p.IdParque
            FOR XML PATH('Concesion'), ROOT('Concesiones'), TYPE
        )
    FROM Parques.Parque p
    ORDER BY p.Nombre
    FOR XML PATH('Parque'), ROOT('ReporteParquesConcesiones');
END
GO