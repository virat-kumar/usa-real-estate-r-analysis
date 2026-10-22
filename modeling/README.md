# Predictive modeling in R | USA Real Estate

This project predicts **listing asking prices**, not actual closing prices, property value, rental return, or investment profit. The original source is [USA Real Estate Dataset on Kaggle](https://www.kaggle.com/datasets/ahmedshahriarsakib/usa-real-estate-dataset), version 25. EDA prepared **916,718** records with group-disjoint train, validation, and test partitions.

## Two completed modeling stages

| Stage | Script | Report | Charts |
|---|---|---|---|
| Four-model selection | [model_selection.R](model_selection.R) | [Selection report](model_selection/report.md) | 12 |
| Nine-trial fine-tuning and final test | [model_fine_tuning.R](model_fine_tuning.R) | [Tuning report](model_fine_tuning/report.md) | 12 |

The pipelines share [common.R](common.R) and follow the [micro-step plan](MODEL_PLAN.md). Both are R-only; Python is used only to obtain the official Kaggle source during setup.

## Reproduce on Windows or Linux

Install R 4.2+, Python 3.9+ (to download the Kaggle data), and Git. From the repository root:

```bash
Rscript setup.R
Rscript EDA/eda.R
Rscript tests/eda/test_outputs.R
Rscript modeling/model_selection.R
Rscript modeling/model_fine_tuning.R
Rscript tests/modeling/test_functions.R
Rscript tests/modeling/test_reports.R
```

**The above commands do not read the held-out test set during model selection or tuning.** For a fresh experiment, once tuning parameters are locked, explicitly run the held-out test *once*:

```bash
Rscript modeling/model_fine_tuning.R --final-test
Rscript tests/modeling/test_local_results.R
```

The guarded final-test command refuses another evaluation if local test results exist. For this finished project, that one final evaluation has already occurred. Do not use test data to select new hyperparameters.

## Results and practical constraints

Selection used the same deterministic **40,000 train / 12,000 validation** subset for four models: log-linear OLS, single CART, randomized-subspace *bagged* CART, and gradient-boosted CART. The bagged ensemble is forest-like, **not a standard random forest**. Boosting had the lowest validation MAE: **$268,754**. After nine tuning trials, the selected configuration (105 trees, depth 5, learning rate 0.08) reached **$257,254** on validation.

The locked final model was refit on **80,000 allowed development records**, then evaluated on all **137,689 held-out test rows**: MAE **$257,631**, RMSE **$710,981**, dollar-price R² **0.480**. Large price-band biases make it **unsuitable for automated valuation or investment decisions** without much better data and independent calibration. Read the reports for per-market errors, predictive associations, plots, and business recommendations.

Target is `log_price`. Predictors are transformed size and lot, filled bedrooms/bathrooms, missingness indicators, and broad state group. Preprocessing learned missing-value replacements on training only. No price-per-square-foot or target-derived location means are predictors. Property grouping uses a source surrogate and cannot certify physical-parcel uniqueness. Historical previous-sale dates are *not* listing observation timestamps.

## Data confidentiality and Git

Source Kaggle CSV is under `data/raw/`. Clean splits are under `data/processed/`. Row-level predictions, local model RDS, tuned parameters and generated numeric reports are in Git-ignored `modeling/artifacts/`. Only source code, Markdown documentation and small PNG figures are tracked. Never upload local Kaggle records or model predictions to the GitHub repository.
