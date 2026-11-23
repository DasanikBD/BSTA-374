# BSTA 374 Milestone M2

This folder contains the reactive Shiny flexdashboard for Pennsylvania
underlying-cause diabetes mortality, 2018-2025.

## Research question

Where and when is underlying-cause diabetes mortality elevated across
Pennsylvania counties after age adjustment, which county signals remain after
empirical-Bayes smoothing, and are there statistically significant
space-time clusters during 2018-2025?

## Run the app

Open this folder in RStudio. If the packages are not installed, run:

```r
source("scripts/install_dependencies.R")
```

Then open `dashboard_app.Rmd` and click **Run Document**, or run:

```r
source("scripts/run_dashboard.R")
```

Do not use **Knit** or `quarto render`: M2 is a running Shiny app.

## Submission files

- `DAS_A_M2.Rmd`: renamed copy for Course Site upload.
- `DAS_A_M2_a.png`: first required app state.
- `DAS_A_M2_b.png`: second required app state.

The screenshots will use different counties and different year ranges.

## Controls and responses

- The county dropdown changes the map outline, county trend, summary cards,
  and age-pattern comparison.
- The two-handle year slider changes the pooled map, summary cards, map
  legend, grey period band, and age-pattern comparison.
- Map classes are fixed so a colour keeps the same SMR meaning across periods.
- The age-pattern panel on the main dashboard compares the selected county
  with Pennsylvania across five age groups for the chosen years.

## Final-dashboard pathway

- **Observed risk:** annual age-adjusted SMR map and county trend.
- **Modeled risk:** annual empirical-Bayes relative-risk map with uncertainty.
- **Cluster detection:** retrospective SaTScan space-time results by year.
- **Monitoring:** an explicit rule that identifies counties or clusters for
  public-health review without interpreting a signal as proof of causation.

## Data

The app reads three processed inputs and two intermediate age-specific inputs.
The source URL and role of every public input are documented in
`data/processed/data_sources.csv`.
