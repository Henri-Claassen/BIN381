# BIN381 Group 5: Education, Internet and Employment (Milestone 3 deployment)
#
# A Shiny app for National Treasury policy analysts. It shows how the predicted
# employment rate differs between people with and without matric and home
# internet, lets analysts explore province scenarios, and checks, scores and
# monitors new survey data.
#
# How to run: open BIN381.Rproj in RStudio and run   shiny::runApp("App")
# (install once with   install.packages(c("shiny", "bslib", "tidyverse", "pROC"))).
#
# Pages:
#   1. Overview                  the answer to Treasury's question, and how to use the app
#   2. Education x internet      predicted employment rates of the four matric x internet groups
#   3. Province scenarios        what the model's association implies if home internet access rose
#   4. Check and predict data    upload a CSV: validation, group predictions, accuracy, monitoring
#   5. About the model           intended use, performance, fairness, limitations, retraining
#
# The app never shows a prediction for an individual person: the evaluation
# found the model unreliable for individuals in some groups, and Treasury's
# decisions are about groups and provinces.

library(shiny)     # the app
library(bslib)     # page layout: navigation bar, cards, value boxes
library(tidyverse) # data handling and charts (ggplot2)
library(pROC)      # AUC (used by R/monitoring.R)

# shiny::runApp("App") runs the app with App/ as the working directory, so the
# shared R files are one folder up
source("../R/model_preparation.R") # category levels, predictor list, prepare_employment_frame()
source("../R/deployment_model.R")  # predict_slim(), delta_method_se()
source("../R/monitoring.R")        # accuracy measures, explanations, drift, thresholds
source("../R/validate_input.R")    # validate_input(), input_columns (the data format)

# What the app loads, and why not the saved model --------------------------------
# app_data.rds is built by Scripts/4) Deployment Preparation.qmd. It contains:
#   slim_model          coefficients, their covariance matrix, formula terms and
#                       category levels: everything needed to predict
#   threshold           0.639, the cut-off chosen in the evaluation that turns a
#                       probability into "Employed" / "Unemployed" (only used to
#                       measure accuracy, never to label a person)
#   group_cells,        the four groups' predicted employment rates for every
#   group_gradients     filter combination on page 2, and what is needed for their
#                       confidence intervals; groups under 50 people are suppressed
#   provinces           province totals for the scenarios on page 3
#   baseline, ...       test-set accuracy measures that monitoring compares with
#   reference_shares    the training data's mix of people, for the drift check
#   key_results,        the interaction results and subgroup performance for
#   subgroups           pages 1 and 5
#
# The app does NOT load Models/employment_logistic.rds. That file is about 7 MB
# because the fitted svyglm object stores a full copy of the training data,
# including every household_id. A deployed app must not carry survey microdata:
# if it were hosted, the data would be published with it. app_data.rds (about
# 360 KB) holds only model parameters, totals and averages, and the deployment
# notebook checks that the slim model predicts exactly like the full model.
app_data <- readRDS("app_data.rds")
slim_model <- app_data$slim_model
key <- app_data$key_results

options(shiny.maxRequestSize = 50 * 1024^2) # allow uploads up to 50 MB

# Formatting helpers ----------------------------------------------------------------
pct <- function(x, digits = 1) paste0(format(round(100 * x, digits), nsmall = digits), "%")
change_points <- function(x, digits = 1) paste0(if_else(x >= 0, "+", "−"), format(round(abs(100 * x), digits), nsmall = digits), " points")
num <- function(x) format(round(x), big.mark = ",", trim = TRUE)

# Coloured label for a status, shown inside HTML tables
status_badge <- function(status) {
  colour <- case_when(status %in% c("Green", "Pass") ~ "text-bg-success",
                      status %in% c("Amber", "Warning") ~ "text-bg-warning",
                      status %in% c("Red", "Fail") ~ "text-bg-danger",
                      TRUE ~ "text-bg-secondary")
  paste0('<span class="badge ', colour, '">', status, "</span>")
}

# Tables with HTML inside them (badges); sanitize.text.function = identity stops
# Shiny from showing the HTML as text
html_table <- function(expr, ...) {
  renderTable(expr, sanitize.text.function = identity, striped = TRUE, spacing = "s", width = "100%", ...)
}

# A small example file users can download and fill in. The values are made up.
template_file <- tribble(
  ~household_id, ~person_weight, ~employed, ~matric_plus, ~any_home_internet, ~has_computer,
  ~smartphone_access, ~age_centred, ~age_centred_squared, ~female, ~population_group, ~province,
  ~settlement_type, ~household_size, ~n_children_under15, ~elderly_in_household, ~female_x_children,
  ~other_member_matric,
  "H001", 950.5, "Employed", 1, 1, 0, "Fewer than 1 per member", -10, 100, 1, "Black African", "Gauteng",
  "Metro urban", 4, 2, 0, 2, "Yes",
  "H002", 1200, "Unemployed", 0, 0, 0, "None", 5, 25, 0, "Black African", "Limpopo",
  "Traditional", 6, 3, 1, 0, "No",
  "H003", 780.25, "Employed", 1, 1, 1, "1 or more per member", -15, 225, 1, "Coloured", "Western Cape",
  "Metro urban", 1, 0, 0, 0, "No other working-age member"
)

# The data format table shown on page 4, built from the same specification the
# validation uses (R/validate_input.R)
format_table <- input_columns |>
  mutate(
    Column = paste0("<code>", column, "</code>"),
    Needed = if_else(required, "Required", "Optional"),
    `Allowed values` = case_when(
      type == "category" & column == "employed" ~ "Employed / Unemployed",
      type == "category" ~ map_chr(column, \(c) paste(category_levels[[c]], collapse = " / ")),
      type == "0/1" ~ "0 or 1",
      column == "person_weight" ~ "Any positive number",
      type == "whole number" ~ paste0("Whole number from ", min, " to ", max),
      TRUE ~ "Any text"
    )
  ) |>
  select(Column, Needed, Type = type, `Allowed values`, Description = description, Example = example)

# ================================================================================
# User interface
# ================================================================================

ui <- page_navbar(
  title = "Education, Internet & Employment",
  theme = bs_theme(version = 5, primary = "#1F3864"),
  navbar_options = navbar_options(bg = "#1F3864", theme = "dark"),
  fillable = FALSE,

  # Page 1: Overview -----------------------------------------------------------------
  nav_panel(
    "Overview",
    layout_columns(
      col_widths = c(4, 4, 4),
      value_box(
        title = "Education and home internet",
        value = "Reinforce each other",
        theme = "primary",
        p(paste0("Odds ratio ", round(key$odds_ratio, 2), " (95% CI ", round(key$odds_ratio_lower, 2), "–",
                 round(key$odds_ratio_upper, 2), "), p = ", round(key$employment_p, 3)))
      ),
      value_box(
        title = "How well the model ranks people (AUC)",
        value = round(app_data$baseline$auc, 3),
        theme = "secondary",
        p("On the test set. 0.5 = coin toss, 1 = perfect. Above the 0.70 minimum set in Milestone 2.")
      ),
      value_box(
        title = "People behind the results",
        value = num(sum(app_data$provinces$people)),
        theme = "secondary",
        p("Labour force aged 15–64 in the Stats SA 2024 survey data")
      )
    ),
    layout_columns(
      col_widths = c(7, 5),
      card(
        card_header("What this app answers"),
        p("National Treasury has to divide limited funding between digital-access subsidies and education programmes.",
          "The question is whether the two", strong("reinforce"), "each other (complements) or can",
          strong("stand in"), "for each other (substitutes)."),
        p("The answer from the survey-weighted logistic regression: among otherwise similar people, having",
          strong("both"), "matric and home internet goes with higher odds of employment than the two separately would suggest.",
          paste0("The interaction's odds ratio is ", round(key$odds_ratio, 2),
                 ": above 1 means they reinforce each other, below 1 would mean substitutes.")),
        p("In practical terms: home internet goes with a bigger employment advantage for people with matric than for people without it.",
          "The", strong("Education × internet"), "page shows this as predicted employment rates for any province, settlement type, age band and sex.")
      ),
      card(
        card_header("How to use this app"),
        tags$ol(
          tags$li(strong("Education × internet:"), " compare the four matric × internet groups for the people you choose."),
          tags$li(strong("Province scenarios:"), " see what the model's association implies if more households had home internet."),
          tags$li(strong("Check and predict new data:"), " upload survey data to validate it, get group predictions, see how accurate they are and run the monitoring checks."),
          tags$li(strong("About the model:"), " what the model is for, how well it works for different groups, and its limits.")
        )
      )
    ),
    card(
      card_header("Income (exploratory)"),
      p("A second model looked at salaries of employed people who reported one.",
        paste0("People with both matric and home internet earned about ", round(key$income_percent, 1),
               "% more than the separate effects of matric and internet would suggest, but the 95% confidence interval runs from ",
               round(key$income_percent_lower, 1), "% to ", round(key$income_percent_upper, 1), "% (p = ",
               round(key$income_p, 2), ")."),
        "There is therefore", strong("no evidence"), "that home internet changes the salary premium for matric.",
        "Salaries are missing for many employed people, so this result is exploratory and is not part of the app's predictions.")
    ),
    card(
      class = "border-warning",
      card_header("Read this before using the results"),
      tags$ul(
        tags$li("These are", strong("associations"), "from one 2024 survey, not proof that providing internet or education", em("causes"), "employment."),
        tags$li("The app shows results for", strong("groups of people"), "only. It must not be used to make decisions about individuals."),
        tags$li("Groups with fewer than 50 people in the survey are not shown, because their estimates would be unreliable and could identify people.")
      )
    )
  ),

  # Page 2: Education x internet ------------------------------------------------------
  nav_panel(
    "Education × internet",
    layout_sidebar(
      sidebar = sidebar(
        title = "Choose a group of people",
        width = 300,
        open = list(desktop = "open", mobile = "always"), # filters stay visible on narrow screens
        selectInput("province", "Province", c("All provinces", category_levels$province)),
        selectInput("settlement", "Settlement type", c("All settlement types", category_levels$settlement_type)),
        selectInput("age_band", "Age band", c("All ages", age_band_levels)),
        selectInput("sex", "Sex", c("Both sexes", "Male", "Female")),
        helpText("Population group is deliberately not a filter. Results average over the real mix of people in the chosen group,",
                 "so the app cannot be used to compare the employment chances of racial groups.")
      ),
      card(
        card_header(textOutput("group_title")),
        plotOutput("group_plot", height = "380px"),
        uiOutput("group_people")
      ),
      uiOutput("group_boxes"),
      card(
        card_header("How to read this page"),
        tags$ul(
          tags$li(strong("Each bar"), " is the predicted share of people employed, if everyone in the chosen group had that education and internet combination and kept all their other characteristics.",
                  " A bar of 65% means about 65 in every 100 such people are predicted to be employed. It is a rate for a group, not one person's chance."),
          tags$li(strong("The black lines"), " are 95% confidence intervals: the range the rate plausibly lies in, given the uncertainty of the model. When the intervals of two bars overlap a lot, the difference between them is uncertain."),
          tags$li(strong("Internet gap"), " is how much higher the predicted employment rate is with home internet than without, in percentage points."),
          tags$li(strong("Difference between the gaps"), " is the interaction. Positive: internet goes with a bigger advantage for people with matric, so education and internet reinforce each other. Negative: a smaller advantage, so they substitute for each other.")
        )
      ),
      accordion(
        open = FALSE,
        accordion_panel(
          "How reliable are these predictions?",
          p(paste0("Measured on the ", num(app_data$baseline$people), " people in the test set, whom the model never saw during training. ",
                   "For the measures that need a yes/no prediction, a person counts as predicted employed when their predicted probability is at least ",
                   round(app_data$threshold, 3), ", the threshold chosen in the evaluation to give employed and unemployed people equal importance.")),
          tableOutput("reliability_table")
        )
      )
    )
  ),

  # Page 3: Province scenarios -----------------------------------------------------------
  nav_panel(
    "Province scenarios",
    layout_sidebar(
      sidebar = sidebar(
        title = "Scenario",
        width = 300,
        open = list(desktop = "open", mobile = "always"), # filters stay visible on narrow screens
        sliderInput("target", "Target share of people with home internet", min = 70, max = 100, value = 95, step = 1, post = "%"),
        helpText("Provinces already at or above the target stay as they are.",
                 "The newly connected people are assumed to be a typical mix of the people who are not connected today.")
      ),
      card(
        card_header("Predicted employment rate now and at the target"),
        plotOutput("province_plot", height = "400px")
      ),
      card(
        card_header("Province figures"),
        tableOutput("province_table"),
        p(class = "text-muted small",
          "Labour force = people aged 15–64 who are employed or unemployed (with known education), estimated with the survey weights.",
          "Employed now is the survey's actual weighted rate; Predicted now is the model's average prediction for the same people.")
      ),
      card(
        class = "border-warning",
        card_header("What this does and does not show"),
        p("For each person without home internet today, the model compares their predicted employment probability with and without internet, keeping everything else the same.",
          "The scenario adds that difference for the share of people who would need to be connected to reach the target."),
        p(strong("This is the association in today's data applied to a scenario, not a forecast of what a subsidy would achieve."),
          "People who get internet through a subsidy may differ from people who have it today, and the survey cannot show cause and effect.",
          "Use the scenarios to compare provinces, not to promise a number of jobs.")
      )
    )
  ),

  # Page 4: Check and predict new data ----------------------------------------------------
  nav_panel(
    "Check and predict new data",
    card(
      card_header("Step 1: Prepare your file"),
      p("Upload a CSV file with one row per person in the labour force (aged 15–64, employed or unemployed).",
        "The columns must have the names and values below, which are the same columns the model was trained on.",
        "The easiest way to see a working example is to upload", code("Datasets/Analytical/model_test.csv"), "from the project repository."),
      accordion(
        open = FALSE,
        accordion_panel(
          "Data format: every column, what it means and which values are allowed",
          tableOutput("format_table"),
          p(strong("Calculated columns:"), code("age_centred"), "= age − 40;", code("age_centred_squared"), "=",
            code("age_centred"), "×", code("age_centred"), ";", code("female_x_children"), "=", code("female"), "×",
            code("n_children_under15"), ". The check rejects rows where these do not agree."),
          p(strong("Optional columns:"), "with", code("employed"), "the app can measure how accurate the predictions are and run the monitoring checks;",
            "with", code("person_weight"), "the group results describe the population rather than just the people in the file.")
        )
      ),
      div(downloadButton("template", "Download a template CSV (3 made-up rows)"), class = "mt-2")
    ),
    card(
      card_header("Step 2: Upload the file"),
      fileInput("upload", NULL, accept = ".csv", buttonLabel = "Choose CSV file", width = "100%"),
      p(class = "text-muted small", "The file is only held in memory while the app is open. It is never saved.")
    ),
    uiOutput("results")
  ),

  # Page 5: About the model ---------------------------------------------------------------
  nav_panel(
    "About the model",
    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header("Intended use"),
        p(strong("Users:"), "National Treasury policy analysts, and the analysts who maintain the model."),
        p(strong("Supports:"), "decisions about dividing funding between digital-access subsidies and education, by showing whether the two reinforce each other and where more home internet access is associated with the largest employment gains."),
        p(strong("Must not be used for:")),
        tags$ul(
          tags$li("decisions about individual people (hiring, grants, eligibility);"),
          tags$li("claims that providing internet or education", em("causes"), "employment;"),
          tags$li("comparing the employment chances of population groups.")
        )
      ),
      card(
        card_header("The model"),
        p("A", strong("survey-weighted logistic regression"), "(", code("survey::svyglm"), ") fitted to",
          num(key$training_people), "people in the Stats SA 2024 survey (the training set), with households as clusters and the survey weights applied."),
        p("It predicts the probability of being employed from matric, home internet and their interaction, plus computer and smartphone access,",
          "age, sex, population group, province, settlement type and household composition."),
        p("It was chosen over a decision tree and a random forest because it is the only one that estimates the education × internet interaction directly,",
          "it performs almost as well as the random forest (test AUC 0.765 against 0.774), and its predictions can be explained.")
      )
    ),
    card(
      card_header("Performance on the test set"),
      p(paste0("Measured on ", num(key$test_people), " people the model never saw during training. For the yes/no measures, a person counts as predicted employed when their probability is at least ",
               round(app_data$threshold, 3), ".")),
      tableOutput("about_metrics"),
      p(strong("AUC in one sentence:"), "take one employed and one unemployed person at random; the AUC is the probability that the model gives the employed person the higher predicted probability.",
        "It is the main measure because it does not depend on the threshold or on how many people are employed.")
    ),
    card(
      card_header("Performance for different groups"),
      p("The model ranks people about equally well in every group (similar AUC). The yes/no measures differ much more, because one threshold meets groups with very different employment rates:"),
      tags$ul(
        tags$li("In the Indian/Asian and White groups, where over 85% are employed, the model almost never predicts unemployment (specificity 0.20 and 0.04): unemployed people in these groups are nearly always counted as employed."),
        tags$li("In traditional areas, where about half are employed, it misses more than half of the employed people (sensitivity 0.45).")
      ),
      p("This is why the app only reports group rates and never labels individuals."),
      tableOutput("about_subgroups")
    ),
    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header("Limitations"),
        tags$ul(
          tags$li("One cross-section (2024): associations, not causes."),
          tags$li("Education is simplified to matric or not; people with unknown education are left out (1.7%)."),
          tags$li("The survey's primary sampling units are not available, so households are the clusters; confidence intervals may be slightly too narrow."),
          tags$li("Small groups (Indian/Asian, farms) have few test people, so their measures are uncertain.")
        )
      ),
      card(
        card_header("Monitoring, retraining and retirement"),
        tableOutput("about_thresholds"),
        p(strong("Retrain"), "when Stats SA releases a new survey wave or any check is red.",
          strong("Retire"), "the model if retraining does not bring the AUC back above 0.70, if Stats SA changes the education or internet questions,",
          "if the complements finding disappears in successive waves, or if the app is used for decisions about individuals.")
      )
    ),
    p(class = "text-muted small",
      paste0("Model: ", app_data$built$model, ". App data built on ", app_data$built$date,
             " by Scripts/4) Deployment Preparation.qmd. Data: Statistics South Africa, 2024 survey microdata (isiBalo portal)."))
  )
)

# ================================================================================
# Server: the calculations behind each page
# ================================================================================

server <- function(input, output, session) {

  # Page 2: Education x internet ------------------------------------------------------

  # The row of group_cells that matches the filters
  selected_cell <- reactive({
    app_data$group_cells |>
      mutate(row = row_number()) |>
      filter(province == input$province, settlement_type == input$settlement,
             age_band == input$age_band, sex == input$sex)
  })

  # The four group rates and the gaps between them, each with a 95% confidence
  # interval. Each interval comes from the stored gradient and the coefficient
  # covariance (delta method): estimate ± 1.96 standard errors.
  group_estimates <- reactive({
    cell <- selected_cell()
    validate(need(!is.na(cell$p00),
                  paste0("Only ", cell$people, " people in the survey match this group, fewer than the minimum of 50. ",
                         "Choose a broader group (for example 'All ages' or 'Both sexes').")))
    gradient <- function(s) app_data$group_gradients[[s]][cell$row, ]
    with_interval <- function(estimate, grad) {
      se <- delta_method_se(slim_model, grad)
      tibble(estimate = estimate, lower = estimate - 1.96 * se, upper = estimate + 1.96 * se)
    }
    list(
      people = cell$people,
      groups = bind_rows(
        with_interval(cell$p00, gradient("00")) |> mutate(education = "Below matric", internet = "No home internet"),
        with_interval(cell$p01, gradient("01")) |> mutate(education = "Below matric", internet = "Home internet"),
        with_interval(cell$p10, gradient("10")) |> mutate(education = "Matric or higher", internet = "No home internet"),
        with_interval(cell$p11, gradient("11")) |> mutate(education = "Matric or higher", internet = "Home internet")
      ),
      gap_below = with_interval(cell$p01 - cell$p00, gradient("01") - gradient("00")),
      gap_matric = with_interval(cell$p11 - cell$p10, gradient("11") - gradient("10")),
      interaction = with_interval((cell$p11 - cell$p10) - (cell$p01 - cell$p00),
                                  (gradient("11") - gradient("10")) - (gradient("01") - gradient("00")))
    )
  })

  output$group_title <- renderText({
    paste("Predicted employment rate:", input$province, "·", input$settlement, "·", input$age_band, "·", input$sex)
  })

  output$group_plot <- renderPlot({
    groups <- group_estimates()$groups |>
      mutate(internet = factor(internet, levels = c("No home internet", "Home internet")))
    ggplot(groups, aes(x = education, y = estimate, fill = internet)) +
      geom_col(position = position_dodge(width = 0.8), width = 0.7) +
      geom_errorbar(aes(ymin = lower, ymax = upper), position = position_dodge(width = 0.8), width = 0.15) +
      geom_text(aes(y = upper + 0.03, label = pct(estimate)), position = position_dodge(width = 0.8), size = 5) +
      scale_fill_manual(values = c("No home internet" = "#9DB4D6", "Home internet" = "#1F3864")) +
      scale_y_continuous(labels = \(x) paste0(round(100 * x), "%"), limits = c(0, 1), expand = c(0, 0)) +
      labs(x = NULL, y = "Predicted share employed", fill = NULL) +
      theme_minimal(base_size = 15) +
      theme(legend.position = "top", panel.grid.major.x = element_blank())
  })

  output$group_people <- renderUI({
    p(class = "text-muted small",
      paste0("Based on ", num(group_estimates()$people),
             " people in the survey, weighted to represent the population. Black lines: 95% confidence intervals."))
  })

  output$group_boxes <- renderUI({
    estimates <- group_estimates()
    interval <- function(x) paste0("95% CI ", change_points(x$lower), " to ", change_points(x$upper))
    interaction_reading <- if (estimates$interaction$lower > 0) {
      "Internet goes with a bigger advantage for people with matric: they reinforce each other."
    } else if (estimates$interaction$upper < 0) {
      "Internet goes with a smaller advantage for people with matric: they substitute for each other."
    } else {
      "The interval includes 0, so for this group the difference is uncertain."
    }
    layout_columns(
      col_widths = c(4, 4, 4),
      value_box(title = "Internet gap without matric", value = change_points(estimates$gap_below$estimate),
                p(interval(estimates$gap_below))),
      value_box(title = "Internet gap with matric", value = change_points(estimates$gap_matric$estimate),
                p(interval(estimates$gap_matric))),
      value_box(title = "Difference between the gaps (the interaction)", value = change_points(estimates$interaction$estimate),
                theme = "primary", p(interval(estimates$interaction)), p(interaction_reading))
    )
  })

  # The test-set measures with their explanations (the "How reliable" panel)
  output$reliability_table <- renderTable(
    describe_metrics(app_data$baseline, app_data$baseline) |>
      select(Measure = measure, `Test set` = value, `What it means` = meaning),
    striped = TRUE, spacing = "s", width = "100%", digits = 3
  )

  # Page 3: Province scenarios ------------------------------------------------------------

  # For a target share t above a province's current share c, the fraction of
  # unconnected people who would be connected is (t - c) / (1 - c); each of them
  # adds the average uplift for the unconnected (Deployment Preparation, section 7)
  scenario <- reactive({
    target <- input$target / 100
    app_data$provinces |>
      mutate(
        target_share = pmax(target, internet_share),
        connected_fraction = (target_share - internet_share) / (1 - internet_share),
        predicted_target = predicted_rate + connected_fraction * uplift_unconnected,
        change = predicted_target - predicted_rate,
        additional_employed = labour_force * change
      )
  })

  output$province_plot <- renderPlot({
    scenario() |>
      mutate(province = fct_reorder(province, change)) |>
      ggplot(aes(y = province)) +
      geom_segment(aes(x = predicted_rate, xend = predicted_target, yend = province), colour = "#9DB4D6", linewidth = 2) +
      geom_point(aes(x = predicted_rate, colour = "Now"), size = 4) +
      geom_point(aes(x = predicted_target, colour = "At the target"), size = 4) +
      geom_text(aes(x = predicted_target, label = change_points(change)), hjust = -0.3, size = 4.5) +
      scale_colour_manual(values = c("Now" = "#9DB4D6", "At the target" = "#1F3864")) +
      scale_x_continuous(labels = \(x) paste0(round(100 * x), "%"), expand = expansion(mult = c(0.05, 0.15))) +
      labs(x = "Predicted employment rate", y = NULL, colour = NULL) +
      theme_minimal(base_size = 15) +
      theme(legend.position = "top")
  })

  output$province_table <- renderTable({
    rows <- scenario()
    national <- rows |>
      summarise(
        province = "South Africa",
        across(c(actual_rate, internet_share, predicted_rate, predicted_target), \(x) sum(x * labour_force) / sum(labour_force)),
        change = predicted_target - predicted_rate,
        additional_employed = sum(additional_employed),
        labour_force = sum(labour_force)
      )
    bind_rows(rows |> arrange(desc(change)), national) |>
      transmute(
        Province = province,
        `Labour force` = num(labour_force),
        `Employed now` = pct(actual_rate),
        `Home internet now` = pct(internet_share),
        `Predicted now` = pct(predicted_rate),
        `Predicted at target` = pct(predicted_target),
        Change = change_points(change),
        `About this many more people employed` = num(additional_employed)
      )
  }, striped = TRUE, spacing = "s", width = "100%")

  # Page 4: Check and predict new data ------------------------------------------------------

  output$format_table <- html_table(format_table)

  output$template <- downloadHandler(
    filename = "employment_data_template.csv",
    content = function(file) write_csv(template_file, file)
  )

  # Read -> validate -> prepare -> predict, once per upload
  scored <- reactive({
    req(input$upload)
    # Every column as text, so wrong types are reported by validate_input()
    raw <- tryCatch(
      read_csv(input$upload$datapath, col_types = cols(.default = col_character()), show_col_types = FALSE),
      error = function(e) NULL
    )
    validate(need(!is.null(raw), "The file could not be read as a CSV file."))

    checked <- validate_input(raw)
    if (checked$fatal) return(list(checked = checked, fatal = TRUE, rows_read = nrow(raw)))

    prepared <- prepare_employment_frame(checked$data[checked$valid, ])
    list(
      checked = checked,
      fatal = FALSE,
      rows_read = nrow(raw),
      prepared = prepared,
      probability = predict_slim(slim_model, prepared),
      has_outcome = "employed" %in% names(prepared) && n_distinct(prepared$employed) == 2,
      has_weight = "person_weight" %in% names(prepared)
    )
  })

  # Accuracy measures for the uploaded file (only with an employed column)
  upload_metrics <- reactive({
    s <- scored()
    req(!s$fatal, s$has_outcome)
    compute_metrics(s$prepared$employed, s$probability, app_data$threshold)
  })

  output$results <- renderUI({
    s <- scored()
    rows_used <- if (s$fatal) 0 else nrow(s$prepared)
    tagList(
      layout_columns(
        col_widths = c(4, 4, 4),
        value_box(title = "Rows in the file", value = num(s$rows_read)),
        value_box(title = "Rows used", value = num(rows_used), theme = if (rows_used > 0) "success" else "danger"),
        value_box(title = "Rows left out", value = num(s$rows_read - rows_used),
                  p("See the validation report for the reasons"))
      ),
      card(
        card_header("Step 3: Validation report"),
        p("Every check the file went through. Rows that fail a check are left out; if a required column is missing, nothing can be predicted."),
        tableOutput("validation_table")
      ),
      if (!s$fatal) card(
        card_header("Step 4: Predicted employment rates by group"),
        p("The average predicted probability of being employed for each group", if (s$has_weight) ", weighted with person_weight" else "",
          if (s$has_outcome) ", next to the actual rate in the file." else ".",
          "Individual predictions are not shown. Groups with fewer than 50 people are marked as unreliable."),
        selectInput("group_by", "Group by", c("Matric × internet", "Province", "Settlement type", "Sex", "Age band"), width = "300px"),
        tableOutput("group_table")
      ),
      if (!s$fatal && s$has_outcome) card(
        card_header("Step 5: How accurate are the predictions?"),
        p(paste0("The model's predictions compared with the actual outcomes in your file. For the yes/no measures, a person counts as predicted employed when their predicted probability is at least ",
                 round(app_data$threshold, 3), ", the threshold chosen in the evaluation to give employed and unemployed people equal importance. ",
                 "The Test set column shows the value on the ", num(app_data$baseline$people), " test people for comparison.")),
        tableOutput("metrics_table"),
        h6("Confusion matrix (number of people)"),
        p(class = "text-muted small", "Rows: what actually happened. Columns: what the model predicted. The diagonal (employed-employed and unemployed-unemployed) is correct."),
        tableOutput("confusion_table")
      ),
      if (!s$fatal && !s$has_outcome) card(
        card_header("Step 5: How accurate are the predictions?"),
        p("Accuracy can only be measured when the file contains the actual outcome. Add an", code("employed"),
          "column (Employed / Unemployed, with both present) to see the accuracy measures and the performance checks.")
      ),
      if (!s$fatal) card(
        card_header("Step 6: Monitoring checks"),
        uiOutput("verdict"),
        p("Each check compares your file with the model's training data or test-set performance. Green: no action. Amber: investigate. Red: retrain or consider retiring the model.",
          "The thresholds are set in", code("R/monitoring.R"), "."),
        tableOutput("monitoring_table")
      )
    )
  })

  output$validation_table <- html_table({
    scored()$checked$checks |>
      transmute(Check = check, Status = status_badge(status), `Rows affected` = num(rows), Details = detail)
  })

  output$group_table <- renderTable({
    s <- scored()
    req(!s$fatal, input$group_by)
    data <- s$prepared |>
      mutate(
        probability = s$probability,
        weight = if (s$has_weight) person_weight else 1,
        # switch() only calculates the grouping the user chose
        group = switch(input$group_by,
                       "Matric × internet" = paste(if_else(matric_plus == 1, "Matric or higher", "Below matric"), "·",
                                                   if_else(any_home_internet == 1, "home internet", "no home internet")),
                       "Province" = as.character(province),
                       "Settlement type" = as.character(settlement_type),
                       "Sex" = if_else(female == 1, "Female", "Male"),
                       "Age band" = as.character(make_age_band(age_centred)))
      )
    summary <- data |>
      group_by(Group = group) |>
      summarise(
        People = n(),
        `Predicted employment rate` = sum(weight * probability) / sum(weight),
        `Actual employment rate` = if (s$has_outcome) sum(weight * (employed == "Employed")) / sum(weight) else NA_real_,
        .groups = "drop"
      ) |>
      mutate(
        Reliability = if_else(People < 50, "Fewer than 50 people: unreliable", ""),
        Difference = `Predicted employment rate` - `Actual employment rate`
      )
    summary <- summary |>
      mutate(across(c(`Predicted employment rate`, `Actual employment rate`), pct),
             Difference = if_else(is.na(Difference), "", change_points(Difference)),
             People = num(People))
    if (!s$has_outcome) summary <- select(summary, -`Actual employment rate`, -Difference)
    summary
  }, striped = TRUE, spacing = "s", width = "100%")

  output$metrics_table <- html_table({
    describe_metrics(upload_metrics(), app_data$baseline) |>
      transmute(Measure = measure, `Your file` = format(value, nsmall = 3), `Test set` = format(test_set, nsmall = 3),
                Status = if_else(status == "-", "", status_badge(if (too_few_rows()) "Not checked" else status)),
                `What it means` = meaning)
  })

  output$confusion_table <- renderTable({
    confusion_table(upload_metrics()) |>
      rename(Actual = actual) |>
      mutate(across(-Actual, num))
  }, striped = TRUE, spacing = "s")

  # All monitoring checks in one table: drift (always) + performance and fairness
  # (only with an employed column)
  monitoring_checks <- reactive({
    s <- scored()
    req(!s$fatal)
    drift <- drift_report(s$prepared, app_data$reference_shares) |>
      transmute(check = paste("Drift (PSI):", str_replace_all(variable, "_", " ")),
                value = round(psi, 3), test_set = "0", status, meaning)
    if (!s$has_outcome) return(drift)

    performance <- describe_metrics(upload_metrics(), app_data$baseline) |>
      filter(status != "-") |>
      transmute(check = measure, value, test_set = as.character(test_set), status,
                meaning = "Compared with the thresholds in the About page. See Step 5 for what the measure means.")

    groups <- subgroup_auc(s$prepared$employed, s$probability, s$prepared$population_group)
    gap <- if (nrow(groups) >= 2) max(groups$auc) - min(groups$auc) else NA_real_
    fairness <- tibble(
      check = "Fairness: AUC gap between population groups",
      value = round(gap, 3),
      test_set = as.character(round(app_data$baseline_subgroup_gap, 3)),
      status = subgroup_gap_status(gap, app_data$baseline_subgroup_gap),
      meaning = if (is.na(gap)) paste0("Not checked: fewer than two population groups have ", monitoring_thresholds$min_group_rows, " or more people.")
                else paste0("The best-ranked population group's AUC minus the worst's (groups of ", monitoring_thresholds$min_group_rows,
                            "+ people). A widening gap means the model works less equally across groups.")
    )
    bind_rows(performance |> mutate(value = round(value, 3)), fairness, drift)
  })

  # With very few rows every measure is dominated by chance (a handful of people
  # can make the mix look completely different), so the checks are not judged
  too_few_rows <- reactive(nrow(scored()$prepared) < monitoring_thresholds$min_rows)

  output$verdict <- renderUI({
    checks <- monitoring_checks()
    if (too_few_rows()) {
      return(div(class = "alert alert-secondary", strong("Verdict: "),
                 paste0("Not checked. The file has fewer than ", monitoring_thresholds$min_rows,
                        " usable rows, so the measures below are shown for information only and cannot be judged reliably.")))
    }
    verdict <- overall_verdict(checks$status)
    colour <- if (any(checks$status == "Red")) "danger" else if (any(checks$status == "Amber")) "warning" else "success"
    div(class = paste0("alert alert-", colour), strong("Verdict: "), verdict)
  })

  output$monitoring_table <- html_table({
    monitoring_checks() |>
      mutate(status = if (too_few_rows()) "Not checked" else status) |>
      transmute(Check = check, `Your file` = format(value), `Test set` = test_set,
                Status = status_badge(status), `What it means` = meaning)
  })

  # Page 5: About the model -----------------------------------------------------------

  output$about_metrics <- renderTable(
    describe_metrics(app_data$baseline, app_data$baseline) |>
      select(Measure = measure, Value = value, `What it means` = meaning),
    striped = TRUE, spacing = "s", width = "100%", digits = 3
  )

  output$about_subgroups <- renderTable(
    app_data$subgroups |>
      transmute(Grouping = grouping, Group = group, `Test people` = num(people),
                `Share employed` = pct(share_employed), AUC = round(auc, 3),
                `Balanced accuracy` = round(balanced_accuracy, 3),
                Sensitivity = round(sensitivity, 3), Specificity = round(specificity, 3)),
    striped = TRUE, spacing = "s", width = "100%", digits = 3
  )

  output$about_thresholds <- renderTable({
    t <- monitoring_thresholds
    tribble(
      ~Check, ~Green, ~Amber, ~Red,
      "AUC", paste("≥", t$auc[["amber"]]), paste(t$auc[["red"]], "–", t$auc[["amber"]]), paste("<", t$auc[["red"]]),
      "Balanced accuracy", paste("≥", t$balanced_accuracy[["amber"]]),
        paste(t$balanced_accuracy[["red"]], "–", t$balanced_accuracy[["amber"]]), paste("<", t$balanced_accuracy[["red"]]),
      "Brier score", paste("≤", t$brier[["amber"]]), paste(t$brier[["amber"]], "–", t$brier[["red"]]), paste(">", t$brier[["red"]]),
      "Calibration gap", paste("within ±", t$calibration_gap[["amber"]]),
        paste("±", t$calibration_gap[["amber"]], "–", t$calibration_gap[["red"]]), paste("beyond ±", t$calibration_gap[["red"]]),
      "Drift (PSI)", paste("<", t$psi[["amber"]]), paste(t$psi[["amber"]], "–", t$psi[["red"]]), paste(">", t$psi[["red"]]),
      "Subgroup AUC gap (widening)", paste("≤ +", t$subgroup_auc_gap[["amber"]]),
        paste("+", t$subgroup_auc_gap[["amber"]], "–", t$subgroup_auc_gap[["red"]]), paste("> +", t$subgroup_auc_gap[["red"]])
    )
  }, striped = TRUE, spacing = "s", width = "100%")
}

shinyApp(ui, server)
