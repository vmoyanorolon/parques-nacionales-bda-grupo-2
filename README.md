# Sistema de Gestión de Parques Nacionales

Trabajo Práctico — Materia 3641 Bases de Datos Aplicada
Universidad Nacional de La Matanza
**Grupo 2** — Integrantes: Patricio Gaudino Tognozzi, Benjamín Velázquez, Valentín Moyano Rolón

---

## Descripción

Sistema centralizado para la gestión de parques nacionales argentinos. Contempla la administración de parques, venta de entradas, actividades turísticas (atracciones y tours), concesiones comerciales, personal (guías y guardaparques), importación de datos públicos oficiales, reportería y seguridad (cifrado de datos sensibles y roles con permisos granulares).

---

## Tecnologías

- Microsoft SQL Server 2022 Developer Edition
- T-SQL (sin CLR ni herramientas externas al motor)
- APIs externas consumidas desde el motor vía Ole Automation Procedures:
  - **Nominatim (OpenStreetMap)** — geocodificación inversa para completar localidad, provincia, departamento y código postal de los parques importados.
  - **ArgentinaDatos** — feriados nacionales, utilizados en el cálculo del canon de las concesiones importadas.

---

## Estructura del repositorio

```
ddl/
  01_base_de_datos.sql                 → Creación de la base de datos y los 5 schemas
  02_tablas.sql                        → Definición de todas las tablas y restricciones
  03_tvps.sql                          → Table-Valued Parameters (schema Ventas)
stored-procedures/
  03_sp_parques.sql                    → ABM de Parque
  04_sp_turismo.sql                    → ABM de Visitante, TipoVisitante, Actividad, Turno, EntradaParque
  05_sp_personal.sql                   → ABM de Guia, Guardaparque, Asignacion, Habilitacion, GuiaTrabajaEnParque
  06_sp_concesiones.sql                → ABM de OrganizacionConcesionaria, Concesion, PagoConcesion
  07_sp_ventas.sql                     → Alta de Venta y de líneas de entrada (parque y actividad)
  08_sp_negocio.sql                    → Lógica de negocio: venta masiva, asignación de guías a tours,
                                         registro de pago de concesión, actualización de precios por parque
  09_sp_importacion_concesiones.sql    → Importación de concesionarias y concesiones (Excel) + API de feriados
  10_sp_importacion_guias.sql          → Importación de guías (CSV)
  11_sp_importacion_parques.sql        → Importación de parques (Excel) + API de geolocalización
  12_sp_reporteria.sql                 → Reportes (Entrega 7); dos de ellos retornan XML
  13_cifrado.sql                       → Cifrado de datos sensibles (Entrega 8) — script de modificación
  14_roles.sql                         → Roles de seguridad y permisos granulares (Entrega 8)
testing/
  test_03 ... test_14                  → Scripts de testing, en relación 1:1 con los scripts de objetos.
                                         Incluyen casos exitosos con evidencia (queries) y casos que
                                         demuestran el comportamiento de las validaciones al incumplirse.
views/
  vistas_bi.sql                        → Vistas que alimentan la plataforma de BI
dml/
  seed_tablas.sql                      → Carga de datos (seed) para los Criterios de Aceptación
  imports/                             → Archivos fuente reales para las importaciones
    parques.xlsx
    concesiones_31.12.2023.xlsx
    guias-a-julio-2019.csv
```

---

## Schemas y tablas

| Schema | Tablas |
|--------|--------|
| `Parques` | `Parque`, `LogImportacionParque` |
| `Turismo` | `Actividad`, `Turno`, `EntradaParque`, `Visitante`, `TipoVisitante` |
| `Ventas` | `Venta`, `LineaDeEntradaParque`, `LineaDeEntradaActividad` |
| `Personal` | `Guia`, `Guardaparque`, `Asignacion`, `Habilitacion`, `GuiaTrabajaEnParque`, `LogImportacionGuia` |
| `Concesiones` | `OrganizacionConcesionaria`, `Concesion`, `PagoConcesion`, `LogImportacionConcesionaria` |

Cada proceso de importación (parques, guías, concesiones) cuenta con su propia tabla `LogImportacionX`, que persiste una auditoría de cada corrida: duplicados detectados dentro del archivo, filas rechazadas por validación con su motivo, y eventos de las llamadas a APIs externas.

---

## Convención de nomenclatura

| Objeto | Convención | Ejemplo |
|--------|------------|---------|
| Tablas | PascalCase con schema como prefijo | `Turismo.Visitante` |
| Stored Procedures | Prefijo `USP_` | `USP_AltaVisitante` |
| Funciones | Prefijo `FN_`, en el schema del módulo al que pertenecen | `Concesiones.FN_NormalizarNombreParque` |
| Vistas | Prefijo `VW_` | `VW_MapaParques` |
| Variables | camelCase con `@` | `@idVisitante` |
| Constraints | Prefijo según tipo + tabla + columna | `CK_Visitante_Edad`, `FK_Visitante_TipoVisitante`, `DF_Parque_CostoHectarea` |
| TVPs | Prefijo `TVP_`, en el schema `Ventas` | `Ventas.TVP_LineaParque` |

---

## Decisiones de diseño

- **Acceso a datos encapsulado:** ninguna operación de alta, baja o modificación se realiza sobre las tablas directamente; todas están encapsuladas en stored procedures.
- **Validaciones con mensaje único:** cada SP acumula todas las condiciones no cumplidas y las informa en un solo mensaje de error claro para el usuario final, mediante `;THROW`.
- **Transacciones:** los SPs detectan con `@@TRANCOUNT` si ya existe una transacción activa; en ese caso utilizan `SAVE TRANSACTION` (savepoints) para no comprometer la transacción del llamador, y propagan los errores con `;THROW`.
- **Re-ejecutabilidad:** los scripts validan la existencia de los objetos antes de crearlos o borrarlos, y los SPs usan `CREATE OR ALTER`.
- **Importaciones con lógica de upsert:** las importaciones insertan registros nuevos y actualizan los existentes, evitando duplicados en corridas reiteradas del mismo dataset. Las filas inválidas se rechazan y se registran en el log con su motivo, sin impedir la importación de los registros válidos. El nombre del archivo es un parámetro del SP de importación.
- **Sin SQL dinámico**, salvo donde es estrictamente necesario (lectura de archivos vía `OPENROWSET` con ruta parametrizada y pasos del script de cifrado que alteran la estructura de columnas).
- **Sin cursores:** los recorridos fila a fila (por ejemplo, las llamadas a la API de geolocalización) se resuelven con `WHILE` sobre tablas temporales.

---

## Orden de ejecución

Para recrear la base desde cero:

1. `ddl/01_base_de_datos.sql`
2. `ddl/02_tablas.sql`
3. `ddl/03_tvps.sql`
4. `stored-procedures/03` a `stored-procedures/12` (en orden)
5. Testing de `stored-procedures/03` a `stored-procedures/12` (`testing/test_03` a `testing/test_12`, en orden)
6. `views/vistas_bi.sql`
7. `dml/seed_tablas.sql` — completar previamente las rutas de los archivos de `dml/imports/` al inicio del script
8. `stored-procedures/13_cifrado.sql` y `stored-procedures/14_roles.sql` (Entrega 8: se aplican como modificación sobre el sistema ya poblado)
9. Testing de la Entrega 8 (`testing/test_13_cifrado.sql` y `testing/test_14_roles.sql`)

Los tests que insertan datos corren dentro de una transacción con `ROLLBACK` al final, para no dejar registros persistidos. Los tests de importación requieren completar la ruta del archivo a importar al inicio del script.

---

## Requisitos de configuración de la instancia

Las importaciones y las llamadas a APIs requieren habilitar las siguientes opciones (los scripts de testing lo hacen mediante `sp_configure`):

- `Ole Automation Procedures` — llamadas HTTP a las APIs de geolocalización y feriados.
- `Ad Hoc Distributed Queries` — lectura de archivos Excel vía `OPENROWSET`.
- Proveedor **Microsoft.ACE.OLEDB.16.0** instalado, con `AllowInProcess` habilitado.

Las rutas de los archivos a importar deben ser accesibles para el **servicio** de SQL Server, no solo para el cliente desde el que se ejecuta el script.

---

## Fuentes de datos

| Dataset | Formato | Uso |
|---------|---------|-----|
| Áreas protegidas nacionales | Excel | Importación de parques (`USP_ImportarParque`) |
| Registro de concesiones al 31/12/2023 | Excel | Importación de concesionarias y concesiones (`USP_ImportarOrganizacionConcesionaria`) |
| Guías habilitados a julio 2019 | CSV | Importación de guías (`USP_ImportarGuiasCsv`) |

Los archivos se procesan tal cual se proveen, sin modificaciones con herramientas externas. Se incluye una copia de cada uno en `dml/imports/`. A continuación, cómo obtener cada dataset desde su fuente original.

### Parques nacionales (SIB — Sistema de Información de Biodiversidad)

1. Entrar a https://sib.gob.ar/
2. Cliquear en **"Lista de Áreas protegidas"**
3. Cliquear en **"Ver la lista completa"**
4. Cliquear el botón **"Descargar"**

### Concesiones (Administración de Parques Nacionales)

1. Entrar a https://www.argentina.gob.ar/parquesnacionales
2. Bajar casi al fondo de la página y cliquear **"Transparencia"**
3. Seleccionar la última opción del desplegable: **"Ver toda la información de transparencia de este organismo"**
4. Cliquear **"Permisos y concesiones"**
5. Cliquear el botón **"Descarga el listado de concesiones vigentes"**
6. Si la descarga falla, modificar la URL reemplazando `back.argentina.gob.ar` por `www.argentina.gob.ar`

Descarga directa: https://www.argentina.gob.ar/sites/default/files/2019/06/concesiones_31.12.2023.xlsx

### Guías de turismo (Datos Abiertos Mendoza)

1. Entrar a https://datosabiertos.mendoza.gov.ar/
2. Cliquear **"Turismo"**
3. Buscar y cliquear **"Guías Turísticos"**
4. Descargar el más reciente disponible (*Guías de turismo habilitados — Julio 2019*)

Descarga directa: https://datosabiertos.mendoza.gov.ar/dataset/c362bae5-355f-46c2-8dde-39624dadb0fc/resource/d81872d8-890d-42c3-8624-34117bc88f53/download/guias-a-julio-2019.csv
