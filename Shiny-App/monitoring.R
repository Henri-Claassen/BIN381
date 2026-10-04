# ---- Run this if you need the packages ----------------------------------------
# Only needed if the packages are not installed yet: remove the # in front of
# install.packages() and run this line once.
# install.packages(c("tidyverse", "pROC"))

# Milestone 3: accuracy measures and monitoring for the deployed employment model
#
# Used by Scripts/3.4) Deployment Preparation.qmd (which calculates the test-set
# baseline every later check is compared with) and by the Shiny app (which runs
# the checks on uploaded data and explains each measure to the user).
#
# The measures are calculated exactly as in Scripts/3.3) Model Evaluation.qmd, so
# the baseline here matches the evaluation's test-set results.

library(tidyverse)
library(pROC)

# 1. Monitoring thresholds ---------------------------------------------------------
# Every threshold is defined here, once. Green = no action, Amber = investigate,
# Red = retrain or consider retiring the model. The test-set baseline of the
# logistic regression is AUC 0.765, Brier score 0.183 and balanced accuracy 0.693.

monitoring_thresholds <- list(
  auc = c(amber = 0.715, red = 0.70),          # amber: more than 0.05 below the test AUC; red: below the Milestone 2 minimum of 0.70
  brier = c(amber = 0.20, red = 0.22),         # test value 0.183; above 0.20 the probabilities are clearly less accurate
  calibration_gap = c(amber = 0.03, red = 0.05), # predicted minus actual employment rate, in either direction
  balanced_accuracy = c(amber = 0.65, red = 0.60), # test value 0.693
  psi = c(amber = 0.10, red = 0.25),           # the standard rule of thumb for the population stability index
  subgroup_auc_gap = c(amber = 0.05, red = 0.10), # widening of the AUC gap between population groups, compared with the test set
  min_rows = 200,                              # fewer usable rows than this: measures are imprecise
  min_group_rows = 100                         # groups smaller than this are left out of the subgroup check
)

# 2. Shared grouping --------------------------------------------------------------
# Age bands used for the app's filters and for the drift check. age_centred is age - 40.
age_band_levels <- c("15-24", "25-34", "35-44", "45-54", "55-64")
make_age_band <- function(age_centred) {
  cut(age_centred + 40, breaks = c(14, 24, 34, 44, 54, 64), labels = age_band_levels)
}

# 3. Accuracy measures -----------------------------------------------------------
# A prediction becomes "Employed" when the model's probability is at least the
# threshold (0.639 for the logistic regression, chosen in the evaluation to give
# the employed and unemployed equal importance). The app only ever reports these
# measures for a whole file or group, never a prediction for one person.
#
# AUC (area under the ROC curve): take one employed and one unemployed person at
# random. The AUC is the probability that the model gives the employed person the
# higher predicted probability. 0.5 means the model ranks people no better than a
# coin toss, 1 means it always ranks them correctly. It does not depend on the
# threshold or on how many people are employed, which is why it is the main
# measure for comparing models and for monitoring.

compute_metrics <- function(truth, probability, threshold) {
  actual_employed <- truth == "Employed"
  predicted_employed <- probability >= threshold
  tp <- sum(predicted_employed & actual_employed)   # employed, predicted employed
  tn <- sum(!predicted_employed & !actual_employed) # unemployed, predicted unemployed
  fp <- sum(predicted_employed & !actual_employed)  # unemployed, predicted employed
  fn <- sum(!predicted_employed & actual_employed)  # employed, predicted unemployed
  sensitivity <- tp / (tp + fn)
  specificity <- tn / (tn + fp)
  precision <- tp / (tp + fp)
  list(
    people = length(truth), employed = sum(actual_employed), unemployed = sum(!actual_employed),
    tp = tp, tn = tn, fp = fp, fn = fn, threshold = threshold,
    accuracy = (tp + tn) / length(truth),
    balanced_accuracy = (sensitivity + specificity) / 2,
    sensitivity = sensitivity,
    specificity = specificity,
    precision = precision,
    f1 = 2 * precision * sensitivity / (precision + sensitivity),
    auc = as.numeric(auc(roc(truth, probability, levels = c("Unemployed", "Employed"),
                             direction = "<", quiet = TRUE))),
    brier = mean((probability - actual_employed)^2),
    mean_predicted = mean(probability),
    actual_rate = mean(actual_employed),
    calibration_gap = mean(probability) - mean(actual_employed)
  )
}

# Green / Amber / Red for one measure. higher_is_better decides the direction.
traffic_light <- function(value, limits, higher_is_better = TRUE) {
  if (is.na(value)) return("Not checked")
  if (higher_is_better) {
    if (value >= limits[["amber"]]) "Green" else if (value >= limits[["red"]]) "Amber" else "Red"
  } else {
    if (value <= limits[["amber"]]) "Green" else if (value <= limits[["red"]]) "Amber" else "Red"
  }
}

# The table the app shows after a prediction: every measure with its value, the
# test-set value, its monitoring status and a plain-language explanation that
# uses the file's own numbers, plus the value restated in everyday units.
# `metrics` and `baseline` come from compute_metrics().
describe_metrics <- function(metrics, baseline) {
  pct <- function(x) paste0(format(round(100 * x, 1), nsmall = 1), "%")
  num <- function(x) format(x, big.mark = ",")
  t <- monitoring_thresholds
  no_skill_brier <- round(metrics$actual_rate * (1 - metrics$actual_rate), 3)
  # measure:  a plain name, with the technical term in brackets
  # in_short: the result in everyday words
  # meaning:  the question the measure answers, in plain words (shown in HTML
  #           tables, so <br> starts a new line)
  tribble(
    ~measure, ~value, ~test_set, ~status, ~in_short, ~meaning,
    "Ranking score (AUC)", round(metrics$auc, 3), round(baseline$auc, 3),
      traffic_light(metrics$auc, t$auc),
      paste0("Right ", round(100 * metrics$auc), " times out of 100"),
      paste0("Take one person who has a job and one who does not, and ask the model which of the two is more likely to be employed. ",
             "This is how many times out of 100 it picks the right person.<br>",
             "Guessing would be right 50 times out of 100, and 70 or more counts as acceptable."),
    "Balanced accuracy", round(metrics$balanced_accuracy, 3), round(baseline$balanced_accuracy, 3),
      traffic_light(metrics$balanced_accuracy, t$balanced_accuracy),
      pct(metrics$balanced_accuracy),
      "When the model labels people \"employed\" or \"unemployed\", how often is it right, with both groups counting equally? Guessing gets 50%.",
    "Employed people spotted (sensitivity)", round(metrics$sensitivity, 3), round(baseline$sensitivity, 3), "-",
      paste0(pct(metrics$sensitivity), " of the ", num(metrics$employed), " employed"),
      "Of the people who really have a job, how many does the model label as employed?",
    "Unemployed people spotted (specificity)", round(metrics$specificity, 3), round(baseline$specificity, 3), "-",
      paste0(pct(metrics$specificity), " of the ", num(metrics$unemployed), " unemployed"),
      "Of the people who really have no job, how many does the model label as unemployed?",
    "Correct \"employed\" labels (precision)", round(metrics$precision, 3), round(baseline$precision, 3), "-",
      paste0(pct(metrics$precision), " correct"),
      "When the model says someone is employed, how often is that true?",
    "F1 score", round(metrics$f1, 3), round(baseline$f1, 3), "-",
      paste0(round(metrics$f1, 2), " out of 1"),
      "One score for the two rows above. It is only high when the model both finds most employed people and is usually right when it says \"employed\".",
    "Overall accuracy", round(metrics$accuracy, 3), round(baseline$accuracy, 3), "-",
      paste0(pct(metrics$accuracy), " labelled correctly"),
      paste0("How many people get the right label overall? Careful: simply saying \"employed\" for everyone would already score ", pct(metrics$actual_rate), "."),
    "Prediction error (Brier score)", round(metrics$brier, 3), round(baseline$brier, 3),
      traffic_light(metrics$brier, t$brier, higher_is_better = FALSE),
      paste0(round(metrics$brier, 3), " (lower is better)"),
      paste0("How close are the model's predicted chances to what really happened? Lower is better. Without a model, just using the average, the score would be ", no_skill_brier, "."),
    "Predicted vs actual employment (calibration)", round(metrics$calibration_gap, 3), round(baseline$calibration_gap, 3),
      traffic_light(abs(metrics$calibration_gap), t$calibration_gap, higher_is_better = FALSE),
      paste0("Predicted ", pct(metrics$mean_predicted), ", actual ", pct(metrics$actual_rate)),
      "Does the share of people the model expects to have a job match the real share? The closer the two numbers, the better."
  )
}

# The confusion matrix: counts of people by actual and predicted outcome
confusion_table <- function(metrics) {
  tibble(
    actual = c("Employed", "Unemployed"),
    `Predicted employed` = c(metrics$tp, metrics$fp),
    `Predicted unemployed` = c(metrics$fn, metrics$tn)
  )
}

# 4. Drift: has the mix of people changed? -------------------------------------------
# The population stability index (PSI) compares the share of people in each
# category of new data with the training data:
#   PSI = sum over categories of (new share - training share) x ln(new share / training share)
# 0 means the same mix. Below 0.10 the change is small, 0.10-0.25 is a moderate
# shift worth investigating, and above 0.25 the population has changed enough that
# the model may no longer describe it well.

drift_variables <- c("province", "settlement_type", "population_group", "age_band",
                     "matric_plus", "any_home_internet", "smartphone_access")

# Category shares of one variable, as a named vector
category_shares <- function(values, categories = NULL) {
  values <- as.character(values)
  if (is.null(categories)) categories <- sort(unique(values))
  counts <- table(factor(values, levels = categories))
  as.numeric(counts) |> setNames(categories) |> (\(x) x / sum(x))()
}

# The drift variables of prepared data, with age turned into age bands
drift_frame <- function(prepared) {
  prepared |>
    mutate(age_band = make_age_band(age_centred)) |>
    select(all_of(drift_variables))
}

psi <- function(reference_shares, new_values) {
  new_shares <- category_shares(new_values, names(reference_shares))
  # A category with no people would make ln(0); a tiny floor keeps the index finite
  reference <- pmax(reference_shares, 0.0001)
  new <- pmax(new_shares, 0.0001)
  sum((new - reference) * log(new / reference))
}

drift_report <- function(prepared, reference) {
  new_data <- drift_frame(prepared)
  tibble(variable = drift_variables) |>
    mutate(
      psi = map_dbl(variable, \(v) psi(reference[[v]], new_data[[v]])),
      status = map_chr(psi, \(x) traffic_light(x, monitoring_thresholds$psi, higher_is_better = FALSE)),
      meaning = case_when(
        status == "Green" ~ "About the same mix as the data the model learned from.",
        status == "Amber" ~ "The mix has shifted somewhat. Check whether the data come from a different group of people.",
        TRUE ~ "The mix has changed a lot. The model may not fit these people well."
      )
    )
}

# 5. Fairness: does the model rank people equally well in every population group? --
# AUC per population group; the gap is the best group's AUC minus the worst's.
# Groups with fewer than min_group_rows people, or without both employed and
# unemployed people, are left out because their AUC would be too imprecise.
subgroup_auc <- function(truth, probability, group) {
  person_group <- as.character(group)
  eligible <- unique(person_group)[sapply(unique(person_group), \(g) {
    sum(person_group == g) >= monitoring_thresholds$min_group_rows && n_distinct(truth[person_group == g]) == 2
  })]
  # Calculated before tibble(): inside tibble() a column called "group" would
  # hide the per-person groups and select the wrong people
  people <- map_int(eligible, \(g) sum(person_group == g))
  group_auc <- map_dbl(eligible, \(g) as.numeric(auc(roc(truth[person_group == g], probability[person_group == g],
                                                         levels = c("Unemployed", "Employed"),
                                                         direction = "<", quiet = TRUE))))
  tibble(group = eligible, people = people, auc = group_auc)
}

subgroup_gap_status <- function(gap, baseline_gap) {
  if (is.na(gap)) return("Not checked")
  traffic_light(gap - baseline_gap, monitoring_thresholds$subgroup_auc_gap, higher_is_better = FALSE)
}

# 6. Overall verdict ---------------------------------------------------------------
overall_verdict <- function(statuses) {
  if (any(statuses == "Red")) {
    "Action needed. Retrain the model on recent data, or stop using it if retraining does not help."
  } else if (any(statuses == "Amber")) {
    "Investigate. At least one check is borderline: find out what changed before relying on the results."
  } else {
    "No action needed. Every check passed, so the model can keep being used."
  }
}
