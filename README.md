# BIN381: Digital Access, Education and Employment in South Africa

Business Intelligence 381 group project (Belgium Campus iTversity, 2026), **Group 5**:
Jandre Neethling (601304) · Henri Claassen (601720) · Declin Vorkel (601756)

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

D04–D07, D09 and D10 are not needed for the research areas. D11 comes from a separate survey and cannot be linked to the others. The full reasoning is in [`Data Selection and Analytical Grain.md`](Milestone%20Documentation/Milestone%202/Data%20Selection%20and%20Analytical%20Grain.md).

**Analytical grain:** one row per person aged 15–64 (45,413 people in 19,780 households), with their household's digital-access values attached.

---

## Repository structure

```
BIN381/
├── BIN381.Rproj                      RStudio project (open this first)
├── README.md
│
├── Scripts/                          Quarto notebooks (run in this order)
│   ├── EDA.qmd                       Milestone 1: data inspection, EDA and data-quality checks
│   ├── Data Preprocessing.qmd        Milestone 2: cleaning, integration, feature engineering
│   └── Train-Test Split.qmd          Milestone 2: target, class balance, household-grouped split
│
├── Datasets/
│   ├── D01_…csv – D11_…csv           Original Stats SA files (read only, never modified)
│   ├── Cleaned/                      One cleaned file per selected source dataset
│   │   ├── D01_clean.csv             45,413 people
│   │   ├── D02_clean.csv             45,413 people
│   │   ├── D03_clean.csv             45,413 people
│   │   └── D08_clean.csv             20,940 households
│   └── Analytical/                   Integrated and modelling datasets
│       ├── analytical_dataset.csv    All four datasets joined + engineered features (Power BI / description)
│       ├── model_data.csv            Employment model: labour force only (28,742 people)
│       ├── model_train.csv           80% of model_data households
│       ├── model_test.csv            20% of model_data households
│       ├── income_data.csv           Income question: employed with a usable salary (18,017 people)
│       ├── income_train.csv          80% of income_data households
│       └── income_test.csv           20% of income_data households
│
├── Milestone Documentation/
│   ├── Project Outline/              Lecturer's project outline and Milestone 2 brief
│   ├── Milestone 1/                  Milestone 1 report and data dictionary
│   └── Milestone 2/
│       ├── BIN381 Milestone 2.docx / .pdf        Data Preparation report
│       ├── Cleaned Datasets Data Dictionary.md   Every source and engineered variable
│       └── Data Selection and Analytical Grain.md  Task 1: dataset, record and column selection
│
├── Rendered Documentation/           Rendered notebook output (code, results, verification)
│   ├── EDA.html / EDA.pdf
│   └── Milestone 2/
│       ├── Data-Preprocessing.pdf
│       └── Train-Test-Split.pdf
│
└── Power Bi/
    ├── Initial Power Bi.pbix         Milestone 1 exploratory dashboard
    └── Dashboard_*_Theme.json        Report colour themes
```

---

## How to reproduce

1. **Open `BIN381.Rproj`** in RStudio, so relative paths such as `../Datasets/` resolve correctly.
2. **Install the packages** (once):
   ```r
   install.packages(c("tidyverse", "janitor", "skimr", "visdat"))
   ```
   `dplyr` 1.1.0 or newer is required: the joins use its `relationship` and `unmatched` checks.
3. **Run the notebooks in order:**
   1. `Scripts/Data Preprocessing.qmd`: reads the original files and writes `Datasets/Cleaned/` and `Datasets/Analytical/` (`analytical_dataset.csv`, `model_data.csv`, `income_data.csv`).
   2. `Scripts/Train-Test Split.qmd`: reads `model_data.csv` and `income_data.csv` and writes the four training and test files.

   Each notebook reads from disk, so either can be rerun on its own once its inputs exist. The split uses `set.seed(67)`, so reruns produce identical files. Rendering to PDF additionally needs a LaTeX installation (e.g. `quarto install tinytex`).

### Reading the output files

- **Read `household_id` (and `person_number`) as text.** They are 18-digit numbers that R would otherwise round, merging different households:
  ```r
  read_csv("Datasets/Analytical/model_data.csv", col_types = cols(household_id = col_character()))
  ```
- **Empty cells mean missing**, and every missing value has a documented reason in the data dictionary.
- **Re-apply the reference levels** after reading `model_data.csv` or its train/test files, because a CSV cannot store them. The code is in section 2 of the [data dictionary](Milestone%20Documentation/Milestone%202/Cleaned%20Datasets%20Data%20Dictionary.md).
- **`person_weight` is a survey weight.** Use it for population estimates, never as a predictor, and never rescale it.

---

## Project status

| Milestone | CRISP-DM phases | Status |
|---|---|---|
| 1. Business and Data Understanding | Business understanding, data understanding | ✅ Complete |
| 2. Data Preprocessing | Data preparation | ✅ Complete |
| 3. Modelling, Evaluation and Deployment | Modelling, evaluation, deployment (Shiny) | ⏳ Upcoming |
| 4. Final Report and Presentation | Synthesis across all phases | ⏳ Upcoming |

---

## Data source

Statistics South Africa, 2026, *isiBalo data portal*. Available at: https://isibaloweb.statssa.gov.za/

The data are de-identified survey microdata used for academic purposes. Results should not be published for groups small enough to identify individuals.
