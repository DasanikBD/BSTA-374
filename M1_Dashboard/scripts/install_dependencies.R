project_library <- file.path(getwd(), ".Rlib")
dir.create(project_library, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(project_library, .libPaths()))

packages <- c(
  "flexdashboard",
  "rmarkdown",
  "knitr",
  "shiny",
  "bslib",
  "leaflet",
  "DT",
  "ggplot2",
  "plotly",
  "dplyr",
  "sf",
  "scales",
  "RColorBrewer",
  "pdftools",
  "spdep"
)

available_locally <- vapply(packages, requireNamespace, logical(1), quietly = TRUE)
missing <- packages[!available_locally]

if (length(missing)) {
  message("Installing ", length(missing), " packages and dependencies...")
  install.packages(
    missing,
    repos = "https://cloud.r-project.org",
    dependencies = c("Depends", "Imports", "LinkingTo"),
    type = getOption("pkgType")
  )
} else {
  message("All dashboard packages are already installed.")
}

still_missing <- packages[
  !vapply(packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(still_missing)) {
  stop("Packages failed to load: ", paste(still_missing, collapse = ", "), call. = FALSE)
}

message("Package library: ", normalizePath(project_library, winslash = "/"))

