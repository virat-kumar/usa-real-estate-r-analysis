#!/usr/bin/env Rscript
source("R/functions.R")
test <- data.table::data.table(
  price = seq(100000, 390000, by = 10000),
  house_size = seq(950, 2400, length.out = 30),
  bed = rep(c(2, 3, 4), length.out = 30),
  bath = rep(c(1, 2), length.out = 30),
  acre_lot = rep(c(0.15, 0.25), length.out = 30),
  state = rep(c("Texas", "Georgia"), length.out = 30),
  city = rep(c("Dallas", "Atlanta"), length.out = 30)
)
clean <- prepare_listings(test)
stopifnot(nrow(clean) == 30L, all(clean$price_per_sqft > 0))
stopifnot(nrow(summarize_by_state(clean)) == 2L)
stopifnot(inherits(estimate_model(clean), "lm"))
cat("R smoke tests passed.\n")

