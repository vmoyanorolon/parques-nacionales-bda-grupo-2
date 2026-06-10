# Sistema de Gestión de Parques Nacionales

Trabajo Práctico — Materia 3641 Bases de Datos Aplicada  
Universidad Nacional de La Matanza  
Grupo 2 — Integrantes: Patricio Gaudino Tognozzi, Benjamín Velázquez, Valentín Moyano Rolón

---

## Descripción

Sistema centralizado para la gestión de parques nacionales argentinos. Contempla la administración de parques, venta de entradas, actividades turísticas, concesiones comerciales y personal (guías y guardaparques).

---

## Tecnologías

- Microsoft SQL Server 2022 Developer Edition
- T-SQL

---

## Convención de nomenclatura

- **Tablas:** PascalCase con schema como prefijo. Ejemplo: `Turismo.Visitante`
- **Stored Procedures:** PascalCase con prefijo `SP_`. Ejemplo: `SP_AltaVisitante`
- **Variables:** camelCase con prefijo `@`. Ejemplo: `@idVisitante`
- **Constraints:** prefijo según tipo seguido de tabla y columna. Ejemplo: `CK_Visitante_Edad`, `FK_Visitante_TipoVisitante`

---

## Schemas

| Schema | Contenido |
|--------|-----------|
| `Parques` | Parque |
| `Turismo` | Actividad, Entrada, Visitante, TipoVisitante |
| `Ventas` | Venta, LineaDeActividad, LineaDeEntrada |
| `Personal` | Guia, Guardaparque, Asignacion, Habilitacion, GuiaTrabajaEnParque |
| `Concesiones` | Concesion, PagoConcesion, OrganizacionConcesionaria |