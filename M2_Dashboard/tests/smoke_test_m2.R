required <- c("dplyr", "sf")
available <- vapply(required, requireNamespace, logical(1), quietly = TRUE)
missing <- required[!available]
if (length(missing)) stop("Missing packages: ", paste(missing, collapse = ", "))

source("R/data_helpers.R")
dashboard <- load_dashboard_data()
validate_dashboard_data(dashboard$data, dashboard$counties)

dat <- dashboard$data
age_deaths <- utils::read.csv(
  "data/intermediate/pa_diabetes_deaths_by_age_2018_2025.csv",
  stringsAsFactors = FALSE
)
age_population <- utils::read.csv(
  "data/intermediate/pa_county_population_by_age_2018_2025.csv",
  stringsAsFactors = FALSE
)
age_data <- dplyr::left_join(
  age_deaths,
  age_population,
  by = c("year", "county_fips", "county_name", "age_group")
)
pooled <- dat |>
  dplyr::filter(dplyr::between(.data$year, 2020L, 2023L)) |>
  dplyr::group_by(.data$county_fips, .data$county_name) |>
  dplyr::summarise(
    observed = sum(.data$deaths),
    expected = sum(.data$expected_annual_age),
    population_person_years = sum(.data$population),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    age_adjusted_smr = .data$observed / .data$expected,
    crude_rate_per_100k = 1e5 * .data$observed / .data$population_person_years
  )

stopifnot(
  nrow(pooled) == 67L,
  all(pooled$observed >= 0),
  all(pooled$expected > 0),
  all(is.finite(pooled$age_adjusted_smr)),
  all(is.finite(pooled$crude_rate_per_100k)),
  sum(pooled$observed) == sum(dat$deaths[dat$year %in% 2020:2023]),
  nrow(age_data) == 67L * 8L * 5L,
  all(age_data$population > 0),
  all(age_data$deaths >= 0),
  length(unique(age_data$age_group)) == 5L,
  file.exists("dashboard_app.Rmd"),
  file.exists("dashboard_app.css")
)

message("M2 smoke test passed: 67 pooled counties, valid SMRs and rates, and required app files.")
