# Shared R modeling utilities. Prediction target: historical listing ASKING price.
suppressPackageStartupMessages(library(data.table))
options(stringsAsFactors = FALSE, scipen = 30)
DATA_VARS <- c("log_house_size","bed_filled","bath_filled","log1p_acre",
               "bed_missing","bath_missing","acre_missing","state_grp")
REG_FORMULA <- as.formula(paste("log_price ~",paste(DATA_VARS,collapse="+")))
MODEL_SEED <- 20261022L
clip_log_price <- function(x) {
  pmin(log(20000000), pmax(log(30000), as.numeric(x)))
}
get_metrics <- function(truth, predlog, name, split="validation") {
  stopifnot(length(truth)==length(predlog),all(is.finite(truth)),all(is.finite(predlog)))
  pr <- exp(clip_log_price(predlog))
  err <- pr - truth
  data.table(model=name,partition=split,n=length(truth),
             mae_usd=mean(abs(err)),rmse_usd=sqrt(mean(err^2)),
             median_ae_usd=median(abs(err)),
             log_rmse=sqrt(mean((log(pr)-log(truth))^2)),
             r2_price=1-sum(err^2)/sum((truth-mean(truth))^2))
}
plot_png <- function(path, expr, width=1200L,height=800L) {
  png(path,width=width,height=height,res=145)
  tryCatch(force(expr),finally=dev.off())
}
sample_part <- function(part,n,seed) {
  # Reads only the named partition. Calling test is FORBIDDEN before final lock.
  stopifnot(part %in% c("train","validation"))
  x <- fread(file.path("data/processed",paste0(part,".csv")))
  set.seed(seed)
  x[sample.int(nrow(x),size=min(nrow(x),as.integer(n)),replace=FALSE)]
}
make_cohort <- function(ntrain=40000L,nvalid=12000L) {
  tr <- sample_part("train",ntrain,MODEL_SEED)
  va <- sample_part("validation",nvalid,MODEL_SEED+1L)
  states <- tr[, .N, by=state][order(-N)]
  top <- head(states$state,20L)
  group <- function(z) {
    z[, state_grp:=factor(ifelse(state %in% top,state,"Other"),
                       levels=c(top,"Other"))]
    z
  }
  tr <- group(tr)
  va <- group(va)
  stopifnot(!anyNA(tr[,..DATA_VARS]),!anyNA(va[,..DATA_VARS]),
            !anyNA(tr$log_price),!anyNA(va$log_price),
            length(intersect(unique(tr$group_id),unique(va$group_id)))==0L)
  list(train=tr,valid=va,top_states=top)
}
# Efficient, explicit random-subspace bagged CART; unlike standard RF, features
# are randomly selected PER TREE, not re-sampled independently at every node.
fit_bagged <- function(tr, ntree=28L, seed=250L,
                       rows_per_tree=11000L, mtry=5L,
                       depth=10L, cp=0.0008) {
  stopifnot(requireNamespace("rpart",quietly=TRUE))
  set.seed(seed)
  trees <- vector("list",ntree)
  for (i in seq_len(ntree)) {
    feats <- sample(DATA_VARS,min(mtry,length(DATA_VARS)),replace=FALSE)
    # sample with replacement -> bootstrap aggregation
    part <- tr[sample.int(nrow(tr),min(nrow(tr),rows_per_tree),replace=TRUE)]
    trees[[i]] <- rpart::rpart(
      as.formula(paste("log_price ~",paste(feats,collapse="+"))),
      data=part,method="anova",
      control=rpart::rpart.control(cp=cp,minsplit=75,minbucket=30,
                                  maxdepth=depth,xval=0))
  }
  structure(list(trees=trees,features=DATA_VARS,
            params=list(ntree=ntree,seed=seed,rows_per_tree=rows_per_tree,
                        mtry=mtry,depth=depth,cp=cp)),class="subspace_forest")
}
predict_bagged <- function(m,newdata) {
  result <- numeric(nrow(newdata))
  for (i in seq_along(m$trees)) {
    result <- result + as.numeric(predict(m$trees[[i]],newdata=newdata))/length(m$trees)
  }
  result
}
# Squared-error gradient boosting on log-price with shallow CART weak learners.
fit_boosted <- function(tr, ntrees=75L,depth=2L,shrinkage=0.10,
                        bag_fraction=0.72,seed=580L,minbucket=80L) {
  set.seed(seed)
  fit0 <- mean(tr$log_price)
  pred <- rep(fit0,nrow(tr))
  trees <- vector("list",ntrees)
  for (i in seq_len(ntrees)) {
    sub <- sample.int(nrow(tr),max(500L,as.integer(nrow(tr)*bag_fraction)))
    work <- tr[sub]
    work[, response := log_price-pred[sub]]
    trees[[i]] <- rpart::rpart(
      as.formula(paste("response ~",paste(DATA_VARS,collapse="+"))),
      data=work,method="anova",
      control=rpart::rpart.control(cp=0,minsplit=180,minbucket=minbucket,
                                  maxdepth=depth,xval=0))
    pred <- pred + shrinkage*as.numeric(predict(trees[[i]],newdata=tr))
  }
  structure(list(intercept=fit0,trees=trees,shrinkage=shrinkage,
    params=list(ntrees=ntrees,depth=depth,shrinkage=shrinkage,
                bag_fraction=bag_fraction,seed=seed,minbucket=minbucket)),
    class="cart_boosted")
}
predict_boosted <- function(m,x) {
  y <- rep(m$intercept,nrow(x))
  for (tree in m$trees) y <- y + m$shrinkage*as.numeric(predict(tree,newdata=x))
  y
}
save_scatter <- function(path,truth,predlog,title) {
  set.seed(17)
  ii <- sample.int(length(truth),min(2200L,length(truth)))
  plot_png(path,{
    plot(truth[ii]/1e6,exp(clip_log_price(predlog[ii]))/1e6,
         pch=16,cex=.48,col=adjustcolor("#2f7895",alpha.f=.25),
         xlab="Actual asking price ($ million)",ylab="Predicted asking price ($ million)",
         main=title)
    abline(a=0,b=1,col="#bf553a",lwd=2)
  })
}
save_error_band <- function(path,truth,predlog,title) {
  x <- data.table(truth=truth,pred=exp(clip_log_price(predlog)))
  x[, band:=cut(truth,breaks=c(0,150000,300000,500000,800000,1500000,Inf),
                labels=c("<150k","150-300k","300-500k","500-800k","800k-1.5m",">1.5m"))]
  v <- x[,.(n=.N,mae=mean(abs(pred-truth))),by=band]
  plot_png(path,{
    par(mar=c(8,5,4,1))
    barplot(v$mae/1000,names.arg=v$band,las=2,col="#5d8c9e",
            ylab="Validation MAE ($ thousand)",main=title)
  })
  v
}
