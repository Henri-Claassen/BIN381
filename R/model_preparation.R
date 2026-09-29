# Milestone 3: shared model preparation
#
# Used by Scripts/Employment Model.qmd and Scripts/Income Model.qmd, and meant to
# be reused by the evaluation notebook and the Shiny app. Every training file, test
# file and new record then goes through exactly the same preparation, so the
# models never see data that was prepared differently from the data they were
# trained on.
#
# Nothing in this file learns from the data: the category levels, reference
# levels and row filters are all fixed rules. It is therefore safe to apply the
# same functions to the training and the test files without leakage.

library(tidyverse)

# 1. Fixed category levels ------------------------------------------------------
# The first level of each vector is the reference level from the Milestone 2
# data dictionary (section 2, item 5). The levels are written out in full, rather
# than taken from the data, so the training file, the test file and any new data
# always get identical factors, even when a level is missing from a small file.

category_levels <- list(
  employed = c("Unemployed", "Employed"),
  population_group = c("Black African", "Coloured", "Indian/Asian", "White"),
  province = c(
    "Gauteng", "Western Cape", "Eastern Cape", "Northern Cape", "Free State",
    "KwaZulu-Natal", "North West", "Mpumalanga", "Limpopo"
  ),
  settlement_type = c("Metro urban", "Non-metro urban", "Traditional", "Farms"),
  smartphone_access = c("None", "Fewer than 1 per member", "1 or more per member"),
  other_member_matric = c("No", "Yes", "No other working-age member")
)

# Applies the fixed levels above to every column in `data` that has an entry in
# `category_levels`. Values outside the list become NA, which the validation
# checks in the notebooks (and later the app) will catch.
apply_category_levels <- function(data) {
  for (column in intersect(names(category_levels), names(data))) {
    data[[column]] <- factor(data[[column]], levels = category_levels[[column]])
  }
  data
}

# 2. Predictor sets -------------------------------------------------------------
# The reasons for including or leaving out each column are given in section 2 of
# each modelling notebook and in "Model Choices.docx".

employment_predictors <- c(
  # Research question: education and digital access
  "matric_plus", "any_home_internet", "has_computer", "smartphone_access",
  # Demographic controls
  "age_centred", "age_centred_squared", "female", "population_group",
  # Geographic controls
  "province", "settlement_type",
  # Household controls
  "household_size", "n_children_under15", "elderly_in_household",
  "female_x_children", "other_member_matric"
)

income_predictors <- c(
  # Research question: education and digital access
  "matric_plus", "any_home_internet",
  # Demographic and geographic controls
  "age_centred", "age_centred_squared", "female", "population_group",
  "province", "settlement_type"
)

# 3. Model formulas -------------------------------------------------------------
# A formula tells a model what to predict and from what: the outcome goes left of
# the ~ and the predictors go right of it, e.g. employed ~ matric_plus + female.
#
# matric_plus and any_home_internet are both 0/1, so together they split people
# into four groups. The employment rates of these groups in model_train.csv are:
#
#                      No internet   Internet
#     Below matric        57.6%        59.7%      internet adds  +2.1 points
#     Matric              58.1%        69.9%      internet adds +11.8 points
#
# + gives each predictor ONE effect that is the same for everyone.
#   "matric_plus + any_home_internet" describes the four groups with three
#   numbers: a starting point (below matric, no internet), a matric step (moving
#   down a row, the same in both columns) and an internet step (moving right a
#   column, the same in both rows). Fitted to the rates above, that gives:
#
#                      No internet          Internet
#     Below matric     55.0                 55.0 + 5.4       = 60.4
#     Matric           55.0 + 8.9 = 63.9    55.0 + 8.9 + 5.4 = 69.4
#
#   The internet step has to be +5.4 in both rows, a compromise between the real
#   +2.1 and +11.8, so + cannot show that internet access goes with a bigger
#   advantage for people with matric.
#
# * adds both predictors AND their interaction. R expands
#   "matric_plus * any_home_internet" to
#   "matric_plus + any_home_internet + matric_plus:any_home_internet".
#   The extra term matric_plus:any_home_internet is a fourth number that applies
#   only to the group with BOTH matric and internet access, so every group gets
#   its own value:
#
#                      No internet          Internet
#     Below matric     57.6                 57.6 + 2.1             = 59.7
#     Matric           57.6 + 0.5 = 58.1    57.6 + 0.5 + 2.1 + 9.7 = 69.9
#
#   The fourth number (+9.7) is how much better the "both" group does than the
#   matric step and the internet step added together. Above zero (an odds ratio
#   above 1 in the logistic regression) means education and internet access
#   reinforce each other (complements); below zero (an odds ratio below 1) means
#   one makes up for the other (substitutes).
#
# These tables use raw percentages without the other predictors, to show the
# idea. The logistic regression works the same way on the log-odds scale with all
# the controls included, where the interaction is an odds ratio of 1.29.
#
# The regressions use * for education x internet, because testing that
# interaction is the Milestone 1 analytics goal, and + for every control. The
# tree and forest use + only: a tree finds interactions itself by splitting on
# one variable inside a split on another.
#
# The formulas are built from the predictor lists in section 2 with paste(), so
# the predictors are written down only once. as.formula() turns the text into a
# formula. Print a formula (e.g. employment_regression_formula) to see it in full.

# Joins every predictor except the two interaction variables with " + "
controls_formula <- function(predictors) {
  paste(setdiff(predictors, c("matric_plus", "any_home_internet")), collapse = " + ")
}

# employed ~ matric_plus * any_home_internet + has_computer + ... + other_member_matric
# Used by the logistic regression
employment_regression_formula <- as.formula(paste(
  "employed ~ matric_plus * any_home_internet +",
  controls_formula(employment_predictors)
))

# employed ~ matric_plus + any_home_internet + has_computer + ... + other_member_matric
# Used by the decision tree and the employment random forest
employment_tree_formula <- as.formula(paste(
  "employed ~", paste(employment_predictors, collapse = " + ")
))

# log_salary ~ matric_plus * any_home_internet + age_centred + ... + settlement_type
# Used by the linear regression
income_regression_formula <- as.formula(paste(
  "log_salary ~ matric_plus * any_home_internet +",
  controls_formula(income_predictors)
))

# log_salary ~ matric_plus + any_home_internet + age_centred + ... + settlement_type
# Used by the income random forest
income_tree_formula <- as.formula(paste(
  "log_salary ~", paste(income_predictors, collapse = " + ")
))

# 4. Preparation functions ------------------------------------------------------

# Reads model_train.csv, model_test.csv (or any file with the same columns) and
# returns the rows and columns the employment models use.
prepare_employment_data <- function(path) {
  read_csv(
    path,
    col_types = cols(household_id = col_character()), # 18 digits: read as text
    show_col_types = FALSE
  ) |>
    apply_category_levels() |>
    # People with Other/unknown education have no matric_plus value. They are
    # left out (1.7% of model_data) so that every model is fitted and compared on
    # exactly the same people, without imputing an education level.
    filter(!is.na(matric_plus)) |>
    # household_id and person_weight are design columns, not predictors
    select(household_id, person_weight, employed, all_of(employment_predictors))
}

# Reads income_train.csv, income_test.csv (or any file with the same columns)
# and returns the rows and columns the income models use.
prepare_income_data <- function(path) {
  read_csv(
    path,
    col_types = cols(household_id = col_character()),
    show_col_types = FALSE
  ) |>
    apply_category_levels() |>
    # Unknown education (matric_plus blank) or unknown household internet
    # (any_home_internet blank). These rows are left out for the same reason as in
    # the employment data (about 2% of income_data).
    filter(!is.na(matric_plus), !is.na(any_home_internet)) |>
    select(household_id, person_weight, log_salary, all_of(income_predictors))
}
