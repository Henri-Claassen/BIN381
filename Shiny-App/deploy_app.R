# ---- Run this if you need the packages ----------------------------------------
# Only needed if the package is not installed yet:
# install.packages("rsconnect")


# Publishes the Shiny app to shinyapps.io.
#
# How to run: open BIN381.Rproj in RStudio (so the working directory is the
# project folder) and run   source("Shiny-App/deploy_app.R")
#
# One-time setup before the first deploy: create a free account at
# https://www.shinyapps.io, open Account > Tokens, click Show, and paste the
# setAccountInfo() line it shows into the R console (not into this file, so the
# secret never ends up in the repository).
#
# shinyapps.io only uploads the app's own folder, but app.R also needs
# Scripts/R/model_preparation.R. This script therefore copies the app files and
# model_preparation.R into a temporary folder and uploads that folder. Nothing in
# the project is moved or changed. Only aggregated data is uploaded:
# app_data.rds holds no survey records (see Scripts/3.4) Deployment Preparation.qmd).

library(rsconnect)

app_files <- c(
  "Shiny-App/app.R",
  "Shiny-App/app_data.rds",
  "Shiny-App/deployment_model.R",
  "Shiny-App/monitoring.R",
  "Shiny-App/validate_input.R",
  "Shiny-App/dummy_employment_test_data.csv",
  "Scripts/R/model_preparation.R"
)

missing_files <- app_files[!file.exists(app_files)]
if (length(missing_files) > 0) {
  stop("Run this from the project folder (open BIN381.Rproj). Missing: ",
       paste(missing_files, collapse = ", "))
}

bundle <- file.path(tempdir(), "bin381-app")
unlink(bundle, recursive = TRUE)
dir.create(bundle)
file.copy(app_files, bundle)

deployApp(appDir = bundle, appName = "bin381-digital-access", forceUpdate = TRUE)
