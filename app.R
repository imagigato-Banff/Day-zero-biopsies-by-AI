# Sistema de biopsia virtual - aplicación Shiny
# HOTFIX7: castellano, diagnóstico claro y modelos descargados en Docker.

options(shiny.sanitize.errors = FALSE)
source("R/prediction.R")

VERSION_APP <- "HOTFIX7 castellano con modelos integrados en Docker"

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
        tabPanel("Resultados", br(), tableOutput("prob_table"), br(), tableOutput("summary_table")),
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
        incProgress(0.15, detail = "Preparando datos")
        donor <- donor_from_input(input)
        incProgress(0.45, detail = "Cargando modelos")
        models <- modelos_cache()
        if (is.null(models)) {
          models <- load_virtual_biopsy_models("models")
          modelos_cache(models)
        }
        incProgress(0.80, detail = "Generando predicción")
        resultado(predict_virtual_biopsy(models, donor))
      }, error = function(e) {
        error_calc(conditionMessage(e))
      })
    })
  })

  output$status <- renderUI({
    if (!is.null(error_calc())) {
      return(div(class = "warning-box", strong("Error: "), error_calc()))
    }
    if (is.null(resultado())) {
      return(div(class = "ok-box", "Aplicación cargada. Introduce los datos del donante y pulsa ‘Calcular biopsia virtual’."))
    }
    res <- resultado()
    if (!is.null(res$warnings) && length(res$warnings) > 0) {
      div(class = "warning-box", strong("Avisos: "), tags$ul(lapply(res$warnings, tags$li)))
    } else {
      div(class = "ok-box", "Modelo cargado y predicción generada correctamente.")
    }
  })

  output$prob_table <- renderTable({
    req(!is.null(resultado()))
    format_probability_table(resultado())
  }, digits = 3, striped = TRUE, bordered = TRUE, hover = TRUE)

  output$summary_table <- renderTable({
    req(!is.null(resultado()))
    format_summary_table(resultado())
  }, digits = 3, striped = TRUE, bordered = TRUE, hover = TRUE)

  output$radar_plot <- renderPlot({
    req(!is.null(resultado()))
    plot_virtual_biopsy_radar(resultado())
  })

  output$clinical_note <- renderUI({
    req(!is.null(resultado()))
    HTML(make_clinical_note(resultado()))
  })

  output$diagnostico <- renderText({
    reqs <- required_model_files()
    paths <- file.path("models", reqs)
    estado <- vapply(paths, function(x) {
      if (file.exists(x)) {
        paste0("OK — ", basename(x), " — ", round(file.info(x)$size / 1024 / 1024, 1), " MB")
      } else {
        paste0("FALTA — ", basename(x))
      }
    }, character(1))
    paste(
      paste("Versión activa:", VERSION_APP),
      paste("URL configurada de modelos:", get_model_base_url()),
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
