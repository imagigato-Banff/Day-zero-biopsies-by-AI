# Sistema de biopsia virtual

Aplicación R Shiny en castellano para desplegar en Render. Los modelos se descargan desde GitHub Releases durante la construcción Docker.

Release de modelos:
`https://github.com/imagigato-Banff/Day-zero-biopsies-by-AI/releases/download/models-v1`

## Despliegue

1. Subir el contenido de este paquete al repositorio, no el ZIP.
2. Confirmar que `Dockerfile` contiene `imagigato-Banff` y no `imaggigato-Banff`.
3. En Render, usar `Manual Deploy -> Deploy latest commit` si el despliegue no comienza solo.
4. Abrir `/ ?v=hotfix14` y revisar `Diagnóstico técnico`.

## Nota clínica

Esta app es orientativa/investigacional y no sustituye la biopsia real, el juicio clínico ni los protocolos locales.
