#!/usr/bin/env Rscript
# Champion hyperparameter tuning, append sections only after reviewing selection results.
options(stringsAsFactors=FALSE, scipen=30)
suppressPackageStartupMessages(library(data.table))
dir.create('modeling/artifacts',recursive=TRUE,showWarnings=FALSE)
dir.create('modeling/model_fine_tuning/figures',recursive=TRUE,showWarnings=FALSE)

# Standard run: Rscript modeling/model_fine_tuning.R => validation tuning ONLY
# One-time final: Rscript modeling/model_fine_tuning.R --final-test
if (!("--final-test" %in% commandArgs(trailingOnly=TRUE))) {

# Pass T1 - confirm selection winner; tune boosting iterations and depth.
source("modeling/common.R")
dir.create("modeling/model_fine_tuning/figures",recursive=TRUE,showWarnings=FALSE)
winner <- fread("modeling/artifacts/selection_winner.csv")
stopifnot(identical(winner$model[1],"gradient_boosted_CART"))
cohort <- make_cohort(ntrain=40000L,nvalid=12000L)
tr <- cohort$train; va <- cohort$valid
trial_grid <- data.table(
 id=c("selection_default","more_trees_small_steps","deeper_trees"),
 ntrees=c(75L,110L,85L),depth=c(2L,2L,3L),
 shrinkage=c(0.10,0.07,0.10),bag_fraction=c(.72,.72,.72),
 minbucket=c(80L,80L,80L))
measure_trial <- function(k) {
  row <- trial_grid[id==k]
  stopifnot(nrow(row)==1L)
  message("TUNING trial ",k,": trees=",row$ntrees," depth=",row$depth,
          " shrinkage=",row$shrinkage)
  m <- fit_boosted(tr,ntrees=row$ntrees,depth=row$depth,
                   shrinkage=row$shrinkage,bag_fraction=row$bag_fraction,
                   minbucket=row$minbucket,seed=580L)
  pr <- predict_boosted(m,va)
  met <- get_metrics(va$price,pr,k)
  met[, ':='(ntrees=row$ntrees,depth=row$depth,shrinkage=row$shrinkage,
            bag_fraction=row$bag_fraction,minbucket=row$minbucket)]
  fwrite(data.table(group_id=va$group_id,price=va$price,pred_log=pr),
         file.path("modeling/artifacts",paste0(k,"_predictions.csv")))
  met
}
trial_metrics <- rbindlist(lapply(trial_grid$id,measure_trial))
fwrite(trial_metrics,"modeling/artifacts/tuning_metrics.csv")
plot_png("modeling/model_fine_tuning/figures/01_initial_search.png",{
  par(mar=c(9,5,4,1))
  barplot(trial_metrics$mae_usd/1000,names.arg=trial_metrics$model,
          las=2,col=c("#7ba6b2","#d0ac77","#7aa88b"),
          ylim=c(0,max(trial_metrics$mae_usd/1000)*1.15),
          main="Boosting tuning stage 1",ylab="Validation MAE ($000)")
})
message("Tuning stage 1 ranked by validation MAE:")
print(trial_metrics[order(mae_usd),.(model,mae_usd,log_rmse,ntrees,depth,shrinkage)])

# Pass T2 - adaptive follow-up: depth 3 is promising, so probe learning
# rate/tree-count tradeoff and check a depth 4 counterfactual.
trial_grid <- rbind(
  trial_grid,
  data.table(
    id=c("depth3_more_rounds","depth4_lower_rate","depth3_faster_rate"),
    ntrees=c(115L,105L,115L),
    depth=c(3L,4L,3L),
    shrinkage=c(0.08,0.08,0.12),
    bag_fraction=c(.72,.72,.72),
    minbucket=c(80L,80L,80L)
  )
)
new_trials <- rbindlist(lapply(tail(trial_grid$id,3L),measure_trial))
trial_metrics <- rbind(trial_metrics,new_trials)
setorder(trial_metrics,mae_usd,log_rmse)
fwrite(trial_metrics,"modeling/artifacts/tuning_metrics.csv")
winner_config <- copy(trial_metrics[1L])
fwrite(winner_config,"modeling/artifacts/tuning_locked_config.csv")
plot_png("modeling/model_fine_tuning/figures/02_full_tuning_ranking.png",{
  par(mar=c(11,5,4,1))
  c <- ifelse(trial_metrics$model==winner_config$model,"#3c8a79","#9eabb5")
  barplot(trial_metrics$mae_usd/1000,names.arg=trial_metrics$model,
          las=2,col=c,ylim=c(0,max(trial_metrics$mae_usd/1000)*1.14),
          main="Six boosted-tree settings on identical validation rows",
          ylab="Validation MAE ($ thousand)")
})
plot_png("modeling/model_fine_tuning/figures/03_trees_vs_error.png",{
  plot(trial_metrics$ntrees,trial_metrics$mae_usd/1000,pch=19,cex=1.3,
       col=ifelse(trial_metrics$depth==2,"#bd8a5b",
           ifelse(trial_metrics$depth==3,"#378f80","#5d75aa")),
       xlab="Boosting rounds",ylab="Validation MAE ($ thousand)",
       main="Iterations / depth / MAE: exploratory sweep")
  text(trial_metrics$ntrees,trial_metrics$mae_usd/1000,
       labels=trial_metrics$model,pos=3,cex=.65)
  legend("topright",legend=c("depth 2","depth 3","depth 4"),
         pch=19,col=c("#bd8a5b","#378f80","#5d75aa"),bty="n")
})
message("After six configurations, best validation settings:")
print(trial_metrics[,.(model,mae_usd,log_rmse,ntrees,depth,shrinkage)])

# Pass T3 - local, data-driven refinement around stage-2 winner (depth 4).
trial_grid <- rbind(trial_grid,
  data.table(id=c("depth4_more_rounds","depth4_higher_rate","depth5_check"),
     ntrees=c(145L,120L,105L),depth=c(4L,4L,5L),
     shrinkage=c(0.07,0.11,0.08),bag_fraction=c(.72,.72,.72),
     minbucket=c(80L,80L,80L)))
final_trials <- rbindlist(lapply(tail(trial_grid$id,3L),measure_trial))
trial_metrics <- rbind(trial_metrics,final_trials)
setorder(trial_metrics,mae_usd,log_rmse)
winner_config <- copy(trial_metrics[1L])
fwrite(trial_metrics,"modeling/artifacts/tuning_metrics.csv")
# Predeclare locked config BEFORE any test read.
fwrite(winner_config,"modeling/artifacts/tuning_locked_config.csv")
plot_png("modeling/model_fine_tuning/figures/04_final_hyperparameter_ranking.png",{
  par(mar=c(12,5,4,1))
  barplot(trial_metrics$mae_usd/1000,names.arg=trial_metrics$model,las=2,
     col=ifelse(trial_metrics$model==winner_config$model,"#348e79","#94a8b7"),
     ylim=c(0,max(trial_metrics$mae_usd/1000)*1.13),
     ylab="MAE (USD thousands)",main="Nine trials: same validation rows")
})
plot_png("modeling/model_fine_tuning/figures/05_improvement_vs_default.png",{
  improve <- trial_metrics[order(-mae_usd)]
  delta <- (trial_metrics[model=="selection_default",mae_usd][1]-improve$mae_usd)/1000
  par(mar=c(12,5,4,1))
  barplot(delta,names.arg=improve$model,las=2,col=ifelse(delta>0,"#489b86","#cb816b"),
          ylab="USD MAE improvement ($ thousands)",
          main="Improvements versus selection-default model")
  abline(h=0,lty=2)
})
message("FINAL TUNING CONFIGURATION LOCKED WITHOUT USING TEST:")
print(winner_config[,.(model,mae_usd,log_rmse,ntrees,depth,shrinkage,
                         bag_fraction,minbucket)])

} # End validation-only tuning path. Test has NOT been opened above.

# Pass T4 - one locked, held-out final test; deliberately opt-in and guarded.
if ("--final-test" %in% commandArgs(trailingOnly=TRUE)) {
  source("modeling/common.R")
  lock_path <- "modeling/artifacts/tuning_locked_config.csv"
  result_path <- "modeling/artifacts/final_test_metrics.csv"
  stopifnot(file.exists(lock_path))
  if (file.exists(result_path)) {
    stop("Final held-out test has already been evaluated; reuse its saved report. ",
         "Do NOT reselect hyperparameters against the test set.")
  }
  champion_config <- fread(lock_path)
  stopifnot(nrow(champion_config)==1L,
            champion_config$model=="depth5_check")
  message("FINAL LOCKED TEST: config=",champion_config$model,
          " no retuning after this step")
  # Refit only on ALLOWED development partitions; enlarge from 40k+12k to 64k+16k.
  part_train <- sample_part("train",64000L,MODEL_SEED+100L)
  part_valid <- sample_part("validation",16000L,MODEL_SEED+101L)
  dev <- rbindlist(list(part_train,part_valid))
  states <- dev[, .N,by=state][order(-N)]
  top <- head(states$state,20L)
  dev[,state_grp:=factor(ifelse(state %in% top,state,"Other"),
                         levels=c(top,"Other"))]
  stopifnot(!anyNA(dev[,..DATA_VARS]))
  m <- fit_boosted(dev,ntrees=champion_config$ntrees,
       depth=champion_config$depth,shrinkage=champion_config$shrinkage,
       bag_fraction=champion_config$bag_fraction,
       minbucket=champion_config$minbucket,seed=580L)
  saveRDS(list(model=m,state_levels=top,config=champion_config),
          "modeling/artifacts/final_champion_model.rds")
  # OPEN THE SEALED HELD-OUT TEST PARTITION HERE, AFTER PARAMETER LOCK.
  test <- fread("data/processed/test.csv")
  test[,state_grp:=factor(ifelse(state %in% top,state,"Other"),
                          levels=c(top,"Other"))]
  stopifnot(!anyNA(test[,..DATA_VARS]),
            length(intersect(unique(test$group_id),unique(dev$group_id)))==0L)
  raw_pred <- predict_boosted(m,test)
  test[,predicted_price:=exp(clip_log_price(raw_pred))]
  test[,absolute_error:=abs(predicted_price-price)]
  test[,signed_error:=predicted_price-price]
  metrics <- get_metrics(test$price,raw_pred,
                         "locked_tuned_boosted_CART","test")
  metrics[,':='(final_dev_rows=nrow(dev),test_rows=nrow(test),
      ntrees=champion_config$ntrees,depth=champion_config$depth,
      shrinkage=champion_config$shrinkage,
      mape_pct=100*mean(abs(test$absolute_error/test$price)))]
  # Row-wise bootstrap is illustrative; it ignores dependence across homes.
  set.seed(2210)
  boot <- replicate(240L,mean(sample(test$absolute_error,length(test$absolute_error),
                                   replace=TRUE)))
  ci <- unname(quantile(boot,c(.025,.975)))
  metrics[,':='(mae_bootstrap_low=ci[1],mae_bootstrap_high=ci[2])]
  fwrite(metrics,result_path)
  saveRDS(metrics,"modeling/artifacts/test_metric_snapshot.rds")
  fwrite(test[,.(group_id,actual_price=price,predicted_price,absolute_error)],
         "modeling/artifacts/test_predictions.csv")
  test[,price_band:=cut(price,breaks=c(0,150000,300000,500000,800000,1500000,Inf),
    labels=c("<150k","150-300k","300-500k","500-800k","800k-1.5m",">1.5m"))]
  bands <- test[,.(n=.N,mae_usd=mean(absolute_error),
      median_ae_usd=median(absolute_error),
      med_actual=median(price),med_predicted=median(predicted_price),
      bias_usd=mean(signed_error)),by=price_band]
  fwrite(bands,"modeling/artifacts/test_price_bands.csv")
  states <- test[,.(n=.N,mae_usd=mean(absolute_error),
          bias_usd=mean(signed_error),
          median_actual=median(price)),by=state][n>=600L][order(-n)]
  fwrite(states,"modeling/artifacts/test_state_errors.csv")
  test[,decile:=cut(log(price),
     breaks=unique(quantile(log(price),seq(0,1,.1),na.rm=TRUE)),
     include.lowest=TRUE,labels=FALSE)]
  cal <- test[,.(n=.N,actual_median=median(price),
          pred_median=median(predicted_price),bias=mean(signed_error)),by=decile]
  fwrite(cal,"modeling/artifacts/test_calibration.csv")
  save_scatter("modeling/model_fine_tuning/figures/06_heldout_actual_vs_predicted.png",
                test$price,raw_pred,"Locked champion: held-out test asking prices")
  plot_png("modeling/model_fine_tuning/figures/07_test_mae_by_price_band.png",{
    par(mar=c(9,5,4,1))
    barplot(bands$mae_usd/1000,names.arg=bands$price_band,las=2,
            col="#5e9b9b",ylab="Test MAE (thousand USD)",
            main="Final model: errors increase with asking-price band")
  })
  plot_png("modeling/model_fine_tuning/figures/08_test_state_mae.png",{
    z <- head(states,15L)
    par(mar=c(5,12,4,2))
    barplot(rev(z$mae_usd/1000),names.arg=rev(z$state),horiz=TRUE,las=1,
            col="#6791ac",xlab="Test MAE (thousand USD)",
            main="15 most represented states: dollar errors")
  })
  plot_png("modeling/model_fine_tuning/figures/09_calibration_by_price_decile.png",{
    ordered <- cal[order(decile)]
    plot(ordered$actual_median/1e6,ordered$pred_median/1e6,type="b",pch=19,
         col="#428c84",lwd=2,xlim=c(0,2),ylim=c(0,2),
         xlab="Median ACTUAL asking price ($ million)",
         ylab="Median PREDICTED asking price ($ million)",
         main="Held-out test: price-decile calibration")
    abline(a=0,b=1,col="#b96a50",lwd=2,lty=2)
    legend("topleft",legend=c("Observed model calibration","Ideal 1:1"),
           col=c("#428c84","#b96a50"),lwd=2,lty=c(1,2),bty="n")
  })
  plot_png("modeling/model_fine_tuning/figures/10_test_error_distribution.png",{
    hist(log1p(test$absolute_error),breaks=55,col="#a8b9cc",
         xlab="ln(1 + absolute dollar error)",
         main="Held-out absolute error distribution")
  })
  # Example *model response*, not a controlled causal effect.
  ref <- data.table(
     log_house_size=log(seq(900,3800,length.out=40)),
     bed_filled=3,bath_filled=2,log1p_acre=log1p(.23),
     bed_missing=0,bath_missing=0,acre_missing=0,
     state_grp=factor(rep(if("Texas" %in% top) "Texas" else top[1],40),
                      levels=c(top,"Other")))
  profile <- data.table(sqft=exp(ref$log_house_size),
         predicted_asking_price=exp(clip_log_price(predict_boosted(m,ref))))
  fwrite(profile,"modeling/artifacts/example_size_profile.csv")
  plot_png("modeling/model_fine_tuning/figures/11_example_size_response.png",{
    plot(profile$sqft,profile$predicted_asking_price/1000,type="l",
         col="#418f85",lwd=3,
         xlab="Living area (sq ft)",ylab="Model asking-price estimate ($ thousands)",
         main="Illustrative Texas-style model response (NOT causal)")
  })
  importance <- sort(table(unlist(lapply(m$trees,function(tree)
    tree$frame$var[tree$frame$var!="<leaf>"]))),decreasing=TRUE)
  plot_png("modeling/model_fine_tuning/figures/12_boosted_split_importance.png",{
    par(mar=c(5,12,4,2))
    barplot(rev(importance),names.arg=rev(names(importance)),
            horiz=TRUE,las=1,col="#778dac",
            xlab="Total CART splits across boosted trees",
            main="Predictive variable-use frequency (NOT causal)")
  })
  message("FINAL TEST ONCE, NO RETUNING:");print(metrics)
  message("TEST BAND ERRORS:");print(bands)
  message("Top test states:");print(head(states,7))
}
