# Sistema de biopsia virtual - aplicación Shiny
# HOTFIX14: estable; no se cae aunque la predicción directa de los RDS falle.

options(shiny.sanitize.errors = FALSE)
source("R/prediction.R", local = FALSE)

VERSION_APP <- "HOTFIX14 castellano estable"

ui <- fluidPage(
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "style.css"),
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1")
  ),
  div(class = "page-header",
      h1("Sistema de biopsia virtual"),
      p("Predicción orientativa de hallazgos histológicos de biopsia día cero en trasplante renal usando parámetros básicos del donante."),
      p(class = "version-text", paste("Versión activa:", VERSION_APP))
  ),
  sidebarLayout(
    sidebarPanel(width = 4,
      h3("Datos del donante"),
      numericInput("age", "Edad (años)", value = 50, min = 18, max = 100, step = 1),
      selectInput("sex", "Sexo", choices = c("Mujer" = "Female", "Hombre" = "Male"), selected = "Male"),
      numericInput("bmi", "Índice de masa corporal / IMC (kg/m²)", value = 27, min = 10, max = 70, step = 0.1),
      radioButtons("creatinine_unit", "Unidad de creatinina", choices = c("mg/dL", "µmol/L"), selected = "mg/dL", inline = TRUE),
      numericInput("creatinine", "Creatinina", value = 1.2, min = 0, max = 2000, step = 0.1),
      selectInput("donor_type", "Tipo de donante", choices = c("Donante vivo" = "Living donor", "Donante fallecido" = "Deceased donor"), selected = "Deceased donor"),
      selectInput("diabetes", "Diabetes", choices = c("No" = "No", "Sí" = "Yes"), selected = "No"),
      selectInput("hypertension", "Hipertensión", choices = c("No" = "No", "Sí" = "Yes"), selected = "No"),
      selectInput("proteinuria", "Proteinuria", choices = c("No" = "No", "Sí" = "Yes"), selected = "No"),
      selectInput("hcv", "Virus de la hepatitis C (VHC)", choices = c("No" = "No", "Sí" = "Yes"), selected = "No"),
      selectInput("dcd", "Donante tras muerte circulatoria", choices = c("No" = "No", "Sí" = "Yes"), selected = "No"),
      selectInput("vascular_death", "Muerte por causa cerebrovascular", choices = c("No" = "No", "Sí" = "Yes"), selected = "No"),
      actionButton("run", "Calcular biopsia virtual", class = "btn-primary btn-lg")
    ),
    mainPanel(width = 8,
      uiOutput("status"),
      tabsetPanel(
        tabPanel("Resultados", br(), tableOutput("summary_table"), br(), tableOutput("prob_table")),
        tabPanel("Gráfico radar", br(), plotOutput("radar_plot", height = "520px")),
        tabPanel("Nota clínica", br(), uiOutput("clinical_note")),
        tabPanel("Diagnóstico técnico", br(), verbatimTextOutput("diagnostico"))
      )
    )
  ),
  hr(),
  div(class = "footer",
      p("Uso orientativo/investigacional. No sustituye la valoración clínica ni una biopsia indicada."),
      p("Modelo publicado por Yoo et al., Nature Communications 2024. Código bajo licencia AGPL-3.0.")
  )
)

server <- function(input, output, session) {
  resultado <- reactiveVal(NULL)
  error_calc <- reactiveVal(NULL)
  modelos_cache <- reactiveVal(NULL)

  observeEvent(input$run, {
    resultado(NULL)
    error_calc(NULL)
    withProgress(message = "Calculando...", value = 0, {
      tryCatch({
        incProgress(0.20, detail = "Preparando datos")
        donor <- donor_from_input(input)
        incProgress(0.50, detail = "Cargando modelos")
        models <- modelos_cache()
        if (is.null(models)) {
          models <- load_virtual_biopsy_models("models")
          modelos_cache(models)
        }
        incProgress(0.85, detail = "Generando salida")
        resultado(predict_virtual_biopsy(models, donor))
      }, error = function(e) {
        error_calc(conditionMessage(e))
      })
    })
  })

  output$status <- renderUI({
    if (!is.null(error_calc())) return(div(class = "warning-box", strong("Aviso técnico: "), error_calc()))
    if (is.null(resultado())) return(div(class = "ok-box", "Aplicación cargada. Introduce los datos del donante y pulsa ‘Calcular biopsia virtual’."))
    res <- resultado()
    if (any(res$modos == "respaldo")) {
      div(class = "warning-box",
          strong("Modo seguro activado: "),
          "los modelos están cargados, pero una o más predicciones directas no fueron compatibles con la estructura interna de los .rds. La app no se rompe; revise la nota clínica antes de interpretar resultados.")
    } else {
      div(class = "ok-box", "Modelo cargado y predicción generada correctamente.")
    }
  })

  output$summary_table <- renderTable({ req(!is.null(resultado())); format_summary_table(resultado()) }, digits = 3, striped = TRUE, bordered = TRUE, hover = TRUE)
  output$prob_table <- renderTable({ req(!is.null(resultado())); format_probability_table(resultado()) }, digits = 3, striped = TRUE, bordered = TRUE, hover = TRUE)
  output$radar_plot <- renderPlot({ req(!is.null(resultado())); plot_virtual_biopsy_radar(resultado()) })
  output$clinical_note <- renderUI({ req(!is.null(resultado())); HTML(make_clinical_note(resultado())) })

  output$diagnostico <- renderText({
    st <- check_model_files("models")
    estado <- paste0(ifelse(st$existe, "OK — ", "FALTA — "), st$archivo, ifelse(st$existe, paste0(" — ", st$tamano_mb, " MB"), ""))
    paste(
      paste("Versión activa:", VERSION_APP),
      paste("URL de modelos integrada:", MODEL_BASE_URL_INTEGRADA),
      paste("Directorio de trabajo:", getwd()),
      paste("Carpeta models presente:", dir.exists("models")),
      "Estado de los modelos:",
      paste(estado, collapse = "\n"),
      paste("Archivos visibles en models:", paste(list.files("models", recursive = TRUE), collapse = ", ")),
      sep = "\n"
    )
  })
}

shinyApp(ui, server)
