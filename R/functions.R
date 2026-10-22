# R-only analysis helpers. price is asking price, NOT actual sold price.
suppressPackageStartupMessages(library(data.table))

load_listings <- function(path = "data/raw/realtor-data.zip.csv") {
  if (!file.exists(path)) stop("Dataset missing: run Rscript setup.R")
  dt <- data.table::fread(path, na.strings = c("", "NA"), showProgress = FALSE)
  missing <- setdiff(c("price", "house_size", "bed", "bath", "acre_lot",
                       "state", "city"), names(dt))
  if (length(missing)) stop("Missing columns: ", paste(missing, collapse = ", "))
  dt
}

prepare_listings <- function(dt) {
  dt <- data.table::copy(data.table::as.data.table(dt))
  for (column in c("price", "house_size", "bed", "bath", "acre_lot")) {
    data.table::set(dt, j = column, value = as.numeric(dt[[column]]))
  }
  dt <- dt[is.finite(price) & price > 0 &
             is.finite(house_size) & house_size > 0 &
             !is.na(state) & nzchar(trimws(state))]
  dt[, price_per_sqft := price / house_size]
  dt
}

summarize_by_state <- function(dt) {
  result <- dt[, .(
    listings = .N,
    median_asking_price = median(price, na.rm = TRUE),
    median_price_per_sqft = median(price_per_sqft, na.rm = TRUE)
  ), by = state]
  result[order(-listings)]
}

estimate_model <- function(dt, limit = 80000L, seed = 2026L) {
  usable <- dt[is.finite(bed) & is.finite(bath) &
               is.finite(acre_lot) & acre_lot >= 0]
  if (nrow(usable) < 25L) stop("Not enough usable records for regression")
  set.seed(seed)
  if (nrow(usable) > limit) usable <- usable[sample.int(nrow(usable), limit)]
  stats::lm(log(price) ~ log(house_size) + bed + bath +
            log1p(acre_lot) + factor(state), data = usable)
}

