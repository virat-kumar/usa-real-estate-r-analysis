#!/usr/bin/env Rscript
source("R/functions.R")
raw <- load_listings()
clean <- prepare_listings(raw)
dir.create("outputs", showWarnings = FALSE)
data.table::fwrite(summarize_by_state(clean), "outputs/state_summary.csv")
data.table::fwrite(data.table::data.table(
  metric = c("raw_rows", "usable_rows", "excluded_rows"),
  count = c(nrow(raw), nrow(clean), nrow(raw)-nrow(clean))
), "outputs/data_quality.csv")
fit <- estimate_model(clean)
capture.output(summary(fit), file = "outputs/model_summary.txt")
cat("Records:", nrow(raw), "usable:", nrow(clean), "\n")
cat("Results in ignored outputs/ folder. Association != causation or investment ROI.\n")

