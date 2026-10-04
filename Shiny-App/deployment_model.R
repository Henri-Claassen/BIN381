# Milestone 3: the deployed ("slim") employment model

# Used by Scripts/3.4) Deployment Preparation.qmd (which creates the slim model) and
# by the Shiny app in Shiny-App/app.R (which uses it to predict).


# A deployed app should never carry survey microdata: if it were hosted online,
# the data would be published with it. To predict, only four things are needed,
# and together they take a few kilobytes:
#   - the coefficients (one number per term in the formula),
#   - their covariance matrix (the uncertainty of the coefficients, from the
#     survey design, used for confidence intervals),
#   - the formula's terms (which columns to use and how to combine them), and
#   - the category levels and contrasts (how each category becomes 0/1 columns).

# Keeps only what is needed to predict from a fitted logistic regression
make_slim_model <- function(model) {
  model_terms <- delete.response(terms(model)) # the formula without the outcome
  # Terms carry the environment they were created in. Resetting it stops R from
  # saving objects from that environment into the file.
  environment(model_terms) <- globalenv()
  list(
    coefficients = coef(model),
    covariance = vcov(model), # survey-design covariance (households as clusters)
    terms = model_terms,
    xlevels = model$xlevels,
    contrasts = model$contrasts
  )
}

# Turns prepared data into the 0/1 design matrix the coefficients multiply:
# one column per coefficient, in the same order, including the
# matric_plus:any_home_internet interaction column.
slim_design_matrix <- function(slim_model, data) {
  frame <- model.frame(slim_model$terms, data, xlev = slim_model$xlevels, na.action = na.pass)
  model.matrix(slim_model$terms, frame, contrasts.arg = slim_model$contrasts)
}

# Predicted probability of being Employed for each row of prepared data.
# The logistic regression predicts log-odds (design matrix x coefficients), and
# plogis() turns log-odds into a probability between 0 and 1.
predict_slim <- function(slim_model, data) {
  design <- slim_design_matrix(slim_model, data)
  as.numeric(plogis(design %*% slim_model$coefficients))
}

# Standard error of an average predicted probability, from its gradient: how the
# average would change if each coefficient changed slightly (the delta method,
# variance = gradient' x covariance x gradient). The gradients are calculated in
# Scripts/3.4) Deployment Preparation.qmd. Passing the difference of two
# gradients gives the standard error of the difference between two averages.
delta_method_se <- function(slim_model, gradient) {
  sqrt(as.numeric(t(gradient) %*% slim_model$covariance %*% gradient))
}
