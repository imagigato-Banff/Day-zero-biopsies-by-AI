# Sistema de biopsia virtual

Aplicación Shiny en castellano para estimar de forma orientativa hallazgos de biopsia día cero en trasplante renal a partir de variables básicas del donante.

## Despliegue en Render

La aplicación descarga los modelos desde esta Release de GitHub:

https://github.com/imaggigato-Banff/Day-zero-biopsies-by-AI/releases/download/models-v1

La variable `MODEL_BASE_URL` es opcional. Si no existe, la aplicación usa esa URL por defecto.

## Archivos esperados en la Release `models-v1`

- `cv_finalround_list_forSynapse.rds`
- `ah_finalround_list_forSynapse.rds`
- `IFTA_finalround_list_forSynapse.rds`
- `Glo_finalround_list_forSynapse.rds`

## Nota clínica

Uso orientativo/investigacional. No sustituye la valoración clínica ni una biopsia indicada.
