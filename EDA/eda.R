#!/usr/bin/env Rscript
# Incremental, auditable EDA for original Kaggle USA Real Estate v25.
# Appended section-by-section AFTER reviewing the preceding step's output.
options(stringsAsFactors = FALSE, scipen = 30)
suppressPackageStartupMessages(library(data.table))
if (!file.exists("data/raw/realtor-data.zip.csv")) stop("Run Rscript setup.R first.")
dir.create("EDA/figures", showWarnings = FALSE, recursive = TRUE)
dir.create("EDA/reports", showWarnings = FALSE, recursive = TRUE)
dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
save_table <- function(x, name) fwrite(x, file.path("EDA/reports", name))
fig_png <- function(name, expression, width = 1200, height = 800, res = 135) {
  png(file.path("EDA/figures", name), width = width, height = height, res = res)
  tryCatch(force(expression), finally = dev.off())
}
message("EDA starting from official original Kaggle CSV.")

# 01 - SOURCE SHAPE, COVERAGE, MISSINGNESS, STATUS AND EXACT DUPLICATES
message("01/07: source shape / missingness / duplicate audit")
raw <- fread("data/raw/realtor-data.zip.csv", na.strings = c("", "NA"),
             colClasses = list(character = c("zip_code", "prev_sold_date")),
             showProgress = FALSE)
stopifnot(nrow(raw) == 2226382L, ncol(raw) == 12L)
na_audit <- data.table(field = names(raw), storage = vapply(raw, function(x) class(x)[1], ""),
                       missing_n = vapply(raw, function(x) sum(is.na(x) | (is.character(x) & !nzchar(trimws(x)))), numeric(1)),
                       distinct_n = vapply(raw, uniqueN, integer(1)))
na_audit[, missing_pct := round(100 * missing_n / nrow(raw), 3)]
setorder(na_audit, -missing_pct)
save_table(na_audit, "01_schema_missing.csv")
status_freq <- raw[, .N, by = status][order(-N)]
save_table(status_freq, "01_status.csv")
duplicate_n <- nrow(raw) - uniqueN(raw)
dq01 <- data.table(metric=c("total_rows","total_columns","exact_duplicate_rows"),
                   value=c(nrow(raw),ncol(raw),duplicate_n))
save_table(dq01, "01_shape_duplicates.csv")
fig_png("01_missingness.png", {
  par(mar=c(10,4,4,1))
  barplot(na_audit$missing_pct, names.arg=na_audit$field, las=2,
          col="steelblue4", ylim=c(0, 100),
          main="Missing values by source column", ylab="Missing (%)")
  abline(h=seq(0,100,20),col="grey85",lty=3)
})
message("01 result: rows=", nrow(raw), " duplicate=", duplicate_n)
print(na_audit)
print(status_freq)

# 02 - DATA VALIDITY, EXTREMES AND TIME FIELD (NOT A LISTING TIMESTAMP)
message("02/07: validity, outliers, historical-date and duplicate-key audit")
validity <- rbindlist(lapply(c("price","house_size","bed","bath","acre_lot"), function(v) {
  x <- raw[[v]]
  data.table(field=v, missing=sum(is.na(x)), nonpositive=sum(!is.na(x) & x<=0),
             negative=sum(!is.na(x) & x<0),
             q01=unname(quantile(x,.01,na.rm=TRUE)),
             median=median(x,na.rm=TRUE), q99=unname(quantile(x,.99,na.rm=TRUE)),
             q999=unname(quantile(x,.999,na.rm=TRUE)), max=max(x,na.rm=TRUE))
}))
save_table(validity,"02_numeric_validity.csv")
status_stats <- raw[!is.na(price) & price>0, .(
  listings=.N,median_price=median(price),
  p95_price=as.numeric(quantile(price,.95)),
  missing_size_pct=round(100*mean(is.na(house_size)),2),
  median_size=median(house_size,na.rm=TRUE)
),by=status]
save_table(status_stats,"02_status_price.csv")
# Anonymized street appears numeric; assess repeated PROPERTY-KEY candidates, not row duplicates.
keyed <- raw[!is.na(street) & !is.na(city) & !is.na(state) & !is.na(zip_code),
             .N, by=.(street,city,state,zip_code)]
key_summary <- data.table(keys=nrow(keyed),repeated_keys=sum(keyed$N>1),
  rows_in_repeated_keys=sum(keyed$N[keyed$N>1]),max_key_multiplicity=max(keyed$N))
save_table(key_summary,"02_property_keys.csv")
yr <- suppressWarnings(as.integer(substr(raw$prev_sold_date,1,4)))
date_stats <- data.table(
  metric=c("date_missing","year_before_1950","year_1950_to_2024",
           "year_after_dataset_update_2024","date_unparseable"),
  count=c(sum(is.na(raw$prev_sold_date)),
          sum(!is.na(yr)&yr<1950),
          sum(!is.na(yr)&yr>=1950 & yr<=2024),
          sum(!is.na(yr)&yr>2024),
          sum(!is.na(raw$prev_sold_date)&is.na(yr))))
save_table(date_stats,"02_date_anomalies.csv")
fig_png("02_status_mix.png", {
  par(mfrow=c(1,2),mar=c(7,4,3,1))
  barplot(status_freq$N/1e6,names.arg=status_freq$status,las=2,col=c("#166e93","#d38727","#7ca68b"),
          ylab="Records (millions)",main="Scraped status mixture")
  boxplot(log10(price)~status,data=raw[is.finite(price)&price>0 & price<1e9],
          col="#d2e7ef",ylab="log10(price)",main="Price by status",las=2,outline=FALSE)
})
print(validity);print(status_stats);print(key_summary);print(date_stats)

# 03 - ASKING-PRICE DISTRIBUTIONS AND CANDIDATE TRANSFORMATIONS
message("03/07: for_sale distributions; logarithms; robust plotting windows")
offers <- raw[status=="for_sale" & is.finite(price) & price>0]
for_sale_quality <- offers[, .(
  n=.N,missing_house_pct=100*mean(is.na(house_size)),
  missing_bed_pct=100*mean(is.na(bed)),
  missing_bath_pct=100*mean(is.na(bath)),
  p01_price=as.numeric(quantile(price,.01)),
  p50_price=median(price),p95_price=as.numeric(quantile(price,.95)),
  p99_price=as.numeric(quantile(price,.99)),
  p999_price=as.numeric(quantile(price,.999)),
  max_price=max(price))]
save_table(for_sale_quality,"03_for_sale_quantiles.csv")
pos_features <- offers[is.finite(house_size) & house_size>0]
feature_quantiles <- rbindlist(lapply(c("price","house_size","bed","bath","acre_lot"),
 function(k) {x <- pos_features[[k]]; x <- x[is.finite(x)&x>0]
   data.table(feature=k,n=length(x),p01=unname(quantile(x,.01)),
    p50=median(x),p95=unname(quantile(x,.95)),
    p99=unname(quantile(x,.99)),p999=unname(quantile(x,.999)),max=max(x))}))
save_table(feature_quantiles,"03_feature_quantiles.csv")
fig_png("03_price_raw_vs_log.png", {
  par(mfrow=c(1,2), mar=c(5,5,4,1))
  cap <- as.numeric(quantile(offers$price,.995))
  hist(offers$price[offers$price<=cap], breaks=60, col="#9abfd0",
       xlab="Price (USD; top 0.5% hidden for display)",main="Asking price: right skew")
  hist(log10(offers$price),breaks=65,col="#376c89",
       xlab="log10(asking price)",main="Log scale reveals main mass")
})
fig_png("04_home_size_and_lot.png", {
  par(mfrow=c(1,2),mar=c(5,5,4,1))
  hist(log10(pos_features$house_size),breaks=60,col="#8ab7aa",
       xlab="log10(square feet)",main="House size among stated areas")
  lot <- pos_features$acre_lot[is.finite(pos_features$acre_lot)&pos_features$acre_lot>0]
  hist(log10(lot),breaks=60,col="#cfa576",
       xlab="log10(lot acres)",main="Lot size is strongly right-skewed")
})
fig_png("05_beds_baths.png", {
  par(mfrow=c(1,2),mar=c(5,4,4,1))
  barplot(table(factor(offers$bed[offers$bed<=12],levels=1:12)),col="#407c9e",
          xlab="Bedrooms",main="Bedrooms (1-12; unknown excluded)")
  barplot(table(factor(offers$bath[offers$bath<=12],levels=1:12)),col="#b78854",
          xlab="Bathrooms",main="Bathrooms (1-12; unknown excluded)")
})
print(for_sale_quality);print(feature_quantiles)

# 04 - MARKET STRUCTURE: STATE / CITY / ZIP GROUPS AND COMPARABILITY
message("04/07: geography, coverage, and per-square-foot comparisons")
# Visualization-only guardrails: explicit and not silently applied to raw data.
geo <- offers[is.finite(house_size) & house_size>=500 & house_size<=20000 &
              price>=10000 & price<=50000000 &
              !is.na(state) & !is.na(city) & nzchar(trimws(city))]
geo[, ppsf := price/house_size]
geo_states <- geo[, .(n=.N,median_asking_price=median(price),
          median_ppsf=median(ppsf),median_size=median(house_size),
          p25_price=as.numeric(quantile(price,.25)),
          p75_price=as.numeric(quantile(price,.75))),by=state][order(-n)]
save_table(geo_states, "04_state_markets.csv")
geo_city <- geo[, .(n=.N,median_price=median(price),
                    median_ppsf=median(ppsf)),by=.(state,city)][order(-n)]
save_table(geo_city[n>=100], "04_cities_ge_100.csv")
zip_groups <- geo[!is.na(zip_code), .N,by=.(state,zip_code)]
geocover <- data.table(total_for_sale=nrow(offers),
                      valid_geo_window=nrow(geo),
                      n_states=uniqueN(geo$state),
                      n_cities=nrow(geo_city),
                      cities_at_least_100=sum(geo_city$n>=100),
                      n_zip_groups=nrow(zip_groups),
                      zips_at_least_30=sum(zip_groups$N>=30))
save_table(geocover,"04_geo_coverage.csv")
top_st <- geo_states[1:min(15,.N)]
fig_png("06_state_median_prices.png", {
  par(mar=c(5,11,4,2))
  barplot(rev(top_st$median_asking_price/1000),names.arg=rev(top_st$state),
          horiz=TRUE,las=1,col="#327596",xlab="Median asking price ($000)",
          main="15 states with most comparable for-sale homes")
})
fig_png("07_state_price_per_sqft.png", {
  par(mar=c(5,11,4,2))
  barplot(rev(top_st$median_ppsf),names.arg=rev(top_st$state),
          horiz=TRUE,las=1,col="#bd875a",xlab="Median USD / sqft",
          main="Size-normalized listing prices (top-15 volume states)")
})
fig_png("08_major_city_price_per_sqft.png", {
  par(mar=c(5,12,4,2))
  topcities <- geo_city[n>=300][order(-n)][1:15]
  nam <- paste(topcities$city,topcities$state,sep=", ")
  barplot(rev(topcities$median_ppsf),names.arg=rev(nam),
          horiz=TRUE,las=1,col="#629f8f",xlab="Median USD / sqft",
          main="High-coverage cities: NOT an investment ROI ranking")
})
print(geocover);print(geo_states[1:15]);print(geo_city[n>=300][1:12])

# 05 - RELATIONSHIPS, EFFECT SIZES AND INFERENTIAL DIAGNOSTICS
message("05/07: correlations, group comparisons, heteroskedasticity")
set.seed(20261022)
study <- copy(geo[sample.int(nrow(geo),min(80000L,nrow(geo)))])
study <- study[is.finite(bed)&bed>=1&bed<=12 &
               is.finite(bath)&bath>=1&bath<=12 &
               (is.na(acre_lot)|(acre_lot>=0&acre_lot<=1000))]
study[, log_price:=log(price)]
study[, log_house:=log(house_size)]
study[, log_lot:=log1p(acre_lot)]
study[, bed_group:=pmin(bed,6L)]
study[, log_ppsf:=log(ppsf)]
numeric_vars <- study[, .(log_price,log_house,bed,bath,log_lot,log_ppsf)]
cors <- cor(numeric_vars,use="pairwise.complete.obs",method="spearman")
save_table(as.data.table(cors,keep.rownames="feature"),"05_spearman_matrix.csv")
size_test <- cor.test(study$log_house,study$log_price,method="spearman",exact=FALSE)
by_state <- study[state %in% c("Texas","California","Florida"),
  .(n=.N,spearman_size_vs_price=cor(log_house,log_price,method="spearman")),
   by=state]
save_table(by_state,"05_state_size_correlations.csv")
bed_sample <- study[bed %in% 1:6]
ktest <- kruskal.test(log_price~factor(bed), data=bed_sample)
eps_sq <- max(0,(as.numeric(ktest$statistic)-6+1)/(nrow(bed_sample)-6))
complete_fit <- study[is.finite(log_lot)]
fit <- lm(log_price ~ log_house + bed + bath + log_lot + factor(state),
          data=complete_fit)
fit_summ <- summary(fit)
size_ci <- confint(fit,"log_house")
# For exploratory heteroskedasticity diagnostic, NOT a formal robust-SE regression.
resid_s <- residuals(fit); fitted_s <- fitted(fit)
bp_fit <- lm(I(resid_s^2)~fitted_s)
bp_nR2 <- length(resid_s)*summary(bp_fit)$r.squared
bp_p <- pchisq(bp_nR2,df=1,lower.tail=FALSE)
tests <- data.table(
  test=c("Spearman size vs log(price)","Kruskal-Wallis bedrooms 1-6",
         "Kruskal epsilon_squared","Log-linear log_house coefficient",
         "Log-linear log_house CI low","Log-linear log_house CI high",
         "Log-linear model R2","Breusch-Pagan-style nR2 on fitted"),
  statistic=c(unname(size_test$estimate),unname(ktest$statistic),eps_sq,
              unname(coef(fit)["log_house"]),size_ci[1],size_ci[2],
              fit_summ$r.squared,bp_nR2),
  p_value=c(size_test$p.value,ktest$p.value,NA,coef(fit_summ)["log_house","Pr(>|t|)"],
            NA,NA,NA,bp_p),
  n=c(nrow(study),nrow(bed_sample),nrow(bed_sample),
      rep(nrow(complete_fit),5)))
save_table(tests,"05_statistical_tests.csv")
set.seed(5)
sc <- study[sample.int(nrow(study),min(12000L,nrow(study)))]
fig_png("09_size_price_relationship.png", {
  par(mar=c(5,5,4,1))
  plot(sc$log_house,sc$log_price,pch=16,cex=.32,col=adjustcolor("#2b789a",alpha.f=.11),
       xlab="ln(living area in sqft)",ylab="ln(asking price USD)",
       main="Size-price association (random sample)")
  abline(lm(log_price~log_house,data=sc),col="#b64d45",lwd=2)
})
fig_png("10_spearman_correlation.png", {
  par(mar=c(10,10,4,3))
  image(seq_len(ncol(cors)),seq_len(nrow(cors)),t(cors[nrow(cors):1,,drop=FALSE]),
    col=colorRampPalette(c("#b04f45","#f5e6e1","#ffffff","#c4e1e5","#327996"))(101),
    zlim=c(-1,1),axes=FALSE,xlab="",ylab="",main="Spearman rank correlations")
  axis(1,1:ncol(cors),colnames(cors),las=2)
  axis(2,1:nrow(cors),rev(rownames(cors)),las=2)
  box()
})
fig_png("11_bedroom_price_groups.png", {
  par(mar=c(5,5,4,1))
  boxplot(log_price~factor(bed),data=bed_sample,
          col="#7aa4b8",outline=FALSE,xlab="Bedrooms (1 to 6)",
          ylab="ln(asking price USD)",main="Bedroom groups (unadjusted)")
})
fig_png("12_model_residual_diagnostics.png", {
  set.seed(122)
  ii <- sample.int(length(resid_s),min(15000L,length(resid_s)))
  par(mfrow=c(1,2),mar=c(5,5,4,1))
  plot(fitted_s[ii],resid_s[ii],pch=16,cex=.3,
       col=adjustcolor("#327996",alpha.f=.13),
       xlab="Fitted ln(price)",ylab="Residual",main="Residual scale varies")
  abline(h=0,col="#b45243",lwd=2)
  qqnorm(resid_s[ii],pch=16,cex=.30,main="Residual normality check")
  qqline(resid_s[ii],col="#b45243",lwd=2)
})
message("05 study n=",nrow(study),", regression n=",nrow(complete_fit))
print(tests);print(by_state)

# 06 - MODEL-READY TABULAR EXPORTS (STRICTLY IGNORED BY GIT)
message("06/07: screened model data, group-safe splits, train-only imputation")
# Explicit scope: active for-sale listings with known, plausible living area and
# price. Not a claim that all remaining records are verified residential homes.
source_n <- nrow(raw)
screen_n <- raw[, .(
  for_sale=sum(status=="for_sale"),
  valid_positive_ask=sum(status=="for_sale"&is.finite(price)&price>0),
  valid_price_window=sum(status=="for_sale"&is.finite(price)&price>=30000&price<=20000000),
  valid_price_and_size=sum(status=="for_sale"&is.finite(price)&price>=30000&price<=20000000&
    is.finite(house_size)&house_size>=400&house_size<=20000))]
save_table(screen_n,"06_screening_counts.csv")
raw[, source_row := seq_len(.N)]
md <- raw[status=="for_sale" & is.finite(price) & price>=30000 & price<=20000000 &
          is.finite(house_size) & house_size>=400 & house_size<=20000 &
          !is.na(state) & nzchar(trimws(state)),
   .(source_row,street,price,house_size,bed,bath,acre_lot,state,city,zip_code)]
md[, bed_missing := as.integer(!is.finite(bed)|bed<1|bed>12)]
md[, bath_missing := as.integer(!is.finite(bath)|bath<1|bath>12)]
md[, acre_missing := as.integer(!is.finite(acre_lot)|acre_lot<0|acre_lot>1000)]
md[bed_missing==1L,bed:=NA_real_]
md[bath_missing==1L,bath:=NA_real_]
md[acre_missing==1L,acre_lot:=NA_real_]
# street is an anonymized numeric surrogate, not a verified cadastral property ID.
# Conservatively keep ALL repeated street codes in the SAME fold across geographies.
# Rows with absent street are distinct, assigned negative IDs.
md[, group_id:=fifelse(is.finite(street)&street>0,as.numeric(street),-as.numeric(source_row))]
md[, bucket:=(abs(group_id*48271) %% 1000)]
md[, split:=fifelse(bucket<700,"train",fifelse(bucket<850,"validation","test"))]
split_counts <- md[, .(
   n=.N,groups=uniqueN(group_id),median_price=median(price),
   missing_beds_pct=round(mean(bed_missing)*100,2),
   missing_baths_pct=round(mean(bath_missing)*100,2),
   missing_acre_pct=round(mean(acre_missing)*100,2)),by=split][order(split)]
save_table(split_counts,"06_split_counts.csv")
train <- md[split=="train"]
fill <- data.table(field=c("bed","bath","acre_lot"),
  train_median=c(median(train$bed,na.rm=TRUE),
                 median(train$bath,na.rm=TRUE),
                 median(train$acre_lot,na.rm=TRUE)))
save_table(fill,"06_train_only_imputation.csv")
md[, bed_filled:=fifelse(is.na(bed),fill$train_median[1],as.numeric(bed))]
md[, bath_filled:=fifelse(is.na(bath),fill$train_median[2],as.numeric(bath))]
md[, acre_filled:=fifelse(is.na(acre_lot),fill$train_median[3],as.numeric(acre_lot))]
md[, log_price:=log(price)]
md[, log_house_size:=log(house_size)]
md[, log1p_acre:=log1p(acre_filled)]
md[is.na(city)|!nzchar(trimws(city)),city:="Unknown"]
md[is.na(zip_code)|!nzchar(trimws(zip_code)),zip_code:="Unknown"]
# Keep group_id for split AUDITING ONLY. It and source_row must NOT be predictors.
# No price_per_sqft, state/city target aggregates, brokered_by or prev_sold_date.
features <- c("source_row","group_id","split","price","log_price",
 "house_size","log_house_size","bed_filled","bath_filled","log1p_acre",
 "bed_missing","bath_missing","acre_missing","state","city","zip_code")
for (part in c("train","validation","test")) {
 fwrite(md[split==part,..features],
        file.path("data/processed",paste0(part,".csv")))
}
# Proven group-disjoint by deterministic hash bucket; verify observationally.
# A vectorized uniqueness check replaces slow ~million-group R aggregation.
unique_group_splits <- unique(md[, .(group_id,split)])
group_overlap <- sum(duplicated(unique_group_splits$group_id))
stopifnot(nrow(unique_group_splits)>0L,group_overlap==0L)
stopifnot(nrow(md)==sum(split_counts$n))
model_manifest <- data.table(
  metric=c("source_rows","for_sale_rows","model_rows","excluded_from_for_sale",
    "train_rows","validation_rows","test_rows","distinct_groups",
    "groups_present_in_multiple_splits"),
  value=c(source_n,screen_n$for_sale,nrow(md),
    screen_n$for_sale-nrow(md),split_counts[split=="train",n],
    split_counts[split=="validation",n],split_counts[split=="test",n],
    nrow(unique_group_splits),group_overlap))
save_table(model_manifest,"06_model_manifest.csv")
fig_png("13_model_split_balance.png", {
  par(mfrow=c(1,2),mar=c(6,5,4,1))
  barplot(split_counts$n/1000,names.arg=split_counts$split,
          col=c("#367494","#78a689","#d4a56d"),ylab="Listings (thousands)",
          main="Deterministic group-disjoint splits")
  barplot(split_counts$median_price/1000,names.arg=split_counts$split,
          col=c("#367494","#78a689","#d4a56d"),ylab="Median asking price ($000)",
          main="Split median-price balance")
})
message("06 rows retained=",nrow(md)," model overlap=0; imputation uses TRAIN medians only")
print(split_counts);print(fill);print(model_manifest)

# 07 - SELECTION BIAS DIAGNOSTICS AND FINAL MODELING CONTRACT
message("07/07: retention bias, split distribution and reproducibility QA")
miss_status <- raw[, .(n=.N,house_missing_pct=100*mean(is.na(house_size)),
    bed_missing_pct=100*mean(is.na(bed)),
    bath_missing_pct=100*mean(is.na(bath))),by=status]
save_table(miss_status,"07_missingness_by_status.csv")
fig_png("14_missingness_by_status.png", {
  x <- as.matrix(miss_status[,.(house_missing_pct,bed_missing_pct,bath_missing_pct)])
  rownames(x) <- miss_status$status
  par(mar=c(7,5,4,1))
  barplot(t(x),beside=TRUE,names.arg=rownames(x),las=2,
          col=c("#2a738e","#a8c8aa","#c89a65"),
          ylab="Missing (%)",ylim=c(0,100),
          main="Missing physical features differ by listing status")
  legend("topright",legend=c("House size","Bedrooms","Bathrooms"),
         fill=c("#2a738e","#a8c8aa","#c89a65"),cex=.8,bty="n")
})
fig_png("15_model_eligibility_funnel.png", {
  vals <- c(source_n,screen_n$for_sale,nrow(md))
  par(mar=c(6,5,4,1))
  barplot(vals/1e6,names.arg=c("All scraped","For sale","Model screen"),
          col=c("#87a9b9","#caa975","#5d9f8b"),
          ylim=c(0,2.55),ylab="Listings (millions)",
          main="Model eligibility: incomplete coverage")
  text(seq_along(vals)*1.2-0.5,vals/1e6+.04,
       labels=format(vals,big.mark=","),cex=.8)
})
fig_png("16_split_logprice_density.png", {
  set.seed(160)
  par(mar=c(5,5,4,1))
  d <- lapply(c("train","validation","test"),function(p) {
    x <- md[split==p,log_price]
    density(sample(x,min(length(x),20000L)))
  })
  plot(d[[1]],col="#276c93",lwd=2,
       xlab="ln(asking price)",main="Split price-distribution balance")
  lines(d[[2]],col="#79a890",lwd=2)
  lines(d[[3]],col="#c58b57",lwd=2)
  legend("topright",legend=c("Train","Validation","Test"),
         col=c("#276c93","#79a890","#c58b57"),lwd=2,bty="n")
})
# State counts are descriptors, never target-encoded via all-row means.
state_split <- md[, .N,by=.(split,state)]
state_split[, share:=N/sum(N),by=split]
save_table(state_split,"07_state_split_coverage.csv")
test_audit <- data.table(
  metric=c("png_count","script_steps","missing_targets_model",
    "invalid_transforms","unique_property_groups","train_only_medians"),
  value=c(length(list.files("EDA/figures",pattern="\\.png$")),
          7L,sum(!is.finite(md$log_price)),
          sum(!is.finite(md$log_house_size)|!is.finite(md$log1p_acre)),
          nrow(unique_group_splits),all(is.finite(fill$train_median))))
save_table(test_audit,"07_final_qa.csv")
stopifnot(all(is.finite(md$log_price)), all(is.finite(md$log_house_size)),
          all(is.finite(md$log1p_acre)),group_overlap==0L,
          length(list.files("EDA/figures",pattern="\\.png$"))>=16L)
message("07 complete: ",nrow(md)," rows, ",length(list.files("EDA/figures",pattern="\\.png$")),
        " figures; zero split leakage; outputs not intended for Git.")
print(miss_status);print(test_audit)
