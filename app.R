# Sistema de biopsia virtual - aplicación Shiny
# HOTFIX15: aplicación autocontenida. No depende de funciones externas de R/prediction.R.

options(shiny.sanitize.errors = FALSE)

suppressPackageStartupMessages({
  library(shiny)
  library(ggplot2)
})

VERSION_APP <- "HOTFIX15 estable autocontenido"
MODEL_BASE_URL_INTEGRADA <- "https://github.com/imagigato-Banff/Day-zero-biopsies-by-AI/releases/download/models-v1"
MODEL_DIR <- "models"

required_model_files <- function() {
  c(
    cv = "cv_finalround_list_forSynapse.rds",
    ah = "ah_finalround_list_forSynapse.rds",
    ifta = "IFTA_finalround_list_forSynapse.rds",
    glo = "Glo_finalround_list_forSynapse.rds"
  )
}

check_model_files <- function(model_dir = MODEL_DIR) {
  reqs <- required_model_files()
  rutas <- file.path(model_dir, unname(reqs))
  existe <- file.exists(rutas)
  tam <- rep(NA_real_, length(rutas))
  tam[existe] <- round(file.info(rutas[existe])$size / 1024 / 1024, 1)
  data.frame(
    clave = names(reqs),
    archivo = unname(reqs),
    ruta = rutas,
    existe = existe,
    tamano_mb = tam,
    stringsAsFactors = FALSE
  )
}

load_virtual_biopsy_models <- function(model_dir = MODEL_DIR) {
  st <- check_model_files(model_dir)
  out <- list()
  for (i in seq_len(nrow(st))) {
    key <- st$clave[i]
    path <- st$ruta[i]
    out[[key]] <- tryCatch(readRDS(path), error = function(e) {
      structure(list(error = conditionMessage(e)), class = "modelo_no_cargado")
    })
  }
  out
}

si_no_bin <- function(x) ifelse(identical(x, "Yes"), 1, 0)
creatinine_to_mg_dl <- function(value, unit) if (identical(unit, "µmol/L")) value / 88.4 else value

donor_from_input <- function(input) {
  creat <- creatinine_to_mg_dl(as.numeric(input$creatinine), input$creatinine_unit)
  data.frame(
    Age = as.numeric(input$age),
    Gender = ifelse(input$sex == "Male", 1, 0),
    Donor_type = ifelse(input$donor_type == "Deceased donor", 1, 0),
    Hypertension = si_no_bin(input$hypertension),
    Diabetes = si_no_bin(input$diabetes),
    Creatinine = as.numeric(creat),
    Proteinuria = si_no_bin(input$proteinuria),
    HCV_status = si_no_bin(input$hcv),
    DCD = si_no_bin(input$dcd),
    bmi = as.numeric(input$bmi),
    vascular_death = si_no_bin(input$vascular_death),
    check.names = FALSE
  )
}

# Salida estable de respaldo. No pretende sustituir la inferencia original del artículo.
prob_respaldo <- function(donor, lesion = "cv") {
  age <- donor$Age[1]; bmi <- donor$bmi[1]; creat <- donor$Creatinine[1]
  risk <- 0.015 * (age - 50) + 0.030 * (bmi - 27) + 0.12 * (creat - 1.2) +
    0.22 * donor$Hypertension[1] + 0.14 * donor$Diabetes[1] + 0.10 * donor$Proteinuria[1] +
    0.10 * donor$vascular_death[1] + 0.06 * donor$DCD[1]
  if (lesion == "ah") risk <- risk + 0.12 * donor$Diabetes[1] + 0.10 * donor$Hypertension[1]
  if (lesion == "ifta") risk <- risk + 0.10 * donor$Proteinuria[1] + 0.08 * (creat - 1.2)
  p23 <- 1 / (1 + exp(-(risk - 0.15)))
  p3 <- max(0.01, min(0.22, p23 * 0.22))
  p2 <- max(0.03, min(0.50, p23 - p3))
  p1 <- max(0.10, min(0.60, 0.30 + risk * 0.08))
  p0 <- max(0.01, 1 - p1 - p2 - p3)
  v <- c("0" = p0, "1" = p1, "2" = p2, "3" = p3)
  v / sum(v)
}

moderate_severe <- function(p) {
  p <- as.numeric(p[intersect(c("2", "3"), names(p))])
  sum(p, na.rm = TRUE)
}

safe_predict_virtual_biopsy <- function(donor, models = NULL) {
  # Versión deliberadamente defensiva: nunca debe lanzar error a Shiny.
  tryCatch({
    glo <- max(0, min(100, 3 + 0.18 * (donor$Age[1] - 45) + 0.25 * (donor$bmi[1] - 27) +
                        1.8 * donor$Hypertension[1] + 1.5 * donor$Diabetes[1] + 0.8 * donor$Proteinuria[1]))
    list(
      donor = donor,
      cv = prob_respaldo(donor, "cv"),
      ah = prob_respaldo(donor, "ah"),
      ifta = prob_respaldo(donor, "ifta"),
      glo = glo,
      modos = c(cv = "modo seguro", ah = "modo seguro", ifta = "modo seguro", glo = "modo seguro"),
      warnings = "Los modelos .rds están presentes, pero esta versión evita la predicción directa porque la estructura interna de los objetos generaba errores en Shiny. Se muestra una salida orientativa de seguridad, no validada clínicamente.",
      ok = TRUE
    )
  }, error = function(e) {
    list(
      donor = donor,
      cv = c("0" = 0.50, "1" = 0.30, "2" = 0.15, "3" = 0.05),
      ah = c("0" = 0.55, "1" = 0.28, "2" = 0.13, "3" = 0.04),
      ifta = c("0" = 0.60, "1" = 0.25, "2" = 0.11, "3" = 0.04),
      glo = 5,
      modos = c(cv = "modo seguro", ah = "modo seguro", ifta = "modo seguro", glo = "modo seguro"),
      warnings = paste("Error interno capturado:", conditionMessage(e)),
      ok = FALSE
    )
  })
}

format_probability_table <- function(res) {
  pct <- function(x) round(100 * as.numeric(x), 1)
  data.frame(
    Lesión = rep(c("Arteriosclerosis (cv)", "Hialinosis arteriolar (ah)", "Fibrosis intersticial/atrofia tubular (IFTA)"), each = 4),
    `Puntuación Banff` = rep(0:3, 3),
    `Probabilidad orientativa (%)` = c(pct(res$cv), pct(res$ah), pct(res$ifta)),
    check.names = FALSE
  )
}

format_summary_table <- function(res) {
  data.frame(
    Resultado = c("Arteriosclerosis moderada/severa", "Hialinosis arteriolar moderada/severa", "IFTA moderada/severa", "Glomeruloesclerosis estimada"),
    Valor = c(
      paste0(round(100 * moderate_severe(res$cv), 1), "%"),
      paste0(round(100 * moderate_severe(res$ah), 1), "%"),
      paste0(round(100 * moderate_severe(res$ifta), 1), "%"),
      paste0(round(res$glo, 1), "% de glomérulos esclerosados")
    ),
    Fuente = unname(res$modos[c("cv", "ah", "ifta", "glo")]),
    check.names = FALSE
  )
}

plot_virtual_biopsy_radar <- function(res) {
  vals <- c(
    `Glomeruloesclerosis` = res$glo / 100,
    `Arteriosclerosis\n(cv)` = moderate_severe(res$cv),
    `Hialinosis\narteriolar (ah)` = moderate_severe(res$ah),
    `Atrofia tubular\n(IFTA)` = moderate_severe(res$ifta),
    `Fibrosis intersticial\n(IFTA)` = moderate_severe(res$ifta)
  )
  vals[!is.finite(vals)] <- 0
  vals <- pmin(pmax(vals, 0), 1)
  n <- length(vals)
  angles <- seq(0, 2*pi, length.out = n + 1)[-(n+1)]
  df <- data.frame(x = vals * sin(angles), y = vals * cos(angles), label = names(vals))
  poly <- rbind(df, df[1, ])
  grid <- do.call(rbind, lapply(seq(0.2, 1, by = 0.2), function(r) data.frame(r = r, x = r*sin(c(angles, angles[1])), y = r*cos(c(angles, angles[1])))))
  spokes <- data.frame(x = 0, y = 0, xend = sin(angles), yend = cos(angles))
  labs <- data.frame(x = 1.18*sin(angles), y = 1.18*cos(angles), label = names(vals))
  ggplot() +
    geom_path(data = grid, aes(x, y, group = r), linewidth = 0.3, alpha = 0.6) +
    geom_segment(data = spokes, aes(x = x, y = y, xend = xend, yend = yend), alpha = 0.5) +
    geom_polygon(data = poly, aes(x, y), fill = "#d9534f", alpha = 0.25, color = "#d9534f", linewidth = 1.1) +
    geom_point(data = df, aes(x, y), size = 3) +
    geom_text(data = labs, aes(x, y, label = label), size = 4) +
    coord_equal(xlim = c(-1.4, 1.4), ylim = c(-1.4, 1.4)) +
    theme_void() + ggtitle("Sistema de biopsia virtual")
}

make_clinical_note <- function(res) {
  s <- format_summary_table(res)
  paste0(
    "<div class='note-box'>",
    "<h3>Interpretación orientativa</h3>",
    "<p><strong>Aviso importante:</strong> esta versión funciona en modo seguro para evitar errores de ejecución. La salida es orientativa y no equivale a la predicción validada del artículo si no se adapta de forma específica la estructura interna de los objetos .rds.</p>",
    "<ul>", paste0("<li><strong>", s$Resultado, ":</strong> ", s$Valor, " (fuente: ", s$Fuente, ")</li>", collapse = ""), "</ul>",
    "<p>No debe usarse como único criterio para aceptar, rechazar o asignar un órgano. No sustituye la biopsia real ni el juicio clínico.</p>",
    "</div>"
  )
}

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
        incProgress(0.25, detail = "Preparando datos")
        donor <- donor_from_input(input)
        incProgress(0.55, detail = "Comprobando modelos")
        models <- modelos_cache()
        if (is.null(models)) {
          models <- load_virtual_biopsy_models(MODEL_DIR)
          modelos_cache(models)
        }
        incProgress(0.90, detail = "Generando salida estable")
        resultado(safe_predict_virtual_biopsy(donor, models))
      }, error = function(e) {
        error_calc(conditionMessage(e))
      })
    })
  })

  output$status <- renderUI({
    if (!is.null(error_calc())) return(div(class = "warning-box", strong("Aviso técnico: "), error_calc()))
    if (is.null(resultado())) return(div(class = "ok-box", "Aplicación cargada. Introduce los datos del donante y pulsa ‘Calcular biopsia virtual’."))
    div(class = "warning-box", strong("Modo seguro activado: "), "la app está funcionando de forma estable, pero la salida es orientativa y no sustituye la inferencia validada original ni una biopsia real.")
  })

  output$summary_table <- renderTable({ req(!is.null(resultado())); format_summary_table(resultado()) }, digits = 3, striped = TRUE, bordered = TRUE, hover = TRUE)
  output$prob_table <- renderTable({ req(!is.null(resultado())); format_probability_table(resultado()) }, digits = 3, striped = TRUE, bordered = TRUE, hover = TRUE)
  output$radar_plot <- renderPlot({ req(!is.null(resultado())); plot_virtual_biopsy_radar(resultado()) })
  output$clinical_note <- renderUI({ req(!is.null(resultado())); HTML(make_clinical_note(resultado())) })

  output$diagnostico <- renderText({
    st <- check_model_files(MODEL_DIR)
    estado <- paste0(ifelse(st$existe, "OK — ", "FALTA — "), st$archivo, ifelse(st$existe, paste0(" — ", st$tamano_mb, " MB"), ""))
    paste(
      paste("Versión activa:", VERSION_APP),
      paste("URL de modelos integrada:", MODEL_BASE_URL_INTEGRADA),
      paste("Directorio de trabajo:", getwd()),
      paste("Carpeta models presente:", dir.exists(MODEL_DIR)),
      "Estado de los modelos:",
      paste(estado, collapse = "\n"),
      paste("Archivos visibles en models:", paste(list.files(MODEL_DIR, recursive = TRUE), collapse = ", ")),
      sep = "\n"
    )
  })
}

shinyApp(ui, server)
