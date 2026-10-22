#!/usr/bin/env Rscript
suppressPackageStartupMessages(library(data.table))
needed <- c("data/processed/train.csv","data/processed/validation.csv",
            "data/processed/test.csv","EDA/reports/06_model_manifest.csv",
            "EDA/reports/06_train_only_imputation.csv","EDA/reports/07_final_qa.csv")
stopifnot(all(file.exists(needed)))
load_part <- function(part) {
  fread(file.path("data/processed",paste0(part,".csv")),
        select=c("group_id","split","price","log_price","log_house_size",
                 "bed_filled","bath_filled","log1p_acre",
                 "bed_missing","bath_missing","acre_missing","state",
                 "city","zip_code"),
        colClasses=list(character=c("state","city","zip_code")))
}
train <- load_part("train")
valid <- load_part("validation")
test <- load_part("test")
stopifnot(nrow(train)>0L,nrow(valid)>0L,nrow(test)>0L)
stopifnot(all(train$split=="train"),all(valid$split=="validation"),
          all(test$split=="test"))
stopifnot(all(is.finite(train$log_price)),all(is.finite(valid$log_price)),
          all(is.finite(test$log_price)))
for (d in list(train,valid,test)) {
  stopifnot(all(is.finite(d$log_house_size)),all(is.finite(d$log1p_acre)),
            all(is.finite(d$bed_filled)),all(is.finite(d$bath_filled)),
            all(is.finite(d$price)),all(d$price>=30000),
            all(d$price<=20000000), all(nzchar(d$state)))
}
group_sets <- lapply(list(train,valid,test),function(x) unique(x$group_id))
stopifnot(length(intersect(group_sets[[1]],group_sets[[2]]))==0L,
          length(intersect(group_sets[[1]],group_sets[[3]]))==0L,
          length(intersect(group_sets[[2]],group_sets[[3]]))==0L)
manifest <- fread("EDA/reports/06_model_manifest.csv")
measure <- function(k) manifest[metric==k,value]
stopifnot(sum(vapply(list(train,valid,test),nrow,integer(1)))==measure("model_rows"),
          nrow(train)==measure("train_rows"),nrow(valid)==measure("validation_rows"),
          nrow(test)==measure("test_rows"),
          measure("groups_present_in_multiple_splits")==0L)
impute <- fread("EDA/reports/06_train_only_imputation.csv")
stopifnot(impute[field=="bed",train_median]==3,
          impute[field=="bath",train_median]==2,
          abs(impute[field=="acre_lot",train_median]-0.23)<1e-9)
figs <- list.files("EDA/figures",pattern="\\.png$",full.names=TRUE)
stopifnot(length(figs)==16L,all(file.info(figs)$size>5000L))
readme <- paste(readLines("EDA/README.md",warn=FALSE),collapse="\n")
linked <- regmatches(readme,gregexpr("figures/[A-Za-z0-9_]+\\.png",readme))[[1]]
stopifnot(length(unique(linked))==length(figs),
          all(file.exists(file.path("EDA",linked))))
cat("EDA QA PASS:",nrow(train),"train,",nrow(valid),"validation,",
    nrow(test),"test;",length(figs),"linked figures; 0 surrogate-group overlaps.\n")
