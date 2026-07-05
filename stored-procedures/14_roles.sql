-- Universidad: UNLaM
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 2
-- Integrantes: Patricio Gaudino Tognozzi (46.636.294), Benjamín Velázquez (46.641.239), Valentín Moyano Rolón (46.292.248)
-- Fecha: 04/07/2026
-- Descripción: Creación de roles de seguridad y asignación de permisos granulares

USE ParquesNacionales
GO

-----------------------------------------------------------------------------------------
-- MATRIZ DE PERMISOS GRANULARES POR ROL
-- Referencias: SEL = SELECT | EXE = EXECUTE | ALL = CONTROL TOTAL (db_owner)
-----------------------------------------------------------------------------------------
/*
| Esquema / Objeto                         | Tipo | Admin | Turismo | Ventas | Personal | Conces. | Import. | Consult. |
|------------------------------------------|------|-------|---------|--------|----------|---------|---------|----------|
| Parques.Parque                           | TAB  |  ALL  |   SEL   |  SEL   |          |         |         |          |
| Parques.LogImportacionParque             | TAB  |  ALL  |         |        |          |         |   SEL   |          |
| Turismo.Visitante                        | TAB  |  ALL  |   SEL   |        |          |         |         |          |
| Turismo.TipoVisitante                    | TAB  |  ALL  |   SEL   |  SEL   |          |         |         |          |
| Turismo.Turno                            | TAB  |  ALL  |   SEL   |        |          |         |         |          |
| Turismo.Actividad                        | TAB  |  ALL  |   SEL   |  SEL   |          |         |         |          |
| Turismo.EntradaParque                    | TAB  |  ALL  |   SEL   |  SEL   |          |         |         |          |
| Ventas.Venta                             | TAB  |  ALL  |         |  SEL   |          |         |         |          |
| Ventas.LineaDeEntradaParque              | TAB  |  ALL  |         |  SEL   |          |         |         |          |
| Ventas.LineaDeEntradaActividad           | TAB  |  ALL  |         |  SEL   |          |         |         |          |
| Personal.Guia                            | TAB  |  ALL  |         |        |   SEL    |         |         |          |
| Personal.Guardaparque                    | TAB  |  ALL  |         |        |   SEL    |         |         |          |
| Personal.Asignacion                      | TAB  |  ALL  |         |        |   SEL    |         |         |          |
| Personal.Habilitacion                    | TAB  |  ALL  |         |        |   SEL    |         |         |          |
| Personal.GuiaTrabajaEnParque             | TAB  |  ALL  |         |        |   SEL    |         |         |          |
| Personal.LogImportacionGuia              | TAB  |  ALL  |         |        |          |         |   SEL   |          |
| Concesiones.OrganizacionConcesionaria    | TAB  |  ALL  |         |        |          |   SEL   |         |          |
| Concesiones.Concesion                    | TAB  |  ALL  |         |        |          |   SEL   |         |          |
| Concesiones.PagoConcesion                | TAB  |  ALL  |         |        |          |   SEL   |         |          |
| Concesiones.LogImportacionConcesionaria  | TAB  |  ALL  |         |        |          |         |   SEL   |          |
|------------------------------------------|------|-------|---------|--------|----------|---------|---------|----------|
| dbo.USP_Alta/Modificacion/BajaVisitante  | SP   |  ALL  |   EXE   |        |          |         |         |          |
| dbo.USP_Alta/Modificacion/BajaTipoVis... | SP   |  ALL  |   EXE   |        |          |         |         |          |
| dbo.USP_Alta/Modificacion/BajaTurno      | SP   |  ALL  |   EXE   |        |          |         |         |          |
| dbo.USP_Alta/Modificacion/BajaActividad  | SP   |  ALL  |   EXE   |        |          |         |         |          |
| dbo.USP_Alta/Modificacion/BajaEntrada... | SP   |  ALL  |   EXE   |        |          |         |         |          |
| dbo.USP_AltaVenta                        | SP   |  ALL  |         |  EXE   |          |         |         |          |
| dbo.USP_AltaLineasDeEntradaParque/Act... | SP   |  ALL  |         |  EXE   |          |         |         |          |
| dbo.USP_RegistrarVentaEntradaMasiva      | SP   |  ALL  |         |  EXE   |          |         |         |          |
| dbo.USP_ActualizarPrecioEntrada          | SP   |  ALL  |         |  EXE   |          |         |         |          |
| dbo.USP_Alta/Modificacion/BajaGuia       | SP   |  ALL  |         |        |   EXE    |         |         |          |
| dbo.USP_Alta/Modificacion/BajaGuardap... | SP   |  ALL  |         |        |   EXE    |         |         |          |
| dbo.USP_Alta/Modificacion/BajaAsignacion | SP   |  ALL  |         |        |   EXE    |         |         |          |
| dbo.USP_Alta/Modificacion/BajaHabilit... | SP   |  ALL  |         |        |   EXE    |         |         |          |
| dbo.USP_Alta/BajaGuiaTrabajaEnParque     | SP   |  ALL  |         |        |   EXE    |         |         |          |
| dbo.USP_AsignarGuiaATour                 | SP   |  ALL  |         |        |   EXE    |         |         |          |
| dbo.USP_Alta/Modif/BajaOrgConcesionaria  | SP   |  ALL  |         |        |          |   EXE   |         |          |
| dbo.USP_Alta/Modificacion/BajaConcesion  | SP   |  ALL  |         |        |          |   EXE   |         |          |
| dbo.USP_Alta/RegistrarPagoConcesion      | SP   |  ALL  |         |        |          |   EXE   |         |          |
| dbo.USP_ImportarParque                   | SP   |  ALL  |         |        |          |         |   EXE   |          |
| dbo.USP_ObtenerLocalidad                 | SP   |  ALL  |         |        |          |         |   EXE   |          |
| dbo.USP_ImportarGuiasCsv                 | SP   |  ALL  |         |        |          |         |   EXE   |          |
| dbo.USP_ImportarOrganizacionConcesionaria| SP   |  ALL  |         |        |          |         |   EXE   |          |
| dbo.USP_ObtenerFeriadosAnio/EnRango      | SP   |  ALL  |         |        |          |         |   EXE   |          |
| dbo.USP_ReporteVisitasPorParque          | SP   |  ALL  |         |        |          |         |         |   EXE    |
| dbo.USP_ReporteIngresosPorParque         | SP   |  ALL  |         |        |          |         |         |   EXE    |
| dbo.USP_ReporteDeudores                  | SP   |  ALL  |         |        |          |         |         |   EXE    |
| dbo.USP_ReporteMatrizVisitas             | SP   |  ALL  |         |        |          |         |         |   EXE    |
| dbo.USP_ReporteParquesYConcesiones       | SP   |  ALL  |         |        |          |         |         |   EXE    |
*/

/*
EXEC USP_CrearRolesSeguridad
SELECT name, type_desc FROM sys.database_principals WHERE type = 'R' AND is_fixed_role = 0
*/

CREATE OR ALTER PROCEDURE USP_CrearRolesSeguridad
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TranCountInicial INT = @@TRANCOUNT;

    BEGIN TRY
        IF @TranCountInicial = 0
            BEGIN TRANSACTION USP_CrearRolesSeguridad;
        ELSE
            SAVE TRANSACTION USP_CrearRolesSeguridad;

        ----------------------------------------
        -- CREACION DE ROLES (idempotente)
        ----------------------------------------

        -- AUTHORIZATION dbo: Garantiza portabilidad e independencia de los roles, centralizando la propiedad en la base de datos y no en cuentas de usuarios locales.
       
        IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'RolAdministrador' AND type = 'R')
            CREATE ROLE RolAdministrador AUTHORIZATION dbo;

        IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'RolTurismo' AND type = 'R')
            CREATE ROLE RolTurismo AUTHORIZATION dbo;

        IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'RolVentas' AND type = 'R')
            CREATE ROLE RolVentas AUTHORIZATION dbo;

        IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'RolPersonal' AND type = 'R')
            CREATE ROLE RolPersonal AUTHORIZATION dbo;

        IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'RolConcesiones' AND type = 'R')
            CREATE ROLE RolConcesiones AUTHORIZATION dbo;

        IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'RolImportador' AND type = 'R')
            CREATE ROLE RolImportador AUTHORIZATION dbo;

        IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'RolConsultas' AND type = 'R')
            CREATE ROLE RolConsultas AUTHORIZATION dbo;

        ----------------------------------------
        -- ROLADMINISTRADOR: control total
        ----------------------------------------
        ALTER ROLE db_owner ADD MEMBER RolAdministrador;

        ----------------------------------------
        -- ROLTURISMO: ABM de 04_sp_turismo.sql
        ----------------------------------------
        GRANT EXECUTE ON dbo.USP_AltaVisitante          TO RolTurismo;
        GRANT EXECUTE ON dbo.USP_ModificacionVisitante   TO RolTurismo;
        GRANT EXECUTE ON dbo.USP_BajaVisitante           TO RolTurismo;
        GRANT EXECUTE ON dbo.USP_AltaTipoVisitante       TO RolTurismo;
        GRANT EXECUTE ON dbo.USP_ModificacionTipoVisitante TO RolTurismo;
        GRANT EXECUTE ON dbo.USP_BajaTipoVisitante       TO RolTurismo;
        GRANT EXECUTE ON dbo.USP_AltaTurno               TO RolTurismo;
        GRANT EXECUTE ON dbo.USP_ModificacionTurno       TO RolTurismo;
        GRANT EXECUTE ON dbo.USP_BajaTurno               TO RolTurismo;
        GRANT EXECUTE ON dbo.USP_AltaActividad           TO RolTurismo;
        GRANT EXECUTE ON dbo.USP_ModificacionActividad   TO RolTurismo;
        GRANT EXECUTE ON dbo.USP_BajaActividad           TO RolTurismo;
        GRANT EXECUTE ON dbo.USP_AltaEntradaParque       TO RolTurismo;
        GRANT EXECUTE ON dbo.USP_ModificacionEntradaParque TO RolTurismo;
        GRANT EXECUTE ON dbo.USP_BajaEntradaParque       TO RolTurismo;

        GRANT SELECT ON Turismo.Visitante      TO RolTurismo;
        GRANT SELECT ON Turismo.TipoVisitante  TO RolTurismo;
        GRANT SELECT ON Turismo.Turno          TO RolTurismo;
        GRANT SELECT ON Turismo.Actividad      TO RolTurismo;
        GRANT SELECT ON Turismo.EntradaParque  TO RolTurismo;
        GRANT SELECT ON Parques.Parque         TO RolTurismo;

        ----------------------------------------
        -- ROLVENTAS: 07_sp_ventas.sql + negocio de ventas (08)
        ----------------------------------------
        GRANT EXECUTE ON dbo.USP_AltaVenta                     TO RolVentas;
        GRANT EXECUTE ON dbo.USP_AltaLineasDeEntradaParque      TO RolVentas;
        GRANT EXECUTE ON dbo.USP_AltaLineasDeEntradaActividad   TO RolVentas;
        GRANT EXECUTE ON dbo.USP_RegistrarVentaEntradaMasiva    TO RolVentas;
        GRANT EXECUTE ON dbo.USP_ActualizarPrecioEntrada        TO RolVentas;

        GRANT SELECT ON Ventas.Venta                    TO RolVentas;
        GRANT SELECT ON Ventas.LineaDeEntradaParque      TO RolVentas;
        GRANT SELECT ON Ventas.LineaDeEntradaActividad   TO RolVentas;
        GRANT SELECT ON Turismo.Actividad                TO RolVentas;
        GRANT SELECT ON Turismo.EntradaParque            TO RolVentas;
        GRANT SELECT ON Turismo.TipoVisitante            TO RolVentas;
        GRANT SELECT ON Parques.Parque                   TO RolVentas;

        ----------------------------------------
        -- ROLPERSONAL: 05_sp_personal.sql + asignación de guías (08)
        ----------------------------------------
        GRANT EXECUTE ON dbo.USP_AltaGuia                  TO RolPersonal;
        GRANT EXECUTE ON dbo.USP_ModificacionGuia          TO RolPersonal;
        GRANT EXECUTE ON dbo.USP_BajaGuia                  TO RolPersonal;
        GRANT EXECUTE ON dbo.USP_AltaGuardaparque          TO RolPersonal;
        GRANT EXECUTE ON dbo.USP_ModificacionGuardaparque  TO RolPersonal;
        GRANT EXECUTE ON dbo.USP_BajaGuardaparque          TO RolPersonal;
        GRANT EXECUTE ON dbo.USP_AltaAsignacion            TO RolPersonal;
        GRANT EXECUTE ON dbo.USP_ModificacionAsignacion    TO RolPersonal;
        GRANT EXECUTE ON dbo.USP_AltaHabilitacion          TO RolPersonal;
        GRANT EXECUTE ON dbo.USP_ModificacionHabilitacion  TO RolPersonal;
        GRANT EXECUTE ON dbo.USP_BajaHabilitacion          TO RolPersonal;
        GRANT EXECUTE ON dbo.USP_AltaGuiaTrabajaEnParque   TO RolPersonal;
        GRANT EXECUTE ON dbo.USP_BajaGuiaTrabajaEnParque   TO RolPersonal;
        GRANT EXECUTE ON dbo.USP_AsignarGuiaATour          TO RolPersonal;

        GRANT SELECT ON Personal.Guia               TO RolPersonal;
        GRANT SELECT ON Personal.Guardaparque       TO RolPersonal;
        GRANT SELECT ON Personal.Asignacion         TO RolPersonal;
        GRANT SELECT ON Personal.Habilitacion       TO RolPersonal;
        GRANT SELECT ON Personal.GuiaTrabajaEnParque TO RolPersonal;

        ----------------------------------------
        -- ROLCONCESIONES: 06_sp_concesiones.sql + pago de canon (08)
        ----------------------------------------
        GRANT EXECUTE ON dbo.USP_AltaOrganizacionConcesionaria        TO RolConcesiones;
        GRANT EXECUTE ON dbo.USP_ModificacionOrganizacionConcesionaria TO RolConcesiones;
        GRANT EXECUTE ON dbo.USP_BajaOrganizacionConcesionaria        TO RolConcesiones;
        GRANT EXECUTE ON dbo.USP_AltaConcesion                        TO RolConcesiones;
        GRANT EXECUTE ON dbo.USP_ModificacionConcesion                TO RolConcesiones;
        GRANT EXECUTE ON dbo.USP_BajaConcesion                        TO RolConcesiones;
        GRANT EXECUTE ON dbo.USP_AltaPagoConcesion                    TO RolConcesiones;
        GRANT EXECUTE ON dbo.USP_RegistrarPagoConcesion               TO RolConcesiones;

        GRANT SELECT ON Concesiones.OrganizacionConcesionaria TO RolConcesiones;
        GRANT SELECT ON Concesiones.Concesion                 TO RolConcesiones;
        GRANT SELECT ON Concesiones.PagoConcesion             TO RolConcesiones;

        ----------------------------------------
        -- ROLIMPORTADOR: SP de importación (09, 10, 11) + solo lectura de logs de auditoría
        ----------------------------------------
        GRANT EXECUTE ON dbo.USP_ImportarParque                    TO RolImportador;
        GRANT EXECUTE ON dbo.USP_ObtenerLocalidad                  TO RolImportador;
        GRANT EXECUTE ON dbo.USP_ImportarGuiasCsv                  TO RolImportador;
        GRANT EXECUTE ON dbo.USP_ImportarOrganizacionConcesionaria TO RolImportador;
        GRANT EXECUTE ON dbo.USP_ObtenerFeriadosAnio               TO RolImportador;
        GRANT EXECUTE ON dbo.USP_ObtenerFeriadosEnRango            TO RolImportador;

        -- Solo lectura del resultado de la importación, no de las tablas destino
        GRANT SELECT ON Parques.LogImportacionParque           TO RolImportador;
        GRANT SELECT ON Personal.LogImportacionGuia            TO RolImportador;
        GRANT SELECT ON Concesiones.LogImportacionConcesionaria TO RolImportador;

        ----------------------------------------
        -- ROLCONSULTAS: SP de reportes (12_sp_reporteria.sql) - uso desde la plataforma de BI
        ----------------------------------------
        GRANT EXECUTE ON dbo.USP_ReporteVisitasPorParque       TO RolConsultas;
        GRANT EXECUTE ON dbo.USP_ReporteIngresosPorParque       TO RolConsultas;
        GRANT EXECUTE ON dbo.USP_ReporteDeudores           TO RolConsultas;
        GRANT EXECUTE ON dbo.USP_ReporteMatrizVisitas          TO RolConsultas;
        GRANT EXECUTE ON dbo.USP_ReporteParquesYConcesiones    TO RolConsultas;

        IF @TranCountInicial = 0
            COMMIT TRANSACTION USP_CrearRolesSeguridad;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
        BEGIN
            IF @TranCountInicial = 0
                ROLLBACK TRANSACTION;
            ELSE
                ROLLBACK TRANSACTION USP_CrearRolesSeguridad;
        END;
        THROW;
    END CATCH
END
GO