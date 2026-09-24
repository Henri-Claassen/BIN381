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
# The regression models include the education x internet interaction explicitly,
# because testing that term is the Milestone 1 analytics goal. The tree-based
# models get the same predictors without an interaction term: a tree finds
# interactions itself by splitting on one variable inside a split on another.

controls_formula <- function(predictors) {
  paste(setdiff(predictors, c("matric_plus", "any_home_internet")), collapse = " + ")
}

employment_regression_formula <- as.formula(paste(
  "employed ~ matric_plus * any_home_internet +",
  controls_formula(employment_predictors)
))

employment_tree_formula <- as.formula(paste(
  "employed ~", paste(employment_predictors, collapse = " + ")
))

income_regression_formula <- as.formula(paste(
  "log_salary ~ matric_plus * any_home_internet +",
  controls_formula(income_predictors)
))

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
