# Modelo de datos y contrato de indicadores

## Grano y relaciones

~~~mermaid
erDiagram
    HOTEL ||--o{ HABITACION : contiene
    TIPO_HABITACION ||--o{ HABITACION : clasifica
    CLIENTE ||--o{ ESTANCIA : realiza
    MODO_PAGO ||--o{ ESTANCIA : utiliza
    ESTANCIA ||--o{ CLIENTE_HABITACION : asignacion
    HABITACION ||--o{ CLIENTE_HABITACION : asignada
    SATISFACCION ||--o{ CLIENTE_HABITACION : encuesta
    ESTANCIA ||--o{ CONSUMO : consume
    CONSUMIBLE ||--o{ CONSUMO : articulo
    TIPO_CONSUMIBLE ||--o{ CONSUMIBLE : categoria
    HOTEL ||--o{ EMPLEADO : emplea
    TIPO_EMPLEADO ||--o{ EMPLEADO : cargo
~~~

La tabla **ESTANCIA** representa un hospedaje (Id_Estancia) de un cliente. **CLIENTE_HABITACION** es el puente de asignaciones, y cada fila pertenece a una estancia concreta. Una estancia puede comprender varias habitaciones, por lo que NO debe inferirse un conteo de estancias usando COUNT(*) sobre el puente. **CONSUMO** pertenece a una estancia; para imputarlo al hotel, usar una lista DISTINCT (Id_Estancia, Id_Hotel) desde las habitaciones vinculadas. La migración rechaza las estancias asociadas a más de un hotel.

Los nuevos campos **Id_Estancia** y **Tarifa_Por_Noche** se añaden mediante la migración después del seed original. No ejecutar esta migración antes de la carga, ya que el script legado inserta los valores sin enumerar columnas.

## Contrato de dbo.vista_estancias

**Grano:** una fila por (Id_Estancia, Id_Cliente_Habitacion), es decir, una asignación de habitación por estancia. El Id_Cliente_Habitacion no se muestra en la vista, por lo que si se requieren claves técnicas de fila para Power BI hay que extender la vista. Se incluyen Id_Estancia e Id_Habitacion; una futura habitación reasignada dentro de una misma estancia podría repetir esa combinación si se modelan intervalos independientes.

| Medida / dimensión | Definición | Cuidado |
| --- | --- | --- |
| Noches | DATEDIFF(DAY, Fecha_Entrada, Fecha_Salida) | Una noche corresponde al intervalo de fechas en SQL Server. |
| Tarifa_Por_Noche | Precio tomado del catálogo al migrar, guardado en la asignación | No hay tarifa contractual en el origen 2022. |
| Ingreso_Alojamiento | Noches × Tarifa_Por_Noche | Es ingreso teórico de alojamiento, no cobros ni neto de impuestos. |
| Estancias | DISTINCTCOUNT(Id_Estancia) | COUNT(*) sobre la vista sobrecontaría estancias con varias habitaciones. |
| Unidades de consumibles | SUM(CONSUMO.Cantidad) | No usar COUNT(Cantidad) para medir demanda en unidades. |
| Ingresos de consumibles | SUM(Cantidad × PrecioUnitario) | No existe precio de venta histórico por consumo; se usa el catálogo actual. |
| Satisfacción favorable | Respuestas Satisfecho o Muy satisfecho / total de respuestas no nulas | Fecha_Entrada es proxy del periodo, no fecha de encuesta. |

La vista conserva por compatibilidad los campos **Nombre**, **Modo_Pago**, **[Nombre de clientes]**, **Tipo** y **Precio** de la implementación previa. Los nuevos campos se deben mapear en el modelo de Power BI. **vista_satisfacion** conserva su nombre original, incluso su grafía, para no romper referencias existentes.

## Medidas DAX sugeridas

Si en Power BI la tabla importada desde dbo.vista_estancias se llama **vista_estancias**:

~~~dax
Ingreso alojamiento = SUM(vista_estancias[Ingreso_Alojamiento])

Estancias = DISTINCTCOUNT(vista_estancias[Id_Estancia])

Noches habitación vendidas = SUM(vista_estancias[Noches])

Tarifa media por noche = 
    DIVIDE([Ingreso alojamiento], [Noches habitación vendidas])

Encuestas contestadas =
    CALCULATE(
        COUNTROWS(vista_estancias),
        NOT ISBLANK(vista_estancias[Nivel_Satisfaccion])
    )

Encuestas favorables =
    CALCULATE(
        COUNTROWS(vista_estancias),
        vista_estancias[Nivel_Satisfaccion] IN {"Satisfecho", "Muy satisfecho"}
    )

Porcentaje satisfacción favorable =
    DIVIDE([Encuestas favorables], [Encuestas contestadas])
~~~

Las medidas de noches y facturación tienen grano **habitación-noche**, no estancia-noche. Si hay más de una habitación por estancia, es correcto sumar noches de habitaciones, pero no usar esa suma para medir noches únicas de huéspedes. Para consumo, construir una tabla de hechos por Id_Consumo con relación correcta a estancia y hotel; no relacionar CONSUMO directamente con una tabla de asignaciones sin desduplicar, porque provocaría fan-out.

## Advertencias sobre el dataset

- **Duplicados de número de habitación** dentro de un mismo hotel: se observaron 1.000 Id_Habitacion frente a 145 pares únicos (Id_Hotel, Numero_Habitacion). Debe decidirse la semántica del dato antes de imponer unicidad o reportar ocupación.
- **Posibles incoherencias de catálogo:** revisar nombres y ciudades de hotel (por ejemplo, el registro "Hampton Arequipa" tiene "Piura" como ciudad).
- **Los 1.000 clientes de muestra presentan una estancia cada uno.** Esta coincidencia permite el backfill de la migración. No es un supuesto de negocio generalizable.
- **No hay cobros efectivos, reservas canceladas, capacidades, inventario fiable ni fecha de encuesta.** Por ello no se deben publicar métricas de RevPAR, ocupación física, cancelación, cobros reales o NPS como si fueran datos observados.
- **Año de facturación:** la consulta 5 asigna todas las noches al año de entrada de la estancia. Si hay estancias que cruzan diciembre/enero, será necesario partirlas por fechas de calendario.

## Comprobaciones recomendadas en Power BI Desktop

1. Actualizar el origen SQL Server hacia la base **BDHOTEL** y validar las credenciales.
2. Comparar SUM(vista_estancias[Ingreso_Alojamiento]) con la suma calculada en SSMS.
3. Confirmar que DISTINCTCOUNT(Id_Estancia) devuelve 1.000 en la muestra inicial.
4. Validar que el total de encuestas por hotel y nivel del primer semestre coincide con dbo.vista_satisfacion.
5. Revisar que la medida de consumo no se infla al filtrar por hotel; usar el puente de estancias y hoteles desduplicado.
6. Documentar capturas del reporte solo después de validar su significado; no se modificó el archivo PBIX original.

**Control de cambios:** las vistas, la migración y las cinco consultas están pensadas como una primera mejora del proyecto, no como una migración automática apta para una base hotelera productiva.
