# Sistema de biopsia virtual — HOTFIX9

Aplicación Shiny en castellano para el sistema de biopsia virtual renal.

## Qué cambia esta versión

- La interfaz está en castellano.
- Los modelos `.rds` se descargan durante la construcción de la imagen Docker desde la Release `models-v1`.
- La app incluye una pestaña **Diagnóstico técnico** para comprobar si los modelos están presentes.

## Qué debes ver en Render

Durante la construcción, en los logs deben aparecer líneas de `curl` descargando estos cuatro modelos:

- `cv_finalround_list_forSynapse.rds`
- `ah_finalround_list_forSynapse.rds`
- `IFTA_finalround_list_forSynapse.rds`
- `Glo_finalround_list_forSynapse.rds`

Si esas líneas no aparecen, Render no está usando el Dockerfile nuevo.
