# Descriptions to add to EDA.qmd later

## 1. Fix needed on existing line 225

Current text says "D08 is person level" - this is WRONG, D08 is household-level.
Replace with:

> D08 is household-level, not person-level, so it cannot be checked with a
> composite key the way D02 and D03 were. The household_id-only intersect
> check performed earlier (20,684 matches, ~99% of D01's unique households)
> is the correct and complete verification for D08.

---

## 2. Dataset exclusion descriptions (for the "Which Datasets we dont choose" section)

D04 - Dwelling Conditions
> Describes housing/dwelling structure (wall material, roof material, dwelling
> type). While household infrastructure could plausibly relate to connectivity
> access (e.g. formal housing may correlate with electricity/internet
> availability), it is not central to the core mechanism being tested -
> whether connectivity moderates education's effect on employment. Excluded
> to keep the model focused; may be reconsidered as a control variable if
> needed during modelling (M3).

D05 - Basic Services
> Covers water, sanitation, and basic service access. Relevant to general
> household wellbeing but not directly tied to the education-employment-
> connectivity relationship this project investigates. Excluded for focus.

D06 - Household Energy
> Covers electricity/cooking energy sources. Notably, electricity access is
> a plausible precondition for internet/computer use, so there is some
> conceptual overlap with D08. However, D08 already captures connectivity
> directly, making D06 redundant for this specific analysis. Excluded.

D07 - Household Wellbeing
> Covers food security and hunger indicators. Relevant to broader household
> vulnerability research but outside the scope of the education-employment-
> connectivity mechanism this project tests. Excluded.

D09 - Household Resources
> Covers income, grants, assets. Could serve as a useful control variable
> for household socioeconomic status in a more complex model, but is not
> required to test the core moderation hypothesis. Excluded for this
> iteration; a candidate for future refinement.

D10 - Mobility Access
> Covers transport access and commuting. Relevant to employment access more
> broadly (e.g. distance to work), but not part of the specific connectivity-
> education-employment mechanism being tested. Excluded.

D11 - Labour Market
> Excluded as the primary employment-outcome source. A key-relationship
> check confirmed zero overlapping household_id values between D01 and D11
> (see intersect results), conclusively ruling out reliable person-level
> linkage. This is consistent with the project brief's warning that D11
> originates from a separate survey environment. D03 (Economic Participation)
> was used instead, as it shares near-identical row counts and structure
> with D01, indicating the same survey wave and a consistent ID system.

---

## 3. Intersect result write-ups (more detailed narrative if needed)

### Household-level checks summary
> To confirm the four selected datasets could be reliably linked before
> proceeding with joins, household_id overlap was checked against D01 as
> the anchor dataset. D02, D03, and D08 each showed 20,684 shared household
> IDs with D01 - approximately 99% of D01's unique households
> (20,684 / n_distinct(D01$household_id) * 100). This confirms all three
> can be reliably joined to D01 via household_id. D11 showed zero overlap,
> confirming it uses a separate identifier system entirely and cannot be
> linked at the household level.

### Person-level (composite key) checks summary
> Since D01, D02, and D03 are person-level datasets, household_id alone is
> insufficient to confirm the SAME individuals are being linked (multiple
> people share a household_id). A composite key was built by combining
> household_id and person_number for each dataset. The intersect of these
> composite keys between D01-D02 and D01-D03 returned counts close to
> D01's total row count (70,440), confirming strong person-to-person
> linkage - not just household-to-household. This means education (D02)
> and employment (D03) records can be reliably matched to the correct
> individual's demographic record (D01).

### Why D08 only needed a household-level check
> D08 is household-level (one row per household, not per person), so a
> composite key with person_number does not apply - connectivity access is
> a household attribute shared by everyone living there. The household_id-
> only check already performed is sufficient and complete for D08.
