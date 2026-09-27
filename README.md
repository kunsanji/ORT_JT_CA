=== CALIFORNIA DIABETES & SOCIAL DETERMINANTS ===

Research question:
  Which social and economic conditions predict county-level diabetes
  prevalence across California, and where is the burden geographically
  concentrated?

Explore diabetes prevalence, health care access, education, food
environment and population scale across California's 58 counties.

Author:         Ba Tung (Jackey) Tran
Institution:    University of Illinois Springfield
Date completed: 2026-09-26

Repository:     https://github.com/kunsanji/ORT_JT_CA.git
DOI:            https://doi.org/10.5281/zenodo.22986615


--- Dashboards ---
California Diabetes Burden & Population Scale
Where is diabetes prevalence highest across California counties, and
how does that geographic pattern change when counties are viewed by
population rather than by land area?




--- Data sources ---
ACS 5-Year 2020-2024    U.S. Census Bureau, via tidycensus and the Census API
                        https://data.census.gov/
CDC PLACES 2025         Centers for Disease Control and Prevention
                        https://data.cdc.gov/resource/swc5-untb
CDC/ATSDR SVI 2022      Social Vulnerability Index
                        https://www.atsdr.cdc.gov/place-health/php/svi/index.html
CDC/ATSDR EJI 2024      Environmental Justice Index
                        https://www.atsdr.cdc.gov/place-health/php/eji/index.html
HRSA AHRF 2024-2025     Area Health Resources Files
                        https://data.hrsa.gov/topics/health-workforce/ahrf
HRSA Health Centers     Health Center Service Delivery sites
                        https://data.hrsa.gov/data/download
USDA Food Atlas 2019    Food Access Research Atlas
                        https://www.ers.usda.gov/data-products/food-access-research-atlas/
CHR&R 2025              County Health Rankings & Roadmaps
                        https://www.countyhealthrankings.org/health-data
NCES CCD 2024-2025      Common Core of Data
                        https://nces.ed.gov/ccd/files.asp

Eight sources merged into a single 58-row, 55-column county file. All
downloaded 2026-08-16.

Raw source files are not included in this repository because several exceed
GitHub's file size limit. All are free public downloads. Each script header
gives the exact download path and expected file name.


--- Analysis configuration ---
State:             California (FIPS 06)
Geography:         County level, all 58 counties
Outcome:           diabetes_pct (CDC PLACES 2025, crude prevalence)
Predictors:        poverty_rate, pct_bachelor_plus, uninsured_rate,
                   pct_lila_tracts
Analysis label:    diabetes_sdoh_model_ca
Methods:           Multiple linear regression with full assumption checks,
                   plus logistic regression on a median split


--- Script run order ---
01_acs.R -> 02_places.R -> 03_svi_eji.R -> 04_hrsa.R
-> 05_usda_nces_chr.R -> 06_merge_all.R -> 07_analysis.R

Every script prints its row count. All should report 58.


--- Key results ---
Diabetes prevalence ranges from 9.3% (Yolo County) to 15.9% (Trinity
County), median 12.0%. The highest-burden counties are small and rural.
The 15 counties with the highest prevalence contain about 6% of
California's census tracts.

Multiple linear regression, n = 58
  R2 = 0.547, adjusted R2 = 0.513, F(4, 53) = 15.98, p < 0.001

  pct_bachelor_plus   b = -0.047   95% CI -0.078 to -0.016   p = 0.004
  uninsured_rate      b =  0.258   95% CI  0.091 to  0.424   p = 0.003
  poverty_rate        b =  0.043   95% CI -0.044 to  0.130   p = 0.324
  pct_lila_tracts     b =  0.004   95% CI -0.020 to  0.029   p = 0.720

  All four predictors were significant unadjusted. Only educational
  attainment and uninsured rate remained significant when adjusted for
  one another.

Assumption checks
  Breusch-Pagan p = 0.065   homoscedasticity met
  Shapiro-Wilk  p = 0.595   normality of residuals met
  VIF 1.41 to 2.00          no multicollinearity

Logistic regression, binary outcome split at the state median (12.0%)
  29 high counties, 29 low counties
  McFadden pseudo-R2 = 0.491, AIC = 50.96
  Hosmer-Lemeshow p = 0.244, model fits adequately
  Classification accuracy 82.8%

  pct_bachelor_plus   OR = 0.83   95% CI 0.72 to 0.92   p = 0.003
  uninsured_rate      OR = 1.69   95% CI 1.07 to 3.14   p = 0.053


--- Limitations ---
Ecological design. All associations are between county-level rates and
  cannot be interpreted as individual-level risk.

Sample size. n = 58 counties. The median split produces 29 events, so
  events per predictor variable is 7.2, below the conventional threshold
  of 10. The linear model is the primary analysis and the logistic model
  is supporting.

Cross-sectional with mixed vintages. Source years differ (ACS 2020-2024,
  PLACES 2021-2022 BRFSS, USDA Atlas 2019), so temporal ordering between
  predictors and outcome cannot be established.

Influential observations. Cook's Distance flagged 7 counties (Imperial,
  Modoc, Mono, Santa Barbara, Sierra, Trinity, Yolo). Excluding them,
  uninsured_rate weakened from 0.258 to 0.117 and lost significance,
  while pct_bachelor_plus held (-0.047 to -0.053, p < 0.001). The
  education finding is robust; the insurance finding is sensitive to a
  small number of counties.

Population scale. County populations range from roughly 1,200 (Alpine)
  to 10 million (Los Angeles). Unweighted county-level models give equal
  weight to each county regardless of population.


--- Known data notes ---
Seven corrections were made to the published toolkit code. Five produce
silently wrong output rather than an error. Full detail is in the change
log accompanying this repository.

voter_turnout uses CHR&R v177. The toolkit's published code uses v153,
  which is homeownership, not voter turnout.
pct_no_vehicle_far is reported as given by USDA (already a percentage).
  The toolkit's published code multiplies it by 100 in error.
mean_dist_supermarket is a population share, not a distance, despite the
  variable name. Retained under the original name for compatibility.
frl_total is the free and reduced lunch table total, not enrollment.
pct_free_lunch and pct_reduced_lunch use frl_total as denominator, so
  they sum to 100 by construction and are not comparable to an
  enrollment-based rate.
n_tracts is the count of census tracts per county, used as a population
  proxy in the dashboard. Tracts are designed around roughly 4,000
  residents, so the count tracks population but is not a headcount.


--- Repository contents ---
code/                            R scripts 01 through 07
data/clean/                      eight cleaned source files, 58 rows each
data/master/sdoh_ca_master.csv   merged county file, 58 rows, 55 columns
output/tableau/                  Tableau extract, health center points,
                                 HPSA long format
output/tables/                   descriptive, regression and odds ratio CSVs
output/figures/                  correlation matrix, regression diagnostics
dictionary/data_dictionary.csv   all 55 variables with label, source, year
README.txt                       this file
LICENSE                          MIT


--- Reproducing this analysis ---
1. Register a free Census API key at
   https://api.census.gov/data/key_signup.html
2. Download the raw files listed above into data/raw/
3. Create the folders data/clean, data/master, output/tables,
   output/figures, output/tableau and dictionary
4. Run the scripts in the order listed above

Adapting to another state: change the state abbreviation and FIPS prefix
in Scripts 1 through 5, and update the valid county FIPS sequence in
Script 5 Part C. Ten edits in total, marked in the script comments.

--- GitHub repository ---
Repository URL: https://github.com/kunsanji/ORT_JT_CA.git
Visibility:     Public

--- Zenodo DOI ---
DOI:            https://doi.org/10.5281/zenodo.22986615

--- License ---
Code: MIT License, see LICENSE.
Data: derived from public U.S. federal and academic sources listed above.
Each retains its own terms. Cite the original source, not this repository,
when reusing the underlying data.


--- R environment ---
R version: 4.5.3
OS:        Darwin 27.0.0 (macOS)

Packages
  tidycensus 1.8.1      tidyverse 2.0.0           haven 2.5.5
  readxl 1.5.0          janitor 2.2.1             skimr 2.2.2
  corrplot 0.95         car 3.1.5                 broom 1.0.13
  lmtest 0.9.40         ResourceSelection 0.3.6   sandwich 3.1.3janitor : 2.2.1 
skimr : 2.2.2 
corrplot : 0.95 
car : 3.1.5 
broom : 1.0.13 
lmtest : 0.9.40 
ResourceSelection : 0.3.6 
sandwich : 3.1.3 
