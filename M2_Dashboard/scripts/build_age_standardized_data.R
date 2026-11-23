project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

if (!file.exists(file.path(project_root, "R", "data_helpers.R"))) {
  stop("Run this script from the final-dashboard project root.", call. = FALSE)
}

required_packages <- c("dplyr", "pdftools")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages)) {
  stop(
    "Missing packages: ", paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}

suppressPackageStartupMessages(library(dplyr))
source("R/data_helpers.R")

county_shape_path <- "data/processed/pa_counties.rds"
existing_death_path <- "data/intermediate/pa_diabetes_deaths_2018_2025.csv"
intercensal_age_path <- "data/raw/cc-est2020int-agesex-42.csv"
vintage_2025_age_path <- "data/raw/cc-est2025-agesex-42.csv"

required_files <- c(
  county_shape_path,
  existing_death_path,
  intercensal_age_path,
  vintage_2025_age_path,
  file.path("data/raw", paste0("pa_deaths_", 2018:2024, ".pdf")),
  "data/raw/county-age-cause-2025.zip"
)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files)) {
  stop(
    "Required source files are missing: ",
    paste(missing_files, collapse = ", "),
    call. = FALSE
  )
}

counties <- readRDS(county_shape_path) |>
  sf::st_drop_geometry() |>
  transmute(
    county_fips = as.character(.data$county_fips),
    county_name = as.character(.data$county_name)
  ) |>
  arrange(.data$county_fips)

existing_deaths <- read.csv(existing_death_path, stringsAsFactors = FALSE)
existing_deaths$county_fips <- sprintf("%05s", existing_deaths$county_fips)

pdf_age_labels <- c(
  "0-4", "5-9", "10-14", "15-19", "20-24", "25-29",
  "30-34", "35-39", "40-44", "45-49", "50-54", "55-59",
  "60-64", "65-69", "70-74", "75-79", "80-84", "85+"
)

age_band_lookup <- c(
  "0-4" = "0-44", "5-9" = "0-44", "10-14" = "0-44",
  "15-19" = "0-44", "20-24" = "0-44", "25-29" = "0-44",
  "30-34" = "0-44", "35-39" = "0-44", "40-44" = "0-44",
  "45-49" = "45-64", "50-54" = "45-64", "55-59" = "45-64",
  "60-64" = "45-64", "65-69" = "65-74", "70-74" = "65-74",
  "75-79" = "75-84", "80-84" = "75-84", "85+" = "85+"
)
age_band_order <- c("0-44", "45-64", "65-74", "75-84", "85+")

extract_pdf_age_counts <- function(path, year, county_lookup) {
  pages <- pdftools::pdf_text(path)
  diabetes_pages <- pages[grepl("Diabetes Mellitus", pages, ignore.case = TRUE)]

  rows <- lapply(diabetes_pages, function(page_text) {
    lines <- trimws(strsplit(page_text, "\n", fixed = TRUE)[[1]])
    county <- county_lookup$county_name[county_lookup$county_name %in% lines][1]
    cause_index <- grep("^Diabetes Mellitus$", lines, ignore.case = TRUE)[1]
    following <- lines[
      seq.int(cause_index + 1L, min(cause_index + 12L, length(lines)))
    ]
    total_line <- following[grep("^Total\\s+[0-9,]+", following)][1]
    tokens <- strsplit(trimws(total_line), "\\s+")[[1]]
    values <- as.integer(gsub(",", "", tokens[-1]))

    if (is.na(county) || length(values) != 19L || anyNA(values)) {
      stop(
        "Could not parse county age counts from ", basename(path),
        " for page containing county ", county,
        call. = FALSE
      )
    }

    county_fips <- county_lookup$county_fips[
      match(county, county_lookup$county_name)
    ]

    data.frame(
      year = year,
      county_fips = county_fips,
      county_name = county,
      source_total = values[[1]],
      source_age_group = pdf_age_labels,
      deaths = values[-1],
      stringsAsFactors = FALSE
    )
  })

  result <- bind_rows(rows)
  if (n_distinct(result$county_fips) != 67L || nrow(result) != 67L * 18L) {
    stop(
      "Expected 67 counties and 18 age groups in ", basename(path),
      "; received ", n_distinct(result$county_fips), " counties and ",
      nrow(result), " rows.",
      call. = FALSE
    )
  }
  result
}

message("Extracting age-specific diabetes deaths from 2018-2024 PDFs...")
pdf_age_deaths <- bind_rows(lapply(2018:2024, function(year) {
  extract_pdf_age_counts(
    file.path("data/raw", paste0("pa_deaths_", year, ".pdf")),
    year,
    counties
  )
}))

zip_path <- "data/raw/county-age-cause-2025.zip"
zip_files <- unzip(zip_path, list = TRUE)$Name
csv_name <- zip_files[grepl("\\.csv$", zip_files, ignore.case = TRUE)][1]
raw_2025 <- read.csv(
  unz(zip_path, csv_name),
  colClasses = "character",
  check.names = FALSE
)

age_deaths_2025 <- raw_2025 |>
  filter(
    .data$cause == "Diabetes mellitus",
    .data$age != "Total",
    .data$county_fips != "42000"
  ) |>
  transmute(
    year = 2025L,
    county_fips = .data$county_fips,
    county_name = .data$county_name,
    source_total = NA_integer_,
    source_age_group = ifelse(
      .data$age == "85+",
      "85+",
      gsub(" to ", "-", .data$age, fixed = TRUE)
    ),
    deaths = as.integer(.data$count)
  )

if (
  n_distinct(age_deaths_2025$county_fips) != 67L ||
    nrow(age_deaths_2025) != 67L * 18L ||
    anyNA(age_deaths_2025$deaths)
) {
  stop("The 2025 age-specific diabetes rows are incomplete.", call. = FALSE)
}

age_deaths_source <- bind_rows(pdf_age_deaths, age_deaths_2025) |>
  mutate(
    age_group = unname(age_band_lookup[.data$source_age_group])
  )

if (anyNA(age_deaths_source$age_group)) {
  stop("At least one source age group was not mapped.", call. = FALSE)
}

age_deaths <- age_deaths_source |>
  group_by(
    .data$year, .data$county_fips, .data$county_name, .data$age_group
  ) |>
  summarise(deaths = sum(.data$deaths), .groups = "drop") |>
  mutate(age_group = factor(.data$age_group, levels = age_band_order)) |>
  arrange(.data$year, .data$county_fips, .data$age_group) |>
  mutate(age_group = as.character(.data$age_group))

age_death_totals <- age_deaths |>
  group_by(.data$year, .data$county_fips, .data$county_name) |>
  summarise(age_deaths = sum(.data$deaths), .groups = "drop")

death_check <- existing_deaths |>
  left_join(
    age_death_totals,
    by = c("year", "county_fips", "county_name")
  )

if (anyNA(death_check$age_deaths) || any(death_check$deaths != death_check$age_deaths)) {
  bad <- death_check |>
    filter(is.na(.data$age_deaths) | .data$deaths != .data$age_deaths)
  stop(
    "Age-specific death counts do not reconcile with existing totals. First mismatch: ",
    paste(bad$year[[1]], bad$county_name[[1]], bad$deaths[[1]], bad$age_deaths[[1]]),
    call. = FALSE
  )
}

population_age_columns <- list(
  "0-44" = c(
    "AGE04_TOT", "AGE59_TOT", "AGE1014_TOT", "AGE1519_TOT",
    "AGE2024_TOT", "AGE2529_TOT", "AGE3034_TOT", "AGE3539_TOT",
    "AGE4044_TOT"
  ),
  "45-64" = c("AGE4549_TOT", "AGE5054_TOT", "AGE5559_TOT", "AGE6064_TOT"),
  "65-74" = c("AGE6569_TOT", "AGE7074_TOT"),
  "75-84" = c("AGE7579_TOT", "AGE8084_TOT"),
  "85+" = "AGE85PLUS_TOT"
)

read_age_population <- function(path, year_codes) {
  raw <- read.csv(path, check.names = FALSE, stringsAsFactors = FALSE) |>
    filter(.data$COUNTY > 0, as.character(.data$YEAR) %in% names(year_codes))

  base <- raw |>
    transmute(
      year = unname(as.integer(year_codes[as.character(.data$YEAR)])),
      county_fips = sprintf("%02d%03d", .data$STATE, .data$COUNTY),
      county_name = sub(" County$", "", .data$CTYNAME),
      population_total = as.numeric(.data$POPESTIMATE)
    )

  pieces <- lapply(names(population_age_columns), function(age_group_name) {
    columns <- population_age_columns[[age_group_name]]
    data.frame(
      base,
      age_group = age_group_name,
      population = rowSums(raw[columns], na.rm = FALSE),
      stringsAsFactors = FALSE
    )
  })

  bind_rows(pieces)
}

message("Reading consistent Census county-age denominators...")
population_age <- bind_rows(
  read_age_population(
    intercensal_age_path,
    c("10" = 2018L, "11" = 2019L)
  ),
  read_age_population(
    vintage_2025_age_path,
    c(
      "2" = 2020L, "3" = 2021L, "4" = 2022L,
      "5" = 2023L, "6" = 2024L, "7" = 2025L
    )
  )
) |>
  mutate(age_group = factor(.data$age_group, levels = age_band_order)) |>
  arrange(.data$year, .data$county_fips, .data$age_group) |>
  mutate(age_group = as.character(.data$age_group))

population_check <- population_age |>
  group_by(.data$year, .data$county_fips, .data$county_name) |>
  summarise(
    population_total = first(.data$population_total),
    age_population = sum(.data$population),
    .groups = "drop"
  )

if (
  nrow(population_check) != 67L * 8L ||
    anyNA(population_check) ||
    any(population_check$population_total != population_check$age_population)
) {
  stop("County age populations do not reconcile with population totals.", call. = FALSE)
}

age_data <- age_deaths |>
  left_join(
    population_age |>
      select(
        year, county_fips, county_name, age_group, population
      ),
    by = c("year", "county_fips", "county_name", "age_group")
  )

if (anyNA(age_data$population)) {
  stop("Age-specific populations did not join completely.", call. = FALSE)
}

annual_age_rates <- age_data |>
  group_by(.data$year, .data$age_group) |>
  summarise(
    statewide_age_deaths = sum(.data$deaths),
    statewide_age_population = sum(.data$population),
    annual_age_rate = .data$statewide_age_deaths / .data$statewide_age_population,
    .groups = "drop"
  )

fixed_age_rates <- age_data |>
  filter(.data$year %in% 2018:2019) |>
  group_by(.data$age_group) |>
  summarise(
    reference_age_deaths = sum(.data$deaths),
    reference_age_population = sum(.data$population),
    fixed_age_rate = .data$reference_age_deaths / .data$reference_age_population,
    .groups = "drop"
  )

age_data <- age_data |>
  left_join(annual_age_rates, by = c("year", "age_group")) |>
  left_join(fixed_age_rates, by = "age_group") |>
  mutate(
    expected_annual_age = .data$population * .data$annual_age_rate,
    expected_fixed_2018_2019 = .data$population * .data$fixed_age_rate
  )

county_year <- age_data |>
  group_by(.data$year, .data$county_fips, .data$county_name) |>
  summarise(
    deaths = sum(.data$deaths),
    population = sum(.data$population),
    expected_annual_age = sum(.data$expected_annual_age),
    expected_fixed_2018_2019 = sum(.data$expected_fixed_2018_2019),
    .groups = "drop"
  ) |>
  mutate(
    crude_rate_per_100k = .data$deaths / .data$population * 100000,
    age_adjusted_smr = .data$deaths / .data$expected_annual_age,
    fixed_reference_smr = .data$deaths / .data$expected_fixed_2018_2019
  )

annual_intervals <- poisson_smr_interval(
  county_year$deaths,
  county_year$expected_annual_age
)
fixed_intervals <- poisson_smr_interval(
  county_year$deaths,
  county_year$expected_fixed_2018_2019
)

reference_crude_rate <- age_data |>
  filter(.data$year %in% 2018:2019) |>
  summarise(rate = sum(.data$deaths) / sum(.data$population) * 100000) |>
  pull(.data$rate)

county_year <- county_year |>
  mutate(
    age_adjusted_smr_low = annual_intervals$lower,
    age_adjusted_smr_high = annual_intervals$upper,
    fixed_reference_smr_low = fixed_intervals$lower,
    fixed_reference_smr_high = fixed_intervals$upper,
    indirect_age_standardized_rate_per_100k =
      .data$fixed_reference_smr * reference_crude_rate
  )

# One Gamma-Poisson empirical-Bayes prior variance for all county-years.
sampling_variance <- mean(1 / county_year$expected_annual_age)
pooled_prior_variance <- max(
  stats::var(county_year$age_adjusted_smr) - sampling_variance,
  0.005
)
prior_shape <- 1 / pooled_prior_variance
prior_rate <- 1 / pooled_prior_variance
posterior_shape <- prior_shape + county_year$deaths
posterior_rate <- prior_rate + county_year$expected_annual_age

county_year <- county_year |>
  mutate(
    eb_rr = posterior_shape / posterior_rate,
    eb_low = stats::qgamma(0.025, posterior_shape, rate = posterior_rate),
    eb_high = stats::qgamma(0.975, posterior_shape, rate = posterior_rate),
    exceedance_prob = 1 - stats::pgamma(
      1, posterior_shape, rate = posterior_rate
    ),
    eb_prior_variance = pooled_prior_variance,
    reference_period = "Pooled Pennsylvania age-specific rates, 2018-2019"
  ) |>
  arrange(.data$year, .data$county_fips)

state_trend <- county_year |>
  group_by(.data$year) |>
  summarise(
    deaths = sum(.data$deaths),
    population = sum(.data$population),
    crude_rate_per_100k = .data$deaths / .data$population * 100000,
    expected_fixed_2018_2019 = sum(.data$expected_fixed_2018_2019),
    fixed_reference_smr = .data$deaths / .data$expected_fixed_2018_2019,
    indirect_age_standardized_rate_per_100k =
      .data$fixed_reference_smr * reference_crude_rate,
    .groups = "drop"
  )

stopifnot(
  nrow(age_deaths) == 67L * 8L * 5L,
  nrow(population_age) == 67L * 8L * 5L,
  nrow(county_year) == 67L * 8L,
  all(table(county_year$year) == 67L),
  !anyNA(county_year),
  all(county_year$age_adjusted_smr_low <= county_year$age_adjusted_smr),
  all(county_year$age_adjusted_smr <= county_year$age_adjusted_smr_high),
  all(county_year$fixed_reference_smr_low <= county_year$fixed_reference_smr),
  all(county_year$fixed_reference_smr <= county_year$fixed_reference_smr_high),
  all(county_year$eb_low <= county_year$eb_rr),
  all(county_year$eb_rr <= county_year$eb_high),
  all(county_year$exceedance_prob >= 0),
  all(county_year$exceedance_prob <= 1),
  length(unique(county_year$eb_prior_variance)) == 1L
)

write.csv(
  age_deaths,
  "data/intermediate/pa_diabetes_deaths_by_age_2018_2025.csv",
  row.names = FALSE
)
write.csv(
  population_age |>
    select(
      year, county_fips, county_name, age_group, population
    ),
  "data/intermediate/pa_county_population_by_age_2018_2025.csv",
  row.names = FALSE
)
write.csv(
  county_year,
  "data/processed/pa_diabetes_mortality_age_adjusted_2018_2025.csv",
  row.names = FALSE
)
write.csv(
  state_trend,
  "data/processed/pa_diabetes_state_trend_2018_2025.csv",
  row.names = FALSE
)

message("Age-specific death counts reconcile with all 536 existing totals.")
message("County age populations reconcile with total population in all 536 rows.")
message(
  "Pooled empirical-Bayes prior variance: ",
  format(pooled_prior_variance, digits = 5)
)
message("Revised age-standardized data files created successfully.")
