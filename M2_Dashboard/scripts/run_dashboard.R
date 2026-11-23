project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

if (!file.exists(file.path(project_root, "dashboard_app.Rmd"))) {
  stop("Run this script from the Exercise_9 project root.", call. = FALSE)
}

project_library <- file.path(project_root, ".Rlib")
if (dir.exists(project_library)) {
  .libPaths(c(project_library, .libPaths()))
}

required_packages <- c(
  "flexdashboard", "rmarkdown", "shiny", "dplyr", "ggplot2",
  "plotly", "leaflet", "DT", "sf", "scales", "RColorBrewer"
)
missing <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing)) {
  stop(
    "Install dependencies with source('scripts/install_dependencies.R'). Missing: ",
    paste(missing, collapse = ", "),
    call. = FALSE
  )
}

rmarkdown::run(
  file = "dashboard_app.Rmd",
  shiny_args = list(
    launch.browser = TRUE,
    host = "127.0.0.1"
  )
)
