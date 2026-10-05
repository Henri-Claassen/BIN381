# BIN381: Digital Access, Education and Employment in South Africa

Business Intelligence 381 group project, **Group 5**:
Jandre Neethling · Henri Claassen · Declin Vorkel

The project follows the **CRISP-DM** methodology to analyse 2024 Statistics South Africa survey data within the brief *Socioeconomic Development & Household Well-being in South Africa (SDHSA)*.

---

## About the project

South Africa combines high unemployment with unequal access to the internet. This project asks whether **household digital access** (internet, computers and smartphones) is linked to **better education**, and whether it makes **education pay off more in the job market**.

**Stakeholder:** the National Treasury, which has to decide how to split limited funding between digital-access subsidies and education spending. The key question is whether the two **reinforce** each other (complements) or can **stand in** for each other (substitutes).

The analysis is organised into four areas:

| Area | Question | Data |
|---|---|---|
| **A** | Is digital access associated with better education outcomes? | D08 → D02 |
| **B** | Is higher education associated with being employed? | D02 → D03 |
| **C** | Does digital access strengthen (or replace) the education–employment link? | Education × digital access → D03 |
| **D** | Among employed people, is income related to education and digital access? *(exploratory)* | D03 |

All findings are **associations, not causes**: the data are a single 2024 snapshot.

---

## Data

Eleven datasets from Statistics South Africa (via the [isiBalo portal](https://isibaloweb.statssa.gov.za/)). Four are used:

| Dataset | Content | Grain |
|---|---|---|
| D01 Population Profile | Age, sex, population group, province, settlement type, survey weights | Person |
| D02 Learning Profile | Education level, attendance, institution type | Person |
| D03 Economic Participation | Employment status, salary | Person |
| D08 Connectivity Access | Fixed/mobile internet, computer, smartphones | Household |

D04–D07, D09 and D10 are not needed for the research areas. D11 comes from a separate survey and cannot be linked to the others. The full reasoning is in [`Data Selection and Analytical Grain.md`](Documentation/Milestone%20Documentation/Milestone%202/Data%20Selection%20and%20Analytical%20Grain.md).

**Analytical grain:** one row per person aged 15–64 (45,413 people in 19,780 households), with their household's digital-access values attached.

---

## Repository structure

```
BIN381/
├── BIN381.Rproj                          RStudio project (open this first)
├── README.md
│
├── Scripts/                              Quarto notebooks (run in this order)
│   ├── _quarto.yml                       Sends every rendered notebook to Documentation/Rendered Documentation
│   ├── 1) EDA.qmd                        Milestone 1: data inspection, EDA and data-quality checks
│   ├── 2.1) Data Preprocessing.qmd       Milestone 2: cleaning, integration, feature engineering
│   ├── 2.2) Train-Test Split.qmd         Milestone 2: target, class balance, household-grouped split
│   ├── 3.1) Employment Model.qmd         Milestone 3: logistic regression, decision tree, random forest
│   ├── 3.2) Income Model.qmd             Milestone 3: linear regression, random forest
│   ├── 3.3) Model Evaluation.qmd         Milestone 3: tuning, test-set evaluation, model selection
│   ├── 3.4) Deployment Preparation.qmd   Milestone 3: deployment strategy, builds Shiny-App/app_data.rds
│   └── R/
│       └── model_preparation.R           Reads and prepares data the same way everywhere; model formulas
│                                         (shared by notebooks 3.1–3.4 and the Shiny app)
│
├── Shiny-App/                            Milestone 3: the deployed Shiny app
│   ├── app.R                             The app
│   ├── app_data.rds                      What the app loads: slim model and aggregated tables only
│   ├── deployment_model.R                The slim model the app predicts with
│   ├── validate_input.R                  Checks uploaded data; defines the app's data format
│   └── monitoring.R                      Accuracy measures, drift checks and monitoring thresholds
│
├── Models/                               Fitted models (.rds) and classification thresholds
│
├── Datasets/
│   ├── D01_…csv – D11_…csv               Original Stats SA files (read only, never modified)
│   ├── Cleaned/                          One cleaned file per selected source dataset
│   │   ├── D01_clean.csv                 45,413 people
│   │   ├── D02_clean.csv                 45,413 people
│   │   ├── D03_clean.csv                 45,413 people
│   │   └── D08_clean.csv                 20,940 households
│   └── Analytical/                       Integrated and modelling datasets
│       ├── analytical_dataset.csv        All four datasets joined + engineered features (Power BI / description)
│       ├── model_data.csv                Employment model: labour force only (28,742 people)
│       ├── model_train.csv               80% of model_data households
│       ├── model_test.csv                20% of model_data households
│       ├── income_data.csv               Income question: employed with a usable salary (18,017 people)
│       ├── income_train.csv              80% of income_data households
│       └── income_test.csv               20% of income_data households
│
├── Documentation/
│   ├── Milestone Documentation/
│   │   ├── Milestone 1/                  Milestone 1 report and data dictionary
│   │   ├── Milestone 2/
│   │   │   ├── BIN381 Milestone 2.docx / .pdf        Data Preparation report
│   │   │   ├── Cleaned Datasets Data Dictionary.md   Every source and engineered variable
│   │   │   └── Data Selection and Analytical Grain.md  Task 1: dataset, record and column selection
│   │   ├── Milestone 3/
│   │   │   └── Milestone 3 Submit.docx                Milestone 3 write-up: model choices, tuning, evaluation
│   │   └── Project Outline/              Lecturer's project outline and milestone briefs
│   └── Rendered Documentation/           Rendered notebooks (code, results, verification),
│                                         named after the notebook that produced them
│
└── Power Bi/
    ├── Initial Power Bi.pbix             Milestone 1 exploratory dashboard
    └── Dashboard_*_Theme.json            Report colour themes
```

---

## How to reproduce

1. **Open `BIN381.Rproj`** in RStudio, so relative paths such as `../Datasets/` resolve correctly.
2. **Install the packages** (once). Every notebook and R file also starts with a commented-out `install.packages()` line listing exactly the packages it needs:
   ```r
   install.packages(c("tidyverse", "janitor", "skimr", "visdat", "survey", "rpart", "rpart.plot",
                      "ranger", "pROC", "caret", "shiny", "bslib"))
   ```
   `dplyr` 1.1.0 or newer is required: the joins use its `relationship` and `unmatched` checks.
3. **Run the notebooks in order:**
   1. `Scripts/2.1) Data Preprocessing.qmd`: reads the original files and writes `Datasets/Cleaned/` and `Datasets/Analytical/` (`analytical_dataset.csv`, `model_data.csv`, `income_data.csv`).
   2. `Scripts/2.2) Train-Test Split.qmd`: reads `model_data.csv` and `income_data.csv` and writes the four training and test files.
   3. `Scripts/3.1) Employment Model.qmd` and `Scripts/3.2) Income Model.qmd`: fit the candidate models on the training files and save them to `Models/`.
   4. `Scripts/3.3) Model Evaluation.qmd`: tunes the models, evaluates them on the test files and selects the final models.
   5. `Scripts/3.4) Deployment Preparation.qmd`: builds `Shiny-App/app_data.rds` for the Shiny app.

   Each notebook reads from disk, so it can be rerun on its own once its inputs exist. Every random step uses seed 67, so reruns produce identical files and models. Rendering a notebook (the **Render** button in RStudio, or `quarto render` in the `Scripts` folder) saves the output in `Documentation/Rendered Documentation/`; `Scripts/_quarto.yml` sets this. Rendering to PDF additionally needs a LaTeX installation (e.g. `quarto install tinytex`).

### Running the Shiny app

With `BIN381.Rproj` open, run:

```r
shiny::runApp("Shiny-App")
```

The app has five pages: an overview of the findings, the employment rates of the four matric × internet groups, province scenarios, a page to check new data against the model (upload `Datasets/Analytical/model_test.csv` for a working example), and a page about the model. It loads only `app_data.rds`, which holds the slim model and aggregated tables, never survey microdata. It shows results for groups of people only, never for individuals.

### Reading the output files

- **Read `household_id` (and `person_number`) as text.** They are 18-digit numbers that R would otherwise round, merging different households:
  ```r
  read_csv("Datasets/Analytical/model_data.csv", col_types = cols(household_id = col_character()))
  ```
- **Empty cells mean missing**, and every missing value has a documented reason in the data dictionary.
- **Re-apply the reference levels** after reading `model_data.csv` or its train/test files, because a CSV cannot store them. The code is in section 2 of the [data dictionary](Documentation/Milestone%20Documentation/Milestone%202/Cleaned%20Datasets%20Data%20Dictionary.md).
- **`person_weight` is a survey weight.** Use it for population estimates, never as a predictor, and never rescale it.

---

## Project status

| Milestone | CRISP-DM phases | Status |
|---|---|---|
| 1. Business and Data Understanding | Business understanding, data understanding | ✅ Complete |
| 2. Data Preprocessing | Data preparation | ✅ Complete |
| 3. Modelling, Evaluation and Deployment | Modelling, evaluation, deployment (Shiny) | ✅ Complete |
| 4. Final Report and Presentation | Synthesis across all phases | ⏳ Upcoming |

---

## Data source

Statistics South Africa, 2026, *isiBalo data portal*. Available at: https://isibaloweb.statssa.gov.za/

The data are de-identified survey microdata used for academic purposes. Results should not be published for groups small enough to identify individuals.
