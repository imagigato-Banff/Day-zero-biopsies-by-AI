# Virtual Biopsy System - Shiny webapp
# Hotfix 2: lazy model loading + corrected function name for model loader.

source("R/prediction.R")

ui <- fluidPage(
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "style.css"),
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1")
  ),
  div(class = "page-header",
      h1("Virtual Biopsy System"),
      p("Predicción de hallazgos histológicos de biopsia día-cero en trasplante renal usando parámetros básicos del donante.")
  ),
  sidebarLayout(
    sidebarPanel(width = 4,
      h3("Datos del donante"),
      numericInput("age", "Edad (años)", value = 50, min = 18, max = 100, step = 1),
      selectInput("sex", "Sexo", choices = c("Female", "Male"), selected = "Male"),
      numericInput("bmi", "Body Mass Index / BMI (kg/m²)", value = 27, min = 10, max = 70, step = 0.1),
      radioButtons("creatinine_unit", "Unidad de creatinina", choices = c("mg/dL", "µmol/L"), selected = "mg/dL", inline = TRUE),
      numericInput("creatinine", "Creatinina", value = 1.2, min = 0, max = 2000, step = 0.1),
      selectInput("donor_type", "Tipo de donante", choices = c("Living donor", "Deceased donor"), selected = "Deceased donor"),
      selectInput("diabetes", "Diabetes", choices = c("No", "Yes"), selected = "No"),
      selectInput("hypertension", "Hipertensión", choices = c("No", "Yes"), selected = "No"),
      selectInput("proteinuria", "Proteinuria", choices = c("No", "Yes"), selected = "No"),
      selectInput("hcv", "Hepatitis C virus (HCV)", choices = c("No", "Yes"), selected = "No"),
      selectInput("dcd", "Donante tras muerte circulatoria (DCD)", choices = c("No", "Yes"), selected = "No"),
      selectInput("vascular_death", "Muerte cerebrovascular", choices = c("No", "Yes"), selected = "No"),
      actionButton("run", "Calcular biopsia virtual", class = "btn-primary btn-lg")
    ),
    mainPanel(width = 8,
      uiOutput("status"),
      tabsetPanel(
        tabPanel("Resultados", br(), tableOutput("prob_table"), br(), tableOutput("summary_table")),
        tabPanel("Radar", br(), plotOutput("radar_plot", height = "520px")),
        tabPanel("Nota clínica", br(), uiOutput("clinical_note"))
      )
    )
  ),
  hr(),
  div(class = "footer",
      p("Uso orientativo/investigacional. No sustituye la valoración clínica ni una biopsia indicada."),
      p("Modelo publicado por Yoo et al. Nature Communications 2024. Código bajo AGPL-3.0.")
  )
)

server <- function(input, output, session) {
  values <- eventReactive(input$run, {
    withProgress(message = "Cargando modelos y calculando...", value = 0, {
      incProgress(0.2, detail = "Preparando datos")
      donor <- donor_from_input(input)
      incProgress(0.4, detail = "Cargando modelos")
      models <- load_virtual_biopsy_models("models")
      incProgress(0.8, detail = "Generando predicción")
      predict_virtual_biopsy(models, donor)
    })
  }, ignoreInit = TRUE)

  output$status <- renderUI({
    if (input$run == 0) {
      return(div(class = "ok-box", "App cargada. Introduce los datos del donante y pulsa 'Calcular biopsia virtual'. La primera predicción puede tardar porque Render descarga/carga los modelos."))
    }
    res <- tryCatch(values(), error = function(e) e)
    if (inherits(res, "error")) {
      div(class = "warning-box", strong("Error: "), conditionMessage(res))
    } else if (!is.null(res$warnings) && length(res$warnings) > 0) {
      div(class = "warning-box", strong("Avisos: "), tags$ul(lapply(res$warnings, tags$li)))
    } else {
      div(class = "ok-box", "Modelo cargado y predicción generada correctamente.")
    }
  })

  output$prob_table <- renderTable({
    req(input$run > 0)
    res <- values()
    validate(need(!inherits(res, "error"), "No se pudo generar la predicción."))
    format_probability_table(res)
  }, digits = 3, striped = TRUE, bordered = TRUE, hover = TRUE)

  output$summary_table <- renderTable({
    req(input$run > 0)
    res <- values()
    validate(need(!inherits(res, "error"), "No se pudo generar la predicción."))
    format_summary_table(res)
  }, digits = 3, striped = TRUE, bordered = TRUE, hover = TRUE)

  output$radar_plot <- renderPlot({
    req(input$run > 0)
    res <- values()
    validate(need(!inherits(res, "error"), "No se pudo generar la predicción."))
    plot_virtual_biopsy_radar(res)
  })

  output$clinical_note <- renderUI({
    req(input$run > 0)
    res <- values()
    validate(need(!inherits(res, "error"), "No se pudo generar la predicción."))
    HTML(make_clinical_note(res))
  })
}

shinyApp(ui, server)
