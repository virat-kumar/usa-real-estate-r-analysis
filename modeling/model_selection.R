#!/usr/bin/env Rscript
# Developed and verified incrementally, one fitted family per section.
options(stringsAsFactors=FALSE, scipen=30)
suppressPackageStartupMessages(library(data.table))
dir.create('modeling/artifacts',recursive=TRUE,showWarnings=FALSE)
dir.create('modeling/model_selection/figures',recursive=TRUE,showWarnings=FALSE)

# Pass 1 - fixed cohort, business metric, naive benchmark, log-linear baseline
source("modeling/common.R")
dir.create("modeling/model_selection/figures",recursive=TRUE,showWarnings=FALSE)
cohort <- make_cohort()
tr <- cohort$train; va <- cohort$valid
message("Selection cohort: training=",nrow(tr),"; validation=",nrow(va))
stopifnot(length(intersect(tr$group_id,va$group_id))==0L)
naive_log <- rep(median(tr$log_price),nrow(va))
baseline <- get_metrics(va$price,naive_log,"constant_median")
ols <- lm(REG_FORMULA,data=tr)
ols_pred <- as.numeric(predict(ols,newdata=va))
ols_metric <- get_metrics(va$price,ols_pred,"log_linear_OLS")
selection_metrics <- rbind(baseline,ols_metric)
fwrite(selection_metrics,"modeling/artifacts/selection_metrics.csv")
fwrite(data.table(variable=names(coef(ols)),estimate=as.numeric(coef(ols))),
       "modeling/artifacts/ols_coefficients.csv")
plot_png("modeling/model_selection/figures/01_cohort_price.png",{
 par(mfrow=c(1,2),mar=c(5,5,4,1))
 hist(log(tr$price),breaks=45,col="#79aeb3",main="Training log(asking price)",xlab="ln USD")
 hist(log(va$price),breaks=45,col="#c89f6e",main="Validation log(asking price)",xlab="ln USD")
})
save_scatter("modeling/model_selection/figures/02_ols_prediction.png",
             va$price,ols_pred,"OLS: asking-price validation predictions")
message("Pass 1: linear and naive baseline")
print(selection_metrics)

# Pass 2 - a single interpretable CART regression tree
suppressPackageStartupMessages(library(rpart))
cart <- rpart(REG_FORMULA,data=tr,method="anova",
              control=rpart.control(cp=0.0015,minsplit=110,minbucket=45,
                                    maxdepth=10,xval=0))
cart_pred <- as.numeric(predict(cart,newdata=va))
cart_metric <- get_metrics(va$price,cart_pred,"CART_single_tree")
selection_metrics <- rbind(selection_metrics,cart_metric)
fwrite(selection_metrics,"modeling/artifacts/selection_metrics.csv")
save_scatter("modeling/model_selection/figures/03_CART_validation.png",
             va$price,cart_pred,"CART validation predictions")
cart_band <- save_error_band("modeling/model_selection/figures/04_CART_price_bands.png",
                         va$price,cart_pred,"Single CART: error by price band")
fwrite(cart_band,"modeling/artifacts/CART_price_bands.csv")
plot_png("modeling/model_selection/figures/05_CART_importance.png",{
 imp <- sort(cart$variable.importance,decreasing=TRUE)
 par(mar=c(5,12,3,2))
 barplot(rev(imp),names.arg=rev(names(imp)),horiz=TRUE,las=1,
         col="#659c9e",main="CART feature importance (split improvement)",
         xlab="Cumulative impurity decrease (not causal)")
})
message("Pass 2: CART leaves=",sum(cart$frame$var=="<leaf>"))
print(selection_metrics)

# Pass 3 - randomized-feature bagged CART ensemble ("forest-style")
# This is NOT ranger's conventional RF, because mtry varies per tree.
forest <- fit_bagged(tr,ntree=28L,seed=250L,rows_per_tree=11000L,
                     mtry=5L,depth=10L,cp=0.0008)
forest_pred <- predict_bagged(forest,va)
forest_metric <- get_metrics(va$price,forest_pred,"randomized_bagged_CART")
selection_metrics <- rbind(selection_metrics,forest_metric)
fwrite(selection_metrics,"modeling/artifacts/selection_metrics.csv")
save_scatter("modeling/model_selection/figures/06_bagged_validation.png",
             va$price,forest_pred,"Bagged randomized CART: validation")
forest_band <- save_error_band(
  "modeling/model_selection/figures/07_bagged_price_bands.png",
  va$price,forest_pred,"Bagged trees: error by actual price band")
fwrite(forest_band,"modeling/artifacts/bagged_price_bands.csv")
used <- table(unlist(lapply(forest$trees,function(tree)
  tree$frame$var[tree$frame$var!="<leaf>"])))
plot_png("modeling/model_selection/figures/08_bagged_split_frequency.png",{
  z <- sort(used,decreasing=TRUE)
  par(mar=c(5,13,3,2))
  barplot(rev(z),names.arg=rev(names(z)),horiz=TRUE,las=1,
          col="#738ba8",main="Bagged CART: split variable frequency",
          xlab="Split count across ensemble, not causal importance")
})
message("Pass 3: randomized bagged CART with ",length(forest$trees)," trees")
print(selection_metrics)

# Pass 4 - additive gradient-boosted shallow regression CART trees
boost <- fit_boosted(tr,ntrees=75L,depth=2L,shrinkage=0.10,
                      bag_fraction=0.72,seed=580L,minbucket=80L)
boost_pred <- predict_boosted(boost,va)
boost_metric <- get_metrics(va$price,boost_pred,"gradient_boosted_CART")
selection_metrics <- rbind(selection_metrics,boost_metric)
fwrite(selection_metrics,"modeling/artifacts/selection_metrics.csv")
save_scatter("modeling/model_selection/figures/09_boosted_validation.png",
             va$price,boost_pred,"Gradient-boosted CART validation predictions")
boost_band <- save_error_band(
  "modeling/model_selection/figures/10_boosted_price_bands.png",
  va$price,boost_pred,"Boosted CART: error by actual asking price")
fwrite(boost_band,"modeling/artifacts/boosted_price_bands.csv")
candidates <- selection_metrics[model!="constant_median"]
setorder(candidates,mae_usd,log_rmse)
stopifnot(nrow(candidates)==4L,length(unique(candidates$model))==4L)
selected <- copy(candidates[1L])
fwrite(candidates,"modeling/artifacts/selection_ranking.csv")
fwrite(selected,"modeling/artifacts/selection_winner.csv")
plot_png("modeling/model_selection/figures/11_four_model_comparison.png",{
 par(mar=c(10,5,4,1))
 cols <- ifelse(candidates$model==selected$model,"#318478","#849eac")
 barplot(candidates$mae_usd/1000,
         names.arg=candidates$model,las=2,col=cols,ylim=c(0,max(candidates$mae_usd/1000)*1.22),
         ylab="Validation MAE (thousand USD)",
         main="Four model families; lower is better")
 text(seq_along(candidates)*1.2-.5,candidates$mae_usd/1000+7,
      labels=paste0("$",format(round(candidates$mae_usd/1000),nsmall=0),"k"),
      cex=.8)
})
errs <- data.table(algorithm=c("OLS","CART","Bagged CART","Boosted CART"),
  mae=c(ols_metric$mae_usd,cart_metric$mae_usd,
        forest_metric$mae_usd,boost_metric$mae_usd),
  log_rmse=c(ols_metric$log_rmse,cart_metric$log_rmse,
             forest_metric$log_rmse,boost_metric$log_rmse))
plot_png("modeling/model_selection/figures/12_error_tradeoff.png",{
 plot(errs$mae/1000,errs$log_rmse,
      pch=19,cex=1.7,col=c("#3c7e9e","#c49a67","#7da58b","#765c9c"),
      xlab="MAE ($ thousand)",ylab="Log-price RMSE",
      main="Selection: USD and log-scale errors")
 text(errs$mae/1000,errs$log_rmse,labels=errs$algorithm,pos=3,cex=.8)
})
message("Pass 4: four-way validation ranking (excludes naive benchmark)")
print(candidates)
message("Selected by validation USD MAE: ",selected$model)
