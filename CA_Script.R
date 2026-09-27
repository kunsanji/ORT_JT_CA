# ############################################################################
# OPEN SCHOLARSHIP TOOLKIT - CALIFORNIA - corrected
# ############################################################################
#
# Sections 1B (install packages) and 1C (Census API key) are omitted.
# You already ran both.
#
# This file keeps all 10 of your state edits and adds 7 bug fixes, each
# marked  # <<< FIX n of 6  so you can point at it on screen.
#
# ---------------------------------------------------------------------------
# WHY YOUR RUN FAILED
# ---------------------------------------------------------------------------
# Sample size came back as 0 because two of the eight source files joined to
# nothing. Both were leading zero problems, and both were invisible in
# Illinois because Illinois FIPS codes start with 17.
#
#   FIX 1  Script #5 Part B. The line  across(everything(), as.numeric)
#          converted the fips column too, so "06001" became the number 6001.
#          Written out and read back it was 6001, which never matched the
#          ACS "06001". All 8 County Health Rankings columns came back NA.
#          Illinois "17001" survives the round trip unchanged, which is why
#          nobody caught this.
#
#   FIX 2  Script #5 Part C. read.delim() and read.csv() parse "06" and
#          "06001" as the integers 6 and 6001. So
#            as.character(fipst) == "06"        was  "6" == "06"   FALSE
#            str_sub(fips, 1, 2) == "06"        was  "60" == "06"  FALSE
#          Every filter returned 0 rows, so 05c_nces_ccd_clean.csv was
#          written with 0 rows. Fixed by reading those columns as character.
#
# Together these made 12 of 55 columns entirely NA. drop_na() in Script #7
# then removed all 58 counties, which is the "Sample size: 0" you saw.
#
# ---------------------------------------------------------------------------
# THREE MORE FIXES (these did not error, they produced wrong numbers)
# ---------------------------------------------------------------------------
#   FIX 3  voter_turnout was mapped to v153_rawvalue. In the 2025 CHR&R file
#          v153 is HOMEOWNERSHIP. Voter turnout is v177. Verified against the
#          label row of your own 2025CHR_CSV_Analytic_Data.csv.
#
#   FIX 4  pct_no_vehicle_far multiplied lahunv1share by 100. In your
#          FoodAccessResearchAtlasData.xlsx that column is already a
#          percentage (California range 0 to 32.3, mean 1.38). The multiplier
#          inflated it roughly 100x.
#
#   FIX 5  The data dictionary assigned its 55 labels by position. The PLACES
#          column order comes out of pivot_wider() in whatever order the
#          measures appear in the download, and your California order is
#          different from the Illinois order the labels were written for.
#          Every PLACES label would have attached to the wrong variable.
#          Rebuilt as a name lookup, so order no longer matters.
#
#   FIX 6  The dictionary block read sdoh_il_master.csv. Changed to ca.
#
#   FIX 7  pct_free_lunch was identical (86.52) for all 58 counties. Two
#          causes, both in Script #5 Part C.
#
#          (a) ifelse() returns a result the same length as its TEST.
#              lunch_check > 0 is a single value, so
#                ifelse(lunch_check > 0, round(free/total*100, 2), NA_real_)
#              returned ONE number, the first county's, and dplyr recycled
#              it across all 58 rows. 86.52 is Alameda. The real values
#              range from 75.35 to 99.12. Replaced with a plain if().
#              In Illinois lunch_check was 0, so this returned a single NA
#              that recycled to an all-NA column, which looked exactly like
#              "Illinois does not report this". That is why it never showed.
#
#          (b) total_enrollment was never enrollment. In this CCD file the
#              row  No Category Codes / Education Unit Total  inside the
#              Free and Reduced-price Lunch Table is the sum of the free,
#              reduced and missing categories, not the student body.
#              Statewide it is 3,592,718 against free + reduced + missing
#              of 3,592,715. So the percentage was free as a share of
#              FRL-eligible students, which is why free and reduced summed
#              to exactly 100. Renamed the column to frl_total so nobody
#              reads it as enrollment, and relabelled both percentages.
#
#              If you want true enrollment by county, it is not in this
#              file. Use the CCD Membership file, or the ACS school
#              enrollment table B14001, and treat this one as FRL only.
#
# ---------------------------------------------------------------------------
# WHAT TO RE-RUN
# ---------------------------------------------------------------------------
# Scripts #1, #2, #3, #4 are fine. Their clean files are already correct.
# Start at Script #5, then #6, then #7, then the README and dictionary.
#
# Checkpoints: Script #5 should print 58 for USDA, 58 for CHR&R, and roughly
# 55 to 58 for NCES CCD. If NCES prints 0 again, the read fix did not apply.
#
# ---------------------------------------------------------------------------
# ONE NOTE ON YOUR UPLOADS
# ---------------------------------------------------------------------------
# FoodAccessResearchAtlasData.csv is a byte for byte copy of
# 2025CHR_CSV_Analytic_Data.csv. Something went wrong when you saved it.
# The .xlsx is the real Food Atlas file and is what Script #5 Part A reads,
# so nothing breaks. Just delete the stray .csv so it does not confuse you
# or anyone who downloads your repo.
# ############################################################################


# ============================================================================
# PART 2 / 2  - Browse ACS variable codes in RStudio
# ============================================================================

library(tidycensus)
vars <- load_variables(2024, "acs5")
View(vars)   # opens a searchable table in RStudio


# ============================================================================
# SCRIPT #1 - ACS 5-Year Download (Domains 1 & 2)
# ============================================================================

# Source:    U.S. Census Bureau, American Community Survey 5-year estimates
# API:       api.census.gov via tidycensus package
# Geography: County level, California (state = 'CA')
# Year:      2024 (most recent 5-year ACS, 2020-2024)
# Citation:  U.S. Census Bureau. (2026). ACS 5-year estimates 2020-2024.
#            https://data.census.gov/

library(tidycensus)
library(tidyverse)
library(janitor)

acs_vars <- c(
  # Domain 1 - Economic Stability
  total_pop          = "B17001_001",  # total population for poverty denom
  poverty_count      = "B17001_002",  # persons below poverty line
  median_hh_income   = "B19013_001",  # median household income ($)
  unemployed         = "B23025_005",  # unemployed persons in labor force
  labor_force        = "B23025_002",  # total labor force
  snap_hh            = "B22010_002",  # households receiving SNAP
  total_hh           = "B22010_001",  # total households (SNAP denom)
  rent_burden_30plus = "B25070_007",  # gross rent 30-34.9% of income
  rent_burden_35plus = "B25070_008",  # gross rent 35-39.9% of income
  rent_burden_40plus = "B25070_009",  # gross rent 40-49.9% of income
  rent_burden_50plus = "B25070_010",  # gross rent 50%+ of income
  rent_denom         = "B25070_001",  # renter-occupied units (denom)
  
  # Domain 2 - Education Access & Quality
  edu_total_25plus   = "B15003_001",  # total pop 25+ (education denom)
  no_hs_diploma      = "B15003_002",  # less than 9th grade
  hs_graduate        = "B15003_017",  # HS graduate or equivalent
  bachelors          = "B15003_022",  # bachelor's degree
  graduate           = "B15003_023",  # master's degree
  professional       = "B15003_024",  # professional school degree
  doctorate          = "B15003_025",  # doctorate degree
  
  # Domain 3 - cross-domain variable (health insurance)
  uninsured_pct = "DP03_0099P"  # % of residents without health insurance
)

acs_raw <- get_acs(
  geography = "county",
  variables = acs_vars,
  state     = "CA",          # <<< EDIT 1 of 10: Illinois -> California
  year      = 2024,
  survey    = "acs5",
  output    = "wide"
)

acs_clean <- acs_raw %>%
  clean_names() %>%
  rename(county_name = name) %>%
  mutate(
    fips = str_pad(geoid, width = 5, side = "left", pad = "0"),
    
    poverty_rate      = round(poverty_count_e / total_pop_e   * 100, 2),
    unemployment_rate = round(unemployed_e    / labor_force_e * 100, 2),
    snap_rate         = round(snap_hh_e       / total_hh_e    * 100, 2),
    
    rent_burden_rate = round(
      (rent_burden_30plus_e + rent_burden_35plus_e +
         rent_burden_40plus_e + rent_burden_50plus_e) / rent_denom_e * 100, 2),
    
    pct_no_hs   = round(no_hs_diploma_e / edu_total_25plus_e * 100, 2),
    pct_hs_grad = round(hs_graduate_e   / edu_total_25plus_e * 100, 2),
    pct_bachelor_plus = round(
      (bachelors_e + graduate_e + professional_e + doctorate_e) /
        edu_total_25plus_e * 100, 2),
    
    uninsured_rate = uninsured_pct_e
  ) %>%
  select(fips, county_name, poverty_rate, median_hh_income_e,
         unemployment_rate, snap_rate, rent_burden_rate,
         pct_no_hs, pct_hs_grad, pct_bachelor_plus, uninsured_rate) %>%
  rename(median_hh_income = median_hh_income_e)

glimpse(acs_clean)
summary(acs_clean)

write_csv(acs_clean, "data/clean/01_acs_clean.csv")
cat("Script #1 complete. Rows:", nrow(acs_clean), "\n")   # expect 58


# ============================================================================
# SCRIPT #2 - CDC PLACES 2025 County Data (Domain 3)
# ============================================================================

# Source:    Centers for Disease Control and Prevention
# Endpoint:  https://data.cdc.gov/resource/swc5-untb.csv
# Citation:  CDC. (2025). PLACES: Local data for better health, county data
#            2025 release. https://data.cdc.gov/resource/swc5-untb

library(tidyverse)
library(janitor)

places_raw <- read.csv(
  "https://data.cdc.gov/resource/swc5-untb.csv?StateAbbr=CA&$limit=10000",   # <<< EDIT 2 of 10
  stringsAsFactors = FALSE
)

cat("Total rows downloaded:", nrow(places_raw), "\n")
names(places_raw)
unique(places_raw$measureid) %>% sort()

places_raw %>%
  filter(datavaluetypeid == "CrdPrv") %>%
  group_by(measureid) %>%
  summarise(n_counties = n()) %>%
  arrange(n_counties) %>%
  View()

measures_keep <- c(
  "DIABETES", "OBESITY", "BPHIGH", "DEPRESSION", "COPD", "CASTHMA",
  "CSMOKING", "LPA", "COLON_SCREEN", "MAMMOUSE", "ACCESS2"
)

places_wide <- places_raw %>%
  filter(measureid %in% measures_keep) %>%
  filter(datavaluetypeid == "CrdPrv") %>%
  select(locationid, locationname, measureid, data_value) %>%
  mutate(
    fips       = str_pad(locationid, width = 5, side = "left", pad = "0"),
    data_value = as.numeric(data_value)
  ) %>%
  pivot_wider(
    id_cols     = c(fips, locationname),
    names_from  = measureid,
    values_from = data_value
  ) %>%
  clean_names() %>%
  rename(
    diabetes_pct          = diabetes,
    obesity_pct           = obesity,
    hypertension_pct      = bphigh,
    depression_pct        = depression,
    copd_pct              = copd,
    asthma_pct            = casthma,
    smoking_pct           = csmoking,
    inactivity_pct        = lpa,
    colorectal_screen_pct = colon_screen,
    mammography_pct       = mammouse,
    uninsured_places      = access2
  )

cat("Counties in PLACES data:", nrow(places_wide), "\n")
glimpse(places_wide)
write_csv(places_wide, "data/clean/02_places_clean.csv")
cat("Script #2 complete. Rows:", nrow(places_wide), "\n")   # expect 58


# ============================================================================
# SCRIPT #3 - SVI 2022 & EJI 2024 (Domains 4 & 5)
# ============================================================================

# SVI Source: ATSDR. (2023). SVI 2022.
#             https://www.atsdr.cdc.gov/place-health/php/svi/index.html
# EJI Source: CDC/ATSDR. (2024). Environmental Justice Index (EJI).
#             https://www.atsdr.cdc.gov/place-health/php/eji/index.html

library(tidyverse)
library(janitor)

# == PART A: Social Vulnerability Index (SVI) ================================

svi_raw <- read_csv("data/raw/SVI2022_US_county.csv")

svi_clean <- svi_raw %>%
  clean_names() %>%
  filter(st_abbr == "CA") %>%     # <<< EDIT 3 of 10
  mutate(
    fips = str_pad(as.character(fips), width = 5, side = "left", pad = "0"),
    across(starts_with("rpl_"), ~ ifelse(. == -999, NA, .))
  ) %>%
  select(
    fips,
    county_name  = county,
    svi_overall  = rpl_themes,
    svi_socioeco = rpl_theme1,
    svi_hh_char  = rpl_theme2,
    svi_minority = rpl_theme3,
    svi_housing  = rpl_theme4,
    pct_poverty  = ep_pov150,
    pct_unemp_svi= ep_unemp,
    pct_uninsured_svi = ep_uninsur
  )

cat("SVI rows (CA counties):", nrow(svi_clean), "\n")   # expect 58
write_csv(svi_clean, "data/clean/03a_svi_clean.csv")

# == PART B: Environmental Justice Index (EJI) ==============================
# EJI is tract level, aggregated to county by averaging

eji_raw <- read_csv("data/raw/EJI_2024_US.csv")

eji_county <- eji_raw %>%
  clean_names() %>%
  mutate(
    fips       = str_sub(geoid, 1, 5),
    state_abbr = stateabbr
  ) %>%
  filter(state_abbr == "CA") %>%   # <<< EDIT 4 of 10
  mutate(across(c(rpl_eji, rpl_ebm, rpl_svm, rpl_hvm),
                ~ ifelse(. == -999, NA, .))) %>%
  group_by(fips) %>%
  summarise(
    eji_overall     = round(mean(rpl_eji, na.rm = TRUE), 4),
    eji_env_burden  = round(mean(rpl_ebm, na.rm = TRUE), 4),
    eji_social_vuln = round(mean(rpl_svm, na.rm = TRUE), 4),
    eji_health_vuln = round(mean(rpl_hvm, na.rm = TRUE), 4),
    n_tracts        = n()
  ) %>%
  ungroup()

cat("EJI county rows (CA):", nrow(eji_county), "\n")   # expect 58
write_csv(eji_county, "data/clean/03b_eji_county_clean.csv")
cat("Script #3 complete.\n")


# ============================================================================
# SCRIPT #4 - HRSA HPSA Shortage Areas from AHRF (Domain 3)
# ============================================================================

# Source:   HRSA, Area Health Resources Files (AHRF) 2024-2025
# URL:      https://data.hrsa.gov/data/download
# Citation: HRSA, Bureau of Health Workforce. (2025). Area Health Resources
#           Files 2024-2025. https://data.hrsa.gov/data/download
# HPSA codes: 0 = no designation, 1 = partial county, 2 = whole county

library(tidyverse)
library(janitor)

ahrf_raw <- read_csv("data/raw/AHRF2025.csv")
names(ahrf_raw) %>% sort()

hpsa_clean <- ahrf_raw %>%
  clean_names() %>%
  filter(st_name_abbrev == "CA") %>%   # <<< EDIT 5 of 10
  mutate(
    fips = str_pad(as.character(fips_st_cnty), 5, "left", "0")
  ) %>%
  select(
    fips,
    county_name        = cnty_name,
    hpsa_prim_care     = hpsa_prim_care_25,
    hpsa_dental        = hpsa_dent_25,
    hpsa_mental_health = hpsa_mentl_hlth_25
  ) %>%
  mutate(
    across(c(hpsa_prim_care, hpsa_dental, hpsa_mental_health), as.numeric),
    hpsa_any_shortage = as.integer(
      hpsa_prim_care > 0 | hpsa_dental > 0 | hpsa_mental_health > 0),
    hpsa_prim_care_designated = as.integer(hpsa_prim_care > 0)
  )

cat("HPSA rows (CA counties):", nrow(hpsa_clean), "\n")   # expect 58

cat("\nPrimary care HPSA designation (0=none, 1=partial, 2=full):\n")
table(hpsa_clean$hpsa_prim_care)
cat("\nDental HPSA designation:\n")
table(hpsa_clean$hpsa_dental)
cat("\nMental health HPSA designation:\n")
table(hpsa_clean$hpsa_mental_health)
cat("\nCounties with ANY shortage designation:",
    sum(hpsa_clean$hpsa_any_shortage), "\n")

write_csv(hpsa_clean, "data/clean/04_hpsa_clean.csv")
cat("Script #4 complete.\n")


# ============================================================================
# SCRIPT #5 - USDA Food Access + County Health Rankings + NCES CCD
# ============================================================================

# USDA:  ers.usda.gov/data-products/food-access-research-atlas/download-the-data
#        Save as: data/raw/FoodAccessResearchAtlasData.xlsx  (2019 data year)
# CHR&R: countyhealthrankings.org/health-data/methodology-and-sources/data-documentation
#        Save as: data/raw/2025CHR_CSV_Analytic_Data.csv
# NCES CCD: nces.ed.gov/ccd/files.asp
#        Nonfiscal > School > 2024-2025 > LUNCH PROGRAM ELIGIBILITY
#              -> data/raw/ccd_lunch.csv
#        Nonfiscal > District > 2024-2025 > DIRECTORY
#              -> data/raw/ccd_lea_directory.csv
#        California DOES report free and reduced lunch counts
#        (9,874 schools with free lunch counts in this file). Illinois does not.

library(tidyverse)
library(readxl)
library(janitor)

# == PART A: USDA Food Access Research Atlas ================================

usda_raw <- read_excel(
  "data/raw/FoodAccessResearchAtlasData.xlsx",
  sheet = "Food Access Research Atlas"
)

usda_raw %>% clean_names() %>% names() %>%
  .[grep("lila|lapop|lahunv|tract|state", .)] %>%
  head(20)

usda_county <- usda_raw %>%
  clean_names() %>%
  filter(state == "California") %>%   # <<< EDIT 6 of 10
  mutate(
    fips = str_pad(as.character(census_tract), 11, "left", "0") %>%
      str_sub(1, 5),
    lapophalfshare = as.numeric(lapophalfshare),
    lahunv1share   = as.numeric(lahunv1share)
  ) %>%
  group_by(fips) %>%
  summarise(
    pct_lila_tracts = round(mean(lila_tracts_1and10, na.rm = TRUE) * 100, 2),
    
    # Share of tract population living more than half a mile from a
    # supermarket. This is a percentage, not a distance, despite the name.
    mean_dist_supermarket = round(mean(lapophalfshare, na.rm = TRUE), 4),
    
    # <<< FIX 1 of 7: removed  * 100
    # lahunv1share is already a percentage in this file (CA range 0 to 32.3).
    # The multiplier produced values in the hundreds.
    pct_no_vehicle_far = round(mean(lahunv1share, na.rm = TRUE), 2)
  ) %>%
  ungroup()

cat("USDA county rows:", nrow(usda_county), "\n")   # expect 58
write_csv(usda_county, "data/clean/05a_usda_food_access_clean.csv")

# == PART B: County Health Rankings 2025 ====================================

# <<< FIX 2 of 7: read every column as character.
# Stops readr from turning fipscode "06001" into the number 6001.
chr_raw <- read_csv(
  "data/raw/2025CHR_CSV_Analytic_Data.csv",
  skip = 1,
  col_types = cols(.default = col_character())
)

chr_clean <- chr_raw %>%
  clean_names() %>%
  filter(state == "CA",                # <<< EDIT 7 of 10
         fipscode != "06000") %>%      # remove the state summary row
  mutate(
    fips = str_pad(as.character(fipscode), 5, "left", "0")
  ) %>%
  select(
    fips,
    premature_death     = v001_rawvalue,
    poor_health_days    = v036_rawvalue,
    poor_mental_days    = v042_rawvalue,
    social_associations = v140_rawvalue,
    
    # <<< FIX 3 of 7: was v153_rawvalue, which is HOMEOWNERSHIP.
    # Voter turnout is v177. Verified against the label row of the
    # 2025 CHR&R analytic file.
    voter_turnout       = v177_rawvalue,
    
    adult_smoking       = v009_rawvalue,
    adult_obesity       = v011_rawvalue,
    food_insecurity     = v139_rawvalue
  ) %>%
  mutate(
    # <<< FIX 4 of 7: was across(everything(), as.numeric), which converted
    # fips as well and destroyed the leading zero. This is what made every
    # CHR&R column NA after the merge. -fips excludes it.
    across(-fips, as.numeric),
    
    voter_turnout   = voter_turnout   * 100,
    adult_smoking   = adult_smoking   * 100,
    adult_obesity   = adult_obesity   * 100,
    food_insecurity = food_insecurity * 100
  )

# Sanity check: fips must still be character with a leading zero
stopifnot(is.character(chr_clean$fips))
stopifnot(all(str_sub(chr_clean$fips, 1, 2) == "06"))

# Note: CHR&R column codes change with each annual release.
# Run names(chr_raw) and check the codebook if you move to a different year.
cat("CHR&R county rows:", nrow(chr_clean), "\n")   # expect 58
write_csv(chr_clean, "data/clean/05b_chr_clean.csv")

# == PART C: NCES CCD Lunch Program Eligibility =============================

STATE_FIPS <- "06"   # <<< EDIT 8 of 10: California = 06

# -- Census TIGER ZIP-to-county crosswalk ----------------------------------
tiger_url <- "https://www2.census.gov/geo/docs/maps-data/data/rel2020/zcta520/tab20_zcta520_county20_natl.txt"

# <<< FIX 5 of 7: colClasses = "character".
# Without it read.delim parses GEOID_COUNTY_20 "06001" as the integer 6001,
# so str_sub(fips, 1, 2) returned "60" and the California filter matched
# nothing. This is why 05c_nces_ccd_clean.csv had 0 rows.
zip_county_xwalk <- read.delim(tiger_url, sep = "|", colClasses = "character") %>%
  clean_names() %>%
  select(geoid_zcta5_20, geoid_county_20) %>%
  rename(zip = geoid_zcta5_20, fips = geoid_county_20) %>%
  mutate(
    zip  = str_pad(as.character(zip),  5, "left", "0"),
    fips = str_pad(as.character(fips), 5, "left", "0")
  ) %>%
  filter(str_sub(fips, 1, 2) == STATE_FIPS) %>%
  distinct()

cat("ZIP-county pairs downloaded:", nrow(zip_county_xwalk), "\n")
stopifnot(nrow(zip_county_xwalk) > 0)

# -- District directory: use ZIP to get county FIPS ------------------------

# <<< FIX 5 (continued): FIPST and MZIP forced to character.
# read.csv turned FIPST "06" into the integer 6, so as.character(fipst)
# gave "6" and never equalled "06". Zero districts passed the filter.
dir_raw <- read.csv("data/raw/ccd_lea_directory.csv",
                    stringsAsFactors = FALSE,
                    colClasses = c(FIPST = "character", MZIP = "character")) %>%
  clean_names() %>%
  mutate(fipst = str_pad(as.character(fipst), 2, "left", "0")) %>%
  filter(fipst == STATE_FIPS) %>%
  mutate(
    leaid = as.character(leaid),
    zip   = str_pad(as.character(mzip), 5, "left", "0")
  )

cat("Districts in state:", nrow(dir_raw), "\n")   # expect about 2,130
stopifnot(nrow(dir_raw) > 0)

# Valid CA county FIPS. California county codes are odd numbers 001 to 115.
valid_ca_fips <- sprintf("06%03d", seq(1, 115, by = 2))   # <<< EDIT 9 of 10

ccd_dir <- dir_raw %>%
  left_join(zip_county_xwalk, by = "zip",
            relationship = "many-to-many") %>%
  filter(!is.na(fips), fips %in% valid_ca_fips) %>%        # <<< EDIT 9 (second use)
  select(leaid, fips) %>%
  distinct()

cat("Districts with valid county FIPS:", nrow(ccd_dir), "\n")
cat("Unique counties:", n_distinct(ccd_dir$fips), "\n")

# -- Lunch file ------------------------------------------------------------

# <<< FIX 5 (continued): same FIPST problem in the lunch file.
ccd_lunch <- read.csv("data/raw/ccd_lunch.csv",
                      stringsAsFactors = FALSE,
                      colClasses = c(FIPST = "character")) %>%
  clean_names() %>%
  mutate(fipst = str_pad(as.character(fipst), 2, "left", "0")) %>%
  filter(fipst == STATE_FIPS)

cat("School lunch rows:", nrow(ccd_lunch), "\n")   # expect about 49,970
stopifnot(nrow(ccd_lunch) > 0)

lunch_check <- ccd_lunch %>%
  filter(lunch_program == "Free lunch qualified",
         total_indicator == "Category Set A",
         !is.na(student_count)) %>%
  nrow()

cat("Schools with free lunch counts:", lunch_check, "\n")   # expect about 9,874

if (lunch_check == 0) {
  cat("NOTE: Your state does not report free lunch counts in this file.\n")
  cat("Only total enrollment and district count will be available.\n")
  cat("Food insecurity is captured via the CHR&R food_insecurity variable.\n")
} else {
  cat("Free lunch data available. Full aggregation will proceed.\n")
}

total_enroll <- ccd_lunch %>%
  filter(data_group == "Free and Reduced-price Lunch Table",
         lunch_program == "No Category Codes",
         total_indicator == "Education Unit Total") %>%
  select(ncessch, leaid, student_count) %>%
  rename(total_students = student_count) %>%
  mutate(
    total_students = as.numeric(total_students),
    leaid          = as.character(leaid)
  )

free_lunch <- ccd_lunch %>%
  filter(data_group == "Free and Reduced-price Lunch Table",
         lunch_program == "Free lunch qualified",
         total_indicator == "Category Set A") %>%
  select(ncessch, student_count) %>%
  rename(free_lunch_count = student_count) %>%
  mutate(free_lunch_count = as.numeric(free_lunch_count))

reduced_lunch <- ccd_lunch %>%
  filter(data_group == "Free and Reduced-price Lunch Table",
         lunch_program == "Reduced-price lunch qualified",
         total_indicator == "Category Set A") %>%
  select(ncessch, student_count) %>%
  rename(reduced_lunch_count = student_count) %>%
  mutate(reduced_lunch_count = as.numeric(reduced_lunch_count))

school_lunch <- total_enroll %>%
  left_join(free_lunch,    by = "ncessch") %>%
  left_join(reduced_lunch, by = "ncessch")

school_county <- school_lunch %>%
  mutate(leaid = as.character(leaid)) %>%
  left_join(ccd_dir, by = "leaid",
            relationship = "many-to-many")

cat("Schools with county FIPS:", sum(!is.na(school_county$fips)), "\n")
cat("Unique counties in schools:", n_distinct(school_county$fips, na.rm = TRUE), "\n")

acs_fips <- read_csv("data/clean/01_acs_clean.csv",
                     col_types = cols(fips = col_character())) %>%
  pull(fips)

ccd_county <- school_county %>%
  filter(!is.na(fips), fips %in% acs_fips) %>%
  group_by(fips) %>%
  summarise(
    n_districts   = n_distinct(leaid),
    
    # NOT total enrollment. This is the free + reduced + missing total from
    # the Free and Reduced-price Lunch Table. Named honestly below.
    frl_total     = sum(total_students,      na.rm = TRUE),
    
    free_lunch    = sum(free_lunch_count,    na.rm = TRUE),
    reduced_lunch = sum(reduced_lunch_count, na.rm = TRUE)
  ) %>%
  ungroup() %>%
  mutate(
    # <<< FIX 7 of 7: plain if(), not ifelse().
    # ifelse() returns a result the same length as its test, and
    # lunch_check > 0 is length 1, so the old code returned a single number
    # (the first county's) which dplyr then recycled to all 58 rows.
    # if() is evaluated once and the whole vector is kept.
    pct_free_lunch = if (lunch_check > 0)
      round(free_lunch / frl_total * 100, 2) else NA_real_,
    
    pct_reduced_lunch = if (lunch_check > 0)
      round(reduced_lunch / frl_total * 100, 2) else NA_real_
  ) %>%
  select(fips, n_districts, frl_total, pct_free_lunch, pct_reduced_lunch)

# Guard: if these percentages have only one distinct value across 58
# counties, the recycling bug is back. California should span roughly
# 75 to 99 percent.
if (n_distinct(ccd_county$pct_free_lunch, na.rm = TRUE) == 1 &&
    nrow(ccd_county) > 1) {
  warning("pct_free_lunch is identical for every county. Check the mutate above.")
}

cat("NCES CCD county rows:", nrow(ccd_county), "\n")   # expect roughly 55 to 58
stopifnot(nrow(ccd_county) > 0)
glimpse(ccd_county)
write_csv(ccd_county, "data/clean/05c_nces_ccd_clean.csv")
cat("Script #5 complete. Rows:", nrow(ccd_county), "\n")


# ============================================================================
# SCRIPT #6 - Merge All Datasets into the Master County CSV
# ============================================================================

# Input:  data/clean/01 through 05 CSV files
# Output: data/master/sdoh_ca_master.csv

library(tidyverse)

# Read every fips column as character so no leading zero is lost on the way in
fips_chr <- cols(fips = col_character())

acs    <- read_csv("data/clean/01_acs_clean.csv",              col_types = fips_chr)
places <- read_csv("data/clean/02_places_clean.csv",           col_types = fips_chr)
svi    <- read_csv("data/clean/03a_svi_clean.csv",             col_types = fips_chr)
eji    <- read_csv("data/clean/03b_eji_county_clean.csv",      col_types = fips_chr)
hpsa   <- read_csv("data/clean/04_hpsa_clean.csv",             col_types = fips_chr)
usda   <- read_csv("data/clean/05a_usda_food_access_clean.csv",col_types = fips_chr)
chr    <- read_csv("data/clean/05b_chr_clean.csv",             col_types = fips_chr)
nces   <- read_csv("data/clean/05c_nces_ccd_clean.csv",        col_types = fips_chr)

cat("ACS base rows:", nrow(acs), "\n")

master <- acs %>%
  left_join(places %>% select(-locationname), by = "fips") %>%
  { cat("After PLACES:", nrow(.), "\n"); . } %>%
  left_join(svi    %>% select(-county_name),  by = "fips") %>%
  { cat("After SVI:",    nrow(.), "\n"); . } %>%
  left_join(eji,                              by = "fips") %>%
  { cat("After EJI:",    nrow(.), "\n"); . } %>%
  left_join(hpsa   %>% select(-county_name),  by = "fips") %>%
  { cat("After HPSA:",   nrow(.), "\n"); . } %>%
  left_join(usda,                             by = "fips") %>%
  { cat("After USDA:",   nrow(.), "\n"); . } %>%
  left_join(chr,                              by = "fips") %>%
  { cat("After CHR:",    nrow(.), "\n"); . } %>%
  left_join(nces,                             by = "fips") %>%
  { cat("After NCES:",   nrow(.), "\n"); . }

# Row count should equal the number of California counties (58)
stopifnot(nrow(master) == nrow(acs))

# -- Join health check ------------------------------------------------------
# A left join that matched nothing returns a full column of NA and no error.
# That is exactly how the previous run failed silently. This catches it.
all_na <- names(master)[colSums(!is.na(master)) == 0]
if (length(all_na) > 0) {
  cat("\nPROBLEM: these columns are entirely NA, so a join failed:\n  ",
      paste(all_na, collapse = ", "), "\n")
  cat("  Check that the fips column in that source file is character",
      "with a leading zero.\n")
} else {
  cat("\nJoin check passed: every column has at least some data.\n")
}

cat("\nMissing values per column:\n")
colSums(is.na(master)) %>% sort(decreasing = TRUE) %>% head(15) %>% print()

STATE_LABEL <- "ca"   # <<< EDIT 10 of 10

master_filename  <- paste0("data/master/sdoh_", STATE_LABEL, "_master.csv")
tableau_filename <- paste0("output/tableau/sdoh_", STATE_LABEL, "_tableau.csv")

write_csv(master, master_filename)
write_csv(master, tableau_filename)

cat("\nScript #6 complete.\n")
cat("Master file saved:", master_filename, "\n")
cat("Tableau file saved:", tableau_filename, "\n")
cat("Rows:", nrow(master), "| Columns:", ncol(master), "\n")


# ============================================================================
# PART 2 / 4  - Verify the master file before analysing
# ============================================================================

STATE_LABEL <- "ca"
master <- read_csv(paste0("data/master/sdoh_", STATE_LABEL, "_master.csv"),
                   col_types = cols(fips = col_character()))
cat("Rows:", nrow(master), "| Columns:", ncol(master), "\n")


# ============================================================================
# SCRIPT #7 PART A/B - Load data + VARIABLE CONFIGURATION
# ============================================================================

library(tidyverse)
library(skimr)
library(corrplot)
library(car)
library(broom)
library(lmtest)
library(ResourceSelection)

STATE_LABEL <- "ca"
master <- read_csv(paste0("data/master/sdoh_", STATE_LABEL, "_master.csv"),
                   col_types = cols(fips = col_character()))

# ============================================================================
# VARIABLE CONFIGURATION - EDIT THIS SECTION TO CHANGE YOUR ANALYSIS
# ============================================================================

# -- Step 1: Choose your OUTCOME variable (Y) -------------------------------
# Must be continuous. It is dichotomized automatically for logistic regression.
#
#   "diabetes_pct"        Diagnosed diabetes prevalence (%)
#   "depression_pct"      Depression prevalence (%)
#   "obesity_pct"         Adult obesity prevalence (%)
#   "hypertension_pct"    High blood pressure prevalence (%)
#   "smoking_pct"         Current smoking prevalence (%)
#   "inactivity_pct"      Physical inactivity prevalence (%)
#   "premature_death"     Premature death rate (YPLL per 100k)
#   "poor_mental_days"    Avg mentally unhealthy days per month
#   "poor_health_days"    Avg physically unhealthy days per month

OUTCOME_VAR <- "diabetes_pct"   # <-- CHANGE THIS

# -- Step 2: Choose your PREDICTOR variables (X) ----------------------------
#
# SAMPLE SIZE NOTE FOR CALIFORNIA. n = 58 counties, not 102.
# Linear regression: 58 rows supports about 4 or 5 predictors comfortably.
# Logistic regression: the median split gives 29 high counties, so events per
# variable is 29 / (number of predictors). The script warns below 10, which
# means 3 predictors gives 9.7 and will still warn. That is expected at this
# sample size. Report it as a limitation rather than chasing it away.
#
#  -- Domain 1: Economic Stability --
#   "poverty_rate", "unemployment_rate", "median_hh_income",
#   "snap_rate", "rent_burden_rate"
#
#  -- Domain 2: Education --
#   "pct_no_hs", "pct_bachelor_plus", "pct_free_lunch"
#   (note: pct_free_lunch is a share of FRL-eligible students, not of
#    enrollment, so it is a weak education proxy. pct_no_hs is better.)
#
#  -- Domain 3: Health Care Access --
#   "uninsured_rate", "hpsa_prim_care", "hpsa_dental", "hpsa_mental_health",
#   "hpsa_any_shortage", "hpsa_prim_care_designated"
#
#  -- Domain 4: Built Environment --
#   "pct_lila_tracts", "eji_overall", "eji_env_burden"
#
#  -- Domain 5: Social & Community Context --
#   "svi_overall", "svi_socioeco", "svi_minority",
#   "social_associations", "voter_turnout"

PREDICTOR_VARS <- c(
  "unemployment_rate",
  "pct_bachelor_plus",
  "uninsured_rate",
  "pct_no_vehicle_far"
)

ANALYSIS_LABEL <- "diabetes_sdoh_model_ca"   # <-- DESCRIBE YOUR MODEL

# ============================================================================
# END OF CONFIGURATION
# ============================================================================

all_vars <- c("fips", "county_name", OUTCOME_VAR, PREDICTOR_VARS)

# -- Missingness check before drop_na() ------------------------------------
# drop_na() removes a row if ANY selected column is missing, so one broken
# column silently deletes the whole dataset. Look here first if n comes out 0.
cat("\n-- Missing values in your selected variables --\n")
master %>%
  select(all_of(c(OUTCOME_VAR, PREDICTOR_VARS))) %>%
  summarise(across(everything(), ~ sum(is.na(.)))) %>%
  pivot_longer(everything(), names_to = "variable", values_to = "n_missing") %>%
  arrange(desc(n_missing)) %>%
  print()

analysis_df <- master %>%
  select(all_of(all_vars)) %>%
  drop_na()

cat("\n-- Analysis configuration --------------------------------\n")
cat("Outcome:    ", OUTCOME_VAR, "\n")
cat("Predictors: ", paste(PREDICTOR_VARS, collapse = ", "), "\n")
cat("Sample size:", nrow(analysis_df), "observations (after removing missing)\n")
cat("Counties dropped due to missing:", nrow(master) - nrow(analysis_df), "\n")

if (nrow(analysis_df) == 0) {
  stop("Sample size is 0. One of your selected variables is entirely NA. ",
       "See the missing values table printed above.")
}


# ============================================================================
# SCRIPT #7 PART C - Descriptive Statistics
# ============================================================================

skim_output <- analysis_df %>%
  select(all_of(c(OUTCOME_VAR, PREDICTOR_VARS))) %>%
  skim()
print(skim_output)

desc_stats <- analysis_df %>%
  select(all_of(c(OUTCOME_VAR, PREDICTOR_VARS))) %>%
  pivot_longer(everything(), names_to = "variable", values_to = "value") %>%
  group_by(variable) %>%
  summarise(
    n       = sum(!is.na(value)),
    missing = sum(is.na(value)),
    mean    = round(mean(value,   na.rm = TRUE), 2),
    sd      = round(sd(value,     na.rm = TRUE), 2),
    min     = round(min(value,    na.rm = TRUE), 2),
    median  = round(median(value, na.rm = TRUE), 2),
    max     = round(max(value,    na.rm = TRUE), 2)
  )

print(desc_stats)
write_csv(desc_stats,
          paste0("output/tables/01_descriptive_", ANALYSIS_LABEL, ".csv"))


# ============================================================================
# SCRIPT #7 PART D - Correlation Matrix
# ============================================================================

cor_data   <- analysis_df %>%
  select(all_of(c(OUTCOME_VAR, PREDICTOR_VARS))) %>%
  drop_na()

cor_matrix <- cor(cor_data, method = "pearson")

corrplot(
  cor_matrix,
  method      = "color",
  type        = "upper",
  order       = "hclust",
  addCoef.col = "black",
  tl.col      = "black",
  tl.srt      = 45,
  number.cex  = 0.75,
  title       = paste("Correlation Matrix -", OUTCOME_VAR),
  mar         = c(0, 0, 2, 0)
)

png(paste0("output/figures/02_correlation_", ANALYSIS_LABEL, ".png"),
    width = 1400, height = 1200, res = 150)
corrplot(cor_matrix, method = "color", type = "upper", order = "hclust",
         addCoef.col = "black", tl.col = "black", tl.srt = 45, number.cex = 0.75)
dev.off()

pred_cor   <- cor(analysis_df %>% select(all_of(PREDICTOR_VARS)), method = "pearson")
high_pairs <- which(abs(pred_cor) > 0.70 & upper.tri(pred_cor), arr.ind = TRUE)

if (nrow(high_pairs) > 0) {
  cat("\nWARNING - High correlations (r > 0.70) between predictors:\n")
  for (i in seq_len(nrow(high_pairs))) {
    r1 <- rownames(pred_cor)[high_pairs[i, 1]]
    r2 <- colnames(pred_cor)[high_pairs[i, 2]]
    r  <- round(pred_cor[high_pairs[i, 1], high_pairs[i, 2]], 2)
    cat(" ", r1, "vs", r2, ":", r, "\n")
  }
  cat("ACTION: Consider removing one variable from each correlated pair.\n")
} else {
  cat("\nNo high inter-predictor correlations (all r < 0.70). Proceed.\n")
}


# ============================================================================
# SCRIPT #7 PART E - Multiple Linear Regression + Assumption Checks
# ============================================================================

cat("\n-- Unadjusted linear models (crude beta, one predictor each) --\n")

unadj_lm_results <- map_dfr(PREDICTOR_VARS, function(var) {
  formula_unadj <- as.formula(paste(OUTCOME_VAR, "~", var))
  model_unadj   <- lm(formula_unadj, data = analysis_df)
  tidy(model_unadj, conf.int = TRUE) %>%
    filter(term == var) %>%
    mutate(model = "Unadjusted", predictor = var,
           across(where(is.numeric), ~ round(., 4)))
})

print(unadj_lm_results %>%
        select(predictor, estimate, conf.low, conf.high, p.value))

cat("\n-- Fully adjusted model (all predictors) --\n")
formula_adj <- as.formula(paste(OUTCOME_VAR, "~",
                                paste(PREDICTOR_VARS, collapse = " + ")))
model_adj   <- lm(formula_adj, data = analysis_df)
summary(model_adj)

cat("\n== ASSUMPTION CHECKS: MULTIPLE LINEAR REGRESSION ==\n")

png(paste0("output/figures/03_lm_diagnostics_", ANALYSIS_LABEL, ".png"),
    width = 1600, height = 1400, res = 150)
par(mfrow = c(2, 2))
plot(model_adj, main = paste("LM Diagnostics -", OUTCOME_VAR))
par(mfrow = c(1, 1))
dev.off()
cat("Diagnostic plots saved to output/figures/\n")
cat("Interpret: (1) Residuals vs Fitted, no pattern = linearity OK\n")
cat("           (2) Q-Q plot, points on line = normality OK\n")
cat("           (3) Scale-Location, flat red line = homoscedasticity OK\n")
cat("           (4) Cook's Distance, no points past dashed line = no influence\n")

cat("\n-- Assumption 3: Homoscedasticity (Breusch-Pagan test) --\n")
bp_test <- bptest(model_adj)
print(bp_test)
if (bp_test$p.value < 0.05) {
  cat("RESULT: p < 0.05, heteroscedasticity detected.\n")
  cat("ACTION: Use robust standard errors (Follow-up 1 below).\n")
} else {
  cat("RESULT: p =", round(bp_test$p.value, 3), ", homoscedasticity met.\n")
}

cat("\n-- Assumption 4: Normality of residuals (Shapiro-Wilk test) --\n")
sw_test <- shapiro.test(residuals(model_adj))
print(sw_test)
if (sw_test$p.value < 0.05) {
  cat("RESULT: p < 0.05, residuals may not be normally distributed.\n")
  cat("NOTE:   With n = 58, linear regression is reasonably robust to mild\n")
  cat("        non-normality. Check the Q-Q plot visually. If it shows heavy\n")
  cat("        skew, consider log-transforming the outcome.\n")
} else {
  cat("RESULT: p =", round(sw_test$p.value, 3), ", normality met.\n")
}

cat("\n-- Assumption 5: Influential observations (Cook's Distance) --\n")
cooks_d     <- cooks.distance(model_adj)
cutoff      <- 4 / nrow(analysis_df)
influential <- which(cooks_d > cutoff)
cat("Cook's D threshold (4/n):", round(cutoff, 4), "\n")
if (length(influential) > 0) {
  cat("Influential observations:\n")
  print(analysis_df[influential, c("fips", "county_name", OUTCOME_VAR)])
  cat("ACTION: Run the sensitivity analysis, Follow-up 2 below.\n")
  cat("NOTE:   In California expect Los Angeles, Alpine and Sierra to show up.\n")
  cat("        Very large and very small counties are natural leverage points.\n")
} else {
  cat("No influential outliers detected.\n")
}

cat("\n-- Multicollinearity check: Variance Inflation Factor (VIF) --\n")
cat("VIF < 5 acceptable | 5-10 moderate concern | > 10 serious problem\n")
vif_vals <- vif(model_adj)
print(round(vif_vals, 2))
if (any(vif_vals > 5)) {
  cat("WARNING: VIF > 5 detected. Consider removing correlated predictors.\n")
  cat("High VIF variables:", names(which(vif_vals > 5)), "\n")
} else {
  cat("VIF OK, no multicollinearity problem detected.\n")
}

cat("\n-- Final regression results --\n")
results_lm <- tidy(model_adj, conf.int = TRUE) %>%
  mutate(across(where(is.numeric), ~ round(., 4)))
print(results_lm)

fit_lm <- glance(model_adj)
cat("R2 =", round(fit_lm$r.squared, 3),
    " | Adj. R2 =", round(fit_lm$adj.r.squared, 3),
    " | F-stat p =", round(fit_lm$p.value, 4), "\n")

write_csv(results_lm,
          paste0("output/tables/03_lm_results_", ANALYSIS_LABEL, ".csv"))


# ============================================================================
# SCRIPT #7 - Follow-up analyses based on the assumption checks
# ============================================================================

library(sandwich)

# -- Follow-up 1: Robust standard errors (if Breusch-Pagan p < 0.05) --------
if (bp_test$p.value < 0.05) {
  cat("\n-- Robust standard errors (heteroscedasticity correction) --\n")
  robust_results <- coeftest(model_adj, vcov = vcovHC(model_adj))
  print(robust_results)
  cat("NOTE: Report these standard errors and p-values.\n")
  cat("      Coefficients are identical, only standard errors change.\n")
  
  # The toolkit lists output/tables/03_lm_robust_[LABEL].csv as a required
  # output but never writes it. This line writes it.
  broom::tidy(robust_results) %>%
    mutate(across(where(is.numeric), ~ round(., 4))) %>%
    write_csv(paste0("output/tables/03_lm_robust_", ANALYSIS_LABEL, ".csv"))
}

# -- Follow-up 2: Sensitivity analysis (drop influential observations) ------
if (length(influential) > 0) {
  cat("\n-- Sensitivity analysis (removing influential observations) --\n")
  
  influential_fips <- analysis_df$fips[influential]
  cat("Removing observations with FIPS:", influential_fips, "\n")
  
  analysis_df_trim <- analysis_df %>%
    filter(!fips %in% influential_fips)
  
  model_trim <- lm(formula_adj, data = analysis_df_trim)
  
  cat("Trimmed model (n =", nrow(analysis_df_trim), "):\n")
  print(summary(model_trim))
  
  cat("\nComparison: key coefficients\n")
  cat("                    Full model    Trimmed model\n")
  for (v in PREDICTOR_VARS) {
    full_coef <- round(coef(model_adj)[v], 3)
    trim_coef <- round(coef(model_trim)[v], 3)
    cat(sprintf("%-20s %10s    %10s\n", v, full_coef, trim_coef))
  }
  cat("\nIf coefficients are similar, results are robust.\n")
}


# ============================================================================
# SCRIPT #7 PART F - Logistic Regression + Assumption Checks
# ============================================================================

library(ResourceSelection)

state_median   <- median(analysis_df[[OUTCOME_VAR]], na.rm = TRUE)
binary_outcome <- paste0(OUTCOME_VAR, "_high")

logistic_df <- analysis_df %>%
  mutate(
    !!binary_outcome := as.integer(.data[[OUTCOME_VAR]] > state_median)
  )

n_events   <- sum(logistic_df[[binary_outcome]] == 1, na.rm = TRUE)
n_nonevent <- sum(logistic_df[[binary_outcome]] == 0, na.rm = TRUE)

cat("\nBinary outcome:", binary_outcome, "\n")
cat("  Threshold (state median):", round(state_median, 2),
    "[", OUTCOME_VAR, "]\n")
cat("  High (= 1):", n_events, "observations\n")
cat("  Low  (= 0):", n_nonevent, "observations\n")

cat("\n-- Assumption 5: Sample size adequacy --\n")
epv <- n_events / length(PREDICTOR_VARS)
cat("Events per predictor variable (EPV):", round(epv, 1), "\n")
if (epv < 10) {
  cat("WARNING: EPV < 10. Consider reducing predictor count to",
      floor(n_events / 10), "or fewer.\n")
  cat("NOTE:    With 58 California counties a median split gives at most 29\n")
  cat("         events, so EPV >= 10 requires 2 predictors or fewer. Most\n")
  cat("         county-level studies accept this and report it as a\n")
  cat("         limitation. The linear model is your primary analysis.\n")
} else {
  cat("EPV OK (>= 10). Sample size is adequate.\n")
}

cat("\n-- Unadjusted logistic models (crude OR, one predictor each) --\n")

unadj_results <- map_dfr(PREDICTOR_VARS, function(var) {
  formula_unadj <- as.formula(paste(binary_outcome, "~", var))
  model_unadj   <- glm(formula_unadj, data = logistic_df,
                       family = binomial(link = "logit"))
  tidy(model_unadj, conf.int = TRUE, exponentiate = TRUE) %>%
    filter(term == var) %>%
    mutate(model = "Unadjusted", predictor = var,
           across(where(is.numeric), ~ round(., 4)))
})

print(unadj_results %>%
        select(predictor, estimate, conf.low, conf.high, p.value))

cat("\n-- Fully adjusted logistic model (all predictors) --\n")
formula_logit <- as.formula(
  paste(binary_outcome, "~", paste(PREDICTOR_VARS, collapse = " + "))
)
logit_model <- glm(formula_logit, data = logistic_df,
                   family = binomial(link = "logit"))
summary(logit_model)

cat("\n== ASSUMPTION CHECKS: LOGISTIC REGRESSION ==\n")

cat("\n-- Assumption 3: Multicollinearity (VIF) --\n")
vif_logit <- vif(logit_model)
print(round(vif_logit, 2))
if (any(vif_logit > 5)) {
  cat("WARNING: VIF > 5, multicollinearity present.\n")
} else {
  cat("VIF OK, no multicollinearity problem.\n")
}

cat("\n-- Assumption 4: Complete separation check --\n")
coef_check <- coef(logit_model)[-1]
if (any(abs(coef_check) > 10, na.rm = TRUE)) {
  cat("WARNING: Very large coefficients, possible complete separation.\n")
  cat("Variables:", names(which(abs(coef_check) > 10)), "\n")
} else {
  cat("No evidence of complete separation (all log-odds coefficients < 10).\n")
}

cat("\n-- Assumption 6: Hosmer-Lemeshow goodness-of-fit test --\n")
cat("Null hypothesis: model fits adequately (p > 0.05 = good fit)\n")
hl_test <- hoslem.test(
  x = logistic_df[[binary_outcome]],
  y = fitted(logit_model),
  g = 10
)
print(hl_test)
if (hl_test$p.value < 0.05) {
  cat("RESULT: p < 0.05, model may not fit well.\n")
} else {
  cat("RESULT: p =", round(hl_test$p.value, 3), ", model fits adequately.\n")
}

cat("\n-- Model fit statistics --\n")
cat("AIC:", round(AIC(logit_model), 2), "\n")
cat("Null deviance:",     round(logit_model$null.deviance, 2), "\n")
cat("Residual deviance:", round(logit_model$deviance, 2), "\n")
mcfadden <- 1 - (logit_model$deviance / logit_model$null.deviance)
cat("McFadden pseudo-R2:", round(mcfadden, 3), "\n")
cat("(0.2 to 0.4 = good fit for logistic models)\n")

cat("\n-- Odds Ratios with 95% Confidence Intervals --\n")
results_logit <- tidy(logit_model, conf.int = TRUE, exponentiate = TRUE) %>%
  mutate(across(where(is.numeric), ~ round(., 4)))
print(results_logit)

cat("\n-- Classification performance (threshold = 0.5) --\n")
predicted_class <- as.integer(fitted(logit_model) >= 0.5)
actual_class    <- logistic_df[[binary_outcome]]
conf_matrix     <- table(Predicted = predicted_class, Actual = actual_class)
print(conf_matrix)

accuracy <- sum(diag(conf_matrix)) / sum(conf_matrix)
cat("Accuracy:", round(accuracy * 100, 1), "%\n")

write_csv(results_logit,
          paste0("output/tables/04_logit_OR_", ANALYSIS_LABEL, ".csv"))
cat("Script #7 complete.\n")


# ============================================================================
# PART 2 / 5  - Generate README.txt automatically
# ============================================================================

# Fill in the bracketed placeholders below before you commit to GitHub.
# The download dates are a stated reproducibility requirement in Part 1.

sink("README.txt")
cat("=== SDOH TOOLKIT - PROJECT README ===\n\n")
cat("Author:            Ba Tung (Jackey) Tran\n")
cat("Institution:       University of Illinois Springfield\n")
cat("Date completed:   ", format(Sys.Date(), "%Y-%m-%d"), "\n")
cat("Research question: [One sentence]\n\n")

cat("--- Analysis configuration ---\n")
cat("State:            ", STATE_LABEL, "\n")
cat("Geography:         County level (58 California counties)\n")
cat("Outcome variable: ", OUTCOME_VAR, "\n")
cat("Predictors:       ", paste(PREDICTOR_VARS, collapse = ", "), "\n")
cat("Analysis label:   ", ANALYSIS_LABEL, "\n\n")

cat("--- Script run order ---\n")
cat("01_acs.R -> 02_places.R -> 03_svi_eji.R -> 04_hrsa.R\n")
cat("-> 05_usda_nces_chr.R -> 06_merge_all.R -> 07_analysis.R\n\n")

cat("--- Data download dates ---\n")
cat("ACS 2020-2024:     [date]\n")
cat("CDC PLACES 2025:   [date]\n")
cat("SVI 2022:          [date]\n")
cat("EJI 2024:          [date]\n")
cat("HRSA AHRF 2024-25: [date]\n")
cat("USDA Atlas 2019:   [date]\n")
cat("CHR&R 2025:        [date]\n")
cat("NCES CCD 2024-25:  [date]\n\n")

cat("--- Output files ---\n")
cat("Master CSV:    data/master/sdoh_", STATE_LABEL, "_master.csv\n", sep = "")
cat("Tableau CSV:   output/tableau/sdoh_", STATE_LABEL, "_tableau.csv\n", sep = "")
cat("Descriptive:   output/tables/01_descriptive_", ANALYSIS_LABEL, ".csv\n", sep = "")
cat("LM results:    output/tables/03_lm_results_", ANALYSIS_LABEL, ".csv\n", sep = "")
cat("Logit results: output/tables/04_logit_OR_", ANALYSIS_LABEL, ".csv\n", sep = "")
cat("Correlation:   output/figures/02_correlation_", ANALYSIS_LABEL, ".png\n", sep = "")
cat("Diagnostics:   output/figures/03_lm_diagnostics_", ANALYSIS_LABEL, ".png\n\n", sep = "")

cat("--- Known data notes ---\n")
cat("voter_turnout uses CHR&R v177. The toolkit's v153 is homeownership.\n")
cat("pct_no_vehicle_far is reported as given by USDA (already a percentage).\n")
cat("mean_dist_supermarket is a population share, not a distance.\n")
cat("frl_total is the free/reduced lunch table total, not enrollment.\n")
cat("pct_free_lunch and pct_reduced_lunch use frl_total as denominator,\n")
cat("  so they sum to 100 by construction. Not comparable to enrollment.\n\n")

cat("--- GitHub repository ---\n")
cat("Repository URL: [your GitHub URL]\n")
cat("Visibility:     Public\n\n")

cat("--- Zenodo DOI ---\n")
cat("DOI: [your DOI]\n\n")

cat("--- R environment ---\n")
cat("R version:", R.version$major, ".", R.version$minor, "\n")
cat("OS:", Sys.info()["sysname"], Sys.info()["release"], "\n\n")

cat("--- Package versions ---\n")
pkgs <- c("tidycensus", "tidyverse", "haven", "readxl",
          "janitor", "skimr", "corrplot", "car", "broom", "lmtest",
          "ResourceSelection", "sandwich")
for (p in pkgs) {
  if (requireNamespace(p, quietly = TRUE)) {
    cat(p, ":", as.character(packageVersion(p)), "\n")
  }
}
sink()
cat("README.txt saved.\n")


# ============================================================================
# PART 2 / 5  - Create dictionary/data_dictionary.csv
# ============================================================================

# <<< FIX 6 of 7: rebuilt as a name lookup instead of a positional vector.
#
# The original assigned 55 labels by position, assuming the Illinois column
# order. Your California PLACES columns come out of pivot_wider() in a
# different order (inactivity, colorectal, diabetes, mammography, ...), so
# every PLACES label would have attached to the wrong variable. A join on
# variable name cannot drift, and it tells you if something is unlabelled.

library(tidyverse)

master <- read_csv("data/master/sdoh_ca_master.csv",   # <<< was sdoh_il_master.csv
                   col_types = cols(fips = col_character()))

dict_lookup <- tribble(
  ~variable_name,              ~label,                                                              ~source,                       ~year,
  
  # Identifiers
  "fips",                      "5-digit county FIPS code (character)",                              "U.S. Census Bureau",          "2024",
  "county_name",               "County name (ACS format, includes state)",                          "U.S. Census Bureau",          "2024",
  
  # ACS
  "poverty_rate",              "Poverty rate (% persons below poverty line)",                       "ACS 5-Year 2020-2024",        "2020-2024",
  "median_hh_income",          "Median household income ($)",                                       "ACS 5-Year 2020-2024",        "2020-2024",
  "unemployment_rate",         "Unemployment rate (% civilian labor force)",                        "ACS 5-Year 2020-2024",        "2020-2024",
  "snap_rate",                 "SNAP participation rate (% households)",                            "ACS 5-Year 2020-2024",        "2020-2024",
  "rent_burden_rate",          "Rent cost burden (% renters paying 30%+ of income on rent)",        "ACS 5-Year 2020-2024",        "2020-2024",
  "pct_no_hs",                 "% adults 25+ with less than a high school diploma",                 "ACS 5-Year 2020-2024",        "2020-2024",
  "pct_hs_grad",               "% adults 25+ with a high school diploma or equivalent",             "ACS 5-Year 2020-2024",        "2020-2024",
  "pct_bachelor_plus",         "% adults 25+ with a bachelor's degree or higher",                   "ACS 5-Year 2020-2024",        "2020-2024",
  "uninsured_rate",            "Uninsured rate (% population, ACS DP03_0099P)",                     "ACS 5-Year 2020-2024",        "2020-2024",
  
  # CDC PLACES
  "diabetes_pct",              "Diagnosed diabetes prevalence (%)",                                 "CDC PLACES 2025",             "2021-2022 BRFSS",
  "obesity_pct",               "Adult obesity prevalence (%)",                                      "CDC PLACES 2025",             "2021-2022 BRFSS",
  "hypertension_pct",          "High blood pressure prevalence (%)",                                "CDC PLACES 2025",             "2021-2022 BRFSS",
  "depression_pct",            "Depression prevalence (%)",                                         "CDC PLACES 2025",             "2021-2022 BRFSS",
  "copd_pct",                  "COPD prevalence (%)",                                               "CDC PLACES 2025",             "2021-2022 BRFSS",
  "asthma_pct",                "Current asthma prevalence (%)",                                     "CDC PLACES 2025",             "2021-2022 BRFSS",
  "smoking_pct",               "Current smoking prevalence (%)",                                    "CDC PLACES 2025",             "2021-2022 BRFSS",
  "inactivity_pct",            "Physical inactivity prevalence (%)",                                "CDC PLACES 2025",             "2021-2022 BRFSS",
  "colorectal_screen_pct",     "Colorectal cancer screening rate (%)",                              "CDC PLACES 2025",             "2021-2022 BRFSS",
  "mammography_pct",           "Mammography use rate (%)",                                          "CDC PLACES 2025",             "2021-2022 BRFSS",
  "uninsured_places",          "Uninsured % (PLACES ACCESS2 measure)",                              "CDC PLACES 2025",             "2021-2022 BRFSS",
  
  # SVI
  "svi_overall",               "SVI overall percentile (0-1, higher = more vulnerable)",            "CDC/ATSDR SVI 2022",          "2022",
  "svi_socioeco",              "SVI Theme 1: socioeconomic status percentile",                      "CDC/ATSDR SVI 2022",          "2022",
  "svi_hh_char",               "SVI Theme 2: household characteristics percentile",                 "CDC/ATSDR SVI 2022",          "2022",
  "svi_minority",              "SVI Theme 3: racial/ethnic minority and language percentile",       "CDC/ATSDR SVI 2022",          "2022",
  "svi_housing",               "SVI Theme 4: housing type and transportation percentile",           "CDC/ATSDR SVI 2022",          "2022",
  "pct_poverty",               "% persons below 150% of the poverty line (SVI component)",          "CDC/ATSDR SVI 2022",          "2022",
  "pct_unemp_svi",             "% civilian unemployed (SVI component)",                             "CDC/ATSDR SVI 2022",          "2022",
  "pct_uninsured_svi",         "% uninsured (SVI component)",                                       "CDC/ATSDR SVI 2022",          "2022",
  
  # EJI
  "eji_overall",               "EJI overall percentile, county mean of tracts",                     "CDC/ATSDR EJI 2024",          "2024",
  "eji_env_burden",            "EJI Environmental Burden percentile, county mean",                  "CDC/ATSDR EJI 2024",          "2024",
  "eji_social_vuln",           "EJI Social Vulnerability percentile, county mean",                  "CDC/ATSDR EJI 2024",          "2024",
  "eji_health_vuln",           "EJI Health Vulnerability percentile, county mean",                  "CDC/ATSDR EJI 2024",          "2024",
  "n_tracts",                  "Number of census tracts averaged for the EJI county value",         "CDC/ATSDR EJI 2024",          "2024",
  
  # HPSA
  "hpsa_prim_care",            "Primary care shortage designation (0=none, 1=partial, 2=whole)",    "HRSA AHRF 2024-2025",         "2025",
  "hpsa_dental",               "Dental shortage designation (0=none, 1=partial, 2=whole)",          "HRSA AHRF 2024-2025",         "2025",
  "hpsa_mental_health",        "Mental health shortage designation (0=none, 1=partial, 2=whole)",   "HRSA AHRF 2024-2025",         "2025",
  "hpsa_any_shortage",         "Any shortage designation (1=yes, 0=no)",                            "HRSA AHRF 2024-2025",         "2025",
  "hpsa_prim_care_designated", "Primary care shortage, binary (1=yes, 0=no)",                       "HRSA AHRF 2024-2025",         "2025",
  
  # USDA
  "pct_lila_tracts",           "% of county tracts that are low-income and low-access (LILA)",      "USDA Food Access Atlas 2019", "2019",
  "mean_dist_supermarket",     "Mean tract share of population over half a mile from a supermarket (a percentage, not a distance)", "USDA Food Access Atlas 2019", "2019",
  "pct_no_vehicle_far",        "Mean tract % of housing units with no vehicle and far from a supermarket", "USDA Food Access Atlas 2019", "2019",
  
  # CHR&R
  "premature_death",           "Premature death rate (YPLL per 100,000)",                           "CHR&R 2025",                  "2025",
  "poor_health_days",          "Average physically unhealthy days per month",                       "CHR&R 2025",                  "2025",
  "poor_mental_days",          "Average mentally unhealthy days per month",                         "CHR&R 2025",                  "2025",
  "social_associations",       "Membership associations per 10,000 population",                     "CHR&R 2025",                  "2025",
  "voter_turnout",             "Voter turnout % (CHR&R v177, presidential election)",               "CHR&R 2025",                  "2025",
  "adult_smoking",             "Adult smoking prevalence (%)",                                      "CHR&R 2025",                  "2025",
  "adult_obesity",             "Adult obesity prevalence (%)",                                      "CHR&R 2025",                  "2025",
  "food_insecurity",           "Food insecurity (%)",                                               "CHR&R 2025",                  "2025",
  
  # NCES CCD
  "n_districts",               "Number of school districts assigned to the county",                 "NCES CCD 2024-2025",          "2024-2025",
  "frl_total",                 "Students in the free/reduced lunch table (free + reduced + missing). NOT total enrollment.", "NCES CCD 2024-2025", "2024-2025",
  "pct_free_lunch",            "% of free/reduced lunch eligible students who qualify for FREE lunch (denominator is frl_total, not enrollment)", "NCES CCD 2024-2025", "2024-2025",
  "pct_reduced_lunch",         "% of free/reduced lunch eligible students who qualify for REDUCED-price lunch (denominator is frl_total). Sums to 100 with pct_free_lunch by construction.", "NCES CCD 2024-2025", "2024-2025"
)

data_dict <- tibble(variable_name = names(master)) %>%
  left_join(dict_lookup, by = "variable_name")

unlabelled <- data_dict %>% filter(is.na(label)) %>% pull(variable_name)
if (length(unlabelled) > 0) {
  cat("WARNING: no label found for:", paste(unlabelled, collapse = ", "), "\n")
  cat("Add a row for each to dict_lookup above.\n")
} else {
  cat("All", nrow(data_dict), "columns labelled.\n")
}

write_csv(data_dict, "dictionary/data_dictionary.csv")
cat("Data dictionary saved with", nrow(data_dict), "variables.\n")


# ============================================================================
# PART 3 / 3  - Health center point file for the asset map (optional)
# ============================================================================

# my_facilities.csv is the HRSA Health Center Service Delivery file, national,
# 19,044 sites. It ALREADY HAS COORDINATES, so tidygeocoder is not needed and
# the toolkit's geocoding block will error on it: that block expects a column
# called street_address, and this file calls it "Site Address".
#
# Only use tidygeocoder if you bring your own facility list that has street
# addresses and no lat/long. For this file, just filter and rename.
#
# California: 3,039 sites, all Active, 1 row missing coordinates.

library(tidyverse)
library(janitor)

facilities_raw <- read_csv("data/raw/my_facilities.csv",
                           show_col_types = FALSE)

ca_facilities <- facilities_raw %>%
  clean_names() %>%
  select(
    site_name,
    site_address,
    site_city,
    state_abbr = site_state_abbreviation,
    status     = site_status_description,
    site_telephone_number,
    # X is longitude, Y is latitude. Do not swap these.
    longitude  = geocoding_artifact_address_primary_x_coordinate,
    latitude   = geocoding_artifact_address_primary_y_coordinate
  ) %>%
  filter(state_abbr == "CA", status == "Active") %>%
  mutate(
    longitude = as.numeric(longitude),
    latitude  = as.numeric(latitude)
  ) %>%
  filter(!is.na(longitude), !is.na(latitude))

cat("California active health center sites:", nrow(ca_facilities), "\n")

write_csv(ca_facilities, "output/tableau/ca_health_centers.csv")

# In Tableau: add this as a SECOND data source (Data menu, New Data Source).
# Right click longitude -> Geographic Role -> Longitude.
# Right click latitude  -> Geographic Role -> Latitude.
# Drag longitude to Columns, latitude to Rows.
# Analysis menu, uncheck Aggregate Measures, or all 3,039 sites become one dot.
# Marks card, mark type Circle. Drop site_name on Tooltip.


# ============================================================================
# PART 3 / 4  - Reshape HPSA to long format for the pie-chart map (optional)
# ============================================================================

# Caution: the reshaped column is named "count" but the values are
# designation codes (0 = none, 1 = partial, 2 = whole county). A 2 does not
# mean two shortages, so sizing pie slices by Angle misrepresents the data.
# Put shortage_type on Color and leave Angle alone, or skip this map.

library(tidyverse)

STATE_LABEL <- "ca"
master <- read_csv(paste0("data/master/sdoh_", STATE_LABEL, "_master.csv"),
                   col_types = cols(fips = col_character()))

hpsa_long <- master %>%
  select(fips, county_name, hpsa_prim_care, hpsa_dental, hpsa_mental_health) %>%
  pivot_longer(
    cols      = c(hpsa_prim_care, hpsa_dental, hpsa_mental_health),
    names_to  = "shortage_type",
    values_to = "designation_code"
  ) %>%
  mutate(shortage_type = case_when(
    shortage_type == "hpsa_prim_care"     ~ "Primary Care",
    shortage_type == "hpsa_dental"        ~ "Dental",
    shortage_type == "hpsa_mental_health" ~ "Mental Health"
  ))

cat("Rows in reshaped file:", nrow(hpsa_long), "\n")
cat("Expected:", nrow(master) * 3, "(3 shortage types x", nrow(master), "counties)\n")

write_csv(hpsa_long, "output/tableau/hpsa_long.csv")
cat("Saved: output/tableau/hpsa_long.csv\n")


# ############################################################################
# END
# ############################################################################