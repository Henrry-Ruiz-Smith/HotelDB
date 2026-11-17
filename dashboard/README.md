# HotelDB · Dashboard visual

Esta carpeta contiene una **alternativa web de visualización** al PBIX original. Se puede abrir sin SQL Server, sin Power BI y sin depender de librerías externas. Los indicadores se calculan sobre datos numéricos extraídos del seed SQL **de 2022**; no hay API ni actualización en vivo.

## Archivos

- **index.html:** dashboard web responsive con filtros, gráficos, resumen por hotel y exportación CSV.
- **data.js:** 1.000 registros, sin identificadores de cliente ni datos personales, con índices de hotel/tipo/mes/pago/satisfacción, noches, importes y cantidades.
- **preview.svg:** imagen de presentación que puede verse directamente en el README de GitHub.

La imagen SVG es una **instantánea sin filtros**; el dashboard web recalcula los indicadores al aplicar los controles.

## Abrir localmente

Clona el repositorio y abre dashboard/index.html en tu navegador. El dashboard carga el archivo local data.js y no requiere conexión a Internet.

Alternativamente, desde la raíz del repositorio:

~~~bash
python -m http.server 8000
~~~

Luego abre http://localhost:8000/dashboard/.

## Regeneración del dataset

Tras cambiar Querys/lnsercion_Hotel.sql:

~~~bash
python scripts/build_dashboard_data.py
python scripts/build_dashboard_data.py --check
python -m unittest discover -s tests -v
~~~

**Importante:** el generador refleja la estructura del seed original, que tiene una estancia, una asignación y un consumo por cliente. Se detiene ante duplicidades para evitar inflar importes o asociar hospedajes incorrectos. Si cambia el modelo, hay que adaptar también el generador y las métricas.

Cuando cambie el dataset, **preview.svg** debe actualizarse manualmente para reflejar nuevos KPI. El archivo Power BI PBIX original permanece intacto.

## Publicar mediante GitHub Pages

Una vez fusionado el pull request en main:

1. Ve a **Settings → Pages**.
2. En **Build and deployment / Source**, selecciona **GitHub Actions**.
3. El workflow .github/workflows/pages.yml publica **solo la carpeta dashboard**: no envía el SQL completo ni los datos personales del seed.
4. Si la publicación inicial no arranca, ejecuta "Deploy HotelDB dashboard" desde **Actions**.

La dirección prevista, tras habilitar el servicio, es:

https://henrry-ruiz-smith.github.io/HotelDB/

**No se considera una URL activa hasta que GitHub Pages confirme su despliegue**. La vista previa SVG sí puede observarse desde el README de la rama del PR sin Pages.

## Limitaciones

- Dataset histórico 2022, ingresos teóricos (no cobros efectivos).
- Inventario físico con duplicados: no se calcula ocupación/RevPAR.
- Satisfacción sin fecha de encuesta: el filtro de meses aplica fecha de entrada.
- El generador actual asume una estancia y una habitación asignada por cliente.
- Tarifa de catálogo y precio unitario de consumibles, no importes contractuales históricos.
