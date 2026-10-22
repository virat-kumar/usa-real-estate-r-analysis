# USA Real Estate Market Analysis in R

An R-based project investigating U.S. residential property **asking prices** and location-adjusted price comparisons.

**Business question:** Which U.S. markets contain relatively competitively priced homes after accounting for house size, bedrooms, bathrooms, lot size and location?

## One-command setup for Windows and Linux

**Prerequisites:** Install [R 4.2+](https://cran.r-project.org/) (\`Rscript\` on PATH), [Python 3.9+](https://www.python.org/downloads/) with pip and venv, and [Git](https://git-scm.com/downloads). Linux distributions may require \`python3-venv\`. On Windows, enable the Python launcher or add Python to PATH.

Open PowerShell / Windows Terminal or a Linux terminal:

\`\`\`sh
git clone https://github.com/virat-kumar/usa-real-estate-r-analysis.git
cd usa-real-estate-r-analysis
Rscript setup.R
Rscript scripts/analysis.R
\`\`\`

**The identical \`Rscript setup.R\` command works on both operating systems.** It (1) restores project-local R dependencies from \`renv.lock\`, (2) creates an ignored \`.venv\` to install the official KaggleHub downloader, (3) downloads the pinned **original Kaggle version 25** into \`data/raw\`, and (4) verifies its SHA-256 checksum and expected columns. Python is used **only for downloading the data**; all modeling and EDA uses R.

| Command | Purpose |
|---|---|
| \`Rscript setup.R\` | Complete environment + data setup |
| \`Rscript setup.R --data-only\` | Official Kaggle download and checksum verification only |
| \`Rscript setup.R --skip-data\` | Restore the R environment without downloading data |
| \`Rscript tests/smoke.R\` | Run R synthetic smoke tests |
| \`Rscript scripts/analysis.R\` | Run EDA, state summaries and exploratory regression |

## Official Kaggle data

Source: [USA Real Estate Dataset by Ahmed Shahriar Sakib](https://www.kaggle.com/datasets/ahmedshahriarsakib/usa-real-estate-dataset), version **25**, updated March 30, 2024.

- Download through official **KaggleHub**, not a third-party mirror. Kaggle may ask for account authorization; see [API authentication](https://www.kaggle.com/docs/api#authentication). Never commit credentials.
- Dataset: **2,226,382 listings**, 12 columns; file name \`realtor-data.zip.csv\` (plain CSV after KaggleHub extraction).
- Required path: \`data/raw/realtor-data.zip.csv\`.
- Official version-25 SHA-256: \`2678a7d0a1054861464d0dbdf938c133ffd3e5c5f22c8065255bab87e9af0de4\`.
- Manual option: download ZIP from the Kaggle page, extract and put the exact CSV in \`data/raw/\`; running setup verifies that file instead of downloading it again.
- The data and credentials are deliberately **not included in GitHub**.

## Files

\`\`\`text
setup.R                       Cross-platform R setup command
renv.lock                     Pinned R package environment
R/functions.R                 R data cleaning, summaries, regression
scripts/analysis.R            R analysis entrypoint
scripts/download_data.py      KaggleHub data retrieval only
tests/smoke.R                 Synthetic R tests
docs/research-proposal.md     Business case and research assignment
data/raw/realtor-data.zip.csv Downloaded locally only, Git-ignored
outputs/                      Generated R results, Git-ignored
\`\`\`

## Analytic scope and caveats

The dependent variable is \`price\` (**listing/asking** price) and model \`log(price)\`. Predictors include \`house_size\`, \`bed\`, \`bath\`, \`acre_lot\` and state location effects; our exploratory R OLS samples up to 80,000 complete listings with a fixed seed. The outcome files are \`outputs/state_summary.csv\`, \`outputs/data_quality.csv\`, and \`outputs/model_summary.txt\`.

The exact **listing collection period is undocumented**. \`prev_sold_date\` represents the **previous sale date**, not the listing timestamp. Historical dates include missing and anomalous values. Model relationships are associations, not causal effects. This dataset cannot establish investment ROI without rent, finance and upkeep data.

## Collaborating

Run \`Rscript setup.R --skip-data\` and \`Rscript tests/smoke.R\` before a pull request. GitHub Actions tests setup and R helpers on Windows and Ubuntu. Raw Kaggle data, outputs and local environments must not be committed. Kaggle labels the dataset license "Other (specified in description)"; follow its terms.



## Comprehensive incremental EDA (16 charts)

This repo now includes a [full R EDA report with 16 inline figures](EDA/README.md), a [micro-step execution plan](EDA/EDA_PLAN.md), and a [modeling handoff](modeling/README.md). The EDA explores data quality, missingness, outliers, geography, log transformations, correlations, statistical tests and creates local leakage-audited train/validation/test tables.

Run after setup:

~~~sh
Rscript EDA/eda.R
Rscript tests/eda/test_outputs.R
~~~

**Only R source, README reports, and small charts are on GitHub**; Kaggle CSV, local model datasets and diagnostic tabular exports remain ignored.

