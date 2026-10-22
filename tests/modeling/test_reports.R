#!/usr/bin/env Rscript
# Static report/source check on both GitHub CI runners.
reports <- c("modeling/model_selection/report.md",
             "modeling/model_fine_tuning/report.md")
dirs <- c("modeling/model_selection","modeling/model_fine_tuning")
for (i in seq_along(reports)) {
  stopifnot(file.exists(reports[i]))
  txt <- paste(readLines(reports[i],warn=FALSE),collapse="\n")
  names <- regmatches(txt,gregexpr("figures/[A-Za-z0-9_]+\\.png",txt))[[1]]
  all_png <- list.files(file.path(dirs[i],"figures"),
                        pattern="\\.png$",full.names=TRUE)
  stopifnot(length(names)==12L,length(all_png)==12L,
            length(unique(names))==12L,
            all(file.exists(file.path(dirs[i],names))),
            all(file.info(all_png)$size>5000))
}
stopifnot(file.exists("modeling/model_selection.R"),
          file.exists("modeling/model_fine_tuning.R"),
          file.exists("modeling/common.R"),
          file.exists("modeling/MODEL_PLAN.md"))
cat("PASS: both modeling reports embed all 24 valid PNGs.\n")
