# Milestone 3: validation of new data for the deployed employment model
#
# Used by the Shiny app (App/app.R) before any prediction is made, and documented
# in Scripts/4) Deployment Preparation.qmd. The checks can also be run outside the
# app, for example on a new Stats SA survey wave:
#   raw <- read_csv("new_file.csv", col_types = cols(.default = col_character()))
#   result <- validate_input(raw)
#
# The file must be read with every column as text, so that values of the wrong
# type (for example "yes" in a 0/1 column) are reported instead of silently
# becoming missing when R guesses the column types.
#
# Relies on R/model_preparation.R (category_levels) and R/monitoring.R
# (monitoring_thresholds$min_rows), which must be sourced first.

library(tidyverse)

# 1. The expected data format ----------------------------------------------------
# One row per column. The Shiny app shows this table as its "Data format" guide,
# so the guide and the checks can never disagree.
#   type: "0/1", "whole number", "number", "category" or "text"
#   min, max: the valid range for numbers (NA where not applicable)

input_columns <- tribble(
  ~column, ~required, ~type, ~min, ~max, ~description, ~example,
  "matric_plus", TRUE, "0/1", 0, 1,
    "1 = completed matric (Grade 12) or higher, 0 = below matric. Leave blank if the education level is unknown: those rows are left out, as in training.", "1",
  "any_home_internet", TRUE, "0/1", 0, 1,
    "1 = the household has fixed or mobile internet at home, 0 = neither.", "1",
  "has_computer", TRUE, "0/1", 0, 1,
    "1 = the household owns a computer, 0 = no.", "0",
  "smartphone_access", TRUE, "category", NA, NA,
    "Smartphones in the household compared with the number of members.", "Fewer than 1 per member",
  "age_centred", TRUE, "whole number", -25, 24,
    "Age minus 40, for ages 15-64 (for example, age 30 gives -10).", "-10",
  "age_centred_squared", TRUE, "whole number", 0, 625,
    "age_centred multiplied by itself (for example, -10 gives 100).", "100",
  "female", TRUE, "0/1", 0, 1,
    "1 = female, 0 = male.", "1",
  "population_group", TRUE, "category", NA, NA,
    "Stats SA population group. Used by the model as a control, not as a filter.", "Black African",
  "province", TRUE, "category", NA, NA,
    "Province of the household.", "Gauteng",
  "settlement_type", TRUE, "category", NA, NA,
    "Where the household is: metro urban, non-metro urban, traditional area or farm.", "Metro urban",
  "household_size", TRUE, "whole number", 1, 25,
    "Number of household members of any age.", "4",
  "n_children_under15", TRUE, "whole number", 0, 24,
    "Number of household members younger than 15. Must be smaller than household_size.", "2",
  "elderly_in_household", TRUE, "0/1", 0, 1,
    "1 = at least one household member is 65 or older, 0 = none.", "0",
  "female_x_children", TRUE, "whole number", 0, 24,
    "female multiplied by n_children_under15 (the number of children for women, 0 for men).", "2",
  "other_member_matric", TRUE, "category", NA, NA,
    "Whether another working-age household member (15-64) has matric or higher.", "Yes",
  "employed", FALSE, "category", NA, NA,
    "Optional. The actual outcome. Only needed to measure how accurate the predictions are.", "Employed",
  "person_weight", FALSE, "number", 0, Inf,
    "Optional. Stats SA survey weight. Makes the group results describe the population; without it, every person counts equally.", "950.5",
  "household_id", FALSE, "text", NA, NA,
    "Optional. Household identifier. Not used by the model.", "H001"
)

# The allowed values of each category column come from R/model_preparation.R,
# the same list the models were trained with
allowed_values <- function(column) {
  category_levels[[column]]
}

# 2. The checks ------------------------------------------------------------------
# validate_input() returns a list with:
#   fatal:  TRUE if the file cannot be used at all (a required column is missing,
#           or no row passes the checks)
#   checks: a table of every check with its status (Pass / Info / Warning / Fail),
#           the number of rows affected and an explanation
#   data:   the file with numbers converted from text to numbers
#   valid:  TRUE/FALSE per row: whether the row passed every check and can be used

validate_input <- function(raw) {
  checks <- tibble(check = character(), status = character(), rows = integer(), detail = character())
  add_check <- function(check, status, rows, detail) {
    checks <<- add_row(checks, check = check, status = status, rows = as.integer(rows), detail = detail)
  }

  # 2.1 Columns ------------------------------------------------------------------
  required <- input_columns$column[input_columns$required]
  missing_required <- setdiff(required, names(raw))
  if (length(missing_required) > 0) {
    add_check("Required columns present", "Fail", nrow(raw),
              paste("Missing:", paste(missing_required, collapse = ", "),
                    "- the file cannot be used. See the data format table."))
    return(list(fatal = TRUE, checks = checks, data = raw, valid = rep(FALSE, nrow(raw))))
  }
  add_check("Required columns present", "Pass", 0, "All 15 predictor columns are in the file.")

  optional_present <- intersect(input_columns$column[!input_columns$required], names(raw))
  add_check("Optional columns", "Info", 0,
            if (length(optional_present) == 0) "None found: accuracy cannot be measured and every person counts equally."
            else paste("Found:", paste(optional_present, collapse = ", ")))

  extra <- setdiff(names(raw), input_columns$column)
  if (length(extra) > 0) {
    add_check("Other columns", "Info", 0,
              paste(length(extra), "column(s) not used by the model are ignored:",
                    paste(head(extra, 8), collapse = ", "), if (length(extra) > 8) "..."))
  }

  # 2.2 Values, column by column ---------------------------------------------------
  data <- raw
  valid <- rep(TRUE, nrow(raw))
  columns_to_check <- input_columns |> filter(column %in% names(raw))

  for (i in seq_len(nrow(columns_to_check))) {
    spec <- columns_to_check[i, ]
    text <- str_trim(as.character(raw[[spec$column]]))
    blank <- is.na(text) | text == ""

    # Missing values. A blank matric_plus means unknown education: those rows are
    # left out, exactly as in the training data, so it is a warning, not a failure.
    if (spec$column == "matric_plus") {
      if (any(blank)) add_check("matric_plus: unknown education", "Warning", sum(blank),
                                "Rows with blank matric_plus are left out, as in the training data.")
      valid[blank] <- FALSE
    } else if (spec$required && any(blank)) {
      add_check(paste0(spec$column, ": missing values"), "Fail", sum(blank),
                "Rows with a blank value in a required column are left out.")
      valid[blank] <- FALSE
    } else if (!spec$required && spec$column != "household_id" && any(blank)) {
      add_check(paste0(spec$column, ": missing values"), "Warning", sum(blank),
                "Rows with a blank value in this optional column are left out.")
      valid[blank] <- FALSE
    }

    if (spec$type %in% c("0/1", "whole number", "number")) {
      number <- suppressWarnings(as.numeric(text))
      not_a_number <- !blank & is.na(number)
      out_of_range <- !blank & !is.na(number) &
        (number < spec$min | number > spec$max |
           (spec$type != "number" & number != round(number)))
      if (any(not_a_number)) {
        add_check(paste0(spec$column, ": not a number"), "Fail", sum(not_a_number),
                  paste0("Values must be numbers, for example ", spec$example, "."))
      }
      if (any(out_of_range)) {
        add_check(paste0(spec$column, ": outside the valid range"), "Fail", sum(out_of_range),
                  if (spec$type == "0/1") "Values must be 0 or 1."
                  else if (spec$column == "person_weight") "Values must be positive numbers."
                  else paste0("Values must be whole numbers from ", spec$min, " to ", spec$max, "."))
      }
      valid[not_a_number | out_of_range] <- FALSE
      data[[spec$column]] <- number
    } else if (spec$type == "category") {
      allowed <- if (spec$column == "employed") c("Employed", "Unemployed") else allowed_values(spec$column)
      not_allowed <- !blank & !(text %in% allowed)
      if (any(not_allowed)) {
        add_check(paste0(spec$column, ": value not allowed"), "Fail", sum(not_allowed),
                  paste0("Allowed values: ", paste(allowed, collapse = " / "),
                         ". Found, for example: ", paste(head(unique(text[not_allowed]), 3), collapse = ", "), "."))
      }
      valid[not_allowed] <- FALSE
      data[[spec$column]] <- text
    } else {
      data[[spec$column]] <- text
    }
  }

  # 2.3 Consistency between columns -----------------------------------------------
  # Columns calculated from other columns must agree with them; a mismatch means
  # the file was built with a different rule than the training data.
  inconsistent <- function(condition) !is.na(condition) & condition # NA (a blank value) is reported above
  bad_square <- inconsistent(data$age_centred_squared != data$age_centred^2)
  if (any(bad_square)) add_check("age_centred_squared = age_centred x age_centred", "Fail", sum(bad_square),
                                 "age_centred_squared must be age_centred multiplied by itself.")
  bad_children <- inconsistent(data$female_x_children != data$female * data$n_children_under15)
  if (any(bad_children)) add_check("female_x_children = female x n_children_under15", "Fail", sum(bad_children),
                                   "female_x_children must be female multiplied by n_children_under15.")
  too_many_children <- inconsistent(data$n_children_under15 >= data$household_size)
  if (any(too_many_children)) add_check("n_children_under15 < household_size", "Fail", sum(too_many_children),
                                        "The household must include at least one person aged 15 or older.")
  valid[bad_square | bad_children | too_many_children] <- FALSE

  if (!any(checks$status == "Fail" & str_detect(checks$check, ":|="))) {
    add_check("All values valid", "Pass", 0, "Every value is of the right type, in range and consistent.")
  }

  # 2.4 Enough rows --------------------------------------------------------------
  if (sum(valid) == 0) {
    add_check("Rows that can be used", "Fail", 0, "No row passed every check, so nothing can be predicted.")
    return(list(fatal = TRUE, checks = checks, data = data, valid = valid))
  }
  add_check("Rows that can be used",
            if (sum(valid) < monitoring_thresholds$min_rows) "Warning" else "Pass",
            sum(valid),
            if (sum(valid) < monitoring_thresholds$min_rows)
              paste0("Fewer than ", monitoring_thresholds$min_rows, " usable rows: the accuracy and monitoring measures will be imprecise.")
            else paste0(sum(!valid), " of ", nrow(raw), " rows are left out because of the checks above."))

  list(fatal = FALSE, checks = checks, data = data, valid = valid)
}
