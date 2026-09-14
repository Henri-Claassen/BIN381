# Data Dictionary: Cleaned and Analytical Datasets

**BIN381 Group 5 – Milestone 2 (Data Preparation)**

This dictionary describes the files produced by `Scripts/Data Preprocessing.qmd`:

- the four cleaned files in `Datasets/Cleaned/` (section 8.2), one per selected source dataset, described in 4–9 below, and
- the three analytical files in `Datasets/Analytical/` (section 10.6), built after the cleaned datasets are integrated (section 9) and the engineered features are added (section 10), described in 10–13 below.

Code labels come from the *BIN381 Project Data Dictionary* (Milestone 1). Counts are taken from the files themselves. "Section" numbers refer to the preprocessing report; plain numbers such as "see 4.2" refer to this dictionary.

---

## 1. Overview

**Cleaned files** (`Datasets/Cleaned/`, section 8.2)

| File | Grain (one row per…) | Key | Rows | Columns | Source file |
|---|---|---|---|---|---|
| `D01_clean.csv` | working-age person (15–64) | `household_id` + `person_number` | 45,413 | 15 | `D01_Population_Profile.csv` |
| `D02_clean.csv` | working-age person (15–64) | `household_id` + `person_number` | 45,413 | 10 | `D02_Learning_Profile.csv` |
| `D03_clean.csv` | working-age person (15–64) | `household_id` + `person_number` | 45,413 | 7 | `D03_Economic_Participation.csv` |
| `D08_clean.csv` | household | `household_id` | 20,940 | 8 | `D08_Connectivity_Access.csv` |

- D01, D02 and D03 contain exactly the same 45,413 people (19,780 households). Each key appears once.
- D08 keeps all 20,940 households. 1,160 of them have no working-age member, so they have no match in D01–D03.
- All four are linked through `household_id`. D01–D03 are linked one-to-one on `household_id` + `person_number`, and D08 joins many-to-one on `household_id`.

**Analytical files** (`Datasets/Analytical/`, section 10.6)

| File | Grain (one row per…) | Key | Rows | Columns | Built from |
|---|---|---|---|---|---|
| `analytical_dataset.csv` | working-age person (15–64) | `household_id` + `person_number` | 45,413 | 59 | The four cleaned datasets joined (section 9), plus 24 engineered columns (section 10) |
| `model_data.csv` | person in the labour force (employed or unemployed) | none (`person_number` is not included) | 28,742 | 24 | Filtered and encoded from `analytical_dataset.csv` (sections 10.4–10.5) |
| `income_data.csv` | employed person with a usable salary | none (`person_number` is not included) | 18,017 | 13 | Filtered from `analytical_dataset.csv` (section 10.6) |

- `analytical_dataset.csv` contains every column of the four cleaned files (35 columns, with the keys counted once) plus the 24 engineered columns in 10. Each person also carries their own household's D08 values, so household values are repeated for every working-age member of the household.
- `model_data.csv` and `income_data.csv` are subsets for the two analysis questions: employment (main question, see 11) and income (secondary question, see 12). `household_id` is kept in both for the household-grouped train/test split.

---

## 2. How to read the files

1. **Read the IDs as text.** `household_id` is 18 digits long. Read as a number, it gets rounded, and different households merge. `person_number` has a leading zero ("01", "02", …).
   ```r
   D01 <- read_csv("Datasets/Cleaned/D01_clean.csv",
                   col_types = cols(household_id = col_character(), person_number = col_character()))
   D08 <- read_csv("Datasets/Cleaned/D08_clean.csv", col_types = cols(household_id = col_character()))
   ```
   In Power BI, set both columns to **Text** before loading.
2. **An empty cell means missing.** R reads it as `NA`, and Power BI reads it as blank.
3. **Label columns are plain text in a CSV.** A CSV does not store the order of categories. Where the order matters, re-apply the order given in the code tables below (for example, for `education_level`).
4. **Read the analytical files the same way.** `analytical_dataset.csv` has both ID columns; `model_data.csv` and `income_data.csv` only have `household_id`.
   ```r
   analytical <- read_csv("Datasets/Analytical/analytical_dataset.csv",
                          col_types = cols(household_id = col_character(), person_number = col_character()))
   model_data <- read_csv("Datasets/Analytical/model_data.csv", col_types = cols(household_id = col_character()))
   income_data <- read_csv("Datasets/Analytical/income_data.csv", col_types = cols(household_id = col_character()))
   ```
5. **Re-apply the reference levels before modelling.** The reference level of each category (the group every other level is compared with) is set in section 10.5, but a CSV cannot store it. Re-apply it after reading `model_data.csv` (the levels are listed in 11.1):
   ```r
   model_data <- model_data |>
     mutate(
       employed = factor(employed, levels = c("Unemployed", "Employed")),
       education_band = fct_relevel(education_band, "Some secondary"),
       province = fct_relevel(province, "Gauteng"),
       population_group = fct_relevel(population_group, "Black African"),
       settlement_type = fct_relevel(settlement_type, "Metro urban"),
       edu_digital_group = fct_relevel(edu_digital_group, "Below matric, no internet"),
       smartphone_access = fct_relevel(smartphone_access, "None"),
       other_member_matric = fct_relevel(other_member_matric, "No")
     )
   ```

---

## 3. Column naming conventions

| Pattern | Meaning | Example |
|---|---|---|
| `…_code` (and `metro_indicator`) | The **original survey code**, kept unchanged so every label can be traced back to its source value | `sex_code` = 1 |
| Same name without `_code` | **Label column** created in section 6 with the data dictionary's label. Non-response and undocumented codes are left **blank** here, while the `_code` column still holds them | `sex` = "Male" |
| `lab_salary_raw` | Original column name from the source (kept as is) | |
| `has_…`, `female`, `matric_plus`, `any_home_internet`, `youth`, `elderly_in_household` | **Engineered 0/1 column** (section 10). 1 always means "yes" (has it, female, matric or higher, aged 15–34, …) and 0 means "no". Non-response codes stay blank | `has_computer` = 1 |
| `n_…` | **Engineered count** of household members (section 10.3.5) | `n_children_under15` = 2 |
| Other new names in `Datasets/Analytical/` | **Engineered feature** (section 10), described in 10 below | `education_band` = "Matric" |

Every value that was changed during cleaning is documented, with before-and-after evidence, in the preprocessing report section given in each column's description.

---

## 4. D01_clean.csv – Population profile

### 4.1 Columns

| Column | Type | Description | Missing |
|---|---|---|---|
| `household_id` | text (18 digits) | Household identifier. The first 11 digits are the PSU. 55 IDs that were blank in the uncleaned file were recovered by matching to D03 (section 2.1); 18 of these people are aged 15–64. | 0 |
| `person_number` | text | Person's number within the household: "01" to "19" in the cleaned data. | 0 |
| `psu` | number (11 digits) | Primary Sampling Unit, the geographic sampling cluster. It always equals the first 11 digits of `household_id`. 3,204 distinct PSUs. | 0 |
| `province_code` | number | Province code (see 4.2). | 0 |
| `sex_code` | number | Sex code (see 4.2). | 0 |
| `age` | number | Age in completed years. Limited to 15–64 by record selection (section 5). Among these people, 60 blank ages and 13 invalid ages (−7, −3, 150, 175) were replaced with the same person's age from D03 (section 2.4). | 0 |
| `population_group_code` | number | Population group code (see 4.2). | 0 |
| `geo_type_code` | number | Geography type code (see 4.2). | 0 |
| `metro_indicator` | number | Whether the person lives in a metropolitan municipality (see 4.2). | 0 |
| `person_weight` | number | Survey weight: how many people in the South African population this person represents. Range 50–5,531, and the weights of the 45,413 people sum to about 41.9 million. **Never trim or scale it.** Use it for population estimates. | 0 |
| `province` | text | Label for `province_code`. | 0 |
| `sex` | text | Label for `sex_code`. | 0 |
| `population_group` | text | Label for `population_group_code`. | 0 |
| `geo_type` | text | Label for `geo_type_code`. | 0 |
| `metro` | text | Label for `metro_indicator`. | 0 |

### 4.2 Codes

**`province_code` → `province`**

| Code | Label | People |
|---|---|---|
| 1 | Western Cape | 4,484 |
| 2 | Eastern Cape | 5,584 |
| 3 | Northern Cape | 1,920 |
| 4 | Free State | 2,603 |
| 5 | KwaZulu-Natal | 7,989 |
| 6 | North West | 2,665 |
| 7 | Gauteng | 11,612 |
| 8 | Mpumalanga | 3,675 |
| 9 | Limpopo | 4,881 |

**`sex_code` → `sex`**

| Code | Label | People |
|---|---|---|
| 1 | Male | 21,952 |
| 2 | Female | 23,461 |

**`population_group_code` → `population_group`**

| Code | Label | People |
|---|---|---|
| 1 | Black African | 38,365 |
| 2 | Coloured | 4,177 |
| 3 | Indian/Asian | 816 |
| 4 | White | 2,055 |
| 5 | Other (in the dictionary; does not occur in the cleaned data) | 0 |

**`geo_type_code` → `geo_type`**

| Code | Label | People |
|---|---|---|
| 1 | Urban | 29,330 |
| 2 | Traditional (tribal / traditional authority areas) | 14,552 |
| 3 | Farms | 1,531 |

**`metro_indicator` → `metro`**

| Code | Label | People |
|---|---|---|
| 1 | Metro | 17,951 |
| 2 | Non-metro | 27,462 |

---

## 5. D02_clean.csv – Learning profile

### 5.1 Columns

| Column | Type | Description | Missing |
|---|---|---|---|
| `household_id` | text | Household identifier (see D01). | 0 |
| `person_number` | text | Person number (see D01). | 0 |
| `education_level_code` | number | Highest level of education completed (see 5.2). 80 values that were blank in the uncleaned file were filled from D03, which records the same variable and never disagrees with D02 (section 2.4). | 0 |
| `education_attendance_code` | integer | Whether the person currently attends an educational institution (see 5.2). The text placeholders "N/A", "Unknown" and "not recorded" were set to missing (section 2.3). "N/A" is not treated as code 8, because code 8 only applies to children aged 0–4. | 23 |
| `institution_type_code` | number | Type of institution attended (see 5.2). | 0 |
| `reason_not_attending_code` | number | Main reason for not attending (see 5.2). | 0 |
| `education_level` | text | Label for `education_level_code`. Blank for codes 29 and 99. | 514 |
| `education_attendance` | text | Label for `education_attendance_code`. Blank for code 3 and for the text placeholders. | 41 |
| `institution_type` | text | Label for `institution_type_code`. | 0 |
| `reason_not_attending` | text | Label for `reason_not_attending_code`. | 0 |

### 5.2 Codes

**`education_level_code` → `education_level`** (listed in the order of the label levels)

| Code | Data dictionary label | Label in `education_level` | People |
|---|---|---|---|
| 98 | No schooling | No schooling | 782 |
| 0 | Grade R/0 | Grade R/0 | 18 |
| 1 | Grade 1/Sub A/Class 1 | Grade 1/Sub A/Class 1 | 111 |
| 2 | Grade 2/Sub B/Class 2 | Grade 2/Sub B/Class 2 | 226 |
| 3 | Grade 3/Standard 1/ABET/AET 1 | Grade 3/Standard 1/ABET/AET 1 | 291 |
| 4 | Grade 4/Standard 2 | Grade 4/Standard 2 | 457 |
| 5 | Grade 5/Standard 3/ABET/AET 2 | Grade 5/Standard 3/ABET/AET 2 | 529 |
| 6 | Grade 6/Standard 4 | Grade 6/Standard 4 | 888 |
| 7 | Grade 7/Standard 5/ABET/AET 3 | Grade 7/Standard 5/ABET/AET 3 | 1,984 |
| 8 | Grade 8/Standard 6/Form 1 | Grade 8/Standard 6/Form 1 | 2,648 |
| 9 | Grade 9/Standard 7/Form 2/ABET/AET 4/NCV Level 1/Occupational Certificate NQF Level 1 | Grade 9/Standard 7/Form 2/ABET/AET 4/NCV 1 | 4,013 |
| 10 | Grade 10/Standard 8/Form 3/NCV Level 2/Occupational Certificate NQF Level 2 | Grade 10/Standard 8/Form 3/NCV 2 | 5,689 |
| 11 | Grade 11/Standard 9/Form 4/NCV Level 3/Occupational Certificate NQF Level 3 | Grade 11/Standard 9/Form 4/NCV 3 | 6,548 |
| 12 | Grade 12/Standard 10/Form 5/National Senior Certificate/Matric/NCV Level 4/Occupational Certificate NQF Level 4 | Grade 12/Standard 10/Form 5/NSC/Matric/NCV 4 | 14,633 |
| 13 | NTC I/N1/NQF 1 | NTC I/N1/NQF 1 | 32 |
| 14 | NTC II/N2/NQF 2 | NTC II/N2/NQF 2 | 65 |
| 15 | NTC III/N3/NQF 3 | NTC III/N3/NQF 3 | 135 |
| 16 | N4/NTC 4/Occupational Certificate NQF Level 5 | N4/NTC 4/Occupational Cert NQF 5 | 203 |
| 17 | N5/NTC 5/Occupational Certificate NQF Level 5 | N5/NTC 5/Occupational Cert NQF 5 | 145 |
| 18 | N6/NTC 6/Occupational Certificate NQF Level 5 | N6/NTC 6/Occupational Cert NQF 5 | 289 |
| 19 | Certificate with less than Grade 12/Standard 10 | Certificate less than Grade 12 | 47 |
| 20 | Diploma with less than Grade 12/Standard 10 | Diploma less than Grade 12 | 62 |
| 21 | Higher/National/Advanced Certificate with Grade 12/Std 10/Occupational Certificate NQF Level 5 | Higher/National/Advanced Certificate with Grade 12/NQF 5 | 503 |
| 22 | Diploma with Grade 12/Standard 10/Occupational Certificate NQF Level 6 | Diploma with Grade 12/Occupational Cert NQF 6 | 1,818 |
| 23 | Higher Diploma/Occupational Certificate (B-Tech Diploma) NQF Level 7 | Higher Diploma/B-Tech/Occupational Cert NQF 7 | 377 |
| 24 | Bachelor's Degree/Occupational Certificate NQF Level 7 | Bachelor's Degree/Occupational Cert NQF 7 | 1,481 |
| 25 | Honours Degree/Postgraduate Diploma/Occupational Certificate NQF Level 8 | Honours Degree/Postgrad Diploma/Occupational Cert NQF 8 | 431 |
| 26 | Post Higher Diploma (M-Tech and Master's Degree) NQF Level 9 | Post Higher Diploma (M-Tech/Master's) NQF 9 | 202 |
| 27 | Doctoral Degrees (D-Tech and PhD) NQF Level 10 | Doctoral Degree (D-Tech/PhD) NQF 10 | 46 |
| 28 | Other | Other | 246 |
| 29 | Do not know | *(blank – non-response)* | 499 |
| 99 | *(not in the data dictionary)* | *(blank – undocumented code)* | 15 |

> **The level order is the dictionary's order, not a ranking.** "No schooling" is first and "Other" is last, and "Other" cannot be placed on the scale. Education bands (Task 3) must be built from explicit groups of codes, not from the level order.

**`education_attendance_code` → `education_attendance`** (currently attending an educational institution)

| Code | Data dictionary label | Label | People |
|---|---|---|---|
| 1 | Yes | Yes | 7,392 |
| 2 | No | No | 37,980 |
| 3 | Do not know | *(blank – non-response)* | 18 |
| 8 | Not applicable | – (only used for children under 15; none left after record selection) | 0 |
| *(blank)* | – | *(blank)* | 23 – the text placeholders "N/A" (10), "Unknown" (8) and "not recorded" (5) in the uncleaned file |

**`institution_type_code` → `institution_type`** (type of educational institution attended)

| Code | Data dictionary label | Label | People |
|---|---|---|---|
| 1 | Pre-school (including ECD centre, e.g. day care, crèche, playground, nursery school or pre-primary school) | Pre-school (incl. ECD centre) | 0 |
| 2 | School (including Grade R to Grade 12 learners who attended a formal school) | School (Grade R-12) | 5,631 |
| 3 | Adult Education and Training Learning Centre (ABET/AET Centre) | ABET/AET centre | 6 |
| 4 | Literacy classes (e.g. Kha Ri Gude) | Literacy classes | 1 |
| 5 | Higher education institution (university/university of technology) | Higher education institution (university / university of technology) | 913 |
| 6 | Technical and Vocational Education and Training (TVET) college | TVET college | 453 |
| 7 | Other college | Other college | 271 |
| 8 | Home-based education/home schooling | Home-based education / home schooling | 14 |
| 9 | Other educational institution | Other educational institution | 105 |
| 88 | Not applicable (the question is only asked of people who attend) | Not applicable | 38,019 |

**`reason_not_attending_code` → `reason_not_attending`** (main reason for not attending an educational institution)

| Code | Data dictionary label | Label | People |
|---|---|---|---|
| 1 | Too old/young | Too old/young | 6,943 |
| 2 | Has completed education/satisfied with my level of education/do not want to study | Completed education / satisfied / doesn't want to study | 5,374 |
| 3 | School/education institution is too far | Institution too far | 50 |
| 4 | Difficulties to get to school (transport) | Difficulty getting there (transport) | 80 |
| 5 | No money for fees | No money for fees | 7,082 |
| 6 | He or she is working at home or business/job | Working (at home, business or job) | 9,314 |
| 7 | Family commitment (e.g. child minding) | Family commitment (e.g. child minding) | 1,986 |
| 8 | Education is useless or not interesting | Education useless / not interesting | 519 |
| 9 | Unable to perform at school | Unable to perform at school | 1,898 |
| 10 | Illness | Illness | 420 |
| 11 | Pregnancy | Pregnancy | 212 |
| 12 | Failed exams | Failed exams | 339 |
| 13 | Got married | Got married | 38 |
| 14 | Disability | Disability | 308 |
| 15 | Violence in school | Violence in school | 20 |
| 16 | Not accepted for enrolment | Not accepted for enrolment | 547 |
| 17 | Do not have time/too busy | No time / too busy | 308 |
| 18 | Other reason for not attending an educational institution | Other reason | 2,563 |
| 88 | Not applicable (the question is only asked of people who do not attend) | Not applicable | 7,412 |

---

## 6. D03_clean.csv – Economic participation

### 6.1 Columns

| Column | Type | Description | Missing |
|---|---|---|---|
| `household_id` | text | Household identifier (see D01). | 0 |
| `person_number` | text | Person number (see D01). | 0 |
| `employment_status2code` | number | Labour-force status (see 6.2). **This is the employment outcome.** | 0 |
| `lab_salary_raw` | number | Original salary value in Rand, **unchanged**, including the placeholder codes 888888888 and 999999999 (see 6.2). Use `salary` for analysis. | 0 |
| `salary` | number | Salary in Rand with both placeholder codes set to missing (section 4.2). Range R1–R1,400,000, median R5,257. The pay period is not documented. 19 values under R100 (the highest is R80) are implausibly low for a monthly salary. They are kept unchanged, and can be excluded with `salary < 100` (section 7.3). | 27,377 |
| `salary_status` | text | Why `salary` is or is not present (see 6.2). | 0 |
| `employment_status` | text | Label for `employment_status2code`. | 0 |

### 6.2 Codes

**`employment_status2code` → `employment_status`**

| Code | Label | People |
|---|---|---|
| 1 | Employed | 18,711 |
| 2 | Unemployed | 10,135 |
| 3 | Not economically active | 16,567 |
| 8 | Not applicable (none after record selection) | 0 |

**`lab_salary_raw` placeholder codes**

| Value | Data dictionary label | How the data actually uses it | Rows |
|---|---|---|---|
| 888888888 | Don't know/refused | Used as "not applicable" for everyone without a job (26,702), and as non-response for 102 employed people | 26,804 |
| 999999999 | Not applicable | Only used for employed people, so it acts as non-response | 573 |
| Any other value | Real salary in Rand | Reported salary | 18,036 |

The dictionary's meanings for the two placeholders do not match how the data uses them (cross-tabulation in section 4.2). `salary_status` is therefore derived from the value **and** employment status together:

**`salary_status`** (derived; no source code)

| Value | Rule | People |
|---|---|---|
| Reported | `salary` has a real value | 18,036 |
| Non-response (employed) | Employed (`employment_status2code` = 1) and `lab_salary_raw` is a placeholder | 675 |
| Not applicable (not employed) | Unemployed or not economically active, with placeholder 888888888 | 26,702 |

---

## 7. D08_clean.csv – Connectivity access (household level)

### 7.1 Columns

| Column | Type | Description | Missing |
|---|---|---|---|
| `household_id` | text | Household identifier (see D01). | 0 |
| `fixed_internet_code` | number | Whether the household has fixed internet access (see 7.2). | 0 |
| `mobile_internet_code` | number | Whether the household has mobile internet access (see 7.2). | 60 (already missing in the uncleaned file) |
| `computer_asset_code` | number | Whether the household owns a computer, desktop, laptop or tablet (see 7.2). | 0 |
| `household_smartphones` | number | Number of smartphones owned by household members. The dictionary's valid range is 0–13. 15 impossible negative counts (−20 to −1) were set to missing (section 7.2). | 15 |
| `fixed_internet` | text | Label for `fixed_internet_code`. | 2 |
| `mobile_internet` | text | Label for `mobile_internet_code`. | 62 |
| `computer_asset` | text | Label for `computer_asset_code`. | 3 |

### 7.2 Codes

**`fixed_internet_code` → `fixed_internet`**

| Code | Label | Households |
|---|---|---|
| 1 | Yes | 2,921 |
| 2 | No | 18,017 |
| 9 | *(not in the data dictionary)* → *blank* | 2 |

**`mobile_internet_code` → `mobile_internet`**

| Code | Label | Households |
|---|---|---|
| 1 | Yes | 15,385 |
| 2 | No | 5,493 |
| 9 | *(not in the data dictionary)* → *blank* | 2 |
| *(blank)* | *(blank)* – already missing in the uncleaned file | 60 |

**`computer_asset_code` → `computer_asset`**

| Code | Data dictionary label | Label | Households |
|---|---|---|---|
| 1 | Yes | Yes | 4,523 |
| 2 | No | No | 16,414 |
| 9 | Unspecified | *(blank – non-response)* | 3 |

**`household_smartphones`** (count, not a code)

| Smartphones | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 12 | 13 | *(blank)* |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Households | 3,441 | 6,676 | 5,664 | 2,869 | 1,464 | 521 | 176 | 68 | 27 | 7 | 9 | 1 | 2 | 15 |

No household has more smartphones than members (section 7.2).

---

## 8. Summary of missing values

| File | Column | Missing | Reason |
|---|---|---|---|
| D02 | `education_attendance_code` | 23 | Text placeholders ("N/A", "Unknown", "not recorded") set to missing (section 2.3) |
| D02 | `education_level` | 514 | Codes 29 (do not know) and 99 (undocumented) have no label |
| D02 | `education_attendance` | 41 | Code 3 (do not know), 18 rows, plus the 23 placeholders |
| D03 | `salary` | 27,377 | Placeholder codes: 26,702 not employed (not applicable), 675 employed non-response |
| D08 | `mobile_internet_code` | 60 | Already missing in the uncleaned file |
| D08 | `mobile_internet` | 62 | The 60 above, plus code 9 (2) |
| D08 | `fixed_internet` | 2 | Code 9 (undocumented) |
| D08 | `computer_asset` | 3 | Code 9 (Unspecified) |
| D08 | `household_smartphones` | 15 | Negative counts set to missing |

D01 has no missing values.

---

## 9. Columns dropped from the source files

The columns not listed above were removed in section 3 (Column Selection) of the preprocessing report, with a reason for each, e.g. `survey_year` (always 2024), `province` text (messy; rebuilt from `province_code`), columns duplicated in another dataset, and leakage columns that reveal the employment outcome. The full list is in the "Columns Dropped" table in section 3.

The six `_flag` columns created during cleaning (`household_id_flag`, `age_flag`, `education_level_flag`, `education_attendance_flag`, `salary_flag` and `household_smartphones_flag`) are used in the report's verification tables but are left out of every saved file (sections 8.2 and 10.1), because they are not analytical variables. Every repaired value can still be identified from its rule in the report, for example `salary < 100`.

---

## 10. analytical_dataset.csv – Integrated dataset with engineered features

`analytical_dataset.csv` has one row per working-age person and contains, in this order:

1. all 15 columns of `D01_clean.csv` (see 4),
2. the 8 non-key columns of `D02_clean.csv` (see 5),
3. the 5 non-key columns of `D03_clean.csv` (see 6),
4. the 7 non-key columns of `D08_clean.csv` (see 7), and
5. the 24 engineered columns below.

The columns from the cleaned files keep the meaning, codes and labels described in 4–7. Every engineered column is built with a fixed rule (a code mapping, a constant or a threshold). Nothing is estimated from the data as a whole, so these columns can be built before the train/test split without leakage.

### 10.1 Engineered columns

| Column | Type | Description | Missing |
|---|---|---|---|
| `female` | integer (0/1) | 1 = Female, 0 = Male, from `sex_code` (section 10.2). | 0 |
| `has_fixed_internet` | integer (0/1) | 1 = the household has fixed internet, 0 = no, from `fixed_internet_code`. Code 9 stays blank (section 10.2). | 3 |
| `has_mobile_internet` | integer (0/1) | 1 = the household has mobile internet, 0 = no, from `mobile_internet_code`. Code 9 and missing codes stay blank (section 10.2). | 142 |
| `has_computer` | integer (0/1) | 1 = the household owns a computer, 0 = no, from `computer_asset_code`. Code 9 (Unspecified) stays blank (section 10.2). | 5 |
| `education_band` | text | Highest education completed, grouped into 7 bands from explicit groups of `education_level_code` (see 10.2; section 10.3.1). Replaces the 31 sparse education levels for modelling. | 0 |
| `matric_plus` | integer (0/1) | 1 = matric or higher, 0 = below matric (see 10.2). Blank for codes 28, 29 and 99, which cannot be placed above or below matric (section 10.3.1). | 760 |
| `any_home_internet` | integer (0/1) | 1 = the household has fixed or mobile internet, 0 = both are "No". Blank when one is "No" and the other is missing (section 10.3.2). | 129 |
| `digital_access_score` | integer (0–4) | Number of forms of digital access in the household: fixed internet + mobile internet + computer + at least one smartphone (see 10.2; section 10.3.2). Blank if any of the four is missing. | 180 |
| `edu_digital_group` | text | Combination of `matric_plus` and `any_home_internet` (see 10.2; section 10.3.3). Shows whether internet access goes with a larger employment advantage for people with matric. | 129 |
| `settlement_type` | text | Where the person lives, combining `geo_type_code` and `metro_indicator` (see 10.2; section 10.3.4). | 0 |
| `youth` | integer (0/1) | 1 = aged 15–34 (South African youth definition), 0 = aged 35–64 (section 10.3.4). For reporting; not a model predictor. | 0 |
| `household_size` | integer (1–25) | Number of household members of **any age**. Counted before record selection removed people under 15 and aged 65+ (sections 5 and 10.3.5). | 0 |
| `n_children_under15` | integer (0–10) | Household members aged under 15, counted before record selection. | 0 |
| `n_elderly_65plus` | integer (0–4) | Household members aged 65 or older, counted before record selection. | 0 |
| `n_working_age` | integer (1–15) | Household members aged 15–64 (the people in this file). For every household, `household_size` = `n_children_under15` + `n_working_age` + `n_elderly_65plus`. | 0 |
| `elderly_in_household` | integer (0/1) | 1 = at least one household member is aged 65+, 0 = none (see 10.2). | 0 |
| `dependency_ratio` | number (0–8) | (`n_children_under15` + `n_elderly_65plus`) ÷ `n_working_age`: the number of dependants per working-age member. | 0 |
| `female_x_children` | integer (0–10) | `female` × `n_children_under15`: the number of children for women, 0 for men. Lets a model estimate a different effect of children for women (section 10.3.5). | 0 |
| `smartphones_per_member` | number (0–1) | `household_smartphones` ÷ `household_size`. | 36 |
| `smartphone_access` | text | `smartphones_per_member` in three groups (see 10.2). Blank where `household_smartphones` is missing. | 36 |
| `other_member_matric` | text | Whether another working-age member of the household has matric or higher (see 10.2). Members with unknown education count as not having matric. | 0 |
| `age_centred` | number (−25 to 24) | `age` − 40. A fixed constant is used instead of the average age, so nothing is estimated from the data (section 10.4, T2). | 0 |
| `age_centred_squared` | number (0–625) | `age_centred`². Lets a logistic regression fit a curved age effect. Centring lowers its correlation with the age term from 0.985 to −0.327 (section 10.4, T2). | 0 |
| `log_salary` | number (4.73–14.15) | Natural log of `salary` for employed people with `salary_status` = "Reported" and `salary` ≥ R100; blank for everyone else (section 10.4, T6). Reduces the strong right skew of salaries. Only for the income question: it reveals the employment outcome. | 27,396 |

### 10.2 Codes and levels

**0/1 columns**

The source codes use 1 = Yes and 2 = No. The 0/1 columns change this so that 1 always means "yes".

| Column | Rule | 1 | 0 | *(blank)* |
|---|---|---|---|---|
| `female` | `sex_code` 2 → 1, 1 → 0 | 23,461 | 21,952 | 0 |
| `has_fixed_internet` | `fixed_internet_code` 1 → 1, 2 → 0, 9 → blank | 6,687 | 38,723 | 3 |
| `has_mobile_internet` | `mobile_internet_code` 1 → 1, 2 → 0, 9 or blank → blank | 35,996 | 9,275 | 142 |
| `has_computer` | `computer_asset_code` 1 → 1, 2 → 0, 9 → blank | 10,535 | 34,873 | 5 |
| `matric_plus` | See `education_band` below | 20,128 | 24,525 | 760 |
| `any_home_internet` | 1 if `has_fixed_internet` or `has_mobile_internet` = 1; 0 if both = 0 | 37,559 | 7,725 | 129 |
| `youth` | `age` ≤ 34 | 22,797 | 22,616 | 0 |
| `elderly_in_household` | `n_elderly_65plus` > 0 | 7,771 | 37,642 | 0 |

**`education_level_code` → `education_band` and `matric_plus`** (listed in band order)

| `education_band` | `education_level_code` | `matric_plus` | People |
|---|---|---|---|
| No schooling | 98 | 0 | 782 |
| Primary (Grade R-7) | 0–7 | 0 | 4,504 |
| Some secondary | 8–11; 13–15 (NTC I–III); 19–20 (certificate or diploma without Grade 12) | 0 | 19,239 |
| Matric | 12 | 1 | 14,633 |
| Post-school certificate/diploma | 16–18 (N4–N6); 21–22 (certificate or diploma with Grade 12) | 1 | 2,958 |
| Degree | 23–27 | 1 | 2,537 |
| Other/unknown | 28 (Other), 29 (do not know), 99 (undocumented) | *(blank)* | 760 |

Unknown education is kept as its own band instead of being dropped, because these people are not missing at random.

**`digital_access_score`**

| Score | 0 | 1 | 2 | 3 | 4 | *(blank)* |
|---|---|---|---|---|---|---|
| People | 3,765 | 4,269 | 25,963 | 7,385 | 3,851 | 180 |

**`edu_digital_group`**

| Level | Rule | People |
|---|---|---|
| Below matric, no internet | `matric_plus` = 0 and `any_home_internet` = 0 | 5,692 |
| Below matric, internet | `matric_plus` = 0 and `any_home_internet` = 1 | 18,744 |
| Matric+, no internet | `matric_plus` = 1 and `any_home_internet` = 0 | 1,871 |
| Matric+, internet | `matric_plus` = 1 and `any_home_internet` = 1 | 18,218 |
| Education unknown | `matric_plus` blank and `any_home_internet` not blank | 759 |
| *(blank)* | `any_home_internet` blank | 129 |

**`settlement_type`**

| Level | `geo_type_code` | `metro_indicator` | People |
|---|---|---|---|
| Metro urban | 1 (Urban) | 1 (Metro) | 16,962 |
| Non-metro urban | 1 (Urban) | 2 (Non-metro) | 12,368 |
| Traditional | 2 (Traditional) | 1 or 2 | 14,552 (862 metro, 13,690 non-metro) |
| Farms | 3 (Farms) | 1 or 2 | 1,531 (127 metro, 1,404 non-metro) |

The small metro traditional and metro farm groups are merged into Traditional and Farms by this fixed rule.

**`smartphone_access`**

| Level | Rule | People |
|---|---|---|
| None | `household_smartphones` = 0 | 4,626 |
| Fewer than 1 per member | `smartphones_per_member` above 0 and below 1 | 28,721 |
| 1 or more per member | `smartphones_per_member` ≥ 1 (no household has more smartphones than members, so this is exactly one per member) | 12,030 |
| *(blank)* | `household_smartphones` missing | 36 |

**`other_member_matric`**

| Level | Rule | People |
|---|---|---|
| No | At least one other working-age member, none with `matric_plus` = 1 | 14,148 |
| Yes | At least one other working-age member has `matric_plus` = 1 | 24,650 |
| No other working-age member | `n_working_age` = 1 | 6,615 |

### 10.3 D08 columns in the analytical file

Household values are repeated for each working-age member, so missing values in the D08 columns are counted per person in `analytical_dataset.csv` and per household in `D08_clean.csv`. The 1,160 households without a working-age member are not in the analytical file.

| Column | Missing households (`D08_clean.csv`) | Missing people (`analytical_dataset.csv`) |
|---|---|---|
| `fixed_internet` | 2 | 3 |
| `mobile_internet_code` | 60 | 139 |
| `mobile_internet` | 62 | 142 |
| `computer_asset` | 3 | 5 |
| `household_smartphones` | 15 | 36 |

---

## 11. model_data.csv – Employment modelling dataset

Built from `analytical_dataset.csv` in sections 10.4–10.5:

- **Rows:** the labour force only (employed or unemployed), 28,846 people. The 104 people whose household has a missing digital-access answer (`any_home_internet` or `digital_access_score` blank) are removed, leaving 28,742.
- **Target:** `employed`, with 18,641 employed (64.9%) and 10,101 unemployed.
- **Columns:** 2 design columns, the target and 21 candidate predictors. Columns that reveal the outcome, identifiers and columns replaced by an engineered feature are left out (see 13).
- **Encoding:** categories are stored as text. After reading, re-apply the reference levels below (code in 2). `glm()`, `rpart()` and `randomForest()` create the dummy columns themselves, leaving out the reference level, so no one-hot columns are stored. No scaling is applied.

### 11.1 Columns

| Column | Role | Type | Reference level / values | Missing |
|---|---|---|---|---|
| `household_id` | Design: household-grouped train/test split (not a predictor) | text | 16,758 households | 0 |
| `person_weight` | Design: survey weight passed as `weights =` (not a predictor) | number | 50–5,531 | 0 |
| `employed` | **Target** | text → factor | Reference: Unemployed | 0 |
| `age_centred` | Predictor | number | −25 to 24 | 0 |
| `age_centred_squared` | Predictor | number | 0 to 625 | 0 |
| `female` | Predictor | integer (0/1) | Reference: 0 (Male) | 0 |
| `population_group` | Predictor (sensitive attribute: control and fairness checks) | text → factor | Reference: Black African | 0 |
| `province` | Predictor | text → factor | Reference: Gauteng | 0 |
| `settlement_type` | Predictor | text → factor | Reference: Metro urban | 0 |
| `education_band` | Predictor | text → factor | Reference: Some secondary | 0 |
| `matric_plus` | Predictor | integer (0/1) | Reference: 0 (below matric) | 497 |
| `has_fixed_internet` | Predictor | integer (0/1) | Reference: 0 (No) | 0 |
| `has_mobile_internet` | Predictor | integer (0/1) | Reference: 0 (No) | 0 |
| `has_computer` | Predictor | integer (0/1) | Reference: 0 (No) | 0 |
| `any_home_internet` | Predictor | integer (0/1) | Reference: 0 (No) | 0 |
| `digital_access_score` | Predictor | integer | 0–4 | 0 |
| `smartphone_access` | Predictor | text → factor | Reference: None | 0 |
| `edu_digital_group` | Predictor | text → factor | Reference: Below matric, no internet | 0 |
| `household_size` | Predictor | integer | 1–25 | 0 |
| `n_children_under15` | Predictor | integer | 0–10 | 0 |
| `elderly_in_household` | Predictor | integer (0/1) | Reference: 0 (No) | 0 |
| `dependency_ratio` | Predictor | number | 0–7 | 0 |
| `female_x_children` | Predictor | integer | 0–10 | 0 |
| `other_member_matric` | Predictor | text → factor | Reference: No | 0 |

- `matric_plus` is blank for the 497 people whose education is Other/unknown. A logistic regression that uses `matric_plus` drops these rows automatically; `education_band` and `edu_digital_group` keep them as their own level.
- The candidate predictors overlap (for example `digital_access_score` and its parts, or `matric_plus` and `education_band`). The final predictor set is chosen in Milestone 3.

---

## 12. income_data.csv – Income dataset

Built from `analytical_dataset.csv` in section 10.6. It contains the 18,017 employed people with `salary_status` = "Reported" and `salary` ≥ R100 (the 18,036 reported salaries minus the 19 under R100). It is used to test whether internet access is associated with higher income among people who report a salary.

| Column | Role | Type | Values | Missing |
|---|---|---|---|---|
| `household_id` | Design: household-grouped split (not a predictor) | text | 13,075 households | 0 |
| `person_weight` | Design: survey weight (not a predictor) | number | 50–5,531 | 0 |
| `log_salary` | **Outcome** | number | 4.73 to 14.15 | 0 |
| `any_home_internet` | Predictor | integer (0/1) | 0 / 1 | 43 |
| `digital_access_score` | Predictor | integer | 0–4 | 64 |
| `education_band` | Predictor | text | 7 bands (see 10.2) | 0 |
| `matric_plus` | Predictor | integer (0/1) | 0 / 1 | 360 |
| `age_centred` | Predictor | number | −25 to 24 | 0 |
| `age_centred_squared` | Predictor | number | 0 to 625 | 0 |
| `female` | Predictor | integer (0/1) | 0 / 1 | 0 |
| `population_group` | Predictor (sensitive attribute) | text | 4 groups | 0 |
| `province` | Predictor | text | 9 provinces | 0 |
| `settlement_type` | Predictor | text | 4 levels (see 10.2) | 0 |

Missing digital-access values are not removed from this file. Handle them in Milestone 3 in the same way as in `model_data.csv`.

---

## 13. Columns left out of model_data.csv

Every column of `analytical_dataset.csv` that is not in `model_data.csv` has a documented reason (section 10.4, "Model Data Verification").

| Columns | Reason |
|---|---|
| `reason_not_attending`, `reason_not_attending_code`, `lab_salary_raw`, `salary`, `salary_status`, `log_salary` | **Leakage:** they reveal the employment outcome. "Working" as a reason for not studying occurs almost only among employed people, and salaries exist only for employed people. `log_salary` is used in `income_data.csv` instead. |
| `employment_status` | Target: kept as `employed` |
| `person_number`, `psu` | Identifier or survey design column |
| `province_code`, `sex_code`, `population_group_code`, `geo_type_code`, `metro_indicator`, `education_level_code`, `education_attendance_code`, `institution_type_code`, `employment_status2code`, `fixed_internet_code`, `mobile_internet_code`, `computer_asset_code` | Code column: its label or an engineered feature is used instead |
| `education_level` | Replaced by `education_band` (31 sparse levels) |
| `sex` | Replaced by `female` (0/1) |
| `geo_type`, `metro` | Replaced by `settlement_type` |
| `age` | Replaced by `age_centred` and `age_centred_squared` |
| `youth` | Reporting group for Power BI; duplicates age in a model |
| `fixed_internet`, `mobile_internet`, `computer_asset` | Replaced by their 0/1 versions |
| `household_smartphones`, `smartphones_per_member` | Replaced by `smartphone_access` |
| `n_elderly_65plus`, `n_working_age` | Used to build `elderly_in_household` and `dependency_ratio` |
| `education_attendance`, `institution_type` | Current study status: mostly outside the labour force, kept for description |
