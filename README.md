# Sistema de biopsia virtual — HOTFIX12

Aplicación Shiny en castellano.

## Corrección clave

HOTFIX12 corrige el cierre de la función `server` en `app.R`. El despliegue anterior podía quedar en Render con:

`The application exited during initialization`

porque `app.R` estaba incompleto.

## Modelos

Los 4 modelos `.rds` se descargan durante la construcción Docker desde:

`https://github.com/imagigato-Banff/Day-zero-biopsies-by-AI/releases/download/models-v1`

## Verificación

Al abrir la app debe verse:

`Versión activa: HOTFIX12 castellano definitivo`
