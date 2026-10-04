# ---- Run this if you need the packages ----------------------------------------
# Only needed if the packages are not installed yet: remove the # in front of
# install.packages() and run this line once.
# install.packages(c("shiny", "bslib", "tidyverse", "pROC"))

# BIN381 Group 5: Education, Internet and Employment (Milestone 3 deployment)
#
# A Shiny app for National Treasury policy analysts. It shows how the predicted
# employment rate differs between people with and without matric and home
# internet, lets analysts explore province scenarios, and checks, scores and
# monitors new survey data.
#
# How to run: open BIN381.Rproj in RStudio and run   shiny::runApp("Shiny-App")
# (install once with   install.packages(c("shiny", "bslib", "tidyverse", "pROC"))).
#
# Pages:
#   1. Overview                  the answer to Treasury's question, in plain words
#   2. Education x internet      predicted employment rates of the four matric x internet groups
#   3. Province scenarios        what the model's pattern implies if home internet access rose
#   4. Check new data            upload a CSV: validation, group predictions, accuracy, monitoring
#   5. About the model           intended use, accuracy, fairness, limitations, retraining
#
# Writing rules for the text on screen: lead with the answer, use everyday words
# ("out of 100 people"), explain a technical term once in brackets, and keep
# every box to one or two short lines.
#
# The app never shows a prediction for an individual person: the evaluation
# found the model unreliable for individuals in some groups, and Treasury's
# decisions are about groups and provinces.

library(shiny)     # the app
library(bslib)     # page layout and theme: navigation bar, cards, value boxes
library(tidyverse) # data handling and charts (ggplot2)
library(pROC)      # AUC (used by R/monitoring.R)

# Shiny runs the app with its own folder (Shiny-App) as the working directory:
# the app's helper files sit next to app.R, and model_preparation.R is shared
# with the notebooks in Scripts/R
source("../Scripts/R/model_preparation.R") # category levels, predictor list, prepare_employment_frame()
source("deployment_model.R")  # predict_slim(), delta_method_se()
source("monitoring.R")        # accuracy measures, explanations, drift, thresholds
source("validate_input.R")    # validate_input(), input_columns (the data format)

# What the app loads, and why not the saved model --------------------------------
# app_data.rds is built by Scripts/3.4) Deployment Preparation.qmd. It contains:
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

# Colours ----------------------------------------------------------------------------
# One palette for the theme and the charts:
#   #17252A  dark ink: text and the navigation bar
#   #2B7A78  deep teal: the main colour (banners, highlighted cards, chart bars)
#   #3AAFA9  bright teal: accents and the lighter chart bars
#   #DEF2F1  pale mint: the page background and table headers
#   #FEFFFF  white: cards and boxes
# plus a slate grey for secondary text and clear status colours.
colours <- list(
  main = "#2B7A78", main_dark = "#17252A", light = "#3AAFA9", light_bg = "#DEF2F1", white = "#FEFFFF",
  ink = "#17252A", slate = "#4A5D63", muted = "#9AB3B5", line = "#C9E4E2", page = "#DEF2F1",
  green = "#15803D", amber = "#B45309", red = "#B91C1C"
)

# Formatting helpers ----------------------------------------------------------------
# Every number on screen goes through one of these, so the wording stays consistent
pct <- function(x, digits = 1) paste0(format(round(100 * x, digits), nsmall = digits), "%")
num <- function(x) format(round(x), big.mark = ",", trim = TRUE, scientific = FALSE)
# Large estimates rounded to two significant figures ("210,000"), never "2.1e+05"
approx_num <- function(x) format(signif(x, 2), big.mark = ",", trim = TRUE, scientific = FALSE)
# A difference between two rates in percentage points, as "+6.3": 6.3 more
# people out of every 100. A plus sign means the first group is ahead.
signed <- function(x, digits = 1) paste0(if_else(x >= 0, "+", "−"), format(round(abs(100 * x), digits), nsmall = digits, trim = TRUE))
# The same difference in words: "6.3 more" or "1.2 fewer"
more_or_fewer <- function(x) paste(format(round(abs(100 * x), 1), nsmall = 1, trim = TRUE), if (x >= 0) "more" else "fewer")
# The same number with a smaller "per 100" label, for the large value boxes
per_100 <- function(x) span(style = "white-space: nowrap;", signed(x), span(class = "unit", "per 100"))

# Coloured label for a status. The internal statuses (Green / Amber / Red) are
# shown to users as plain words.
status_label <- c(Green = "OK", Amber = "Investigate", Red = "Action needed", Pass = "Pass",
                  Info = "Note", Warning = "Warning", Fail = "Problem", `Not checked` = "Not checked")
status_badge <- function(status) {
  colour <- case_when(status %in% c("Green", "Pass") ~ "text-bg-success",
                      status %in% c("Amber", "Warning") ~ "text-bg-warning",
                      status %in% c("Red", "Fail") ~ "text-bg-danger",
                      TRUE ~ "text-bg-secondary")
  paste0('<span class="badge rounded-pill ', colour, '">', status_label[status], "</span>")
}

# Table outputs with the app's standard look. The expression is passed on with
# quoted = TRUE, the documented way to wrap a render function, so the table
# re-runs whenever its inputs change. html_table() also shows HTML (the badges)
# instead of printing it as text.
plain_table <- function(expr, ...) {
  renderTable(substitute(expr), env = parent.frame(), quoted = TRUE,
              striped = TRUE, spacing = "s", width = "100%", ...)
}
html_table <- function(expr, ...) {
  renderTable(substitute(expr), env = parent.frame(), quoted = TRUE, sanitize.text.function = identity,
              striped = TRUE, spacing = "s", width = "100%", ...)
}

# The coloured banner at the top of each page that states the answer.
# tone: "main" (the answer), "slate" (neutral or uncertain), or a status colour.
hero <- function(title, ..., tone = "main") {
  div(class = paste0("hero hero-", tone), h4(class = "hero-title", title), ...)
}

# The "How to read this page" box, the first thing on every page
reading_guide <- function(...) {
  div(class = "guide", div(class = "guide-title", "How to read this page"), tags$ul(class = "mb-0", ...))
}

# A short grey note under a chart or table
note <- function(...) p(class = "note", ...)

# Value box styles: white with dark text, or deep teal for the box that matters most
box_plain <- value_box_theme(bg = colours$white, fg = colours$ink)
box_main <- value_box_theme(bg = colours$main, fg = colours$white)

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

# A group's employment rate, e.g. rate_of(e, "Matric or higher", "Home internet")
rate_of <- function(e, education, internet) {
  e$groups$estimate[e$groups$education == education & e$groups$internet == internet]
}

# The likely range of a gap and what it means: a range entirely above (or
# below) 0 shows a real gap; a range that includes 0 means the gap may be chance
range_sentence <- function(x) {
  paste0("Likely range: ", signed(x$lower), " to ", signed(x$upper), " per 100. ",
         if (x$lower > 0 || x$upper < 0) "The whole range is on one side of 0, so this gap is real."
         else "The range includes 0, so this gap may be down to chance.")
}

# A value box comparing people with and without home internet. The explanation
# sits inside the box: the two employment rates, the gap in people, and whether
# the likely range shows the gap is real.
gap_box <- function(title, gap, rate_with, rate_without, who, theme = box_plain) {
  value_box(
    title = title, value = per_100(gap$estimate), theme = theme,
    div(class = "box-facts",
        div(span("With home internet"), strong(pct(rate_with), " have a job")),
        div(span("Without home internet"), strong(pct(rate_without), " have a job"))),
    p(paste0("So out of 100 ", who, " who have home internet, about ", round(abs(100 * gap$estimate)),
             if (gap$estimate >= 0) " more" else " fewer", " have a job than out of 100 who don't.")),
    p(class = "range", range_sentence(gap))
  )
}

# The third box: how much bigger the internet gap is for people with matric
both_box <- function(e, theme = box_main) {
  value_box(
    title = "Extra boost from having both", value = per_100(e$interaction$estimate), theme = theme,
    div(class = "box-facts",
        div(span("Gap with matric"), strong(signed(e$gap_matric$estimate), " per 100")),
        div(span("Gap without matric"), strong(signed(e$gap_below$estimate), " per 100"))),
    p(paste0("The first gap minus the second. Home internet is linked to about ", round(abs(100 * e$interaction$estimate)),
             if (e$interaction$estimate >= 0) " more" else " fewer",
             " extra people with a job per 100 when people also have matric.")),
    p(class = "range", range_sentence(e$interaction))
  )
}

# The national figures (every filter on "All"), used on the Overview page
national <- estimates_for_cell(which(
  app_data$group_cells$province == "All provinces" & app_data$group_cells$settlement_type == "All settlement types" &
    app_data$group_cells$age_band == "All ages" & app_data$group_cells$sex == "Both sexes"
))

# "Women aged 25-34 in Limpopo": the chosen filters as words
describe_group <- function(province, settlement, age_band, sex) {
  words <- paste0(
    switch(sex, "Male" = "men", "Female" = "women", "people"),
    if (age_band == "All ages") "" else paste0(" aged ", age_band),
    if (settlement == "All settlement types") "" else if (settlement == "Farms") " on farms" else paste0(" in ", tolower(settlement), " areas"),
    if (province == "All provinces") " in South Africa" else paste0(" in ", province)
  )
  paste0(toupper(substr(words, 1, 1)), substr(words, 2, nchar(words)))
}

# Plain names of the variables in the drift check
drift_names <- c(province = "provinces", settlement_type = "settlement types", population_group = "population groups",
                 age_band = "ages", matric_plus = "education levels", any_home_internet = "home internet access",
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
# validation uses (validate_input.R)
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
  select(Column, Needed, `Allowed values`, `What it means` = description, Example = example)

# Theme ------------------------------------------------------------------------------
app_theme <- bs_theme(
  version = 5,
  bg = colours$page, fg = colours$ink,
  primary = colours$main, secondary = colours$slate,
  success = colours$green, warning = colours$amber, danger = colours$red, info = colours$main,
  base_font = font_collection("Segoe UI", "Inter", "Roboto", "Helvetica Neue", "Arial", "sans-serif"),
  "border-radius" = "0.75rem",
  "card-border-width" = "0"
) |>
  bs_add_rules("
    .navbar { box-shadow: 0 2px 8px rgba(23, 37, 42, .25); }
    .navbar .nav-link.active { color: #3AAFA9 !important; }
    .navbar .nav-link { font-weight: 500; }
    .card { box-shadow: 0 1px 3px rgba(15, 23, 42, .08), 0 4px 12px rgba(15, 23, 42, .04); }
    .card { background: #FEFFFF; }
    .card-header { background: transparent; border-bottom: 1px solid #DEF2F1; font-weight: 600; font-size: 1.02rem; }
    .guide { background: #FEFFFF; border-left: 5px solid #3AAFA9; box-shadow: 0 1px 3px rgba(23, 37, 42, .08); border-radius: .75rem; padding: .85rem 1.2rem; margin-bottom: 1rem; font-size: .95rem; }
    .guide-title { font-weight: 700; color: #2B7A78; margin-bottom: .3rem; }
    .guide li { margin-bottom: .2rem; }
    .hero { border-radius: 1rem; padding: 1.25rem 1.5rem; margin-bottom: 1.1rem; color: #FEFFFF; font-size: 1.05rem; line-height: 1.55; }
    .hero p:last-child { margin-bottom: 0; }
    .hero-title { font-weight: 700; margin-bottom: .45rem; }
    .hero-main  { background: linear-gradient(135deg, #2B7A78, #1F5C5A); }
    .hero-slate { background: linear-gradient(135deg, #475569, #334155); }
    .hero-green { background: linear-gradient(135deg, #15803D, #166534); }
    .hero-amber { background: linear-gradient(135deg, #B45309, #92400E); }
    .hero-red   { background: linear-gradient(135deg, #B91C1C, #991B1B); }
    .hero .badge { font-size: .8rem; vertical-align: middle; background: #FEFFFF !important; }
    .hero .badge.text-bg-success { color: #15803D !important; }
    .hero .badge.text-bg-warning { color: #B45309 !important; }
    .hero .badge.text-bg-danger { color: #B91C1C !important; }
    .hero .badge.text-bg-secondary { color: #475569 !important; }
    .bslib-value-box .value-box-title { font-size: .95rem; font-weight: 600; opacity: .9; }
    .bslib-value-box .value-box-value { font-weight: 700; }
    .bslib-value-box p { margin-bottom: .35rem; font-size: .9rem; line-height: 1.4; }
    .bslib-value-box .range { font-size: .82rem; opacity: .8; margin-bottom: 0; }
    .box-facts { margin: .3rem 0 .5rem; font-size: .9rem; }
    .box-facts div { display: flex; justify-content: space-between; gap: .5rem; padding: .2rem 0; border-bottom: 1px solid color-mix(in srgb, currentColor 22%, transparent); }
    .unit { font-size: .5em; font-weight: 500; opacity: .75; margin-left: .3rem; }
    .note { color: #4A5D63; font-size: .875rem; margin: .5rem 0 0; }
    .section-title { font-weight: 700; color: #17252A; margin: 1.2rem 0 .6rem; }
    table.table { font-size: .9rem; margin-bottom: 0; }
    table.table th { background: #DEF2F1; color: #17252A; font-weight: 600; }
    .result-list { list-style: none; padding-left: 0; margin-bottom: .6rem; }
    .result-list li { margin-bottom: .35rem; }
    .accordion-button { font-weight: 600; }
    dt { margin-top: .6rem; }
  ")

# Shared chart styling
chart_theme <- theme_minimal(base_size = 14) +
  theme(legend.position = "top", legend.text = element_text(size = 13),
        panel.grid.minor = element_blank(), panel.grid.major.y = element_line(colour = colours$line),
        axis.text = element_text(colour = colours$slate), axis.title = element_text(colour = colours$slate))

# ================================================================================
# User interface
# ================================================================================
# Every page follows the same pattern: a "How to read this page" box first, then
# the answer in a coloured banner, then the key numbers with their explanation
# inside each box, then charts and tables, and technical detail last.

ui <- page_navbar(
  title = "Education, Internet & Employment",
  theme = app_theme,
  navbar_options = navbar_options(bg = colours$main_dark, theme = "dark"),
  fillable = FALSE,

  # Page 1: Overview -----------------------------------------------------------------
  nav_panel(
    "Overview",
    reading_guide(
      tags$li("The teal box gives the answer. The three cards below it give the evidence behind it."),
      tags$li(strong("\"+6.3 per 100\""), " means: take 100 people with home internet and 100 people without it. About 6 more of the first 100 have a job."),
      tags$li(strong("Likely range"), " is where the true number almost certainly lies. If the whole range is above 0, the gap is real and not down to chance.")
    ),
    hero(
      "Should education and home internet be funded together? Yes.",
      p("Among people with matric, those with home internet are clearly more likely to have a job.",
        "Among people without matric, home internet makes little difference.",
        "So the two work best together, not as replacements for each other."),
      p("For National Treasury this means that money for internet access is likely to do the most good where people also finish school,",
        "and money for education goes further where people can get online.")
    ),
    h5(class = "section-title", "The evidence, for South Africa as a whole"),
    layout_columns(
      col_widths = c(4, 4, 4),
      gap_box("People with matric", national$gap_matric,
              rate_of(national, "Matric or higher", "Home internet"), rate_of(national, "Matric or higher", "No home internet"),
              "people with matric"),
      gap_box("People without matric", national$gap_below,
              rate_of(national, "Below matric", "Home internet"), rate_of(national, "Below matric", "No home internet"),
              "people without matric"),
      both_box(national)
    ),
    layout_columns(
      col_widths = c(6, 6),
      class = "mt-3",
      card(
        card_header("What this means for funding decisions"),
        tags$ul(class = "mb-0",
          tags$li(strong("Fund them together."), paste0(
            " With matric, home internet goes with ", signed(national$gap_matric$estimate), " more people with a job per 100;",
            " without matric, only ", signed(national$gap_below$estimate), ". The link is about ",
            round(national$gap_matric$estimate / national$gap_below$estimate), " times stronger when people have matric.")),
          tags$li(strong("Internet access alone is not enough."), " For people without matric, the gap is small and may be down to chance."),
          tags$li(strong("Start where internet access is lowest."), " The Province scenarios tab shows which provinces have the most to gain.")
        )
      ),
      card(
        card_header("How far can I trust this?"),
        tags$ul(class = "mb-0",
          tags$li(strong("The pattern is very likely real."), paste0(
            " If home internet mattered equally with and without matric, a difference this big would turn up by chance only about 1 time in ",
            round(1 / key$employment_p), ".")),
          tags$li(strong("Good enough for groups, not for individuals."), paste0(
            " Shown one person with a job and one without, the model picks the one with the job ",
            round(100 * app_data$baseline$auc), " times out of 100 (guessing would get 50).")),
          tags$li(strong("It shows a pattern, not a cause."), " Internet and jobs go together, but one survey cannot prove that one leads to the other."),
          tags$li(paste0("Based on ", num(sum(app_data$provinces$people)), " people aged 15–64 surveyed by Statistics South Africa in 2024."))
        )
      )
    ),
    card(
      card_header("Does internet also mean higher pay?"),
      p(class = "mb-0", strong("No clear evidence."), paste0(
        "People with both matric and home internet did not clearly earn more than expected: the likely range runs from ",
        signed(key$income_percent_lower / 100, 0), "% to ", signed(key$income_percent_upper / 100, 0),
        "%, which includes no difference at all. Many people did not report their salary, so treat this as a side result."))
    ),
    accordion(
      open = FALSE,
      accordion_panel(
        "The technical details, explained",
        tags$dl(class = "mb-0",
          tags$dt("How strongly do education and internet work together?"),
          tags$dd(paste0(
            "Having both matric and home internet is linked to ", round(100 * (key$odds_ratio - 1)),
            "% higher odds of having a job than the two separately would give. The likely range is ",
            round(key$odds_ratio_lower, 2), " to ", round(key$odds_ratio_upper, 2), "; it stays above 1, so the boost is real. ",
            "Technical: odds ratio ", round(key$odds_ratio, 2), " of the matric × internet term in a survey-weighted logistic regression; ",
            "a Rao-Scott likelihood-ratio test gives p = ", round(key$employment_p, 3), ", meaning a boost this big would appear by chance about 1 time in ",
            round(1 / key$employment_p), ".")),
          tags$dt("Where do the \"per 100\" numbers come from?"),
          tags$dd("The model takes every surveyed person and gives them each education and internet combination in turn, keeping everything else about them the same.",
                  "It then averages the chance of having a job in each case. The differences between those averages are the \"per 100\" numbers (percentage points)."),
          tags$dt("How accurate is the model?"),
          tags$dd(paste0(
            "On ", num(key$test_people), " people it had never seen, it picks the person with a job out of a pair ",
            round(100 * app_data$baseline$auc), " times out of 100 (AUC ", round(app_data$baseline$auc, 3), "). ",
            "Its employed/unemployed labels are right ", round(100 * app_data$baseline$balanced_accuracy), "% of the time with both groups counting equally (balanced accuracy ",
            round(app_data$baseline$balanced_accuracy, 3), "). Its predicted chances are off by a small amount on average (Brier score ",
            round(app_data$baseline$brier, 3), ", where 0 would be perfect).")),
          tags$dt("And income?"),
          tags$dd(paste0(
            "A second model (a linear regression of salaries) finds that having both is linked to about ", round(key$income_percent),
            "% higher pay than expected, but the likely range runs from ", signed(key$income_percent_lower / 100, 0), "% to ",
            signed(key$income_percent_upper / 100, 0), "%. Because that includes 0, there may be no link at all (p = ", round(key$income_p, 2), ")."))
        )
      )
    )
  ),

  # Page 2: Education x internet ------------------------------------------------------
  nav_panel(
    "Education × internet",
    layout_sidebar(
      sidebar = sidebar(
        title = "Who do you want to look at?",
        width = 290,
        open = list(desktop = "open", mobile = "always"), # filters stay visible on narrow screens
        selectInput("province", "Province", c("All provinces", category_levels$province)),
        selectInput("settlement", "Area", c("All settlement types", category_levels$settlement_type)),
        selectInput("age_band", "Age", c("All ages", age_band_levels)),
        selectInput("sex", "Sex", c("Both sexes", "Male", "Female")),
        helpText("Population group is left out on purpose, so the app cannot be used to compare racial groups.")
      ),
      reading_guide(
        tags$li("Choose a group of people on the left. Everything on this page updates for that group."),
        tags$li("Each bar shows how many out of 100 people like this have a job. Dark bars: with home internet. Light bars: without.",
                "The thin black line on each bar is its likely range."),
        tags$li("The cards below the chart give the gap between the dark and light bars, and explain it.")
      ),
      uiOutput("group_answer"),
      card(
        card_header("Out of 100 people, how many have a job?"),
        plotOutput("group_plot", height = "340px"),
        uiOutput("group_people")
      ),
      uiOutput("group_boxes")
    )
  ),

  # Page 3: Province scenarios -----------------------------------------------------------
  nav_panel(
    "Province scenarios",
    layout_sidebar(
      sidebar = sidebar(
        title = "Set a target",
        width = 290,
        open = list(desktop = "open", mobile = "always"), # filters stay visible on narrow screens
        sliderInput("target", "Share of people with home internet", min = 70, max = 100, value = 95, step = 1, post = "%"),
        helpText("Provinces already above the target stay as they are.")
      ),
      reading_guide(
        tags$li("Move the slider to choose a target: the share of people who would have home internet."),
        tags$li("The page shows how many more people could have a job if that target were reached, based on today's pattern. It is a what-if, not a promise."),
        tags$li(strong("\"+2.0 per 100\""), " means: out of every 100 people in the labour force (everyone aged 15–64 who is working or looking for work), about 2 more would have a job.")
      ),
      uiOutput("scenario_answer"),
      uiOutput("scenario_boxes"),
      card(
        card_header("Employment rate per province: today and at the target"),
        plotOutput("province_plot", height = "380px"),
        note("Grey dot: today. Teal dot: at the target. The number is the gain: how many more people out of 100 would have a job.")
      ),
      card(
        card_header("The figures per province"),
        tableOutput("province_table"),
        note("The survey asked about 28,000 people. Stats SA gives each one a weight (about 1,000 on average) for how many South Africans they stand for,",
             "so \"Labour force\" is an estimate for the whole province.")
      ),
      card(
        card_header("Is this a forecast?"),
        p(class = "mb-0", strong("No, it is a \"what if\"."),
          "It assumes that people who get home internet would have a job as often as similar people who already have it.",
          "That may not hold, and the survey cannot prove cause and effect.",
          "Use it to compare provinces and set priorities, not to promise a number of jobs.")
      )
    )
  ),

  # Page 4: Check new data ----------------------------------------------------------------
  nav_panel(
    "Check new data",
    reading_guide(
      tags$li("Use this page to check whether the model still works on new survey data."),
      tags$li("Step 1: get your file ready, using the list of columns. Step 2: upload it. Then read the coloured result box first; the details follow below it."),
      tags$li("Each check is marked ", HTML(status_badge("Green")), " (fine), ", HTML(status_badge("Amber")), " (find out what changed) or ",
              HTML(status_badge("Red")), " (retrain the model).")
    ),
    layout_columns(
      col_widths = c(7, 5),
      card(
        card_header("1. Get your file ready"),
        p("One row per person aged 15–64 who is working or looking for work, with the columns listed below.",
          "To try it out, upload", code("Datasets/Analytical/model_test.csv"), "from the project folder."),
        accordion(
          open = FALSE,
          accordion_panel(
            "Which columns the file needs",
            tableOutput("format_table"),
            note("Without the", code("employed"), "column the app can still predict, but it cannot measure accuracy.")
          )
        ),
        div(class = "mt-2 d-flex flex-wrap gap-2",
            downloadButton("template", "Download an example file", class = "btn-outline-primary btn-sm"),
            downloadButton("test_data", "Download test data (1,200 people)", class = "btn-primary btn-sm")),
        note("The example file shows the format with 3 rows. The test data is a ready-made file of 1,200 made-up people:",
             "download it and upload it in step 2 to see the whole page working.")
      ),
      card(
        card_header("2. Upload it"),
        fileInput("upload", NULL, accept = ".csv", buttonLabel = "Choose CSV file", width = "100%")
      )
    ),
    uiOutput("results")
  ),

  # Page 5: About the model ---------------------------------------------------------------
  nav_panel(
    "About the model",
    reading_guide(
      tags$li("This page explains what the model does, how good it is, who it works less well for, and when it should be replaced."),
      tags$li(paste0("All scores come from a test on ", num(key$test_people),
                     " surveyed people the model had never seen while it was built, like an exam with new questions.")),
      tags$li("In the tables, read the \"Result\" column first. \"What this means\" explains each result in plain words.")
    ),
    hero(
      "The model in one minute",
      tags$ul(class = "mb-0",
        tags$li("It estimates how likely groups of people are to have a job, based on their education, home internet and background."),
        tags$li(paste0("It is reasonably accurate: shown one person with a job and one without, it picks the one with the job ",
                       round(100 * app_data$baseline$auc), " times out of 100.")),
        tags$li("Use it to compare groups and provinces. Do not use it to make decisions about individual people.")
      )
    ),
    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header("What it is for"),
        p(strong("For:"), "helping National Treasury decide how to split funding between internet access and education, and where to start."),
        p(class = "mb-0", strong("Not for:"), "decisions about individual people (jobs, grants), proving that internet causes employment, or comparing racial groups.")
      ),
      card(
        card_header("How it works"),
        p("It learned from", num(key$training_people), "people in the 2024 Stats SA survey how having a job relates to matric, home internet and the two together,",
          "taking into account age, sex, area, household and phone and computer access."),
        p(class = "mb-0", "It was chosen over two other models (a decision tree and a random forest) because it is almost as accurate as the best of them",
          "and is the only one that measures directly whether education and internet work best together.",
          span(class = "text-muted", "(Technical name: survey-weighted logistic regression.)"))
      )
    ),
    card(
      card_header("How accurate is it?"),
      p(paste0("While building the model we kept ", num(key$test_people), " surveyed people aside. Afterwards we asked the model about them and compared",
               " its answers with what really happened. These are the results. The first row is the most important.")),
      tableOutput("about_metrics"),
      note(paste0("Some rows use yes/no labels: the model calls a person \"employed\" when it gives them a ",
                  round(100 * app_data$threshold), "% chance or more of having a job."))
    ),
    card(
      card_header("Does it work equally well for everyone?"),
      p("It ranks people about equally well in every group (similar ranking scores below), which is why group results can be trusted.",
        "But its yes/no labels are uneven, so it must not be used to judge individuals:"),
      tags$ul(
        tags$li("In the Indian/Asian and White groups, where almost everyone has a job, it rarely spots the few who don't."),
        tags$li("In traditional areas, where about half have a job, it misses many of the people who do.")
      ),
      tableOutput("about_subgroups"),
      note("Groups with few people tested (for example Indian/Asian, farms) have less certain figures.")
    ),
    layout_columns(
      col_widths = c(5, 7),
      card(
        card_header("Limitations"),
        tags$ul(class = "mb-0",
          tags$li("One survey (2024): shows patterns, not causes."),
          tags$li("Education is simplified to \"matric or not\"."),
          tags$li("People with unknown education (1.7%) are left out."),
          tags$li("Small groups have less certain results.")
        )
      ),
      card(
        card_header("When to retrain or stop using it"),
        p("Every file uploaded on \"Check new data\" is tested against these limits:"),
        tableOutput("about_thresholds"),
        note(strong("Retrain"), "when Stats SA releases a new survey or a check shows \"Action needed\".",
             strong("Stop using it"), "if retraining does not fix the ranking score, if Stats SA changes its survey questions,",
             "or if it is being used to judge individuals.")
      )
    ),
    accordion(
      open = FALSE,
      accordion_panel(
        "Glossary",
        tags$dl(class = "mb-0",
          tags$dt("Per 100 (percentage points)"), tags$dd("The difference between two groups. 70% against 64% with a job is \"+6 per 100\": out of 100 people, 6 more have a job."),
          tags$dt("Likely range (95% confidence interval)"), tags$dd("Where the true number almost certainly lies. If the range of a difference includes 0, it may not be real."),
          tags$dt("Work best together (complements)"), tags$dd("Education and internet together are linked to more jobs than each on its own. The opposite (substitutes) would mean one can replace the other."),
          tags$dt("Odds ratio"), tags$dd("The technical measure of \"work best together\": above 1 means yes, below 1 means they replace each other."),
          tags$dt("Ranking score (AUC)"), tags$dd("Shown one person with a job and one without, how often the model picks the one with the job. Guessing gets 50 out of 100."),
          tags$dt("Survey weight"), tags$dd("How many South Africans one surveyed person stands for. Used to turn the survey into national estimates."),
          tags$dt("Drift"), tags$dd("A change in the kind of people in new data compared with the data the model learned from."),
          tags$dt("Labour force"), tags$dd("Everyone aged 15–64 who is working or looking for work.")
        )
      )
    ),
    p(class = "note mt-3",
      paste0("Model: ", app_data$built$model, ". App data built on ", app_data$built$date,
             " by Scripts/3.4) Deployment Preparation.qmd. Data: Statistics South Africa, 2024 survey (isiBalo portal)."))
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
                  paste0("Only ", cell$people, " people in the survey match this group, too few to give a reliable answer. ",
                         "Choose a broader group, for example \"All ages\" or \"Both sexes\".")))
    estimates_for_cell(row)
  })

  group_words <- reactive(describe_group(input$province, input$settlement, input$age_band, input$sex))

  # The answer for the chosen group. The verdict depends on whether the likely
  # range of the difference between the two internet gaps includes 0.
  output$group_answer <- renderUI({
    e <- group_estimates()
    with_matric <- more_or_fewer(e$gap_matric$estimate)
    without_matric <- more_or_fewer(e$gap_below$estimate)
    if (e$interaction$lower > 0) {
      hero(paste0(group_words(), ": education and internet work best together"),
           p(paste0("With matric, home internet is linked to ", with_matric, " people with a job out of every 100. ",
                    "Without matric, only ", without_matric, ".")))
    } else if (e$interaction$upper < 0) {
      hero(paste0(group_words(), ": internet seems to make up for lower education"),
           p(paste0("Home internet is linked to ", without_matric, " people with a job out of every 100 for people without matric, ",
                    "but only ", with_matric, " for people with matric.")))
    } else {
      hero(paste0(group_words(), ": no clear answer for this group"),
           p(paste0("With matric, home internet is linked to ", with_matric, " people with a job out of every 100; without matric, ", without_matric, ". ",
                    "Only ", num(e$people), " people in this group were surveyed, so the difference is uncertain. ",
                    "For South Africa as a whole the answer is clear: the two work best together.")),
           tone = "slate")
    }
  })

  output$group_boxes <- renderUI({
    e <- group_estimates()
    layout_columns(
      col_widths = c(4, 4, 4),
      gap_box("People with matric", e$gap_matric,
              rate_of(e, "Matric or higher", "Home internet"), rate_of(e, "Matric or higher", "No home internet"), "people with matric"),
      gap_box("People without matric", e$gap_below,
              rate_of(e, "Below matric", "Home internet"), rate_of(e, "Below matric", "No home internet"), "people without matric"),
      both_box(e)
    )
  })

  output$group_plot <- renderPlot({
    group_estimates()$groups |>
      mutate(internet = factor(internet, levels = c("No home internet", "Home internet"))) |>
      ggplot(aes(x = education, y = estimate, fill = internet)) +
      geom_col(position = position_dodge(width = 0.8), width = 0.7) +
      geom_errorbar(aes(ymin = lower, ymax = upper), position = position_dodge(width = 0.8), width = 0.12, colour = colours$ink) +
      geom_text(aes(y = upper + 0.035, label = pct(estimate, 0)), position = position_dodge(width = 0.8), size = 5,
                fontface = "bold", colour = colours$ink) +
      scale_fill_manual(values = c("No home internet" = colours$light, "Home internet" = colours$main)) +
      scale_y_continuous(labels = \(x) paste0(round(100 * x), "%"), limits = c(0, 1), expand = c(0, 0)) +
      labs(x = NULL, y = "Share with a job", fill = NULL) +
      chart_theme +
      theme(panel.grid.major.x = element_blank(), axis.text.x = element_text(size = 14, colour = colours$ink))
  })

  output$group_people <- renderUI({
    note(paste0(group_words(), ": ", num(group_estimates()$people), " people surveyed. ",
                "The black lines show the likely range of each bar."))
  })

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
        people = sum(people),
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
      return(hero(paste0("Every province already has at least ", input$target, "% home internet"),
                  p("Move the slider higher to see what more home internet could mean."), tone = "slate"))
    }
    top_rate <- provinces |> slice_max(change, n = 1, with_ties = FALSE)
    top_people <- provinces |> slice_max(additional_employed, n = 1, with_ties = FALSE)
    hero(
      paste0("If ", input$target, "% of people had home internet, about ", approx_num(country$additional_employed),
             " more people could have a job"),
      p(paste0("Today ", pct(country$internet_share, 0), " have home internet. Based on today's pattern, the share of the labour force with a job would rise from ",
               pct(country$employed_today), " to ", pct(country$employed_target), ".")),
      p(paste0(top_rate$province, " would gain the most for its size; ", top_people$province, " would gain the most people."))
    )
  })

  output$scenario_boxes <- renderUI({
    country <- scenario_national()
    provinces <- scenario()
    if (all(provinces$change == 0)) return(NULL)
    top_rate <- provinces |> slice_max(change, n = 1, with_ties = FALSE)
    top_people <- provinces |> slice_max(additional_employed, n = 1, with_ties = FALSE)
    largest <- top_people$province == provinces$province[which.max(provinces$labour_force)]
    layout_columns(
      col_widths = c(4, 4, 4),
      value_box(title = "South Africa", value = per_100(country$change), theme = box_main,
                p(strong(paste0("About ", approx_num(country$additional_employed), " more people with a job."))),
                p(paste0("Out of every 100 people in the labour force, about ", round(100 * country$change, 1),
                         " more would have a job: ", pct(country$employed_target), " instead of ", pct(country$employed_today), "."))),
      value_box(title = "Biggest gain for its size", value = span(class = "fs-3", top_rate$province), theme = box_plain,
                p(strong(paste0(signed(top_rate$change), " per 100"))),
                p(paste0("Out of every 100 people there, about ", round(100 * top_rate$change), " more would have a job. Only ",
                         pct(top_rate$internet_share, 0), " have home internet today, so it has the most room to grow."))),
      value_box(title = "Most extra people with a job", value = span(class = "fs-3", top_people$province), theme = box_plain,
                p(strong(paste0("About ", approx_num(top_people$additional_employed), " people"))),
                p(if (top_people$province == top_rate$province) "It has both the biggest gain per 100 and enough people for that gain to add up the most."
                  else if (largest) "Not the biggest gain per 100, but it has the largest labour force, so the gain adds up to the most people."
                  else "It combines a sizeable labour force with room to gain."))
    )
  })

  output$province_plot <- renderPlot({
    scenario() |>
      mutate(province = fct_reorder(province, change)) |>
      ggplot(aes(y = province)) +
      geom_segment(aes(x = employed_today, xend = employed_target, yend = province), colour = colours$muted, linewidth = 1.6) +
      geom_point(aes(x = employed_today, colour = "Today"), size = 4.5) +
      geom_point(aes(x = employed_target, colour = "At the target"), size = 4.5) +
      geom_text(aes(x = employed_target, label = signed(change)), hjust = -0.45, size = 4.5, colour = colours$main_dark, fontface = "bold") +
      scale_colour_manual(values = c("Today" = colours$muted, "At the target" = colours$main), breaks = c("Today", "At the target")) +
      scale_x_continuous(labels = \(x) paste0(round(100 * x), "%"), expand = expansion(mult = c(0.05, 0.12))) +
      labs(x = "Share of the labour force with a job", y = NULL, colour = NULL) +
      chart_theme +
      theme(panel.grid.major.y = element_blank(), panel.grid.major.x = element_line(colour = colours$line),
            axis.text.y = element_text(size = 13, colour = colours$ink))
  })

  output$province_table <- plain_table({
    bind_rows(scenario() |> arrange(desc(change)), scenario_national()) |>
      transmute(
        Province = province,
        `People surveyed` = num(people),
        `Labour force (estimate)` = approx_num(labour_force),
        `With a job today` = pct(employed_today),
        `Home internet today` = pct(internet_share, 0),
        `With a job at the target` = pct(employed_target),
        `Gain per 100` = signed(change),
        `Extra people with a job` = approx_num(additional_employed)
      )
  })

  # Page 4: Check new data ------------------------------------------------------------------

  output$format_table <- html_table(format_table)

  output$template <- downloadHandler(
    filename = "employment_data_example.csv",
    content = function(file) write_csv(template_file, file)
  )

  # Ready-made test data: 1,200 made-up people in the right format, kept in the
  # app folder. Their mix matches the training data and "employed" was simulated
  # from the model's own chances, so every check on this page can run.
  output$test_data <- downloadHandler(
    filename = "test_data.csv",
    content = function(file) file.copy("dummy_employment_test_data.csv", file)
  )

  # Read -> validate -> prepare -> predict, once per upload
  scored <- reactive({
    req(input$upload)
    # Every column as text, so wrong types are reported by validate_input()
    raw <- tryCatch(
      read_csv(input$upload$datapath, col_types = cols(.default = col_character()), show_col_types = FALSE),
      error = function(e) NULL
    )
    validate(need(!is.null(raw), "This file could not be opened as a CSV file."))

    checked <- validate_input(raw)
    if (checked$fatal) return(list(checked = checked, fatal = TRUE, rows_read = nrow(raw)))

    prepared <- prepare_employment_frame(checked$data[checked$valid, ])
    list(
      checked = checked,
      fatal = FALSE,
      rows_read = nrow(raw),
      prepared = prepared,
      probability = predict_slim(slim_model, prepared),
      has_outcome = "employed" %in% names(prepared) && n_distinct(prepared$employed) == 2
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
                check = paste0("Same mix of ", drift_names[variable], "?"),
                value = round(psi, 3), expected = "0", status, meaning)
    if (!s$has_outcome) return(drift)

    performance <- describe_metrics(upload_metrics(), app_data$baseline) |>
      filter(status != "-") |>
      transmute(variable = NA_character_, check = measure, value, expected = as.character(test_set), status, meaning = in_short)

    groups <- subgroup_auc(s$prepared$employed, s$probability, s$prepared$population_group)
    gap <- if (nrow(groups) >= 2) max(groups$auc) - min(groups$auc) else NA_real_
    fairness <- tibble(
      variable = NA_character_,
      check = "Equally accurate for all population groups?",
      value = round(gap, 3),
      expected = as.character(round(app_data$baseline_subgroup_gap, 3)),
      status = subgroup_gap_status(gap, app_data$baseline_subgroup_gap),
      meaning = if (is.na(gap)) paste0("Not checked: needs at least two population groups with ", monitoring_thresholds$min_group_rows, "+ people.")
                else "Gap between the best and worst group's ranking score. A growing gap means the model is becoming less fair."
    )
    bind_rows(performance |> mutate(value = round(value, 3)), fairness, drift)
  })

  # The result of the upload in plain words, shown before the detailed tables
  output$summary_card <- renderUI({
    s <- scored()
    line <- function(status, label, text) tags$li(HTML(status_badge(status)), " ", strong(label), " ", text)

    if (s$fatal) {
      problem <- s$checked$checks |> filter(status == "Fail") |> slice(1)
      return(hero("This file cannot be used",
                  p(problem$detail),
                  p("Check \"Which columns the file needs\" above, fix the file and upload it again."),
                  tone = "red"))
    }

    # Unweighted: the people in the file as they are, so these rates match the
    # accuracy measures below
    rows_used <- nrow(s$prepared)
    predicted_rate <- mean(s$probability)
    checks <- monitoring_checks()
    changed <- checks |> filter(!is.na(variable), status != "Green")

    file_line <- line(if (rows_used < s$rows_read) "Warning" else "Pass", "File:",
                      paste0(num(rows_used), " of ", num(s$rows_read), " rows could be used",
                             if (rows_used < s$rows_read) paste0(" (", num(s$rows_read - rows_used), " skipped, see the data checks below).") else "."))
    prediction_line <- line("Info", "Prediction:",
                            paste0(pct(predicted_rate), " of these people are expected to have a job",
                                   if (s$has_outcome) {
                                     paste0(" (in reality: ", pct(mean(s$prepared$employed == "Employed")), ").")
                                   } else "."))

    if (too_few_rows()) {
      return(hero("Result",
                  tags$ul(class = "result-list", file_line, prediction_line,
                          line("Not checked", "Reliability:", paste0("too few rows (under ", monitoring_thresholds$min_rows, ") to judge accuracy fairly."))),
                  tone = "slate"))
    }

    accuracy_line <- if (s$has_outcome) {
      m <- upload_metrics()
      auc_status <- traffic_light(m$auc, monitoring_thresholds$auc)
      line(auc_status, "Accuracy:",
           paste0(switch(auc_status, Green = "as good as when the model was tested", Amber = "a bit lower than when tested",
                         "clearly lower than when tested"),
                  " (right ", round(100 * m$auc), " times out of 100; normally ", round(100 * app_data$baseline$auc), ")."))
    } else {
      line("Info", "Accuracy:", "cannot be measured, because the file has no \"employed\" column.")
    }
    drift_line <- line(if (nrow(changed) == 0) "Green" else if (any(changed$status == "Red")) "Red" else "Amber", "Data:",
                       if (nrow(changed) == 0) "the same kind of people as the model learned from."
                       else paste0("different from what the model learned from, in ", paste(drift_names[changed$variable], collapse = ", "), "."))
    worst <- if (any(checks$status == "Red")) "Red" else if (any(checks$status == "Amber")) "Amber" else "Green"

    hero(overall_verdict(checks$status),
         tags$ul(class = "result-list", file_line, prediction_line, accuracy_line, drift_line),
         tone = c(Green = "green", Amber = "amber", Red = "red")[[worst]])
  })

  output$results <- renderUI({
    s <- scored()
    tagList(
      uiOutput("summary_card"),
      if (!s$fatal) card(
        card_header("Predicted employment by group"),
        p("Out of 100 people in each group, how many the model expects to have a job",
          if (s$has_outcome) "and how many really do. Close numbers mean the model fits that group well." else ".",
          "Groups under 50 people are marked as unreliable."),
        selectInput("group_by", NULL, c("Matric × internet", "Province", "Area", "Sex", "Age"), width = "260px"),
        tableOutput("group_table")
      ),
      if (!s$fatal && s$has_outcome) card(
        card_header("How accurate is the model on this file?"),
        p("Each measure compared with the result when the model was first tested. The first row is the main score."),
        tableOutput("metrics_table"),
        layout_columns(
          col_widths = c(5, 7),
          tableOutput("confusion_table"),
          note(paste0("Right and wrong labels, counted in people. A person is labelled \"employed\" when the model gives them at least a ",
                      round(100 * app_data$threshold), "% chance of having a job. The labels are only used to measure accuracy."))
        )
      ),
      if (!s$fatal) card(
        card_header("Can the model still be trusted?"),
        p("Checks that compare this file with the data the model was built and tested on.",
          HTML(paste0(status_badge("Green"), " fine &nbsp; ", status_badge("Amber"), " find out why &nbsp; ",
                      status_badge("Red"), " retrain the model"))),
        tableOutput("monitoring_table")
      ),
      accordion(
        open = s$fatal,
        accordion_panel("Data checks on the file", tableOutput("validation_table"))
      )
    )
  })

  output$validation_table <- html_table({
    scored()$checked$checks |>
      transmute(Check = check, Result = status_badge(status), Rows = num(rows), Details = detail)
  })

  output$group_table <- plain_table({
    s <- scored()
    req(!s$fatal, input$group_by)
    data <- s$prepared |>
      mutate(
        probability = s$probability,
        # switch() only calculates the grouping the user chose
        group = switch(input$group_by,
                       "Matric × internet" = paste(if_else(matric_plus == 1, "Matric or higher", "Below matric"), "·",
                                                   if_else(any_home_internet == 1, "home internet", "no home internet")),
                       "Province" = as.character(province),
                       "Area" = as.character(settlement_type),
                       "Sex" = if_else(female == 1, "Female", "Male"),
                       "Age" = as.character(make_age_band(age_centred)))
      )
    summary <- data |>
      group_by(Group = group) |>
      summarise(
        People = n(),
        `Expected to have a job` = mean(probability),
        `Really have a job` = if (s$has_outcome) mean(employed == "Employed") else NA_real_,
        .groups = "drop"
      ) |>
      mutate(Note = if_else(People < 50, "Too few people: unreliable", ""),
             across(c(`Expected to have a job`, `Really have a job`), pct),
             People = num(People))
    if (!s$has_outcome) summary <- select(summary, -`Really have a job`)
    summary
  })

  output$metrics_table <- html_table({
    describe_metrics(upload_metrics(), app_data$baseline) |>
      transmute(Measure = measure, Result = in_short, `This file` = format(value, nsmall = 3),
                `When tested` = format(test_set, nsmall = 3),
                Status = if_else(status == "-", "", status_badge(if (too_few_rows()) "Not checked" else status)),
                `What this means` = meaning)
  })

  output$confusion_table <- plain_table({
    confusion_table(upload_metrics()) |>
      transmute(` ` = if_else(actual == "Employed", "Has a job", "No job"),
                `Labelled employed` = num(`Predicted employed`),
                `Labelled unemployed` = num(`Predicted unemployed`))
  })

  output$monitoring_table <- html_table({
    monitoring_checks() |>
      mutate(status = if (too_few_rows()) "Not checked" else status) |>
      transmute(Check = check, `This file` = format(value), Normal = expected,
                Status = status_badge(status), `In plain words` = meaning)
  })

  # Page 5: About the model -----------------------------------------------------------

  output$about_metrics <- html_table(
    describe_metrics(app_data$baseline, app_data$baseline) |>
      select(Measure = measure, Result = in_short, `What this means` = meaning)
  )

  output$about_subgroups <- plain_table(
    app_data$subgroups |>
      transmute(Group = paste0(group, " (", tolower(grouping), ")"), `People tested` = num(people),
                `Have a job` = pct(share_employed, 0),
                `Ranking score (out of 100)` = round(100 * auc),
                `Employed spotted` = pct(sensitivity, 0), `Unemployed spotted` = pct(specificity, 0)),
    digits = 0
  )

  output$about_thresholds <- html_table({
    t <- monitoring_thresholds
    tribble(
      ~Check, ~ok, ~investigate, ~action,
      "Ranking score (AUC)", paste("at least", t$auc[["amber"]]), paste(t$auc[["red"]], "to", t$auc[["amber"]]), paste("below", t$auc[["red"]]),
      "Balanced accuracy", paste("at least", t$balanced_accuracy[["amber"]]),
        paste(t$balanced_accuracy[["red"]], "to", t$balanced_accuracy[["amber"]]), paste("below", t$balanced_accuracy[["red"]]),
      "Prediction error (Brier score)", paste("at most", t$brier[["amber"]]),
        paste(t$brier[["amber"]], "to", t$brier[["red"]]), paste("above", t$brier[["red"]]),
      "Predicted vs actual (calibration gap)", paste("within", t$calibration_gap[["amber"]]),
        paste(t$calibration_gap[["amber"]], "to", t$calibration_gap[["red"]]), paste("over", t$calibration_gap[["red"]]),
      "Change in the mix of people (drift)", paste("below", t$psi[["amber"]]), paste(t$psi[["amber"]], "to", t$psi[["red"]]), paste("above", t$psi[["red"]]),
      "Gap between population groups grows by", paste("at most", t$subgroup_auc_gap[["amber"]]),
        paste(t$subgroup_auc_gap[["amber"]], "to", t$subgroup_auc_gap[["red"]]), paste("over", t$subgroup_auc_gap[["red"]])
    ) |>
      setNames(c("Check", status_badge("Green"), status_badge("Amber"), status_badge("Red")))
  })
}

shinyApp(ui, server)
