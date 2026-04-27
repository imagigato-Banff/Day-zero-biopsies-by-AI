# Virtual Biopsy Webapp

Aplicación R Shiny para estimar hallazgos histológicos de biopsia día-cero en trasplante renal usando los modelos públicos asociados al estudio de Yoo et al.

## Estructura

- `app.R`: aplicación Shiny.
- `R/prediction.R`: carga de modelos y funciones de predicción.
- `models/parts/`: modelos `.rds` divididos en partes de menos de 25 MB para poder subirlos desde la web de GitHub sin instalar Git ni GitHub Desktop.
- `Dockerfile`: despliegue en Render u otros servicios Docker.
- `render.yaml`: configuración para Render.
- `www/style.css`: estilos.

## Nota importante sobre los modelos

GitHub no permite subir desde navegador archivos individuales mayores de 25 MB. Por eso los modelos están divididos en partes `.part000`, `.part001`, etc.

No hay que unirlos manualmente. La aplicación los reconstruye automáticamente en el servidor cuando arranca.

## Despliegue recomendado: Render

1. Sube todos los archivos y carpetas de este proyecto a un repositorio GitHub.
2. En Render crea un nuevo **Web Service**.
3. Conecta el repositorio.
4. Elige **Docker**.
5. Deja Root Directory vacío.
6. Haz clic en **Create Web Service**.

La aplicación escuchará en el puerto 3838 mediante `rocker/shiny`.

## Limitación clínica

Uso orientativo/investigacional. No sustituye la valoración clínica ni una biopsia indicada.
