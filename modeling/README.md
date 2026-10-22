# Modeling handoff — USA Real Estate in R

The modeling phase is intentionally separated from exploratory work. EDA runs in **EDA/eda.R**; output datasets are saved under **data/processed/** locally and never committed.

## Reproduce

~~~sh
Rscript setup.R
Rscript EDA/eda.R
Rscript tests/eda/test_outputs.R
~~~

Inputs: **train.csv** (641,573 records), **validation.csv** (137,456), **test.csv** (137,689), generated from official Kaggle v25.

## Target and features

Response: **log_price** for log-scale loss; **price** can be used only for dollar-scale reporting. Numeric predictors: **log_house_size**, **bed_filled**, **bath_filled**, **log1p_acre**; missingness flags: **bed_missing**, **bath_missing**, **acre_missing**; categorical: **state**, optional **city** or **zip_code** if encoded with train-only rules.

Never use **price**, **log_price**, **group_id**, **source_row**, **split**, **price_per_sqft**, or any target-derived geographic average as predictors. group_id and source_row exist solely to check partition leakage.

Train-only imputation: bed median **3**, bath median **2**, acre median **0.23**. If you change split criteria, refit those medians using the new training partition. The splits are group-disjoint by anonymized street surrogate ID, not independently verified physical-property IDs.

Rows were limited to for_sale with asking price $30k-$20m and house size 400-20k sqft and known state; possible selection bias. No separate listing observation date exists. **Do not use prior sold_date as listing date.**

Next modeling phases: (1) linear/log-linear baseline with robust error metrics, (2) train-fold categorical coding for unseen states/cities, (3) cross-validated nonlinear models (ranger/boosting if added to renv), (4) geographic and price-band slice evaluation, (5) residual/fairness/business checks, (6) final test evaluation exactly once after model selection. Publish metrics, not raw records.
