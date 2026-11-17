# Data revision log after project approval

Professor feedback received: November 8, 2026

The approved project outcome remains annual Pennsylvania county deaths for which diabetes mellitus was recorded as the underlying cause. The revisions below address age structure, population consistency, temporal interpretation, source checks, and empirical-Bayes comparability.

## 1. Source-count audit

Two unusual observations were checked directly against the original Pennsylvania Department of Health PDF tables.

- Armstrong County, 2018: **14 diabetes deaths**, confirmed on PDF page 21.
- Cambria County, 2024: **108 diabetes deaths**, confirmed on PDF page 89.

Both values are correctly extracted. They remain in the dataset.

The 2018-2024 values are extracted from the `Diabetes Mellitus` section of each county's annual PDF page. For each county, the extraction reads the `Total` row and its 18 five-year age columns. The 2025 values come from the Department's county-age-cause CSV archive and select `cause = Diabetes mellitus` and the county rows. The Department lists 2025 as its most recent regular release and lists 2026 separately as preliminary.

## 2. Consistent population denominators

The revised pipeline uses:

- Census 2010-2020 intercensal county-age estimates for 2018-2019.
- Census Vintage 2025 county-age estimates for 2020-2025.

This change materially reduces the artificial break at 2020:

| Series | 2019 Pennsylvania population | 2020 Pennsylvania population | Change |
| --- | ---: | ---: | ---: |
| Previous mixed-vintage series | 12,801,989 | 12,995,576 | 193,587 |
| Revised series | 12,991,539 | 12,995,576 | 4,037 |

## 3. Broad age groups

Both deaths and population denominators are aggregated into the same five groups:

- 0-44
- 45-64
- 65-74
- 75-84
- 85+

All 2,680 county-year-age death rows reconcile to the original 536 county-year observed totals. All county-age populations reconcile to their corresponding total county populations.

## 4. Two complementary expected-count measures

### Annual age-adjusted spatial comparison

For each year and age group, the statewide age-specific rate is applied to each county's age-specific population. Summing the age-specific expected counts gives `expected_annual_age`. The corresponding `age_adjusted_smr` compares a county with Pennsylvania in the same year while accounting for broad age structure.

### Fixed 2018-2019 temporal reference

Pooled Pennsylvania age-specific rates from 2018-2019 are applied to every county-year population. Summing these expected counts gives `expected_fixed_2018_2019`. The corresponding `fixed_reference_smr` can show change over time because its reference does not change each year.

The indirect age-standardized rate is calculated as the fixed-reference SMR multiplied by the pooled 2018-2019 Pennsylvania crude rate.

## 5. Empirical-Bayes estimator

The working estimator remains a Gamma-Poisson empirical-Bayes model with prior mean relative risk equal to 1. The prior variance is now estimated once from all 536 age-adjusted county-year SMRs, after subtracting approximate Poisson sampling variance.

- Pooled prior variance: **0.17697**

Using one pooled value makes the degree of shrinkage comparable across years.

## Revised output files

- `data/intermediate/pa_diabetes_deaths_by_age_2018_2025.csv`
- `data/intermediate/pa_county_population_by_age_2018_2025.csv`
- `data/processed/pa_diabetes_mortality_age_adjusted_2018_2025.csv`
- `data/processed/pa_diabetes_state_trend_2018_2025.csv`

The original approved files have not been overwritten. The revised pipeline is in `scripts/build_age_standardized_data.R`.

## Next dashboard changes

1. Switch the map and monitoring table to the annual age-adjusted SMR and pooled empirical-Bayes estimates.
2. Use the fixed-reference SMR or indirect age-standardized rate for time trends.
3. Add a year selector or slider.
4. Add Moran's I by year after the revised spatial measures are integrated.
5. Evaluate a retrospective annual space-time scan after the reactive dashboard is stable.
