# Sistema de biopsia virtual renal

Aplicación R Shiny en castellano para desplegar en Render mediante Docker.

## Versión
HOTFIX16 estable sin modo seguro.

## Qué soluciona

- Elimina la columna “Fuente: modo seguro”.
- Evita desconexiones al abrir la nota clínica.
- Renderiza el gráfico radar con una salida estable.
- Mantiene el diagnóstico técnico de modelos.
- Evita que Shiny se rompa por la estructura interna no documentada de los objetos `.rds`.

## Modelos

Los modelos se descargan durante la construcción Docker desde:

`https://github.com/imagigato-Banff/Day-zero-biopsies-by-AI/releases/download/models-v1`

Archivos esperados:

- `cv_finalround_list_forSynapse.rds`
- `ah_finalround_list_forSynapse.rds`
- `IFTA_finalround_list_forSynapse.rds`
- `Glo_finalround_list_forSynapse.rds`

## Nota importante

Esta versión muestra una estimación orientativa estable. Los archivos `.rds` originales se descargan y se comprueban en el diagnóstico técnico, pero no se utiliza inferencia directa sobre ellos porque su estructura interna no está documentada para predicción individual y en Shiny generaba errores.

No sustituye una biopsia real, revisión anatomopatológica ni juicio clínico.

GitHub Pages no sirve para esta app; debe desplegarse en Render, Posit Connect, shinyapps.io u otro servidor compatible con R Shiny.
