=== SDOH TOOLKIT - PROJECT README ===

Author:            Ba Tung (Jackey) Tran
Institution:       University of Illinois Springfield
Date completed:    2026-09-20 
Research question: [One sentence]

--- Analysis configuration ---
State:             ca 
Geography:         County level (58 California counties)
Outcome variable:  diabetes_pct 
Predictors:        unemployment_rate, pct_bachelor_plus, uninsured_rate, pct_no_vehicle_far 
Analysis label:    diabetes_sdoh_model_ca 

--- Script run order ---
01_acs.R -> 02_places.R -> 03_svi_eji.R -> 04_hrsa.R
-> 05_usda_nces_chr.R -> 06_merge_all.R -> 07_analysis.R

--- Data download dates ---
ACS 2020-2024:     [date]
CDC PLACES 2025:   [date]
SVI 2022:          [date]
EJI 2024:          [date]
HRSA AHRF 2024-25: [date]
USDA Atlas 2019:   [date]
CHR&R 2025:        [date]
NCES CCD 2024-25:  [date]

--- Output files ---
Master CSV:    data/master/sdoh_ca_master.csv
Tableau CSV:   output/tableau/sdoh_ca_tableau.csv
Descriptive:   output/tables/01_descriptive_diabetes_sdoh_model_ca.csv
LM results:    output/tables/03_lm_results_diabetes_sdoh_model_ca.csv
Logit results: output/tables/04_logit_OR_diabetes_sdoh_model_ca.csv
Correlation:   output/figures/02_correlation_diabetes_sdoh_model_ca.png
Diagnostics:   output/figures/03_lm_diagnostics_diabetes_sdoh_model_ca.png

--- Known data notes ---
voter_turnout uses CHR&R v177. The toolkit's v153 is homeownership.
pct_no_vehicle_far is reported as given by USDA (already a percentage).
mean_dist_supermarket is a population share, not a distance.
frl_total is the free/reduced lunch table total, not enrollment.
pct_free_lunch and pct_reduced_lunch use frl_total as denominator,
  so they sum to 100 by construction. Not comparable to enrollment.

--- GitHub repository ---
Repository URL: [your GitHub URL]
Visibility:     Public

--- Zenodo DOI ---
DOI: [your DOI]

--- R environment ---
R version: 4 . 5.3 
OS: Darwin 27.0.0 

--- Package versions ---
tidycensus : 1.8.1 
tidyverse : 2.0.0 
haven : 2.5.5 
readxl : 1.5.0 
janitor : 2.2.1 
skimr : 2.2.2 
corrplot : 0.95 
car : 3.1.5 
broom : 1.0.13 
lmtest : 0.9.40 
ResourceSelection : 0.3.6 
sandwich : 3.1.3 
