required <- c("dplyr", "sf")
available <- vapply(required, requireNamespace, logical(1), quietly = TRUE)
missing <- required[!available]
if (length(missing)) stop("Missing packages: ", paste(missing, collapse = ", "))

source("R/data_helpers.R")
dashboard <- load_dashboard_data()
validate_dashboard_data(dashboard$data, dashboard$counties)

data <- dashboard$data
monitoring <- calculate_monitoring(data, probability_threshold = 0.95)
year_sums <- data |>
  dplyr::group_by(.data$year) |>
  dplyr::summarise(
    observed = sum(.data$deaths),
    expected = sum(.data$expected_annual_age),
    .groups = "drop"
  )
adams_2024 <- data |>
  dplyr::filter(.data$county_fips == "42001", .data$year == 2024)
armstrong_2018 <- data |>
  dplyr::filter(.data$county_fips == "42005", .data$year == 2018)
cambria_2024 <- data |>
  dplyr::filter(.data$county_fips == "42021", .data$year == 2024)
state_population <- data |>
  dplyr::group_by(.data$year) |>
  dplyr::summarise(population = sum(.data$population), .groups = "drop")

stopifnot(
  nrow(data) == 536L,
  nrow(dashboard$counties) == 67L,
  identical(sort(unique(data$year)), 2018:2025),
  sum(data$deaths[data$year == 2025]) == 3645L,
  adams_2024$deaths == 29L,
  armstrong_2018$deaths == 14L,
  cambria_2024$deaths == 108L,
  all(abs(year_sums$observed - year_sums$expected) < 1e-6),
  state_population$population[state_population$year == 2020] -
    state_population$population[state_population$year == 2019] == 4037,
  all(data$age_adjusted_smr_low <= data$age_adjusted_smr &
        data$age_adjusted_smr <= data$age_adjusted_smr_high),
  all(data$fixed_reference_smr_low <= data$fixed_reference_smr &
        data$fixed_reference_smr <= data$fixed_reference_smr_high),
  all(data$eb_low <= data$eb_rr & data$eb_rr <= data$eb_high),
  all(data$exceedance_prob >= 0 & data$exceedance_prob <= 1),
  length(unique(round(data$eb_prior_variance, 12))) == 1L,
  is.logical(monitoring$flag),
  is.logical(monitoring$persistent_flag),
  any(monitoring$flag[monitoring$year == 2025])
)

message("Smoke test passed: age-adjusted county-years, verified source values, consistent populations, intervals, and monitoring fields.")
