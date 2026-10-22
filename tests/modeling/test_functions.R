#!/usr/bin/env Rscript
# CI smoke tests on synthetic data: never read held-out test.csv.
source("modeling/common.R")
stopifnot(requireNamespace("rpart",quietly=TRUE))
set.seed(2121)
n <- 650L
d <- data.table(
  log_house_size=log(runif(n,750,3200)),
  bed_filled=sample(1:5,n,TRUE),
  bath_filled=sample(1:4,n,TRUE),
  log1p_acre=log1p(runif(n,0.04,.9)),
  bed_missing=sample(0:1,n,TRUE,prob=c(.9,.1)),
  bath_missing=sample(0:1,n,TRUE,prob=c(.9,.1)),
  acre_missing=sample(0:1,n,TRUE,prob=c(.85,.15)),
  state_grp=factor(sample(c("Texas","Florida","Other"),n,TRUE)))
d[,log_price:=10+0.35*log_house_size+0.08*bed_filled+
    0.04*bath_filled+0.2*(state_grp=="Florida")+
    rnorm(.N,0,.24)]
linear <- lm(REG_FORMULA,data=d)
single <- rpart::rpart(REG_FORMULA,data=d,method="anova",
    control=rpart::rpart.control(minsplit=50,xval=0))
bagged <- fit_bagged(d,ntree=3L,seed=9L,rows_per_tree=400L,
                     mtry=5L,depth=5L)
boosted <- fit_boosted(d,ntrees=8L,depth=2L,seed=33L,minbucket=20L)
p <- list(as.numeric(predict(linear,newdata=d)),
          as.numeric(predict(single,newdata=d)),
          predict_bagged(bagged,d),predict_boosted(boosted,d))
stopifnot(length(p)==4L,all(vapply(p,length,integer(1))==n),
          all(vapply(p,function(x) all(is.finite(x)),logical(1))))
truth <- exp(d$log_price)
errors <- rbindlist(lapply(seq_along(p),function(i)
  get_metrics(truth,p[[i]],paste0("m",i))))
stopifnot(nrow(errors)==4L,all(is.finite(errors$mae_usd)),
          all(errors$mae_usd>=0),all(errors$n==n))
stopifnot(isTRUE(all.equal(p[[4]],predict_boosted(boosted,d),tolerance=0)))
cat("PASS: OLS, single CART, randomized bagged CART, boosted CART; n=",n,"\n")
