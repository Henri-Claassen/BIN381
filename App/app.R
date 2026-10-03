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
# Every number on screen goes through one of these, so the wording stays consistent
pct <- function(x, digits = 1) paste0(format(round(100 * x, digits), nsmall = digits), "%")
num <- function(x) format(round(x), big.mark = ",", trim = TRUE)
# A difference between two rates, as "+6.3": 6.3 more people in every 100 (percentage points)
signed <- function(x, digits = 1) paste0(if_else(x >= 0, "+", "−"), format(round(abs(100 * x), digits), nsmall = digits, trim = TRUE))
change_points <- function(x, digits = 1) paste0(signed(x, digits), " points")
# The same difference spelled out, naming who is compared with whom. Every
# "+6.3 in every 100" figure is the first group's employment rate minus the
# second group's, so a plus sign means the first group is ahead:
# "Of every 100 people with home internet, about 6 more have a job than of every
# 100 people without home internet (63 more in every 1,000)."
in_words <- function(x, group = "people with home internet", other = "people without home internet") {
  n <- abs(100 * x)
  direction <- if (x >= 0) "more" else "fewer"
  if (round(10 * n) == 0) {
    paste0("Almost no difference: ", group, " and ", other, " have a job about equally often.")
  } else if (round(n) < 1) {
    paste0("Of every 1,000 ", group, ", about ", round(10 * n), " ", direction, " have a job than of every 1,000 ", other, ".")
  } else {
    paste0("Of every 100 ", group, ", about ", round(n), " ", direction, " have a job than of every 100 ", other,
           " (", round(10 * n), " ", direction, " in every 1,000).")
  }
}

# For the province scenarios the comparison is the same people at the target
# level of home internet against today
in_words_scenario <- function(x) {
  n <- 100 * x
  if (round(10 * n) == 0) return("No change: this province is already at or above the target.")
  if (round(n) < 1) {
    paste0("Of every 1,000 people in the labour force, about ", round(10 * n), " more would have a job at the target than have one today.")
  } else {
    paste0("Of every 100 people in the labour force, about ", round(n), " more would have a job at the target than have one today (",
           round(10 * n), " more in every 1,000).")
  }
}

# Coloured label for a status, shown inside HTML tables. The internal statuses
# (Green / Amber / Red) are shown to users as plain words.
status_label <- c(Green = "OK", Amber = "Investigate", Red = "Action needed", Pass = "Pass",
                  Info = "Note", Warning = "Warning", Fail = "Problem", `Not checked` = "Not checked")
status_badge <- function(status) {
  colour <- case_when(status %in% c("Green", "Pass") ~ "text-bg-success",
                      status %in% c("Amber", "Warning") ~ "text-bg-warning",
                      status %in% c("Red", "Fail") ~ "text-bg-danger",
                      TRUE ~ "text-bg-secondary")
  paste0('<span class="badge ', colour, '">', status_label[status], "</span>")
}

# Tables with HTML inside them (badges); sanitize.text.function = identity stops
# Shiny from showing the HTML as text
html_table <- function(expr, ...) {
  renderTable(expr, sanitize.text.function = identity, striped = TRUE, spacing = "s", width = "100%", ...)
}

# A highlighted box that states the answer of a page in one or two sentences
answer_box <- function(title, ..., colour = "primary") {
  div(class = paste0("alert alert-", colour, " mb-3"), style = "font-size: 1.08rem;",
      div(class = "fw-bold mb-1", title), ...)
}

# The four group rates of one filter combination (a row of group_cells), the
# internet gaps and the difference between the gaps, each with a 95% confidence
# interval ("likely range"). Each interval comes from the stored gradient and the
# coefficient covariance (delta method): estimate ± 1.96 standard errors.
estimates_for_cell <- function(row) {
  cell <- app_data$group_cells[row, ]
  gradient <- function(s) app_data$group_gradients[[s]][row, ]
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
}

# The national figures (every filter on "All"), used on the Overview page
national <- estimates_for_cell(which(
  app_data$group_cells$province == "All provinces" & app_data$group_cells$settlement_type == "All settlement types" &
    app_data$group_cells$age_band == "All ages" & app_data$group_cells$sex == "Both sexes"
))
national_rate <- function(education, internet) {
  national$groups$estimate[national$groups$education == education & national$groups$internet == internet]
}

# "women aged 25-34 in metro urban areas in Gauteng": the chosen filters as words
describe_group <- function(province, settlement, age_band, sex) {
  paste0(
    switch(sex, "Male" = "men", "Female" = "women", "people"),
    if (age_band == "All ages") "" else paste0(" aged ", age_band),
    if (settlement == "All settlement types") "" else if (settlement == "Farms") " on farms" else paste0(" in ", tolower(settlement), " areas"),
    if (province == "All provinces") " in South Africa" else paste0(" in ", province)
  )
}

# Plain names of the variables in the drift check
drift_names <- c(province = "provinces", settlement_type = "settlement types", population_group = "population groups",
                 age_band = "ages", matric_plus = "education (matric or not)", any_home_internet = "home internet access",
                 smartphone_access = "smartphone access")

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
# Every page follows the same pattern, so a reader never has to search:
#   1. the answer in plain words at the top,
#   2. the key numbers, each with a one-line explanation in everyday units,
#   3. the detail (charts, tables), and
#   4. the technical terms last, for analysts.

ui <- page_navbar(
  title = "Education, Internet & Employment",
  theme = bs_theme(version = 5, primary = "#1F3864"),
  navbar_options = navbar_options(bg = "#1F3864", theme = "dark"),
  fillable = FALSE,

  # Page 1: Overview -----------------------------------------------------------------
  nav_panel(
    "Overview",
    answer_box(
      "The question: should government fund internet access and education together, or can one stand in for the other?",
      p(class = "mb-1", strong("The short answer: fund them together."),
        "People who have", strong("both"), "matric and home internet are employed more often than you would expect from either one on its own.",
        "Home internet goes with a clear employment advantage for people who have matric, and with little or no advantage for people who do not.")
    ),
    h5("The evidence in three numbers"),
    layout_columns(
      col_widths = c(4, 4, 4),
      value_box(
        title = "With matric, home internet goes with",
        value = paste0(signed(national$gap_matric$estimate), " in every 100"),
        theme = "primary",
        p(strong(in_words(national$gap_matric$estimate, "people with matric who have home internet", "people with matric who do not"))),
        p(class = "small", paste0("Among people with matric, ", pct(national_rate("Matric or higher", "Home internet")),
                                  " of those with home internet have a job, against ",
                                  pct(national_rate("Matric or higher", "No home internet")), " of those without it."))
      ),
      value_box(
        title = "Without matric, home internet goes with",
        value = paste0(signed(national$gap_below$estimate), " in every 100"),
        theme = "secondary",
        p(strong(in_words(national$gap_below$estimate, "people without matric who have home internet", "people without matric who do not"))),
        p(class = "small", paste0("Among people without matric, ", pct(national_rate("Below matric", "Home internet")),
                                  " of those with home internet have a job, against ",
                                  pct(national_rate("Below matric", "No home internet")), " of those without it. ",
                                  if (national$gap_below$lower < 0) "A difference this small could be chance." else ""))
      ),
      value_box(
        title = "How sure are we that the two differ?",
        value = if (key$employment_p < 0.05) "Confident" else "Not sure",
        theme = "secondary",
        p(paste0("If internet really mattered equally with and without matric, a difference this large would show up by chance only about 1 time in ",
                 round(1 / key$employment_p), "."))
      )
    ),
    layout_columns(
      col_widths = c(7, 5),
      card(
        card_header("What this means for decisions"),
        tags$ul(
          tags$li(strong("Pair the two investments."), paste0(
            " The employment advantage that goes with home internet is about ",
            round(national$gap_matric$estimate / national$gap_below$estimate), " times larger for people with matric (",
            signed(national$gap_matric$estimate), " people in every 100) than for people without (", signed(national$gap_below$estimate),
            " in every 100). Connectivity and education spending support each other; they are not alternatives.")),
          tags$li(strong("Internet access on its own is not enough."), " For people without matric, home internet shows almost no employment difference."),
          tags$li(strong("Where to look first:"), " the ", em("Province scenarios"), " page shows which provinces have the most to gain from more home internet access."),
          tags$li(strong("Keep in mind:"), " this is a pattern in one 2024 survey. It shows what goes together, not what causes what.")
        )
      ),
      card(
        card_header("Where to find what"),
        tags$ul(
          tags$li(strong("Does this hold for a specific province, age group or sex?"), " → Education × internet"),
          tags$li(strong("What could more home internet mean for each province?"), " → Province scenarios"),
          tags$li(strong("Does the model still work on new survey data?"), " → Check and predict new data"),
          tags$li(strong("Can I trust the model, and what are its limits?"), " → About the model")
        )
      )
    ),
    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header("How good is the model behind these numbers?"),
        p(strong(paste0("Acceptable: right about ", round(100 * app_data$baseline$auc), " times out of 100.")),
          "Shown one employed and one unemployed person it has never seen, the model picks the employed one about",
          round(100 * app_data$baseline$auc), "times out of 100. A coin toss would get 50, a perfect model 100, and 70 was set as the minimum."),
        p(paste0("The results are based on ", num(sum(app_data$provinces$people)),
                 " people aged 15–64 in the labour force, from Statistics South Africa's 2024 survey.")),
        p(class = "text-muted small mb-0", "This is good enough to describe groups of people, but not to judge individuals. See About the model.")
      ),
      card(
        card_header("Does the same hold for income?"),
        p(strong("No clear evidence."), "A second model looked at the salaries of employed people.",
          paste0("People with both matric and home internet earned about ", round(key$income_percent), "% more than expected from the two separately, ",
                 "but the likely range runs from ", round(key$income_percent_lower), "% to +", round(key$income_percent_upper),
                 "%, so the true difference could easily be zero.")),
        p(class = "text-muted small mb-0", "Many employed people did not report a salary, so this part is exploratory and is not used elsewhere in the app.")
      )
    ),
    card(
      class = "border-warning",
      card_header("Read this before using the results"),
      tags$ul(class = "mb-0",
        tags$li("These are", strong("associations"), "from one 2024 survey, not proof that providing internet or education", em("causes"), "employment."),
        tags$li("The app shows results for", strong("groups of people"), "only. It must not be used to make decisions about individuals."),
        tags$li("Groups with fewer than 50 people in the survey are not shown, because their results would be unreliable and could identify people.")
      )
    ),
    accordion(
      open = FALSE,
      accordion_panel(
        "Technical details (for analysts)",
        tags$ul(
          tags$li(paste0("Model: survey-weighted logistic regression. Interaction (matric × home internet) odds ratio ",
                         round(key$odds_ratio, 2), ", 95% confidence interval ", round(key$odds_ratio_lower, 2), "–",
                         round(key$odds_ratio_upper, 2), ", Rao-Scott likelihood-ratio test p = ", round(key$employment_p, 3),
                         ". An odds ratio above 1 means complements, below 1 substitutes.")),
          tags$li(paste0("The \"in every 100\" figures are percentage-point differences between average predicted employment rates, ",
                         "with everyone given each education and internet combination in turn and all other characteristics unchanged.")),
          tags$li(paste0("Test-set AUC ", round(app_data$baseline$auc, 3), "; balanced accuracy ", round(app_data$baseline$balanced_accuracy, 3),
                         "; Brier score ", round(app_data$baseline$brier, 3), ".")),
          tags$li(paste0("Income model: interaction ", round(key$income_percent, 1), "% (95% CI ", round(key$income_percent_lower, 1),
                         "% to ", round(key$income_percent_upper, 1), "%), p = ", round(key$income_p, 2), "."))
        )
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
      uiOutput("group_answer"),
      card(
        card_header(textOutput("group_title")),
        plotOutput("group_plot", height = "360px"),
        uiOutput("group_people")
      ),
      h5("The differences between the bars, in numbers"),
      uiOutput("group_boxes"),
      card(
        card_header("How to read this page"),
        tags$ul(class = "mb-0",
          tags$li(strong("Each bar"), " is the share of people expected to have a job, for people like the ones you chose, if they had that education and internet combination.",
                  " A bar of 65% means about 65 of every 100. It describes a group, not one person's chance."),
          tags$li(strong("\"+6.3 in every 100\""), " compares two groups: the dark bar (home internet) minus the light bar (no home internet).",
                  " If 69.7% of people with home internet have a job and 63.5% of people without, the difference is about +6.3:",
                  " of every 100 people with home internet, about 6 more have a job than of every 100 people without.",
                  strong(" A plus sign means the group with home internet is ahead; a minus sign means it is behind."),
                  " It compares two groups of people; it does not say that getting internet gives someone a job."),
          tags$li(strong("Likely range"), " (the thin black lines, and the ranges in the boxes): the model cannot be exact, so this is the range the true value very probably lies in.",
                  " If a range includes 0, the difference may not be real."),
          tags$li(strong("The verdict"), " compares the two internet gaps. If internet goes with a clearly bigger gap for people with matric, education and internet reinforce each other.")
        )
      ),
      accordion(
        open = FALSE,
        accordion_panel(
          "How reliable are these predictions?",
          p(paste0("The model was tested on ", num(app_data$baseline$people), " people it never saw while it was being built. ",
                   "\"In short\" gives each result in everyday terms. For the rows about employed and unemployed people found, ",
                   "a person is counted as predicted employed when the model gives them a chance of at least ",
                   round(100 * app_data$threshold), "% (the cut-off that treats both groups equally).")),
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
        title = "Set the scenario",
        width = 300,
        open = list(desktop = "open", mobile = "always"), # filters stay visible on narrow screens
        sliderInput("target", "What if this share of people had home internet?", min = 70, max = 100, value = 95, step = 1, post = "%"),
        helpText("Move the slider to set the target. Provinces already at or above the target stay as they are.")
      ),
      uiOutput("scenario_answer"),
      uiOutput("scenario_boxes"),
      card(
        card_header("Each province: employment rate today and at the target"),
        plotOutput("province_plot", height = "400px"),
        p(class = "text-muted small mb-0",
          "Light dot: the employment rate today. Dark dot: the rate at the target. The longer the line, the more the province stands to gain.",
          "The label compares the target with today: +3.0 in every 100 means that of every 100 people in that province's labour force, about 3 more would have a job at the target than have one today.",
          "Provinces at the top gain the most for their size.")
      ),
      card(
        card_header("The figures per province"),
        tableOutput("province_table"),
        tags$ul(class = "text-muted small mb-0",
          tags$li(strong("People in the labour force:"), " people aged 15–64 who have a job or are looking for one."),
          tags$li(strong("Employed today:"), " the share of them who have a job, according to the survey."),
          tags$li(strong("Home internet today:"), " the share living in a household with fixed or mobile internet."),
          tags$li(strong("Employed at the target:"), " the employment rate the model expects if home internet reached the target."),
          tags$li(strong("More employed in every 100 people:"), " employed at the target minus employed today. +3.0 means that of every 100 people, about 3 more would have a job at the target than have one today."),
          tags$li(strong("More people employed:"), " that gain turned into a rough number of people.")
        )
      ),
      card(
        class = "border-warning",
        card_header("How far can these numbers be trusted?"),
        p(strong("They are a \"what if\", not a forecast."),
          "The app takes the people who have no home internet today and asks the model how often similar people who do have it are employed.",
          "It assumes the newly connected would be a typical mix of today's unconnected people."),
        p(class = "mb-0", "People who get internet through a subsidy may differ from people who have it today, and one survey cannot prove cause and effect.",
          strong("Use the scenarios to compare provinces and set priorities, not to promise a number of jobs."))
      )
    )
  ),

  # Page 4: Check and predict new data ----------------------------------------------------
  nav_panel(
    "Check and predict new data",
    answer_box(
      "What this page is for",
      p(class = "mb-0", "Upload a file of people (for example a new survey) and the app tells you, in order:",
        strong("is the file usable"), ",", strong("what employment rate does the model predict"), ",",
        strong("how accurate are the predictions"), ", and", strong("can the model still be trusted"), "on this data.")
    ),
    card(
      card_header("Step 1: Prepare your file"),
      p("Upload a CSV file with one row per person in the labour force (aged 15–64, employed or unemployed).",
        "The columns must have the names and values listed below, which are the same columns the model was built on.",
        "To see a working example, upload", code("Datasets/Analytical/model_test.csv"), "from the project folder."),
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
      p(class = "text-muted small mb-0", "The file is only held in memory while the app is open. It is never saved.")
    ),
    uiOutput("results")
  ),

  # Page 5: About the model ---------------------------------------------------------------
  nav_panel(
    "About the model",
    answer_box(
      "The model in short",
      tags$ul(class = "mb-0",
        tags$li(strong("What it does:"), " estimates how likely people are to be employed, from their education, home internet access and background."),
        tags$li(strong("How good it is:"), paste0(" acceptable. It ranks an employed person above an unemployed one about ",
                                                  round(100 * app_data$baseline$auc), " times out of 100 (50 is a coin toss).")),
        tags$li(strong("What it is for:"), " comparing groups and provinces to guide funding priorities."),
        tags$li(strong("What it is not for:"), " decisions about individual people, or proving that internet causes employment.")
      )
    ),
    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header("Intended use"),
        p(strong("Users:"), "National Treasury policy analysts, and the analysts who maintain the model."),
        p(strong("Supports:"), "decisions about dividing funding between digital-access subsidies and education, by showing whether the two reinforce each other and where more home internet access goes with the largest employment gains."),
        p(strong("Must not be used for:")),
        tags$ul(class = "mb-0",
          tags$li("decisions about individual people (hiring, grants, eligibility);"),
          tags$li("claims that providing internet or education", em("causes"), "employment;"),
          tags$li("comparing the employment chances of population groups.")
        )
      ),
      card(
        card_header("How the model works"),
        p("It learned from", num(key$training_people), "people in the Stats SA 2024 survey how employment goes with matric, home internet and the two together,",
          "while taking into account computer and smartphone access, age, sex, population group, province, settlement type and household make-up."),
        p("For any group of people it then gives the share expected to be employed."),
        p(class = "mb-0", "It was chosen over two other models (a decision tree and a random forest) because it is the only one that measures directly whether education and internet reinforce each other,",
          "it is almost as accurate as the best of them (a ranking score of 0.765 against 0.774), and its results can be explained.",
          span(class = "text-muted", "Technical name: survey-weighted logistic regression."))
      )
    ),
    card(
      card_header("How accurate is it?"),
      p(paste0("Tested on ", num(key$test_people), " people the model never saw while it was being built. ",
               "Read the \"In short\" column first; the \"Value\" column is the technical score.")),
      tableOutput("about_metrics"),
      p(class = "text-muted small mb-0",
        paste0("For the rows about people found and predictions, a person is counted as predicted employed when the model gives them a chance of at least ",
               round(100 * app_data$threshold), "%."))
    ),
    card(
      card_header("Does it work equally well for everyone?"),
      p(strong("Not for individuals, which is why the app only shows groups."),
        "The model ranks people about equally well in every group (the \"Ranking accuracy\" column is similar everywhere). But when it has to say employed or unemployed for each person, it treats groups unevenly:"),
      tags$ul(
        tags$li("In the Indian/Asian and White groups, where more than 85 of every 100 people are employed, it almost never spots the unemployed (it finds 20% and 4% of them)."),
        tags$li("In traditional areas, where only about half are employed, it misses more than half of the people who do have a job (it finds 45%).")
      ),
      tableOutput("about_subgroups"),
      p(class = "text-muted small mb-0",
        "Ranking accuracy: out of 100 pairs of one employed and one unemployed person, how many the model ranks correctly.",
        "Employed found / Unemployed found: the share of each group the model identifies. Groups with few test people give less certain figures.")
    ),
    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header("Limitations"),
        tags$ul(class = "mb-0",
          tags$li("One survey year (2024): it shows what goes together, not what causes what."),
          tags$li("Education is simplified to \"matric or not\"; people with unknown education are left out (1.7%)."),
          tags$li("The likely ranges may be slightly too narrow, because the survey's sampling areas were not available."),
          tags$li("Small groups (Indian/Asian people, farms) have few test people, so their figures are uncertain.")
        )
      ),
      card(
        card_header("When to check, retrain or retire the model"),
        p("Every upload on the \"Check and predict new data\" page is tested against these limits:"),
        tableOutput("about_thresholds"),
        p(class = "mb-0", strong("Retrain"), "when Stats SA releases a new survey or any check shows \"Action needed\".",
          strong("Retire"), "the model if retraining does not bring the ranking accuracy back above 70 out of 100, if Stats SA changes the education or internet questions,",
          "if education and internet stop reinforcing each other in new surveys, or if the app is used for decisions about individuals.")
      )
    ),
    accordion(
      open = FALSE,
      accordion_panel(
        "Glossary: the terms used in this app",
        tags$dl(
          tags$dt("Predicted employment rate"), tags$dd("The share of a group the model expects to be employed, for example 65% = 65 of every 100 people."),
          tags$dt("\"+6 in every 100\" (percentage points)"), tags$dd("A comparison of two groups: the first group's employment rate minus the second group's. If 70% of people with home internet have a job and 64% of people without, that is +6 in every 100: of every 100 people with home internet, six more have a job than of every 100 without (60 more in every 1,000). A plus sign means the first group is ahead, a minus sign that it is behind. On the province page the comparison is the target against today."),
          tags$dt("Likely range (95% confidence interval)"), tags$dd("The range the true value very probably lies in. If the range of a difference includes 0, the difference may not be real."),
          tags$dt("Reinforce each other (complements)"), tags$dd("Having both education and internet goes with more employment than the two separate advantages added together. The opposite is substitutes: one makes up for the lack of the other."),
          tags$dt("Odds ratio"), tags$dd("The technical measure of \"reinforce\". Above 1: reinforce. Below 1: substitute. Exactly 1: no difference."),
          tags$dt("Ranking accuracy (AUC)"), tags$dd("Shown one employed and one unemployed person, how often the model gives the employed person the higher chance. 50 out of 100 is a coin toss; 100 is perfect."),
          tags$dt("Cut-off (threshold)"), tags$dd(paste0("The chance above which a person is counted as predicted employed (", round(100 * app_data$threshold), "%). Only used to measure accuracy, never to label a person.")),
          tags$dt("Drift (PSI)"), tags$dd("How much the mix of people in new data differs from the data the model learned from. 0 is identical; above 0.25 is a large change."),
          tags$dt("Labour force"), tags$dd("People aged 15–64 who are employed or looking for work.")
        )
      )
    ),
    p(class = "text-muted small mt-2",
      paste0("Model: ", app_data$built$model, ". App data built on ", app_data$built$date,
             " by Scripts/4) Deployment Preparation.qmd. Data: Statistics South Africa, 2024 survey microdata (isiBalo portal)."))
  )
)

# ================================================================================
# Server: the calculations behind each page
# ================================================================================

server <- function(input, output, session) {

  # Page 2: Education x internet ------------------------------------------------------

  # The estimates for the filter combination the user chose
  group_estimates <- reactive({
    row <- which(app_data$group_cells$province == input$province &
                   app_data$group_cells$settlement_type == input$settlement &
                   app_data$group_cells$age_band == input$age_band & app_data$group_cells$sex == input$sex)
    cell <- app_data$group_cells[row, ]
    validate(need(!is.na(cell$p00),
                  paste0("Only ", cell$people, " people in the survey match this group, fewer than the minimum of 50. ",
                         "Choose a broader group (for example 'All ages' or 'Both sexes').")))
    estimates_for_cell(row)
  })

  group_words <- reactive(describe_group(input$province, input$settlement, input$age_band, input$sex))

  # The answer for the chosen group, in plain words. The verdict depends on
  # whether the likely range of the difference between the gaps includes 0.
  output$group_answer <- renderUI({
    e <- group_estimates()
    rate <- function(education, internet) pct(e$groups$estimate[e$groups$education == education & e$groups$internet == internet])
    clear <- e$interaction$lower > 0 || e$interaction$upper < 0
    verdict <- if (e$interaction$lower > 0) {
      "Education and home internet reinforce each other for this group."
    } else if (e$interaction$upper < 0) {
      "Education and home internet substitute for each other for this group."
    } else {
      "No clear difference for this group."
    }
    answer_box(
      paste0("For ", group_words(), ": ", verdict),
      p(class = "mb-1", paste0(
        "With matric, ", rate("Matric or higher", "Home internet"), " of people with home internet are expected to be employed, against ",
        rate("Matric or higher", "No home internet"), " of those without it. So of every 100 people with home internet, about ", round(abs(100 * e$gap_matric$estimate)),
        if (e$gap_matric$estimate >= 0) " more" else " fewer", " have a job than of every 100 without it. Without matric, it is ",
        rate("Below matric", "Home internet"), " against ", rate("Below matric", "No home internet"), ": about ",
        round(abs(100 * e$gap_below$estimate)), if (e$gap_below$estimate >= 0) " more" else " fewer", " in every 100.")),
      p(class = "mb-0", if (e$interaction$lower > 0) {
        "Home internet goes with a clearly bigger employment advantage for people who have matric."
      } else if (e$interaction$upper < 0) {
        "Home internet goes with a clearly smaller employment advantage for people who have matric: it seems to make up for lower education."
      } else {
        paste0("The two internet gaps differ, but with only ", num(e$people),
               " people in the survey for this group the difference is too uncertain to rely on. The national result (all people) is clear: they reinforce each other.")
      }),
      colour = if (clear) "primary" else "secondary"
    )
  })

  output$group_boxes <- renderUI({
    e <- group_estimates()
    rate <- function(education, internet) pct(e$groups$estimate[e$groups$education == education & e$groups$internet == internet])
    range_text <- function(x) paste0("Likely range: ", signed(x$lower), " to ", signed(x$upper), ".",
                                     if (x$lower < 0 && x$upper > 0) " It includes 0, so this may be no real difference." else "")
    layout_columns(
      col_widths = c(4, 4, 4),
      value_box(title = "Without matric: people with home internet compared with people without",
                value = paste0(signed(e$gap_below$estimate), " in every 100"), theme = "secondary",
                p(strong(in_words(e$gap_below$estimate, "people without matric who have home internet", "people without matric who do not"))),
                p(class = "small", paste0(rate("Below matric", "Home internet"), " of those with home internet have a job, against ",
                                          rate("Below matric", "No home internet"), " of those without. ", range_text(e$gap_below)))),
      value_box(title = "With matric: people with home internet compared with people without",
                value = paste0(signed(e$gap_matric$estimate), " in every 100"), theme = "secondary",
                p(strong(in_words(e$gap_matric$estimate, "people with matric who have home internet", "people with matric who do not"))),
                p(class = "small", paste0(rate("Matric or higher", "Home internet"), " of those with home internet have a job, against ",
                                          rate("Matric or higher", "No home internet"), " of those without. ", range_text(e$gap_matric)))),
      value_box(title = "How much more home internet is worth with matric than without",
                value = paste0(signed(e$interaction$estimate), " in every 100"), theme = "primary",
                p(strong(paste0("The advantage that goes with home internet is about ", round(abs(100 * e$interaction$estimate)),
                                if (e$interaction$estimate >= 0) " more" else " fewer",
                                " employed people in every 100 for people with matric than for people without matric."))),
                p(class = "small", paste0("The second box minus the first: ", signed(e$gap_matric$estimate), " minus ", signed(e$gap_below$estimate),
                                          ". Above 0 means education and internet reinforce each other. ", range_text(e$interaction))))
    )
  })

  output$group_title <- renderText(paste0("Share expected to be employed: ", group_words()))

  output$group_plot <- renderPlot({
    groups <- group_estimates()$groups |>
      mutate(internet = factor(internet, levels = c("No home internet", "Home internet")))
    ggplot(groups, aes(x = education, y = estimate, fill = internet)) +
      geom_col(position = position_dodge(width = 0.8), width = 0.7) +
      geom_errorbar(aes(ymin = lower, ymax = upper), position = position_dodge(width = 0.8), width = 0.15) +
      geom_text(aes(y = upper + 0.03, label = pct(estimate)), position = position_dodge(width = 0.8), size = 5) +
      scale_fill_manual(values = c("No home internet" = "#9DB4D6", "Home internet" = "#1F3864")) +
      scale_y_continuous(labels = \(x) paste0(round(100 * x), "%"), limits = c(0, 1), expand = c(0, 0)) +
      labs(x = NULL, y = "Share expected to be employed", fill = NULL) +
      theme_minimal(base_size = 15) +
      theme(legend.position = "top", panel.grid.major.x = element_blank())
  })

  output$group_people <- renderUI({
    p(class = "text-muted small mb-0",
      paste0("Based on ", num(group_estimates()$people),
             " people in the survey, weighted to represent the population. Thin black lines: the likely range of each bar."))
  })

  # The test-set measures with their explanations (the "How reliable" panel)
  output$reliability_table <- renderTable(
    describe_metrics(app_data$baseline, app_data$baseline) |>
      select(Measure = measure, `In short` = in_short, `What it means` = meaning),
    striped = TRUE, spacing = "s", width = "100%"
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
        change = predicted_target - predicted_rate, # the model's gain
        additional_employed = labour_force * change,
        # Shown to the user: the survey's actual rate today, and that rate plus the
        # model's gain, so that "today" matches the published employment figures
        employed_today = actual_rate,
        employed_target = actual_rate + change
      )
  })

  # The whole country: the provinces added up, weighted by their labour force
  scenario_national <- reactive({
    scenario() |>
      summarise(
        province = "South Africa",
        across(c(internet_share, employed_today, employed_target), \(x) sum(x * labour_force) / sum(labour_force)),
        change = employed_target - employed_today,
        additional_employed = sum(additional_employed),
        labour_force = sum(labour_force)
      )
  })

  output$scenario_answer <- renderUI({
    country <- scenario_national()
    provinces <- scenario()
    if (all(provinces$change == 0)) {
      return(answer_box(paste0("At a target of ", input$target, "%, nothing changes"),
                        p(class = "mb-0", "Every province already has at least this share of people with home internet. Move the slider to a higher target."),
                        colour = "secondary"))
    }
    top_rate <- provinces |> slice_max(change, n = 1, with_ties = FALSE)
    top_people <- provinces |> slice_max(additional_employed, n = 1, with_ties = FALSE)
    answer_box(
      paste0("If ", input$target, "% of people had home internet (today: ", pct(country$internet_share, 0), ")"),
      p(class = "mb-1", paste0(
        "The pattern in the data suggests the national employment rate would be about ", pct(country$employed_target),
        " instead of ", pct(country$employed_today), ": roughly ", num(signif(country$additional_employed, 2)), " more people employed.")),
      p(class = "mb-0", paste0(
        top_rate$province, " gains the most for its size (of every 100 people, about ", round(100 * top_rate$change), " more would have a job than today), and ",
        top_people$province, " gains the most people (about ", num(signif(top_people$additional_employed, 2)), ").",
        " Provinces with the least home internet today have the most room to gain."))
    )
  })

  output$scenario_boxes <- renderUI({
    country <- scenario_national()
    provinces <- scenario()
    top_rate <- provinces |> slice_max(change, n = 1, with_ties = FALSE)
    top_people <- provinces |> slice_max(additional_employed, n = 1, with_ties = FALSE)
    layout_columns(
      col_widths = c(4, 4, 4),
      value_box(title = "South Africa: more people employed", value = paste0(signed(country$change), " in every 100"), theme = "primary",
                p(strong(in_words_scenario(country$change))),
                p(class = "small", paste0("Across the country that is about ", num(signif(country$additional_employed, 2)), " people."))),
      value_box(title = "Biggest gain for its size", value = span(style = "font-size: 1.5rem;", top_rate$province), theme = "secondary",
                p(strong(in_words_scenario(top_rate$change))),
                p(class = "small", paste0("It has the most room to grow: only ", pct(top_rate$internet_share, 0), " have home internet today."))),
      value_box(title = "Most people gained", value = span(style = "font-size: 1.5rem;", top_people$province), theme = "secondary",
                p(paste0("About ", num(signif(top_people$additional_employed, 2)), " more people employed, because it has the largest labour force.")))
    )
  })

  output$province_plot <- renderPlot({
    scenario() |>
      mutate(province = fct_reorder(province, change)) |>
      ggplot(aes(y = province)) +
      geom_segment(aes(x = employed_today, xend = employed_target, yend = province), colour = "#9DB4D6", linewidth = 2) +
      geom_point(aes(x = employed_today, colour = "Today"), size = 4) +
      geom_point(aes(x = employed_target, colour = "At the target"), size = 4) +
      geom_text(aes(x = employed_target, label = paste0(signed(change), " in every 100")), hjust = -0.15, size = 4.5) +
      scale_colour_manual(values = c("Today" = "#9DB4D6", "At the target" = "#1F3864"), breaks = c("Today", "At the target")) +
      scale_x_continuous(labels = \(x) paste0(round(100 * x), "%"), expand = expansion(mult = c(0.05, 0.3))) +
      labs(x = "Share of the labour force employed", y = NULL, colour = NULL) +
      theme_minimal(base_size = 15) +
      theme(legend.position = "top")
  })

  output$province_table <- renderTable({
    bind_rows(scenario() |> arrange(desc(change)), scenario_national()) |>
      transmute(
        Province = province,
        `People in the labour force` = num(labour_force),
        `Employed today` = pct(employed_today),
        `Home internet today` = pct(internet_share),
        `Employed at the target` = pct(employed_target),
        `More employed in every 100 people` = signed(change),
        `More people employed (about)` = num(signif(additional_employed, 2))
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

  # With very few rows every measure is dominated by chance (a handful of people
  # can make the mix look completely different), so the checks are not judged
  too_few_rows <- reactive(nrow(scored()$prepared) < monitoring_thresholds$min_rows)

  # All monitoring checks in one table: performance and fairness (only with an
  # employed column) and drift (always)
  monitoring_checks <- reactive({
    s <- scored()
    req(!s$fatal)
    drift <- drift_report(s$prepared, app_data$reference_shares) |>
      transmute(variable,
                check = paste0("Has the mix of ", drift_names[variable], " changed? (drift, PSI)"),
                value = round(psi, 3), expected = "0 (same mix)", status,
                meaning = paste(meaning, "0 is identical; above 0.10 is a noticeable shift; above 0.25 a large one."))
    if (!s$has_outcome) return(drift)

    performance <- describe_metrics(upload_metrics(), app_data$baseline) |>
      filter(status != "-") |>
      transmute(variable = NA_character_, check = measure, value, expected = as.character(test_set), status,
                meaning = paste0(in_short, ". ", meaning))

    groups <- subgroup_auc(s$prepared$employed, s$probability, s$prepared$population_group)
    gap <- if (nrow(groups) >= 2) max(groups$auc) - min(groups$auc) else NA_real_
    fairness <- tibble(
      variable = NA_character_,
      check = "Does the model work equally well across population groups? (gap in ranking accuracy)",
      value = round(gap, 3),
      expected = as.character(round(app_data$baseline_subgroup_gap, 3)),
      status = subgroup_gap_status(gap, app_data$baseline_subgroup_gap),
      meaning = if (is.na(gap)) paste0("Not checked: fewer than two population groups have ", monitoring_thresholds$min_group_rows, " or more people.")
                else paste0("The ranking accuracy of the best-served population group minus that of the worst-served (groups of ",
                            monitoring_thresholds$min_group_rows, "+ people). If the gap grows, the model is becoming less fair.")
    )
    bind_rows(performance |> mutate(value = round(value, 3)), fairness, drift)
  })

  # The result of the upload in plain words, shown before the detailed steps
  output$summary_card <- renderUI({
    s <- scored()
    line <- function(status, ...) tags$li(class = "mb-1", HTML(status_badge(status)), " ", ...)

    if (s$fatal) {
      problem <- s$checked$checks |> filter(status == "Fail") |> slice(1)
      return(answer_box("The result in short: this file cannot be used",
                        tags$ul(class = "list-unstyled mb-0", line("Fail", problem$detail)),
                        p(class = "mb-0 mt-1", "Fix the file using the data format in Step 1 and upload it again."),
                        colour = "danger"))
    }

    rows_used <- nrow(s$prepared)
    weight <- if (s$has_weight) s$prepared$person_weight else rep(1, rows_used)
    predicted_rate <- sum(weight * s$probability) / sum(weight)
    checks <- monitoring_checks()
    changed <- checks |> filter(!is.na(variable), status != "Green")

    file_line <- line(if (rows_used < s$rows_read) "Warning" else "Pass", strong("Is the file usable? "),
                      paste0("Yes. ", num(rows_used), " of ", num(s$rows_read), " rows can be used",
                             if (rows_used < s$rows_read) paste0("; ", num(s$rows_read - rows_used), " were left out (see Step 3).") else "."))
    prediction_line <- line("Info", strong("What does the model predict? "),
                            paste0(pct(predicted_rate), " of these people are expected to be employed",
                                   if (s$has_outcome) {
                                     actual_rate <- sum(weight * (s$prepared$employed == "Employed")) / sum(weight)
                                     paste0("; the actual figure in the file is ", pct(actual_rate), " (", format(round(100 * abs(predicted_rate - actual_rate), 1), nsmall = 1), " points apart).")
                                   } else "."))

    if (too_few_rows()) {
      return(answer_box("The result in short",
                        tags$ul(class = "list-unstyled mb-0", file_line, prediction_line,
                                line("Not checked", strong("Can the model still be trusted on this data? "),
                                     paste0("Not judged: the file has fewer than ", monitoring_thresholds$min_rows,
                                            " usable rows, too few for reliable accuracy and monitoring checks."))),
                        colour = "secondary"))
    }

    accuracy_line <- if (s$has_outcome) {
      m <- upload_metrics()
      auc_status <- traffic_light(m$auc, monitoring_thresholds$auc)
      line(auc_status, strong("How accurate are the predictions? "),
           paste0(switch(auc_status, Green = "As accurate as expected", Amber = "Somewhat less accurate than expected", "Clearly less accurate than expected"),
                  ": the model ranks people correctly ", round(100 * m$auc), " times out of 100 (expected: about ",
                  round(100 * app_data$baseline$auc), ")."))
    } else {
      line("Info", strong("How accurate are the predictions? "),
           "Cannot be measured: the file has no usable ", code("employed"), " column with the actual outcomes.")
    }
    drift_line <- line(if (nrow(changed) == 0) "Green" else if (any(changed$status == "Red")) "Red" else "Amber",
                       strong("Are these people like the ones the model learned from? "),
                       if (nrow(changed) == 0) "Yes, the mix of people is about the same."
                       else paste0("Not entirely. The mix differs in: ", paste(drift_names[changed$variable], collapse = ", "), "."))
    worst <- if (any(checks$status == "Red")) "Red" else if (any(checks$status == "Amber")) "Amber" else "Green"

    answer_box("The result in short",
               tags$ul(class = "list-unstyled mb-2", file_line, prediction_line, accuracy_line, drift_line),
               p(class = "mb-0", strong("What to do: "), overall_verdict(checks$status)),
               colour = c(Green = "success", Amber = "warning", Red = "danger")[[worst]])
  })

  output$results <- renderUI({
    s <- scored()
    tagList(
      uiOutput("summary_card"),
      card(
        card_header("Step 3: Was the file valid?"),
        p("Every check the file went through. Rows with a problem are left out; if a required column is missing, nothing can be predicted."),
        tableOutput("validation_table")
      ),
      if (!s$fatal) card(
        card_header("Step 4: What employment rate does the model predict for each group?"),
        p("The share of each group the model expects to be employed", if (s$has_weight) " (weighted to represent the population)" else "",
          if (s$has_outcome) ", next to the actual share in the file. A small difference means the model describes that group well." else ".",
          "Predictions for individual people are not shown. Groups with fewer than 50 people are marked as unreliable."),
        selectInput("group_by", "Show the results by", c("Matric × internet", "Province", "Settlement type", "Sex", "Age band"), width = "300px"),
        tableOutput("group_table")
      ),
      if (!s$fatal && s$has_outcome) card(
        card_header("Step 5: How accurate are the predictions?"),
        p("The model's predictions compared with what actually happened to the people in your file.",
          strong("Read the \"In short\" column first."), "\"Expected\" is the score on the",
          num(app_data$baseline$people), "people the model was tested on, and \"Result\" says whether your file is in line with it."),
        tableOutput("metrics_table"),
        p(class = "text-muted small",
          paste0("For the rows about people found and predictions, a person is counted as predicted employed when the model gives them a chance of at least ",
                 round(100 * app_data$threshold), "% (the cut-off that treats employed and unemployed people equally).")),
        h6("How many people were classified right and wrong"),
        tableOutput("confusion_table"),
        p(class = "text-muted small mb-0", "Each person is in one cell. Correct: employed and predicted employed, or unemployed and predicted unemployed. The other two cells are the mistakes.")
      ),
      if (!s$fatal && !s$has_outcome) card(
        card_header("Step 5: How accurate are the predictions?"),
        p(class = "mb-0", "Accuracy can only be measured when the file contains what actually happened. Add an", code("employed"),
          "column (Employed / Unemployed, with both present) to see the accuracy measures.")
      ),
      if (!s$fatal) card(
        card_header("Step 6: Can the model still be trusted on this data? (monitoring)"),
        uiOutput("verdict"),
        p("Each check compares your file with what the model was built and tested on.",
          HTML(paste0(status_badge("Green"), " in line with expectations. ", status_badge("Amber"), " borderline: find out why. ",
                      status_badge("Red"), " retrain the model or consider retiring it."))),
        tableOutput("monitoring_table")
      )
    )
  })

  output$validation_table <- html_table({
    scored()$checked$checks |>
      transmute(Check = check, Result = status_badge(status), `Rows affected` = num(rows), Details = detail)
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
        `Predicted to be employed` = sum(weight * probability) / sum(weight),
        `Actually employed` = if (s$has_outcome) sum(weight * (employed == "Employed")) / sum(weight) else NA_real_,
        .groups = "drop"
      ) |>
      mutate(
        Difference = `Predicted to be employed` - `Actually employed`,
        Note = if_else(People < 50, "Fewer than 50 people: unreliable", "")
      )
    summary <- summary |>
      mutate(across(c(`Predicted to be employed`, `Actually employed`), pct),
             Difference = if_else(is.na(Difference), "", change_points(Difference)),
             People = num(People))
    if (!s$has_outcome) summary <- select(summary, -`Actually employed`, -Difference)
    summary
  }, striped = TRUE, spacing = "s", width = "100%")

  output$metrics_table <- html_table({
    describe_metrics(upload_metrics(), app_data$baseline) |>
      transmute(Measure = measure, `In short` = in_short, `Your file` = format(value, nsmall = 3),
                Expected = format(test_set, nsmall = 3),
                Result = if_else(status == "-", "", status_badge(if (too_few_rows()) "Not checked" else status)),
                `What it means` = meaning)
  })

  output$confusion_table <- renderTable({
    confusion_table(upload_metrics()) |>
      transmute(` ` = paste("Actually", tolower(actual)), `Predicted employed` = num(`Predicted employed`),
                `Predicted unemployed` = num(`Predicted unemployed`))
  }, striped = TRUE, spacing = "s")

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
      transmute(Check = check, `Your file` = format(value), Expected = expected,
                Result = status_badge(status), `What it means` = meaning)
  })

  # Page 5: About the model -----------------------------------------------------------

  output$about_metrics <- renderTable(
    describe_metrics(app_data$baseline, app_data$baseline) |>
      select(Measure = measure, `In short` = in_short, Value = value, `What it means` = meaning),
    striped = TRUE, spacing = "s", width = "100%", digits = 3
  )

  output$about_subgroups <- renderTable(
    app_data$subgroups |>
      transmute(`Grouped by` = grouping, Group = group, `Test people` = num(people),
                `Employed in reality` = pct(share_employed, 0),
                `Ranking accuracy (out of 100)` = round(100 * auc),
                `Employed found` = pct(sensitivity, 0), `Unemployed found` = pct(specificity, 0)),
    striped = TRUE, spacing = "s", width = "100%", digits = 0
  )

  output$about_thresholds <- html_table({
    t <- monitoring_thresholds
    tribble(
      ~Check, ~ok, ~investigate, ~action,
      "Ranking accuracy (AUC)", paste("at least", t$auc[["amber"]]), paste(t$auc[["red"]], "to", t$auc[["amber"]]), paste("below", t$auc[["red"]]),
      "Fair accuracy (balanced accuracy)", paste("at least", t$balanced_accuracy[["amber"]]),
        paste(t$balanced_accuracy[["red"]], "to", t$balanced_accuracy[["amber"]]), paste("below", t$balanced_accuracy[["red"]]),
      "Error of the predicted chances (Brier score)", paste("at most", t$brier[["amber"]]),
        paste(t$brier[["amber"]], "to", t$brier[["red"]]), paste("above", t$brier[["red"]]),
      "Predicted minus actual rate (calibration gap)", paste("within", t$calibration_gap[["amber"]], "either way"),
        paste(t$calibration_gap[["amber"]], "to", t$calibration_gap[["red"]], "either way"), paste("more than", t$calibration_gap[["red"]], "either way"),
      "Change in the mix of people (drift, PSI)", paste("below", t$psi[["amber"]]), paste(t$psi[["amber"]], "to", t$psi[["red"]]), paste("above", t$psi[["red"]]),
      "Growth of the gap between population groups", paste("at most", t$subgroup_auc_gap[["amber"]]),
        paste(t$subgroup_auc_gap[["amber"]], "to", t$subgroup_auc_gap[["red"]]), paste("more than", t$subgroup_auc_gap[["red"]])
    ) |>
      setNames(c("Check", status_badge("Green"), status_badge("Amber"), status_badge("Red")))
  })
}

shinyApp(ui, server)
