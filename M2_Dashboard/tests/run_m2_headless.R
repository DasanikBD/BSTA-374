port <- as.integer(Sys.getenv("M2_TEST_PORT", unset = "3880"))

project_library <- file.path(getwd(), ".Rlib")
if (dir.exists(project_library)) {
  .libPaths(c(project_library, .libPaths()))
}

if (!requireNamespace("rmarkdown", quietly = TRUE)) {
  stop("The rmarkdown package is required.", call. = FALSE)
}

rmarkdown::run(
  file = "dashboard_app.Rmd",
  shiny_args = list(
    port = port,
    host = "127.0.0.1",
    launch.browser = FALSE
  )
)
