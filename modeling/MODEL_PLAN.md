# Model selection and tuning in R

Outcome: predict **asking price** on data/processed train/validation/test exported by EDA (not sold price/ROI).

1. Fix same seed/stratified cohort across all four: log-linear OLS, single CART (rpart), random forest (ranger), gradient boosted trees (gbm). Compare on untouched **validation** only, MAE in dollars primary, RMSE/log RMSE secondary.
2. Append ONE selection section at a time to modeling/model_selection.R. Execute after each addition, inspect output, then choose next step. Make charts and local CSV diagnostics. Sampling allows memory/time bounded fair comparison, report cohort explicitly. Feature sets comparable: numeric log_house_size/bed/bath/log1p_acre, missing indicators, state category (city/ZIP high-cardinality deferred). No target-derived predictors.
3. Choose best validation MAE among four; fine-tune that ONE model in separate modeling/model_fine_tuning.R using incremental trials. Lock winner before *any* final test access; then once evaluate test. Report association/feature contributions as predictive not causal.
4. Publish two dedicated modeling/.../report.md files and all lightweight plots, code and tests. Keep CSV predictions, fitted binary models and raw/split records Git-ignored.
