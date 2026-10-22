#!/usr/bin/env Rscript
# Universal entrypoint on Windows and Linux: Rscript setup.R
# Options: --data-only (Kaggle download), --skip-data (restore only R packages).
options(repos = c(CRAN = "https://cloud.r-project.org"))
args <- commandArgs(trailingOnly = TRUE)
if (length(setdiff(args, c("--data-only", "--skip-data"))) > 0L ||
    all(c("--data-only", "--skip-data") %in% args)) {
  stop("Usage: Rscript setup.R [--data-only | --skip-data]", call. = FALSE)
}
if (getRversion() < "4.2") stop("R 4.2 or newer is required.")
root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(root, "scripts", "download_data.py"))) {
  stop("Run this command from the cloned repository root.")
}
run_checked <- function(command, arguments, label) {
  code <- suppressWarnings(system2(command, args = arguments, stdout = "", stderr = ""))
  if (!identical(as.integer(code), 0L)) {
    stop(label, " failed (code ", code, ")", call. = FALSE)
  }
}
if (!("--data-only" %in% args)) {
  cat("[1/2] Restoring R packages using renv.lock...\n")
  if (!requireNamespace("renv", quietly = TRUE)) {
    install.packages("renv", quiet = TRUE)
  }
  if (!file.exists(file.path(root, "renv.lock"))) stop("renv.lock is missing.")
  renv::restore(project = root, prompt = FALSE)
  cat("R environment ready.\n")
}
if (!("--skip-data" %in% args)) {
  cat("[2/2] Downloading or verifying Kaggle dataset...\n")
  candidates <- if (.Platform$OS.type == "windows") {
    list(list(cmd = "py", prefix = "-3"),
         list(cmd = "python", prefix = character()))
  } else {
    list(list(cmd = "python3", prefix = character()),
         list(cmd = "python", prefix = character()))
  }
  py <- NULL
  for (candidate in candidates) {
    executable <- Sys.which(candidate$cmd)
    if (!nzchar(executable)) next
    out <- suppressWarnings(system2(executable,
       c(candidate$prefix, "--version"), stdout = TRUE, stderr = TRUE))
    status <- attr(out, "status")
    if (is.null(status) || identical(as.integer(status), 0L)) {
      py <- list(exe = unname(executable), prefix = candidate$prefix)
      break
    }
  }
  if (is.null(py)) stop("Python 3.9+ with pip/venv is required.")
  venv <- file.path(root, ".venv")
  local_python <- if (.Platform$OS.type == "windows") {
    file.path(venv, "Scripts", "python.exe")
  } else {
    file.path(venv, "bin", "python")
  }
  if (!file.exists(local_python)) {
    cat("Creating isolated local Python venv for downloader...\n")
    run_checked(py$exe, c(py$prefix, "-m", "venv", shQuote(venv)),
                "Creating venv")
  }
  run_checked(local_python,
    c("-m", "pip", "install", "--disable-pip-version-check", "--quiet",
      shQuote("kagglehub>=0.3,<1")),
    "Installing KaggleHub")
  run_checked(local_python,
    shQuote(file.path(root, "scripts", "download_data.py")),
    "Downloading/verifying Kaggle dataset")
}
cat("Setup complete. Run: Rscript scripts/analysis.R\n")

