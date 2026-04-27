# Virtual Biopsy System - Shiny Webapp

Webapp R Shiny para desplegar el sistema de biopsia virtual renal.

## Archivos principales

- `app.R`: interfaz Shiny.
- `R/prediction.R`: carga de modelos y predicción.
- `Dockerfile`: despliegue en Render.
- `render.yaml`: configuración para Render.

## Modelos

Los modelos `.rds` no van dentro del repositorio porque GitHub no permite subir archivos grandes desde la web.

Sube estos 4 archivos como **GitHub Release assets** con el tag `models-v1`:

- `cv_finalround_list_forSynapse.rds`
- `ah_finalround_list_forSynapse.rds`
- `IFTA_finalround_list_forSynapse.rds`
- `Glo_finalround_list_forSynapse.rds`

En Render añade esta variable de entorno:

```text
MODEL_BASE_URL=https://github.com/TU_USUARIO/TU_REPO/releases/download/models-v1
```

Ejemplo:

```text
MODEL_BASE_URL=https://github.com/imaggigato-Banff/Day-zero-biopsies-by-AI/releases/download/models-v1
```

La app descargará los modelos automáticamente al arrancar.

## Nota

GitHub Pages no sirve para Shiny. Usar Render como Web Service con Docker.
