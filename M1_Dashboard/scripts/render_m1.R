project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

if (!file.exists(file.path(project_root, "dashboard.Rmd"))) {
  stop("Run this script from the final-dashboard project root.", call. = FALSE)
}

pandoc_candidates <- c(
  "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools",
  file.path(
    Sys.getenv("USERPROFILE"),
    "AppData", "Local", "Programs", "Quarto", "bin", "tools"
  )
)
pandoc_dirs <- pandoc_candidates[
  file.exists(file.path(pandoc_candidates, "pandoc.exe"))
]
if (length(pandoc_dirs)) {
  rmarkdown::find_pandoc(dir = pandoc_dirs[[1]], cache = FALSE)
}
if (!rmarkdown::pandoc_available()) {
  stop("Pandoc was not found. Render from RStudio.", call. = FALSE)
}

required_packages <- c(
  "flexdashboard", "rmarkdown", "knitr", "dplyr", "ggplot2",
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

output_path <- rmarkdown::render(
  input = "dashboard.Rmd",
  output_file = "DAS_A_M1.html",
  envir = new.env(parent = globalenv()),
  clean = TRUE,
  quiet = FALSE
)

output_path <- normalizePath(output_path, winslash = "/", mustWork = TRUE)
output_size <- file.info(output_path)$size
html_text <- readChar(output_path, nchars = output_size, useBytes = TRUE)

stopifnot(
  output_size > 500000,
  grepl("Pennsylvania Diabetes Mortality", html_text, fixed = TRUE),
  grepl("leaflet", html_text, ignore.case = TRUE),
  grepl("plotly", html_text, ignore.case = TRUE)
)

message("M1 dashboard created successfully: ", output_path)
message("Output size: ", scales::comma(output_size), " bytes")

