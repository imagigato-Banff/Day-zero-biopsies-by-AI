suppressPackageStartupMessages({
  library(shiny)
  library(caret)
  library(caretEnsemble)
  library(randomForest)
  library(gbm)
  library(xgboost)
  library(MASS)
  library(nnet)
  library(ggplot2)
})
rebuild_model_from_parts <- function(model_dir, filename) {
  target <- file.path(model_dir, filename)
  if (file.exists(target)) return(invisible(TRUE))

  parts_dir <- file.path(model_dir, "parts")
  parts <- list.files(
    parts_dir,
    pattern = paste0("^", gsub("\\.", "\\\\.", filename), "\\.part[0-9]+$"),
    full.names = TRUE
  )
  parts <- sort(parts)
  if (length(parts) == 0) return(invisible(FALSE))

  out <- file(target, open = "wb")
  on.exit(close(out), add = TRUE)
  for (part in parts) {
    bytes <- readBin(part, what = "raw", n = file.info(part)$size)
    writeBin(bytes, out)
  }
  invisible(TRUE)
}

load_virtual_biopsy_models <- function(model_dir = "models") {
  required <- c(
    cv = "cv_finalround_list_forSynapse.rds",
    ah = "ah_finalround_list_forSynapse.rds",
    ifta = "IFTA_finalround_list_forSynapse.rds",
    glo = "Glo_finalround_list_forSynapse.rds"
  )

  if (!dir.exists(model_dir)) dir.create(model_dir, recursive = TRUE)
  invisible(lapply(required, function(filename) rebuild_model_from_parts(model_dir, filename)))

  paths <- file.path(model_dir, required)
  missing <- paths[!file.exists(paths)]
  if (length(missing) > 0) {
    stop("Faltan modelos o partes de modelos: ", paste(basename(missing), collapse = ", "))
  }
  list(
    cv = readRDS(paths[["cv"]]),
    ah = readRDS(paths[["ah"]]),
    ifta = readRDS(paths[["ifta"]]),
    glo = readRDS(paths[["glo"]])
  )
}
yes_no <- function(x) ifelse(identical(x, "Yes"), 1, 0)

creatinine_to_mg_dl <- function(value, unit) {
  if (identical(unit, "µmol/L")) return(value / 88.4)
  value
}

donor_from_input <- function(input) {
  creat <- creatinine_to_mg_dl(input$creatinine, input$creatinine_unit)
  deceased <- ifelse(input$donor_type == "Deceased donor", 1, 0)
  male <- ifelse(input$sex == "Male", 1, 0)

  data.frame(
    Age = as.numeric(input$age),
    Gender = male,
    Gender1 = male,
    Donor_type = deceased,
    Donor_type1 = deceased,
    Hypertension = yes_no(input$hypertension),
    Hypertension1 = yes_no(input$hypertension),
    Diabetes = yes_no(input$diabetes),
    Diabetes1 = yes_no(input$diabetes),
    Creatinine = as.numeric(creat),
    Proteinuria = yes_no(input$proteinuria),
    Proteinuria1 = yes_no(input$proteinuria),
    HCV_status = yes_no(input$hcv),
    HCV_status1 = yes_no(input$hcv),
    DCD = yes_no(input$dcd),
    DCD1 = yes_no(input$dcd),
    bmi = as.numeric(input$bmi),
    vascular_death = yes_no(input$vascular_death),
    vascular_death1 = yes_no(input$vascular_death),
    check.names = FALSE
  )
}

collect_train_models <- function(x) {
  out <- list()
  walk <- function(obj, nm = "model") {
    if (inherits(obj, "train")) {
      out[[nm]] <<- obj
    } else if (is.list(obj)) {
      nms <- names(obj)
      if (is.null(nms)) nms <- paste0(nm, "_", seq_along(obj))
      for (i in seq_along(obj)) walk(obj[[i]], nms[[i]])
    }
  }
  walk(x)
  out
}

required_predictors <- function(model) {
  vars <- NULL
  if (!is.null(model$trainingData)) {
    vars <- setdiff(names(model$trainingData), c(".outcome", "outcome", "y"))
  }
  if (length(vars) == 0 && !is.null(model$coefnames)) vars <- model$coefnames
  if (length(vars) == 0 && !is.null(model$finalModel$xNames)) vars <- model$finalModel$xNames
  unique(vars)
}

align_for_model <- function(model, donor) {
  vars <- required_predictors(model)
  if (length(vars) == 0) return(donor)

  x <- donor
  for (v in vars) {
    if (!v %in% names(x)) x[[v]] <- 0
  }
  x <- x[, vars, drop = FALSE]

  if (!is.null(model$trainingData)) {
    td <- model$trainingData
    for (v in vars) {
      if (v %in% names(td)) {
        if (is.factor(td[[v]])) {
          x[[v]] <- factor(as.character(x[[v]]), levels = levels(td[[v]]))
          if (is.na(x[[v]][1])) x[[v]] <- factor(levels(td[[v]])[1], levels = levels(td[[v]]))
        } else if (is.numeric(td[[v]]) || is.integer(td[[v]])) {
          x[[v]] <- as.numeric(x[[v]])
        }
      }
    }
  }
  x
}

clean_prob_names <- function(p) {
  nm <- gsub("^X", "", colnames(p))
  colnames(p) <- nm
  p
}

predict_classification_ensemble <- function(model_object, donor, lesion_name) {
  mods <- collect_train_models(model_object)
  warnings <- character(0)
  probs <- list()

  for (nm in names(mods)) {
    m <- mods[[nm]]
    p <- tryCatch({
      nd <- align_for_model(m, donor)
      as.data.frame(predict(m, newdata = nd, type = "prob"))
    }, error = function(e) {
      warnings <<- c(warnings, paste0(lesion_name, " / ", nm, ": ", conditionMessage(e)))
      NULL
    })
    if (!is.null(p)) {
      p <- clean_prob_names(p)
      for (s in c("0", "1", "2", "3")) if (!s %in% colnames(p)) p[[s]] <- 0
      probs[[nm]] <- p[, c("0", "1", "2", "3"), drop = FALSE]
    }
  }

  if (length(probs) == 0) {
    return(list(prob = setNames(rep(NA_real_, 4), c("0", "1", "2", "3")), warnings = warnings))
  }

  mat <- Reduce("+", probs) / length(probs)
  list(prob = as.numeric(mat[1, c("0", "1", "2", "3")]), warnings = warnings)
}

predict_regression_ensemble <- function(model_object, donor) {
  mods <- collect_train_models(model_object)
  warnings <- character(0)
  preds <- numeric(0)

  for (nm in names(mods)) {
    m <- mods[[nm]]
    pr <- tryCatch({
      nd <- align_for_model(m, donor)
      as.numeric(predict(m, newdata = nd))[1]
    }, error = function(e) {
      warnings <<- c(warnings, paste0("Glomerulosclerosis / ", nm, ": ", conditionMessage(e)))
      NA_real_
    })
    preds <- c(preds, pr)
  }

  if (length(preds) == 0 || all(is.na(preds))) return(list(value = NA_real_, warnings = warnings))
  list(value = max(0, min(100, mean(preds, na.rm = TRUE))), warnings = warnings)
}

predict_virtual_biopsy <- function(models, donor) {
  cv <- predict_classification_ensemble(models$cv, donor, "Arteriosclerosis")
  ah <- predict_classification_ensemble(models$ah, donor, "Arteriolar hyalinosis")
  ifta <- predict_classification_ensemble(models$ifta, donor, "IFTA")
  glo <- predict_regression_ensemble(models$glo, donor)

  names(cv$prob) <- names(ah$prob) <- names(ifta$prob) <- c("0", "1", "2", "3")

  list(
    donor = donor,
    cv = cv$prob,
    ah = ah$prob,
    ifta = ifta$prob,
    glo = glo$value,
    warnings = unique(c(cv$warnings, ah$warnings, ifta$warnings, glo$warnings))
  )
}

format_probability_table <- function(res) {
  pct <- function(x) ifelse(is.na(x), NA, round(100 * x, 1))
  data.frame(
    Lesion = rep(c("Arteriosclerosis (cv)", "Arteriolar hyalinosis (ah)", "IFTA"), each = 4),
    `Banff score` = rep(0:3, 3),
    `Probability (%)` = c(pct(res$cv), pct(res$ah), pct(res$ifta)),
    check.names = FALSE
  )
}

moderate_severe <- function(p) sum(p[c("2", "3")], na.rm = TRUE)
format_summary_table <- function(res) {
  data.frame(
    Resultado = c("Arteriosclerosis moderada/severa", "Hialinosis arteriolar moderada/severa", "IFTA moderada/severa", "Glomeruloesclerosis estimada"),
    Valor = c(
      paste0(round(100 * moderate_severe(res$cv), 1), "%"),
      paste0(round(100 * moderate_severe(res$ah), 1), "%"),
      paste0(round(100 * moderate_severe(res$ifta), 1), "%"),
      ifelse(is.na(res$glo), NA, paste0(round(res$glo, 1), "% de glomérulos esclerosados"))
    ),
    check.names = FALSE
  )
}

plot_virtual_biopsy_radar <- function(res) {
  vals <- c(
    `Glomerulosclerosis` = ifelse(is.na(res$glo), 0, res$glo / 100),
    `Arteriosclerosis\n(cv)` = moderate_severe(res$cv),
    `Arteriolar\nhyalinosis (ah)` = moderate_severe(res$ah),
    `Tubular atrophy\n(ct/IFTA)` = moderate_severe(res$ifta),
    `Interstitial fibrosis\n(ci/IFTA)` = moderate_severe(res$ifta)
  )
  n <- length(vals)
  angles <- seq(0, 2 * pi, length.out = n + 1)[- (n + 1)]
  df <- data.frame(
    x = vals * sin(angles),
    y = vals * cos(angles),
    label = names(vals),
    val = vals
  )
  poly <- rbind(df, df[1, ])
  grid <- do.call(rbind, lapply(seq(0.2, 1, by = 0.2), function(r) {
    data.frame(r = r, x = r * sin(c(angles, angles[1])), y = r * cos(c(angles, angles[1])))
  }))
  spokes <- data.frame(x = 0, y = 0, xend = sin(angles), yend = cos(angles))
  labs <- data.frame(x = 1.15 * sin(angles), y = 1.15 * cos(angles), label = names(vals))

  ggplot() +
    geom_path(data = grid, aes(x, y, group = r), linewidth = 0.3, alpha = 0.6) +
    geom_segment(data = spokes, aes(x = x, y = y, xend = xend, yend = yend), alpha = 0.5) +
    geom_polygon(data = poly, aes(x, y), fill = "#d9534f", alpha = 0.25, color = "#d9534f", linewidth = 1.2) +
    geom_point(data = df, aes(x, y), size = 3) +
    geom_text(data = labs, aes(x, y, label = label), size = 4) +
    coord_equal(xlim = c(-1.35, 1.35), ylim = c(-1.35, 1.35)) +
    theme_void() +
    ggtitle("Virtual Biopsy System")
}

make_clinical_note <- function(res) {
  s <- format_summary_table(res)
  paste0(
    "<div class='note-box'>",
    "<h3>Interpretación orientativa</h3>",
    "<p>El sistema estima la probabilidad de lesiones crónicas del injerto presentes en biopsia día-cero a partir de variables clínicas del donante.</p>",
    "<ul>",
    paste0("<li><strong>", s$Resultado, ":</strong> ", s$Valor, "</li>", collapse = ""),
    "</ul>",
    "<p><strong>Advertencia:</strong> este resultado no debe usarse como diagnóstico histológico definitivo ni como sustituto de una biopsia cuando exista indicación clínica.</p>",
    "</div>"
  )
}
