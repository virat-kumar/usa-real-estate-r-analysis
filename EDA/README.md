# USA Real Estate Dataset | Exploratory Data Analysis (R)

> **Reproducible execution:** Rscript EDA/eda.R from the repository root, after Rscript setup.R. Dataset is the original Kaggle **version 25**, updated 2024-03-30. EDA figures are committed; raw/processed records and diagnostic CSVs are intentionally kept local.

## Executive findings (measured, not hypothesized)

The official dataset has **2,226,382 scraped records** with 12 columns. Its status mix is **1,389,306 for_sale**, **812,009 sold**, and **25,067 ready_to_build**. Exact full-row duplicates: **0**. The interpretation of the price for sold statuses is not independently confirmed, so the modeling analysis focuses on **for_sale** rows only.

Missingness is material: **25.53% house size**, **22.99% bathrooms**, **21.62% bedrooms**, **14.62% acreage**, and **32.98% previous sale dates**, calculated across all statuses. In *for_sale* alone, **33.45%** lack house size and ~**29.6%** lack bedrooms. This is nonrandom selection risk.

The positive-price for-sale subset (n=**1,388,345**) has a **$305,000 median asking price** and **$4,585,000 99th-percentile asking price**. Extreme records reach **$2.147 billion** in price, **1.04 billion square feet** in house size, and hundreds of beds/baths: clearly unsuitable for an unfiltered price regression.

**For-sale comparability window** (size 500-20,000 sqft, asking price $10,000-$50m, known state/city): **917,282** rows. Among this restricted sample, median price/sqft is about **$422.90 California**, **$176.74 Texas**, **$239.70 Florida**. These are *asking-price* comparisons, not transaction prices, appreciation, rental yields, or investment ROI.

A reproducible sample of **78,702** comparable listings shows a **Spearman association of 0.568** between living area and log asking price. A bedroom-group Kruskal-Wallis test (n=77,705) produces **epsilon-squared ~0.129**. On 65,072 complete-case sampled listings, an exploratory log-linear OLS fit reports **log(size) coefficient 0.712** (conventional 95% interval 0.697-0.727) and **R² 0.634**. A fitted-value residual variance check yields p=**0.00000212**, suggesting heteroskedasticity; those conventional regression intervals are *not heteroskedasticity-robust* and do not prove causality.

**Model-ready subset:** **916,718** rows after restricting to for-sale price $30k-$20m, size 400-20k sqft, known state. Deterministic splits are **641,573 train**, **137,456 validation**, and **137,689 test**, with **zero group-ID overlaps** among **906,107** groups. Imputation medians are fit **only on train**: **3 beds**, **2 baths**, **0.23 lot acres**.

## Folder layout and execution

| Path | Purpose | Version controlled? |
|---|---|---|
| EDA/eda.R | One R script appended step-by-step during analysis | Yes |
| EDA/EDA_PLAN.md | EDA micro-step plan and source decisions | Yes |
| EDA/figures/*.png | Publication-ready lightweight charts | Yes |
| EDA/reports/*.csv | Full diagnostic counts and tests | **No** |
| modeling/README.md | Modeling handoff and leakage constraints | Yes |
| data/raw/realtor-data.zip.csv | Original downloaded Kaggle data | **No** |
| data/processed/{train,validation,test}.csv | Model-ready records | **No** |
| tests/eda/test_outputs.R | Reproducibility, split and leakage assertions | Yes |

Commands:

~~~sh
Rscript setup.R
Rscript EDA/eda.R
Rscript tests/eda/test_outputs.R
~~~

The EDA script performs the following **in its actual run order**: (01) schema/missingness/duplicates, (02) validity/status/dates/repeat-key audit, (03) skew and transformations, (04) geographic comparability, (05) relationships/statistical testing, (06) modeling splits and imputation, (07) selection-bias/balance checks. Sections were appended and executed *sequentially* after examining preceding logs.

## All 16 EDA figures

### 01 - Structure and data quality

**1. Missingness by original field.** Physical attributes and sale dates have substantial gaps.

![Missingness](figures/01_missingness.png)

**2. Mixed listing statuses and price comparisons.** Different statuses must not be pooled for a single asking-price model without justification.

![Status mixture](figures/02_status_mix.png)

### 02 - Distributions and transformation choices

**3. Raw vs log-scale asking price.** The raw panel hides the upper 0.5% *for display only*, while calculations preserve the raw audit. Log price stabilizes visualization.

![Price skew](figures/03_price_raw_vs_log.png)

**4. House size and lot area.** Both are strongly skewed; use log(size) and log1p(lot) when practical.

![Size and lot](figures/04_home_size_and_lot.png)

**5. Bedroom/bathroom distributions.** Display shows 1-12 with missingness and extreme values separately audited.

![Bedrooms and bathrooms](figures/05_beds_baths.png)

### 03 - Geographic market variation

**6. State-level median asking price** among top-volume geographically comparable active listings.

![State medians](figures/06_state_median_prices.png)

**7. Median asking price per square foot.** Use only as a descriptive *derived* measure, not a model predictor of price.

![State price per square foot](figures/07_state_price_per_sqft.png)

**8. High-volume city comparisons.** City strings include potential aliases (e.g. "New York" and "New York City"); they were **not merged without external address validation**.

![City price per sqft](figures/08_major_city_price_per_sqft.png)

### 04 - Relationships and statistical tests

**9. Living area vs asking price (log-log scatter, random sample).** Positive association; not a causal elasticity estimate.

![Size-price scatter](figures/09_size_price_relationship.png)

**10. Spearman correlation matrix.** Rank-based relationships help with skew and extreme observations; log(price/sqft) is included only for EDA, never as a predictor.

![Rank correlation](figures/10_spearman_correlation.png)

**11. Asking price by bedroom group.** Statistically distinguishable groups in a large sample (Kruskal-Wallis); epsilon-squared ~0.129 gives practical magnitude.

![Bedroom group price](figures/11_bedroom_price_groups.png)

**12. Exploratory regression residual patterns.** Nonconstant variance and departures from the normal line motivate robust standard errors or alternative model families.

![Residual diagnostics](figures/12_model_residual_diagnostics.png)

### 05 - Model handoff and selection-bias checks

**13. Train/validation/test sizes and asking-price medians.** Group IDs do not cross partitions.

![Split balance](figures/13_model_split_balance.png)

**14. Missingness differs by source status.** Complete-case-only modeling can select an unrepresentative inventory segment.

![Status missingness](figures/14_missingness_by_status.png)

**15. Data eligibility funnel.** Record loss is primarily from status exclusions and unavailable/plausibility-screened house size; conclusions apply to the retained subset.

![Model eligibility funnel](figures/15_model_eligibility_funnel.png)

**16. Log-price density by split.** Train, validation and test distributions are checked, but split balance alone is not a generalization guarantee.

![Split density](figures/16_split_logprice_density.png)

## Detailed data decisions and modeling contract

1. **Population definition.** Exclude sold and ready_to_build from *asking-price* model. No trustworthy actual closing price or listing observation timestamp is available.
2. **Original source remains immutable.** The EDA uses official original version-25 Kaggle data only. No scraped mirror and no external data joins; geographic comparisons are computed directly from provided state, city and ZIP columns.
3. **Integrity.** Exact duplicates are zero, but **142,424 repeated (street, city, state, ZIP) keys** cover **311,233 rows** in the full dataset. The numeric street field is an anonymized surrogate; this is a *conservative grouping proxy*, not a proven physical-property identifier.
4. **Outlier and eligibility windows.** Descriptive plots show raw distributions with explicitly stated display windows. Model data requires asking price $30k-$20m, 400-20,000 sqft, a valid state, and for_sale status. These are pragmatic guardrails based on observed tails, not verified ground-truth removal. Excluded cases may include true luxury homes, tiny dwellings, undeveloped properties or missing-size listings; changing the windows changes the target population.
5. **Missing features.** Keep model rows with missing/implausible bed, bath and lot values, add explicit missing indicators and replace using *training-only* global medians (3, 2, 0.23). Required living area and target price cannot be imputed from target-derived information. ZIP is read as character to preserve leading zeros.
6. **Transforms.** Use log_price (response), log_house_size and log1p_acre (predictors). Retain original price and house_size for interpretability, but do **not** include both versions in the same formula without collinearity checks.
7. **Group-safe split.** A deterministic bucket function assigns all repeated nonmissing anonymized **street surrogate codes** to the same 70/15/15 approximate partition; unknown street values receive row-specific negative IDs. The audit shows zero surrogate-group overlap, **not** guaranteed zero overlap between physical homes if the source surrogate is imperfect.
8. **Leakage avoidance.** Drop **group_id**, **source_row**, **split**, **price** and **log_price** from predictor columns. Price per square foot and state/city aggregate *mean/median target price* are target-derived; do not join them from all rows as predictors. Any future encoding or normalization must be fitted on **train only** or within cross-validation folds.
9. **Possible future external joins (not performed).** ACS income, neighborhood safety, walkability, school quality and interest-rate context could improve models, but require valid geographic keys, consistent as-of dates, licenses, and tests against leakage. None is silently inferred.
10. **Date warning.** prev_sold_date is previous sale date, not the listing date. Historic records reach 1901 and include anomalies after the dataset update. This source is a cross-section, not an annual sales panel.

### Feature choices for a first model

| Role | Field(s) |
|---|---|
| Response | log_price (and price for dollar errors) |
| Numeric predictors | log_house_size, bed_filled, bath_filled, log1p_acre |
| Missingness indicators | bed_missing, bath_missing, acre_missing |
| Categorical | state; evaluate city/ZIP as high-cardinality categoricals with train-only encoding |
| **Exclude from predictors** | price, log_price, group_id, source_row, split, plus all target-derived medians and price_per_sqft |

**Caveats:** Dataset collection dates and transaction-price semantics are undocumented. The numeric surrogate may not uniquely identify physical homes. There are no rents, operating costs, mortgage terms, condition ratings, reliable neighborhood boundaries or true investor profit labels. Large-sample p-values are not economic significance and the EDA OLS coefficient is not a causal effect.

### Local artifacts

Run the script to produce **EDA/reports/**: 01_schema_missing, 02_numeric_validity, 03_for_sale_quantiles, 04_state_markets, 05_statistical_tests, 06_model_manifest, 06_train_only_imputation, 07_final_qa and additional breakdown tables. These are deliberately Git-ignored; regenerate from the source rather than committing potentially large derived record-level data.

### Source and attribution

- [Original official Kaggle dataset](https://www.kaggle.com/datasets/ahmedshahriarsakib/usa-real-estate-dataset) by Ahmed Shahriar Sakib, version 25.
- [Dataset creator's explanation](https://www.kaggle.com/general/327648), proposing real estate trends/correlations/regression.
- [Evan W.'s Kaggle USA Real Estate EDA notebook](https://www.kaggle.com/code/evantwescott/usa-real-estate-dataset-eda). Kaggle **datasets** do not have a model competition leaderboard; this project's tests, charts and findings are independently produced in R.

EDA findings are reproducible under source version and environment lock. Uncertainty about selection bias, dates and missing property characteristics is a genuine limit rather than an error to suppress.
