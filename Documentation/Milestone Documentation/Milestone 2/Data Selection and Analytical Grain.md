# Milestone 2 – Task 1: Data Selection and Analytical Grain

**BIN381 Project – Group 5**
Jandre Neethling (601304) · Henri Claassen (601720) · Declin Vorkel (601756)

---

## 1. Project Goal

### 1.1 Problem

**Digital access as a pathway to, and a multiplier of, education's labour-market returns in South Africa.**

The project asks two connected questions:

1. Does digital access (household internet and computer access) go together with better education outcomes?
2. Does education lead to employment more strongly for people who have digital access?

Together these describe a pathway: **digital access → education → employment**, with digital access potentially also strengthening the education → employment step directly.

### 1.2 Background

South Africa continues to experience high structural unemployment and persistent inequality in access to digital infrastructure. Finding work increasingly depends on digital communication technologies (Oyedemi & Choung, 2020), while connectivity problems, limited digital skills and high data costs restrict access to online job searching for many job-seekers (Ohei & Alao, 2019; Shaw & Wheeler, 2023). Government initiatives such as South Africa Connect aimed to close this gap, but disparities persist (Department of Communications, 2013; Frans & Pather, 2022).

Policy debate often treats connectivity either as a standalone "digital divide" issue or as a convenience upgrade, rather than asking whether it changes how well other interventions, such as education, work. If digital access improves education, and education improves employment, then digital access contributes to employment both **indirectly** (through education) and potentially **directly**. If digital access also makes education pay off more in the labour market, then education spending may be underperforming in areas without connectivity. International evidence shows that education and labour-market support can either reinforce or substitute for each other depending on the country and population (Plavgo, 2023), so the pattern for South Africa has to be tested rather than assumed.

### 1.3 Stakeholder

**National Treasury**, which advises government on the allocation of development funding. Treasury must decide how to prioritise limited intervention budgets between digital-access subsidies (e.g. subsidised data and devices) and continued education spending. Its information need is whether these two policy areas are **complements** (they strengthen each other) or **substitutes** (one can stand in for the other), so that funding reflects actual labour-market dynamics rather than an assumed separation between the two.

### 1.4 Business Objective

Determine whether household digital access is associated with better educational outcomes, and whether it strengthens the relationship between educational attainment and employment, in order to inform whether connectivity expansion is a cost-effective complement to education-focused labour-market interventions.

### 1.5 The Research Pathway

| Link | Question | Measured by |
|---|---|---|
| **A** Digital access → Education | Do people in connected households have better education outcomes? | Household internet / computer access (D08) → highest education level, current attendance and post-school enrolment (D02) |
| **B** Education → Employment | Is higher education associated with being employed? | Education level (D02) → employment status (D03) |
| **C** Digital access × Education → Employment | Does digital access strengthen (or substitute for) the education–employment link? | Interaction between education and digital access in the employment model |
| **D** Income *(exploratory)* | Among employed people, is salary associated with education and digital access? | Salary (D03) |

Links A and B together describe the indirect route ("digitalisation → education → jobs"). Link C describes the moderating route. Link D is secondary and exploratory.

### 1.6 Analytics Goals

1. **Link A:** Model education outcomes as a function of household digital access, controlling for age, sex, population group and geography. Attainment is modelled for adults aged 25–64 (whose education is largely complete); current attendance and post-school enrolment (university, TVET or college) are modelled for youth aged 15–24. Reasons for not attending are compared descriptively between connected and unconnected youth to help interpret the results.
2. **Links B and C:** Model the employment status of working-age people (15–64) as a function of education level, household digital access and the interaction between the two, with the same controls.
3. **Link D (exploratory):** Compare reported salary across education and digital-access groups among employed people.

### 1.7 Hypotheses

| # | Hypothesis | Link |
|---|---|---|
| H1 | People in households with internet or computer access have higher educational attainment (ages 25–64) and, among youth aged 15–24, are more likely to be attending an educational institution, in particular a post-school institution (university, TVET or college). | A |
| H2 | Higher educational attainment is associated with a higher likelihood of employment. | B |
| H3 | The association between education and employment differs by household digital access: it is either stronger (reinforcing) or weaker (substitution) for connected people. | C |
| H4 | Province, settlement type and metro status are associated with digital access, education and employment, and therefore must be controlled for when testing H1–H3. | Control |
| H5 | Among employed people, reported salary is associated with education and digital access. | D |

### 1.8 Success Criteria

**Business success criterion:** a defensible, statistically supported answer (**yes / no / inconclusive**) to two questions: (1) is household digital access associated with better education outcomes, and (2) does digital access moderate the education–employment relationship, and if so, in which direction (reinforcing or substitution)? Every conclusion must state its limitations, in particular that the findings are associations.

**Technical success criteria (carried into Milestone 3):**

- The education × digital-access interaction is tested with a likelihood-ratio test at α = 0.05, using standard errors clustered by household (people in the same household share one connectivity value).
- Effects are reported both as odds ratios and as predicted probabilities for each education × digital-access group.
- Model performance is evaluated on a held-out test set split by household, against a threshold agreed before modelling (e.g. AUC ≥ 0.70) and a demographics-only baseline.
- Findings are checked with at least two modelling approaches (logistic regression and a tree-based method).

### 1.9 What the Data Can and Cannot Show

- **Associations, not causes.** D01–D10 are a single 2024 cross-section. The analysis can show whether digital access and education *go together*, not that one *caused* the other.
- **Timing.** Most adults completed their education years before their household's 2024 internet status was recorded. For adults, H1 is therefore tested as an association only. Current attendance among 15–24 year olds is measured at the same time as connectivity, which makes youth attendance the stronger evidence for Link A.
- **Reverse direction.** Employment and income can pay for internet access, so part of any association may run from employment to connectivity.
- **Household wealth.** Wealth plausibly drives internet access, education and employment at the same time. D09 (Household Resources) is not included in the core dataset; this is recorded as a limitation (Section 9).
- **Access is not use.** D08 records whether the *household* has access, not whether each person uses it.

---

## 2. Data Environment

The project portfolio contains 11 datasets derived from Statistics South Africa 2024 survey data (Statistics South Africa, 2026). D01–D10 come from one household survey and share a common household identifier; D11 comes from a separate labour-force survey environment.

| Dataset | Domain | Grain (one row =) | Rows | Decision |
|---|---|---|---|---|
| D01 Population Profile | Demographics | Person | 70,440 | **Included** |
| D02 Learning Profile | Education | Person | 70,462 | **Included** |
| D03 Economic Participation | Employment and income | Person | 70,460 | **Included** |
| D04 Dwelling Conditions | Housing | Household | 20,956 | Excluded |
| D05 Basic Services | Water and sanitation | Household | 20,940 | Excluded |
| D06 Household Energy | Energy | Household | 20,940 | Excluded |
| D07 Household Wellbeing | Food security | Household | 20,955 | Excluded |
| D08 Connectivity Access | Digital access | Household | 20,940 | **Included** |
| D09 Household Resources | Income, grants, assets | Household | 20,955 | Excluded (see Section 9) |
| D10 Mobility Access | Transport and health access | Household | 20,940 | Excluded |
| D11 Labour Market | Labour-market (quarterly) | Person-quarter | 170,432 | Excluded |

---

## 3. Dataset Selection

### 3.1 Included Datasets

| Dataset | Role in the pathway | Why it is needed |
|---|---|---|
| **D08 Connectivity Access** | Digital access: the exposure in Link A and the moderator in Link C | The only dataset measuring household internet (fixed and mobile), computer ownership and smartphones. Without it, neither question can be asked. |
| **D02 Learning Profile** | Education: the outcome of Link A and the main predictor in Links B and C | Holds highest education level, current attendance, the type of institution attended (school vs university / TVET / college) and the reason for not attending. |
| **D03 Economic Participation** | Employment: the outcome of Links B and C; salary for Link D | Holds employment status (employed / unemployed / not economically active) and salary at person level, linkable to D01, D02 and D08. |
| **D01 Population Profile** | Controls, survey design and weights | Supplies age, sex, population group, province, settlement type and metro status (the controls required by H4), plus the sampling cluster (PSU) and person weights. |

### 3.2 Evidence that the Four Datasets Can Be Linked

All checks were run on the raw files with `HouseholdID` and `PersonNumber` read as text, to prevent the 18-digit identifiers from being rounded.

| Check | Result |
|---|---|
| Distinct households in D01, D02, D03, D08 | 20,940 in each |
| D01 households found in D02 / D03 / D08 | 20,940 / 20,940 / 20,940 (100%) |
| D08 rows vs distinct `household_id` | 20,940 = 20,940 (exactly one row per household) |
| Distinct person keys (`household_id` + `person_number`) in D02 and D03 | 70,440 in each; the two sets are identical |
| Distinct person keys in D01 | 70,415, plus 25 rows with a missing `household_id` |
| D02/D03 person keys not found in D01 | 25, matching the 25 D01 rows with a missing ID (recovery handled in Task 2) |
| Shared attributes, D01 vs D02 and D03 (sex, province, settlement type, person weight) | 0 mismatches across 70,415 matched people |
| Education level, D02 vs D03 | 0 mismatches across 70,320 people |
| Province and settlement type, D01 vs D08 | 0 mismatches across 20,940 households |

> **Correction to Milestone 1:** the EDA reported a 98.77% household match. That figure used a hard-coded count (20,684). Re-running `intersect()` with identifiers read as text returns 20,940 of 20,940 households: a 100% match.

### 3.3 Excluded Datasets

| Dataset | Reason for exclusion |
|---|---|
| **D11 Labour Market** | Comes from a separate survey. 0 of D01's 20,940 household IDs appear in D11, so it cannot be linked at household or person level. Its grain (person per quarter) also differs. D03 already provides person-level employment status that links to education and connectivity, so D11 adds nothing that can be joined. |
| **D04 Dwelling Conditions** | Housing quality is not part of the digital access → education → employment pathway. |
| **D05 Basic Services** | Water and sanitation access does not measure any link in the pathway. |
| **D06 Household Energy** | Electricity may enable connectivity, but D08 measures connectivity directly, so energy would only add an indirect proxy. |
| **D07 Household Wellbeing** | Food security is an outcome of household circumstances, not part of the pathway being tested. |
| **D10 Mobility Access** | Transport and health-facility access is outside the scope of the research questions. |
| **D09 Household Resources** | Not needed to measure any link directly. It is, however, the best available source of a household wealth control. It is excluded from the core dataset to limit scope (Milestone 1 risk #6) and recorded as a limitation and a possible robustness check (Section 9). |

Adding datasets that do not measure a link in the pathway would increase complexity without improving the answer to Treasury's question. This is the scope-creep risk identified in Milestone 1.

---

## 4. Analytical Grain

### 4.1 Grain of the Source Datasets

| Dataset | Grain | Key | Rows | Distinct keys | Note |
|---|---|---|---|---|---|
| D01 | Person | `household_id` + `person_number` | 70,440 | 70,415 | 25 rows have a missing `household_id` |
| D02 | Person | `household_id` + `person_number` | 70,462 | 70,440 | 22 exact duplicate rows |
| D03 | Person | `household_id` + `person_number` | 70,460 | 70,440 | 20 exact duplicate rows |
| D08 | Household | `household_id` | 20,940 | 20,940 | One row per household |

After removing exact duplicates, no person key appears more than once in any person-level dataset. The repeated `household_id` values in D01–D03 are **legitimate**: a household contains several people (mean 3.36, median 3, maximum 25). They are not duplicates.

### 4.2 Target Grain of the Final Dataset

> **One row = one person aged 15–64**, identified by `household_id` + `person_number`, with their household's digital-access variables attached.

**Why person level:**

- Both outcomes, education and employment, belong to individuals. A person's education must be compared with **that same person's** employment status to test Links B and C.
- A household-level dataset would force several people's education and employment into one value per household (e.g. "anyone employed"), destroying the person-level education–employment relationship that the project tests.
- Digital access is measured per household, so it is attached to every person in that household. This is a valid many-to-one relationship: each person belongs to exactly one household, and each household has exactly one D08 record.

**Consequence for later tasks:** because all members of a household share one connectivity value, people in the same household are not independent observations. This is handled with household-clustered standard errors (Milestone 3) and a train/test split that keeps each household entirely in one set (Task 4).

### 4.3 Planned Integration (carried out in Task 3)

| Step | Join | Key | Expected cardinality | Expected result |
|---|---|---|---|---|
| 1 | D01 ← D02 | `household_id` + `person_number` | One-to-one | 70,440 persons |
| 2 | (D01 + D02) ← D03 | `household_id` + `person_number` | One-to-one | 70,440 persons |
| 3 | Persons ← D08 | `household_id` | Many-to-one | 70,440 persons; row count unchanged |

Each dataset is cleaned at its own grain **before** any join, so that duplicates cannot multiply rows. Row counts are verified before and after every join.

---

## 5. Record Selection

Counts below are from D03 after removing its 20 exact duplicate rows (70,440 persons). D03's age column is used because it contains no invalid or missing ages; D01's invalid ages are repaired from D02/D03 in Task 2.

| Criterion | Rule | Reason | Persons |
|---|---|---|---|
| All persons (deduplicated) | – | – | 70,440 |
| Under 15 | **Exclude** | Below working age. Employment status is structurally "not applicable" for every person under 15. | −19,803 |
| 65 and older | **Exclude** | Above working age; retirement dominates labour-market status. | −5,224 |
| **Aged 15–64** | **Include** | Statistics South Africa's working-age population definition (Statistics South Africa, 2024) | **45,413** persons in **19,780** households |
| Persons whose household cannot be identified | Exclude only if the ID cannot be recovered | Digital access cannot be attached | at most 2 (Task 2) |

### 5.1 Analysis Subsets (all at the same person grain)

| Subset | Rule | Used for | Persons |
|---|---|---|---|
| Working-age | Age 15–64 | Links B and C (employment model) | 45,413 (18,711 employed · 10,135 unemployed · 16,567 not economically active) |
| Adults | Age 25–64 | Link A: educational attainment | 33,273 |
| Youth | Age 15–24 | Link A: current attendance and post-school enrolment | 12,140 (6,649 attending · 5,484 not attending · 7 unknown) |
| Attending youth | Age 15–24, currently attending | Link A: type of institution | 6,649 (5,600 school · 507 university · 306 TVET · 151 other college · 85 other) |
| Non-attending youth | Age 15–24, not attending | Link A: reasons for not attending (descriptive only) | 5,484 |
| Employed with a reported salary | Employed and valid salary | Link D (exploratory) | Confirmed in Task 2 |

Whether the employment model compares employed with unemployed people only (the labour force) or with everyone not employed is a **modelling-target decision made in Task 4**. The analytical dataset keeps all three employment categories so that either definition can be applied.

---

## 6. Attribute Selection

### 6.1 Selection Rule

A column is kept only if it:

1. **measures a link** in the pathway (an outcome, the exposure or the moderator), **or**
2. **controls** for something that would otherwise distort a link (H4), **or**
3. is needed to **link, cluster or weight** records, **or**
4. is needed to **interpret a link descriptively**. Such a column is never used as a model input.

Every other column is excluded, with one of these reasons: no information, duplicate of another source, not applicable to the population (or only recorded for people who already have the outcome), **leakage** (the column reveals or is defined by an outcome), or unusable.

### 6.2 Column Decisions

All four datasets contain `survey_year` (always 2024, so it carries no information) and a text `province` column (24 different spellings of 9 provinces, mapping one-to-one onto `province_code`). Both are dropped everywhere, and the province label is rebuilt from `province_code`.

**D01: Population Profile (17 → 10 columns)**

| Column | Decision | Evidence |
|---|---|---|
| `survey_year`, `province` | Drop | See above |
| `household_id` | **Keep: key** | Links all four datasets; kept as text because 18 digits are rounded if stored as a number; 25 missing values, 23 recoverable |
| `person_number` | **Keep: key** | With `household_id`, identifies one person (the analytical grain) |
| `psu` | **Keep: survey design** | 3,218 sampling clusters (the first 11 digits of `household_id`); used for clustered standard errors, not as a predictor |
| `province_code` | **Keep: H4** | Location control; identical in D02, D03 and D08 |
| `sex_code` | **Keep: control** | Standard employment control; identical in D02/D03 |
| `age` | **Keep: control and record filter** | Defines the working-age population; 18 invalid values (−7 to 175) and 90 missing, all repairable from D02/D03 |
| `age_group_code` | Drop: duplicate | Matches `age` in 70,332 of 70,332 valid rows |
| `population_group_code` | **Keep: control** | Likely associated with both digital access and employment in South Africa; also required for fairness checks |
| `language_code` | Drop: no hypothesis | 14 levels overlapping province and population group; scope creep (M1 risk #6) |
| `relationship_to_head_code` | Drop: no hypothesis | Being household head is partly a result of earning (reverse direction) |
| `marital_status_code` | Drop: no hypothesis | Not needed to test H1–H5 |
| `geo_type_code` | **Keep: H4** | Urban / traditional / farm settlement type; identical in D02, D03 and D08 |
| `metro_code` | Drop: too detailed | 17 levels nested inside province and `metro_indicator`; small groups carry disclosure risk (M1 constraint #6) |
| `metro_indicator` | **Keep: H4** | Metro vs non-metro within a province (e.g. Johannesburg vs rural Gauteng) |
| `person_weight` | **Keep: weight** | Survey weight for population estimates; identical in D02/D03 |

**D02: Learning Profile (23 → 4 columns + keys)**

| Column | Decision | Evidence |
|---|---|---|
| `survey_year`, `province` | Drop | See above |
| `household_id`, `person_number` | Keep for joining | Link to D01 |
| `province_code`, `age`, `sex_code`, `geo_type_code`, `person_weight` | Drop: duplicates of D01 | 0 mismatches across 70,415 matched people; `age` is first used to repair D01 |
| `education_level_code` | **Keep: outcome (Link A), main predictor (Links B, C)** | 120 missing values, all filled from D03; 53 coded 99 (not in the dictionary), which become "unknown" |
| `education_attendance_code` | **Keep: outcome (Link A, youth), control (Link C)** | Separates students from job-seekers; 35 text entries ("N/A", "not recorded", "Unknown") to fix |
| `institution_type_code` | **Keep: outcome (Link A, youth)** | Separates school from post-school study among the 6,649 attending youth: 5,600 school, 507 university, 306 TVET, 151 other college, 85 other. Supports a post-school enrolment outcome, which attendance alone cannot show because most attending youth are still at school. |
| `reason_not_attending_code` | **Keep: descriptive only (Link A)** | Most common reasons among the 5,484 non-attending youth: no money for fees (1,647), completed or satisfied with their education (785), working (649), not accepted for enrolment (387). Comparing these between connected and unconnected youth shows whether the barrier is cost or connectivity. **Never a model input:** it is only recorded for people not attending (so it is defined by the attendance outcome), and code 06 ("working") reveals the employment outcome. |
| `grade_code` | Drop: duplicate | Always exactly `education_level_code` + 1 for school learners (5,575 of 5,575) |
| `public_private_institution_code`, `transport_mode_to_education_code`, `travel_time_to_education`, `bursary_code`, `total_education_fees`, `no_fees_school_code`, `school_food_programme_code`, `absence_code`, `absence_days` | Drop: only recorded for people already attending | 84–99% "not applicable" among 15–64 year olds. Because they only exist for people who already attend, they cannot explain whether someone attends; they describe conditions of schooling (cost, transport, meals, absence), not education outcomes or digital access. |

**D03: Economic Participation (25 → 2 columns + keys)**

| Column | Decision | Evidence |
|---|---|---|
| `survey_year`, `province` | Drop | See above |
| `household_id`, `person_number` | Keep for joining | Link to D01 |
| `province_code`, `age`, `sex_code`, `geo_type_code`, `person_weight` | Drop: duplicates of D01 | 0 mismatches; `age` is first used to repair D01 |
| `education_level_code` | Use, then drop | Identical to D02 (0 mismatches) with no missing values; fills D02's 120 gaps |
| `employment_status2code` | **Keep: outcome (Links B, C)** | Complete; employed / unemployed / not economically active |
| `employment_status1code` | Drop: duplicate | Same information as `employment_status2code`, but 21,399 "not economically active" rows are labelled "Unspecified" and 100 values are missing |
| `wage_work_code`, `business_work_code`, `volunteer_work_code`, `retired_code` | Drop: leakage | Employment status is built from these questions; everyone with `wage_work_code` = 1 is Employed (15,782 of 15,782) |
| `looking_for_work_code`, `could_start_work_code` | Drop: leakage | They define unemployment; `looking_for_work_code` = 1 covers all 10,137 unemployed |
| `transport_to_work_code`, `minutes_to_work`, `sector_code` | Drop: leakage | Only recorded for employed people; "not applicable" for 100% of unemployed and inactive people |
| `salary_amount_raw` | Drop: unusable | Only 7 distinct values (1, 2, 3, 8, …), so it does not contain Rand amounts |
| `salary_period_code` | Drop | Describes the pay period of `salary_amount_raw`, which is dropped; 84% not applicable |
| `salary_category_code` | Drop | Cannot fill salary gaps: all 719 employed people without a salary value are coded "don't know", "refused" or not applicable |
| `lab_salary_raw` | **Keep: outcome (Link D only)** | 96% of employed people report a value; never used as a predictor, because only employed people can have a salary |

**D08: Connectivity Access (18 → 4 columns + key)**

| Column | Decision | Evidence |
|---|---|---|
| `survey_year`, `province` | Drop | See above |
| `household_id` | **Keep: key** | Unique per household (20,940); joins onto persons |
| `province_code`, `geo_type_code` | Drop: duplicates of D01 | Identical for all 20,940 households |
| `fixed_internet_code` | **Keep: exposure / moderator** | Core connectivity; 2 rows coded 9 (not in the dictionary) |
| `mobile_internet_code` | **Keep: exposure / moderator** | Core connectivity; 60 missing and 2 coded 9 |
| `computer_asset_code` | **Keep: exposure / moderator** | Computer access, named explicitly in the business objective |
| `household_smartphones` | **Keep: exposure / moderator** | Internet-capable devices; 15 negative counts to treat in Task 2 |
| `household_mobile_phones` | Drop | Basic phones do not provide internet access; smartphones capture this |
| `cellphone_code` | Drop | 95.7% "yes"; every household with at least one phone is coded 1 |
| `telephone_code` | Drop: not internet | Landline; 97% "no" |
| `study_internet_code` | Drop: leakage (Link A) | Using the internet for study implies someone is studying, which is part of the education outcome: 80% of youth in households reporting study use are themselves attending (633 of 789) |
| `work_internet_code` | Drop: leakage (Links B, C) | Using the internet for work implies having work |
| `public_wi_fi_internet_code`, `library_internet_code`, `cafe_internet_code` | Drop: outside the home | 1.7–6.1% "yes"; the research question concerns household access |
| `household_weight` | Drop | The final grain is the person, so `person_weight` applies |

---

## 7. Attribute Importance and Weighting

### 7.1 Attribute Importance

Attributes are ranked by their role in answering the research questions:

| Tier | Attributes | Treatment |
|---|---|---|
| 1. Outcomes | `education_level_code`, `education_attendance_code`, `institution_type_code` (Link A); `employment_status2code` (Links B, C); `lab_salary_raw` (Link D) | Define what is being explained |
| 2. Exposure / moderator | `fixed_internet_code`, `mobile_internet_code`, `computer_asset_code`, `household_smartphones` | Always included; the focus of the study |
| 3. Controls | `age`, `sex_code`, `population_group_code`, `province_code`, `geo_type_code`, `metro_indicator` | Fixed set, always included, to prevent distortion of Tiers 1–2 |
| 4. Descriptive only | `reason_not_attending_code` | Used to interpret Link A; never a model input |
| 5. Linkage and design | `household_id`, `person_number`, `psu`, `person_weight` | Never used as predictors |

Importance is expressed through each attribute's **role in the model**, not through arbitrary numeric multipliers. Tier 1–3 variables are fixed in advance and are not subject to automated variable selection, which could otherwise drop a core variable. The tree-based model in Milestone 3 will estimate variable importance from the data, which will be compared against this ranking.

### 7.2 Survey Weights

The data come from a stratified, multi-stage cluster sample (Milestone 1 risk #5), so each record represents a different number of people.

- **`person_weight`** is retained and used for population-level descriptive statistics (e.g. the percentage of working-age South Africans with household internet access).
- **`psu`** is retained so that model standard errors can account for sampling clusters and households.
- Whether weights are also applied when fitting the models is decided in Task 4, with weighted and unweighted results compared as a robustness check.
- **`household_weight`** (D08) is not retained, because the final grain is the person.

---

## 8. The Intended Analytical Dataset

| # | Column | Source | Role |
|---|---|---|---|
| 1 | `household_id` | D01 | Key |
| 2 | `person_number` | D01 | Key |
| 3 | `psu` | D01 | Survey design |
| 4 | `person_weight` | D01 | Survey weight |
| 5 | `age` | D01 (repaired from D02/D03) | Control, record filter |
| 6 | `sex_code` | D01 | Control |
| 7 | `population_group_code` | D01 | Control |
| 8 | `province_code` | D01 | Control (H4) |
| 9 | `geo_type_code` | D01 | Control (H4) |
| 10 | `metro_indicator` | D01 | Control (H4) |
| 11 | `education_level_code` | D02 (gaps filled from D03) | Outcome (A), predictor (B, C) |
| 12 | `education_attendance_code` | D02 | Outcome (A, youth), control (C) |
| 13 | `institution_type_code` | D02 | Outcome (A, youth: post-school enrolment) |
| 14 | `reason_not_attending_code` | D02 | Descriptive only (A) |
| 15 | `employment_status2code` | D03 | Outcome (B, C) |
| 16 | `lab_salary_raw` | D03 | Outcome (D) |
| 17 | `fixed_internet_code` | D08 | Exposure / moderator |
| 18 | `mobile_internet_code` | D08 | Exposure / moderator |
| 19 | `computer_asset_code` | D08 | Exposure / moderator |
| 20 | `household_smartphones` | D08 | Exposure / moderator |

**20 of the 83 source columns** are retained (join keys counted once), at a grain of one row per person aged 15–64: **45,413 persons in 19,780 households** before Task 2 cleaning.

Further education detail is **derived in Task 3** from these columns rather than by keeping extra source columns, with the original code columns kept for traceability:

- **Combined digital-access indicator:** from the four D08 columns.
- **Education bands / years of schooling:** from `education_level_code` (code 98 "no schooling" placed at the bottom of the scale).
- **Post-school enrolment:** from `education_attendance_code` + `institution_type_code`.
- **Matric completed (ages 20–24) and behind the expected grade for age:** from `education_level_code` + `age`.
- **Highest education of other adults (25+) in the household:** from other members' `education_level_code` and `age`. This controls for family background in Link A.
- **Household size:** number of persons per household in D01.

---

## 9. Limitations and Open Decisions

| Item | Status |
|---|---|
| Employment target definition (labour force only vs all working-age) | Decided in Task 4; both remain possible with this dataset |
| Household wealth is not controlled (D09 excluded) | Recorded as a limitation. If Milestone 3 results suggest wealth drives the associations, a D09 asset-based wealth control can be added without changing the grain (D09 is household-level and joins the same way as D08). |
| Family background (e.g. parents' education) may drive both household internet access and youth education | Controlled in Link A with the derived "highest education of other adults in the household" feature (Task 3) |
| Cross-sectional data | All findings are reported as associations |
| Access is measured per household, not per person | Findings refer to living in a connected household, not to personal internet use |
| 60 households with missing `mobile_internet_code` | Treatment decided in Task 2 |

---

## References

Department of Communications, 2013, *South Africa Connect: Creating opportunities, ensuring inclusion*, Electronic Communications Act No. 36 of 2005, Government Gazette (37119), 3–64. Available at: https://www.gpwonline.co.za (Accessed: 5 September 2026).

Frans, C. & Pather, S., 2022, 'Determinants of ICT adoption and uptake at a rural public-access ICT centre: A South African case study', *African Journal of Science, Technology, Innovation and Development*, 14(6), pp. 1575–1590. https://doi.org/10.1080/20421338.2021.1975354

Ohei, K.N. & Alao, A., 2019, 'Information and communication technology (ICTs) graduates and challenges of employability: A conceptual framework for enhancing employment opportunities in South Africa', *Gender & Behaviour*, 17, pp. 13500–13521.

Oyedemi, T.D. & Choung, M., 2020, 'Digital inequality and youth unemployment in South Africa', *Communicatio*, 46(3), pp. 68–86. https://doi.org/10.1080/02500167.2020.1821738

Plavgo, I., 2023, 'Education and active labour market policy complementarities in promoting employment: Reinforcement, substitution and compensation', *Social Policy & Administration*, 57(2), pp. 235–253. https://doi.org/10.1111/spol.12894

Shaw, P. & Wheeler, L., 2023, 'Digital networking and the case of youth unemployment in South Africa', in T. Madon, A.J. Gadgil, R. Anderson, L. Casaburi, K. Lee & A. Rezaee (eds.), *Introduction to Development Engineering*, pp. 293–321, Springer, Cham. https://doi.org/10.1007/978-3-030-86065-3_12

Statistics South Africa, 2024, *Quarterly Labour Force Survey*. Pretoria: Statistics South Africa. *(Confirm the specific quarterly release used for the working-age definition.)*

Statistics South Africa, 2026, *isiBalo data portal*. Available at: https://isibaloweb.statssa.gov.za/
