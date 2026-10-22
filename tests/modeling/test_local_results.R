#!/usr/bin/env Rscript
# Run after local selection, tuning, and --final-test; excluded from CI so
# automated builds cannot accidentally access or repeatedly score test data.
suppressPackageStartupMessages(library(data.table))
root <- "modeling/artifacts"
rank <- fread(file.path(root,"selection_ranking.csv"))
tune <- fread(file.path(root,"tuning_metrics.csv"))
lock <- fread(file.path(root,"tuning_locked_config.csv"))
final <- fread(file.path(root,"final_test_metrics.csv"))
stopifnot(nrow(rank)==4L,length(unique(rank$model))==4L,
          rank$model[1]=="gradient_boosted_CART",
          nrow(tune)==9L,length(unique(tune$model))==9L,
          lock$model[1]==tune$model[1],
          final$partition[1]=="test",
          final$n[1]==137689,
          final$ntrees[1]==lock$ntrees[1],
          final$depth[1]==lock$depth[1],
          final$shrinkage[1]==lock$shrinkage[1],
          is.finite(final$mae_usd[1]),
          final$mae_usd[1]>0)
cat("PASS: selection 4 families, 9 tuning trials, locked held-out evaluation metadata.\n")
