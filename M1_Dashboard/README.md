# Pennsylvania Diabetes Mortality Surveillance

This folder contains the static M1 flexdashboard for underlying-cause diabetes mortality in Pennsylvania's 67 counties, 2018-2025.

The assignment source is `dashboard.Rmd`, which knits to the self-contained submission file `DAS_A_M1.html`.

## Render the dashboard

Open this folder in RStudio and run:

```r
source("scripts/render_m1.R")
```

Alternatively, open `dashboard.Rmd` and click **Knit**. The output file is `DAS_A_M1.html`.

## What M1 shows

- A 2025 county map of annual age-adjusted SMR.
- Hover labels with county, observed deaths, expected deaths, SMR, and uncertainty.
- A fixed-reference 2018-2025 time series for Pennsylvania and Allegheny County.
- An About panel with outcome, population, geography, method, sources, missing-area check, and limitation.

The primary outcome is **underlying-cause diabetes mortality**, not diabetes prevalence. Each observation is an aggregated county-year count, not an individual record or point location.

## Main dataset

`data/processed/pa_diabetes_mortality_age_adjusted_2018_2025.csv`

- 536 rows: 67 counties x 8 years.
- Observed deaths and population denominators.
- Indirectly age-standardized expected deaths using five broad age groups.
- Annual age-adjusted SMR with exact Poisson confidence intervals.
- Fixed 2018-2019 reference SMR and age-standardized rate for temporal comparison.
- Gamma-Poisson empirical-Bayes RR with one pooled prior variance, credible intervals, and exceedance probability.

## Rebuild and test

From a clean R session:

```r
source("scripts/install_dependencies.R")
source("scripts/fetch_data.R")
source("tests/smoke_test.R")
source("scripts/render_m1.R")
```

The fetch script downloads the official public files, extracts Pennsylvania diabetes death counts, builds consistent county-age denominators, and recreates the processed analysis dataset.

## Core definitions

For county `i`, year `t`, and age group `a`:

```text
PA age-specific rate_at = statewide deaths_at / statewide population_at
annual expected_it      = sum_a(county population_iat x PA rate_at)
age-adjusted SMR_it     = observed_it / annual expected_it

fixed expected_it       = sum_a(county population_iat x pooled PA 2018-2019 rate_a)
fixed-reference SMR_it  = observed_it / fixed expected_it
```

The annual age-adjusted SMR compares counties within the same year. The fixed-reference measure shows temporal change against a constant 2018-2019 baseline.

The default monitoring rule is:

```text
EB relative risk > 1 and Pr(RR > 1 | data) >= 0.95
```

A signal identifies a county for review; it does not establish a causal change.

## Clean project structure

```text
M1_Dashboard/
|-- dashboard.Rmd                 # static M1 source
|-- dashboard.css                 # static M1 styling
|-- DAS_A_M1.html                 # exact M1 upload file
|-- README.md
|-- DATA_REVISION_LOG.md
|-- R/
|   `-- data_helpers.R
|-- scripts/
|   |-- install_dependencies.R
|   |-- fetch_data.R
|   |-- build_age_standardized_data.R
|   `-- render_m1.R
|-- tests/
|   `-- smoke_test.R
`-- data/
    `-- processed/                # final dashboard inputs and source list
```

## Important limitations

- Mortality measures fatal burden, not everyone living with diabetes.
- Five broad age groups do not remove every possible age difference.
- Small expected counts can create unstable annual SMRs.
- The empirical-Bayes layer is a transparent nonspatial working model.
- County-level patterns cannot establish individual-level or causal relationships.

## Official sources

The complete year-specific URLs and their roles are in `data/processed/data_sources.csv`.

- Pennsylvania Department of Health death-certificate statistical tables, 2018-2024.
- Pennsylvania Department of Health county-age-cause archive, 2025.
- Census 2010-2020 intercensal county-age estimates for 2018-2019.
- Census Vintage 2025 county-age estimates for 2020-2025.
- Census 2022 county cartographic boundaries.

Pennsylvania Department of Health disclaimer: "These data were provided by the Pennsylvania Department of Health. The Department specifically disclaims responsibility for any analyses, interpretations, or conclusions made by the user of this data product."
