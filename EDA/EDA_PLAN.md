# Incremental R EDA execution plan

**Method:** Append one numbered micro-step to `EDA/eda.R`, execute it against the Kaggle version-25 CSV, inspect actual diagnostics, adapt the next step, and record observed results here and in `EDA/README.md`. No notebook leaderboard exists for this Kaggle *dataset*; its [community code](https://www.kaggle.com/code/evantwescott/usa-real-estate-dataset-eda) and [creator's description](https://www.kaggle.com/general/327648) inspire coverage but do not provide results for this run.

1. Schema, missingness, statuses, exact duplicates, identifiers.
2. Value validity, past-sale-date anomalies, questionable sizes/lots.
3. Price / size / lot / bedroom / bathroom distributions; robust/log transformations.
4. Geographic market composition, statewide and within-state comparisons.
5. Price-characteristic relationships, correlations, effect sizes, sampling and statistical tests.
6. Model-ready data quality decisions, leakage-safe splits, train-only preprocessing specification and audit.
7. Embed **every** generated figure in EDA README; publish transparent findings, exclusions, data limitations, sources and run commands.

**Source:** `data/raw/realtor-data.zip.csv` from original Kaggle version 25, SHA256 `2678a7d0a1054861464d0dbdf938c133ffd3e5c5f22c8065255bab87e9af0de4`. No source records, processed splits, or diagnostic CSVs are committed. Only R code, docs, and small figures are committed.

**Design:** Nested source is immutable. EDA outputs under `EDA/reports/` are local diagnostic artifacts; small publication PNGs under `EDA/figures/` are tracked. `modeling/` is reserved for algorithms, CV and reporting. No external data joins unless a verified, useful, correctly keyed source is provided; location summaries from the same dataset must be fitted on training folds only to avoid target leakage.

## Observed micro-step checkpoints

- **01**: 2,226,382 rows, 12 columns, no exact duplicates; 1,389,306 for_sale, 812,009 sold, 25,067 ready_to_build. Missing house_size 25.53% overall.
- **02**: implausible high values (max price 2.147b, house size 1.04b sqft), repeated surrogate property keys, past-sale-date anomalies.
- **03**: for_sale median asking price $305,000, p99 $4.585m. Log(price) and log(house_size), log1p(acre) warranted by long right tails.
- **04**: 917,282 comparable for-sale records across 54 state/territory labels; ppsf California $422.90 vs Texas $176.74 vs Florida $239.70; differences are not ROI.
- **05**: Spearman size/ln(price) rho=.568 (n=78,702); Kruskal bedroom epsilon2=.129; exploratory log-house coefficient .712 and R2=.634, heteroskedasticity diagnostic p=2.12e-6.
- **06**: 916,718 model-screened rows, 641,573 train/137,456 validation/137,689 test; 906,107 surrogate property groups with 0 cross-partition overlap. Only train medians (3 bed/2 bath/0.23 acres) used for missing predictors.
- **07**: source status missingness bias measured; 16 named figures render; no nonfinite modeled transforms; README embeds 16 figures. All local source + generated outputs remain outside Git except small PNG illustrations.
