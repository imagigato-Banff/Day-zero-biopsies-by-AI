# Sistema de biopsia virtual renal

Aplicación R Shiny en castellano para desplegar en Render mediante Docker.

## Versión
HOTFIX15 estable autocontenido.

## Modelos
Los modelos se descargan durante la construcción Docker desde:

`https://github.com/imagigato-Banff/Day-zero-biopsies-by-AI/releases/download/models-v1`

Archivos esperados:

- `cv_finalround_list_forSynapse.rds`
- `ah_finalround_list_forSynapse.rds`
- `IFTA_finalround_list_forSynapse.rds`
- `Glo_finalround_list_forSynapse.rds`

## Nota importante
Esta versión funciona en modo seguro para impedir que la aplicación se rompa por errores internos de los objetos `.rds`. La salida es orientativa y no sustituye la biopsia real ni el juicio clínico.

GitHub Pages no sirve para esta app; debe desplegarse en Render, Posit Connect, shinyapps.io u otro servidor compatible con R Shiny.
