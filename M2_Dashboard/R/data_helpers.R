poisson_smr_interval <- function(observed, expected, level = 0.95) {
  alpha <- 1 - level
  lower <- ifelse(
    observed == 0,
    0,
    stats::qchisq(alpha / 2, 2 * observed) / (2 * expected)
  )
  upper <- stats::qchisq(1 - alpha / 2, 2 * (observed + 1)) / (2 * expected)

  data.frame(lower = lower, upper = upper)
}

calculate_monitoring <- function(data, probability_threshold = 0.95) {
  threshold <- min(max(probability_threshold, 0.5), 0.999)

  data |>
    dplyr::arrange(.data$county_fips, .data$year) |>
    dplyr::group_by(.data$county_fips) |>
    dplyr::mutate(
      previous_eb_rr = dplyr::lag(.data$eb_rr),
      eb_change = .data$eb_rr - .data$previous_eb_rr,
      flag = .data$eb_rr > 1 & .data$exceedance_prob >= threshold,
      persistent_flag = .data$flag & dplyr::lag(.data$flag, default = FALSE)
    ) |>
    dplyr::ungroup()
}

load_dashboard_data <- function(
    data_path = "data/processed/pa_diabetes_mortality_age_adjusted_2018_2025.csv",
    shape_path = "data/processed/pa_counties.rds") {
  if (!file.exists(data_path) || !file.exists(shape_path)) {
    stop(
      "Dashboard data are missing. Run source('scripts/fetch_data.R') from the project root.",
      call. = FALSE
    )
  }

  data <- utils::read.csv(data_path, stringsAsFactors = FALSE)
  data$county_fips <- sprintf("%05s", data$county_fips)
  numeric_columns <- names(data)[vapply(data, is.numeric, logical(1))]
  data[numeric_columns] <- lapply(data[numeric_columns], as.numeric)
  data$year <- as.integer(data$year)
  data$deaths <- as.integer(data$deaths)

  counties <- readRDS(shape_path)
  counties$county_fips <- as.character(counties$county_fips)

  list(data = data, counties = counties)
}

validate_dashboard_data <- function(data, counties) {
  expected_years <- 2018:2025
  counts <- table(data$year)
  numeric_required <- c(
    "deaths", "population", "expected_annual_age",
    "expected_fixed_2018_2019", "crude_rate_per_100k",
    "age_adjusted_smr", "age_adjusted_smr_low", "age_adjusted_smr_high",
    "fixed_reference_smr", "fixed_reference_smr_low",
    "fixed_reference_smr_high", "indirect_age_standardized_rate_per_100k",
    "eb_rr", "eb_low", "eb_high", "exceedance_prob",
    "eb_prior_variance"
  )

  stopifnot(
    identical(sort(unique(data$year)), expected_years),
    all(counts == 67L),
    nrow(data) == 67L * length(expected_years),
    length(unique(data$county_fips)) == 67L,
    nrow(counties) == 67L,
    all(unique(data$county_fips) %in% counties$county_fips),
    all(numeric_required %in% names(data)),
    all(data$deaths >= 0),
    all(data$population > 0),
    all(data$eb_low <= data$eb_rr),
    all(data$eb_rr <= data$eb_high),
    all(data$exceedance_prob >= 0 & data$exceedance_prob <= 1)
  )

  stopifnot(
    all(data$expected_annual_age > 0),
    all(data$expected_fixed_2018_2019 > 0),
    all(data$age_adjusted_smr_low <= data$age_adjusted_smr),
    all(data$age_adjusted_smr <= data$age_adjusted_smr_high),
    all(data$fixed_reference_smr_low <= data$fixed_reference_smr),
    all(data$fixed_reference_smr <= data$fixed_reference_smr_high),
    length(unique(data$eb_prior_variance)) == 1L
  )

  expected_sums <- data |>
    dplyr::group_by(.data$year) |>
    dplyr::summarise(
      observed = sum(.data$deaths),
      expected = sum(.data$expected_annual_age),
      .groups = "drop"
    )
  stopifnot(all(abs(expected_sums$observed - expected_sums$expected) < 1e-6))

  invisible(TRUE)
}
