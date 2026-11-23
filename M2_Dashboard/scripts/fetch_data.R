required_packages <- c("dplyr", "sf", "pdftools")
available_packages <- vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
missing_packages <- required_packages[!available_packages]

if (length(missing_packages)) {
  stop(
    "Install packages first with source('scripts/install_dependencies.R'). Missing: ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}

dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
dir.create("data/intermediate", recursive = TRUE, showWarnings = FALSE)
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)

download_if_missing <- function(url, destination) {
  if (!file.exists(destination)) {
    message("Downloading ", basename(destination), "...")
    utils::download.file(url, destination, mode = "wb", quiet = FALSE)
  }
  destination
}

# -----------------------------------------------------------------------------
# County geography
# -----------------------------------------------------------------------------
boundary_zip <- "data/raw/cb_2022_us_county_500k.zip"
boundary_url <- paste0(
  "https://www2.census.gov/geo/tiger/GENZ2022/shp/",
  "cb_2022_us_county_500k.zip"
)
download_if_missing(boundary_url, boundary_zip)

shape_path <- "data/processed/pa_counties.rds"
if (!file.exists(shape_path)) {
  shape_dir <- tempfile("county_shapes_")
  dir.create(shape_dir)
  utils::unzip(boundary_zip, exdir = shape_dir)
  shape_file <- list.files(shape_dir, pattern = "\\.shp$", full.names = TRUE)

  counties <- sf::st_read(shape_file, quiet = TRUE) |>
    dplyr::filter(.data$STATEFP == "42") |>
    dplyr::transmute(
      county_fips = .data$GEOID,
      county_name = .data$NAME
    ) |>
    sf::st_make_valid() |>
    sf::st_transform(4326)

  saveRDS(counties, shape_path, compress = "xz")
  unlink(shape_dir, recursive = TRUE, force = TRUE)
} else {
  counties <- readRDS(shape_path)
}

if (nrow(counties) != 67L) {
  stop("Expected 67 Pennsylvania county polygons; received ", nrow(counties), ".",
       call. = FALSE)
}

# -----------------------------------------------------------------------------
# Observed diabetes deaths from Pennsylvania death certificates
# -----------------------------------------------------------------------------
death_pdf_url <- function(year) {
  paste0(
    "https://www.pa.gov/content/dam/copapwp-pagov/en/health/documents/",
    "topics/healthstatistics/vitalstatistics/deathstatistics/documents/",
    "Death_AgeSexRaceCause_Cnty_", year, ".pdf"
  )
}

extract_pdf_counts <- function(path, year, county_names) {
  pages <- pdftools::pdf_text(path)
  diabetes_pages <- pages[grepl("Diabetes Mellitus", pages, ignore.case = TRUE)]

  rows <- lapply(diabetes_pages, function(page_text) {
    lines <- trimws(strsplit(page_text, "\\n", fixed = FALSE)[[1]])
    county <- county_names[county_names %in% lines][1]
    cause_index <- grep("^Diabetes Mellitus$", lines, ignore.case = TRUE)[1]
    following <- lines[seq.int(cause_index + 1, min(cause_index + 12, length(lines)))]
    total_line <- following[grep("^Total\\s+[0-9,]+", following)][1]
    deaths <- as.integer(gsub(",", "", sub("^Total\\s+([0-9,]+).*$", "\\1", total_line)))

    data.frame(
      year = year,
      county_name = county,
      deaths = deaths,
      stringsAsFactors = FALSE
    )
  })

  result <- dplyr::bind_rows(rows)
  if (nrow(result) != 67L || anyNA(result)) {
    stop(
      "Expected 67 complete county diabetes rows in ", basename(path),
      "; extracted ", nrow(result), ".",
      call. = FALSE
    )
  }
  result
}

pdf_deaths <- lapply(2018:2024, function(year) {
  destination <- file.path("data/raw", paste0("pa_deaths_", year, ".pdf"))
  download_if_missing(death_pdf_url(year), destination)
  message("Extracting observed diabetes deaths for ", year, "...")
  extract_pdf_counts(destination, year, counties$county_name)
}) |>
  dplyr::bind_rows()

death_2025_url <- paste0(
  "https://www.pa.gov/content/dam/copapwp-pagov/en/health/documents/",
  "topics/healthstatistics/vitalstatistics/deathstatistics/documents/2025/",
  "data-zipped/county-age-cause-2025.zip"
)
death_2025_zip <- download_if_missing(
  death_2025_url,
  "data/raw/county-age-cause-2025.zip"
)
death_2025_files <- utils::unzip(death_2025_zip, list = TRUE)$Name
death_2025_csv <- death_2025_files[grepl("\\.csv$", death_2025_files, ignore.case = TRUE)][1]
death_2025_raw <- utils::read.csv(
  unz(death_2025_zip, death_2025_csv),
  colClasses = "character",
  check.names = FALSE
)
death_2025 <- death_2025_raw |>
  dplyr::filter(
    .data$age == "Total",
    .data$cause == "Diabetes mellitus",
    .data$county_fips != "42000"
  ) |>
  dplyr::transmute(
    year = 2025L,
    county_name = .data$county_name,
    deaths = as.integer(.data$count)
  )

if (nrow(death_2025) != 67L || anyNA(death_2025)) {
  stop("Expected 67 complete county diabetes rows in the 2025 CSV.", call. = FALSE)
}

death_counts <- dplyr::bind_rows(pdf_deaths, death_2025) |>
  dplyr::left_join(
    sf::st_drop_geometry(counties),
    by = "county_name"
  ) |>
  dplyr::select(
    .data$year, .data$county_fips, .data$county_name, .data$deaths
  ) |>
  dplyr::arrange(.data$year, .data$county_fips)

if (nrow(death_counts) != 67L * 8L || anyNA(death_counts)) {
  stop("Observed death counts did not join cleanly to all county FIPS codes.", call. = FALSE)
}

utils::write.csv(
  death_counts,
  "data/intermediate/pa_diabetes_deaths_2018_2025.csv",
  row.names = FALSE
)

# -----------------------------------------------------------------------------
# Consistent county-age denominators and indirectly standardized measures
# -----------------------------------------------------------------------------
intercensal_age_url <- paste0(
  "https://www2.census.gov/programs-surveys/popest/datasets/",
  "2010-2020/intercensal/county/asrh/cc-est2020int-agesex-42.csv"
)
vintage_2025_age_url <- paste0(
  "https://www2.census.gov/programs-surveys/popest/datasets/",
  "2020-2025/counties/asrh/cc-est2025-agesex-42.csv"
)
download_if_missing(
  intercensal_age_url,
  "data/raw/cc-est2020int-agesex-42.csv"
)
download_if_missing(
  vintage_2025_age_url,
  "data/raw/cc-est2025-agesex-42.csv"
)
source("scripts/build_age_standardized_data.R", local = TRUE)

death_source_years <- 2018:2024
sources <- data.frame(
  component = c(
    paste0("Observed diabetes deaths, ", death_source_years),
    "Observed diabetes deaths, 2025",
    "Intercensal county-age population, 2018-2019",
    "County-age population, 2020-2025",
    "County boundaries"
  ),
  url = c(
    vapply(death_source_years, death_pdf_url, character(1)),
    death_2025_url,
    intercensal_age_url,
    vintage_2025_age_url,
    boundary_url
  ),
  role = c(
    rep("Primary observed count", length(death_source_years)),
    "Primary observed count",
    "Primary age-specific denominator",
    "Primary age-specific denominator",
    "Areal geometry"
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(sources, "data/processed/data_sources.csv", row.names = FALSE)

message("Age-adjusted surveillance data are ready in data/processed/.")
