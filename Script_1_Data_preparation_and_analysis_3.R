# =============================================================================
# Script 1: Data preparation and analysis
# Purpose:
#   - Load and merge FADN datasets for selected countries and years
#   - Prepare variables (CDI, fertilizer use, subsidies)
#   - Match farms with and without subsidies
#   - Perform statistical analysis (mean differences, t-tests)
#   - Calculate environmental benefits (GHG-based monetisation)
#   - Save outputs for visualization
#
# =============================================================================
# ASSUMPTIONS & PARAMETERS FOR BENEFIT CALCULATION
# =============================================================================
#
# 1. Nitrogen Fertilizer — GHG Emission Factor
#    Total emission factor: 9.91 kg CO2-eq per kg N
#    Composed of:
#      - Direct N2O emissions:      4.68  kg CO2-eq/kg N
#          Source: IPCC (2006), Tier 1 default emission factor
#      - Indirect — volatilisation: 0.47  kg CO2-eq/kg N
#          Source: IPCC (2006), Table 11.3
#      - Indirect — leaching/runoff:1.05  kg CO2-eq/kg N
#          Source: IPCC (2006), Table 11.3
#      - Fertilizer production:     3.70  kg CO2-eq/kg N
#          Source: Brentrup & Pallière (2008), International Fertiliser Society
#    Reference: Brentrup, F. & Pallière, C. (2008). GHG emissions and energy
#      efficiency in European nitrogen fertiliser production and use.
#      Proceedings 639, International Fertiliser Society, York, UK.
#
# 2. Permanent Grassland — GHG Emission Factor
#    Emission factor for arable land:     1,194.676 kg CO2-eq/ha/year
#    Emission factor for permanent grassland: 781.35 kg CO2-eq/ha/year
#    => Net reduction per ha converted:     413.326 kg CO2-eq/ha/year
#    Source: IPCC (2006) Guidelines for National Greenhouse Gas Inventories,
#      Chapter 6 (Land Use, Land-Use Change, and Forestry), Tier 1 defaults.
#
# 3. Crop Diversity Index (CDI) — Farm Performance Effect
#    Coefficient: 0.102 (i.e., +10.2% farm performance per 1-unit CDI increase)
#    Used as proxy for farm-level economic benefit of diversification.
#    Source: Nilsson, P. et al. (2022). Crop diversity and farm performance:
#      Evidence from Swedish farm-level data. Journal of Agricultural Economics.
#      https://doi.org/10.1111/1477-9552.12471
#
# 4. Carbon Price
#    Price: EUR 70 per tonne CO2 (= EUR 0.07 per kg CO2)
#    Rationale: Reflects EU ETS price range and social cost estimates
#      used in European agricultural policy impact assessments (ca. 2022/2023).
#
# =============================================================================

# --- Load required packages ---
library(dplyr)
library(tidyr)
library(knitr)
library(ggplot2)
library(here)

# --- Define directories ---
# Uses the {here} package to build paths relative to the project root (.Rproj).
# Expected folder structure:
#   <project_root>/
#     data/        <- raw FADN input files (one CSV per country-year)
#     analysis/    <- output files (summary stats, benefit summary, plots)
main_dir     <- here("data")
analysis_dir <- here("analysis")

# --- Define countries, years, and subsidy measures of interest ---
countries <- c("DEU", "POL", "OST", "DAN", "ITA", "LTU", "NED", "HUN", "FRA")
years <- c("2021", "2022")
measures <- c("SE621", "SORGSUB_2_V")
# SE621        = Environmental subsidies
# SORGSUB_2_V  = Organic farming subsidy

# --- Parameters for benefit calculation (see header for full references) ---
# Adjust these values if you want to use alternative emission factors or prices.

# Nitrogen emission factor [kg CO2-eq / kg N]
# Sources: IPCC (2006) Ch. 11; Brentrup & Palliere (2008), Int. Fertiliser Society
EF_NITROGEN  <- 9.91

# Grassland emission factors [kg CO2-eq / ha / year]
# Source: IPCC (2006) Guidelines, Ch. 6 (LULUCF), Tier 1 defaults
EF_ARABLE    <- 1194.676
EF_GRASSLAND <-  781.35
EF_GRASS_RED <- EF_ARABLE - EF_GRASSLAND   # = 413.326 kg CO2-eq / ha / year

# Carbon price [EUR / tonne CO2] — EU ETS reference value ~2022/2023
CARBON_PRICE <- 70 / 1000                  # convert to EUR per kg CO2

# CDI performance coefficient [-]
# Source: Nilsson et al. (2022), doi:10.1111/1477-9552.12471
CDI_COEFF    <- 0.102                      # 10.2% farm performance per 1-unit CDI increase

# Derived unit prices (computed from parameters above — do not edit directly)
PRICE_PER_KG_N     <- EF_NITROGEN  * CARBON_PRICE   # EUR per kg N reduced      (= 0.6937)
PRICE_PER_HA_GRASS <- EF_GRASS_RED * CARBON_PRICE   # EUR per ha grassland gained (= 28.93)

# -----------------------------------------------------------------------------
# Load and merge datasets
# -----------------------------------------------------------------------------
all_countries_years <- list()

for (country in countries) {
  for (year in years) {
    FADN <- read.csv(file.path(main_dir, paste0(country, year, "SO.csv")))
    list_name <- paste(country, year, sep = "_")
    all_countries_years[[list_name]] <- FADN
  }
}

# Combine all datasets into one
FADN_combined <- bind_rows(all_countries_years)

# Save combined dataset for reuse
write.csv(FADN_combined, file.path(analysis_dir, "FADN_combined_all.csv"), row.names = FALSE)

# Alternatively: load pre-combined dataset
FADN_combined_all <- read.csv(file.path(analysis_dir, "FADN_combined_all.csv")) %>%
  filter(SE025 >= 1)   # Exclude farms with 0 ha UAA

# -----------------------------------------------------------------------------
# Prepare dataset: calculate CDI, process variables, normalize nutrient use
# -----------------------------------------------------------------------------

# 1. Define relevant crop area columns
crop_columns <- c(
  "CBRL_A", "CFODMZ_A", "CGRSTMP_A", "CGRSXRG_A", "CLNTL_A", "CMZ_A", "COAT_A",
  "CPEA_A", "CRAPE_A", "CRG_A", "CRICE_A", "CRYE_A", "CSNFL_A", "CSOYA_A",
  "CSUGBT_A", "CTOMAT_A", "CTOTFRUT_A", "CTOTGRASS_A", "CTOTHORT_A", "CVEGOF_A",
  "CWDED_A", "CWHTC_A", "CWHTD_A", "CWINEOTH_A"
)

# 2. Create potato total area (fresh + starch)
FADN_combined_all$CPOT_TOTAL <- ifelse(is.na(FADN_combined_all$CPOT_A), 0, FADN_combined_all$CPOT_A) +
  ifelse(is.na(FADN_combined_all$CPOTST_A), 0, FADN_combined_all$CPOTST_A)

# 3. Add potatoes to crop list
crop_columns <- c(crop_columns, "CPOT_TOTAL")

# 4. Replace missing values in crop areas with 0
FADN_combined_all[crop_columns][is.na(FADN_combined_all[crop_columns])] <- 0

# 5. Function to calculate Herfindahl Index (HI) and Crop Diversity Index (CDI)
calc_hi_cdi <- function(row) {
  crop_areas <- as.numeric(row[crop_columns])
  total_area <- sum(crop_areas)
  if (total_area == 0) return(c(HI = NA, CDI = NA))
  shares <- crop_areas / total_area
  hi <- sum(shares^2)
  c(HI = hi, CDI = 1 - hi)
}

# 6. Apply CDI/HI calculation
hi_cdi_matrix <- t(apply(FADN_combined_all, 1, calc_hi_cdi))
FADN_combined_all$HI <- hi_cdi_matrix[, "HI"]
FADN_combined_all$CDI <- hi_cdi_matrix[, "CDI"]

# 7. Reclassify ORGANIC variable (shift so 0 = no subsidy)
FADN_combined_all$ORGANIC <- FADN_combined_all$ORGANIC - 1

# 8. Keep only relevant variables
FADN_combined_all <- FADN_combined_all %>%
  select(
    ID, COUNTRY, YEAR, countryyear, TF8, SE025, SYS02,
    SE621, ORGANIC, SAEAWSUB_2_V, SORGSUB_2_V,
    INUSE_Q, IPUSE_Q, IKUSE_Q,
    HI, CDI, SE028
  )

# 9. Convert fertilizer use from tonnes/farm → kg/ha
FADN_combined_all <- FADN_combined_all %>%
  mutate(
    INUSE_Q = (INUSE_Q * 1000) / SE025,
    IPUSE_Q = (IPUSE_Q * 1000) / SE025,
    IKUSE_Q = (IKUSE_Q * 1000) / SE025,
    SE028 = SE028 / SE025
  )

# 10. Convert subsidies to €/ha and calculate total payments
FADN_combined_all <- FADN_combined_all %>%
  mutate(
    SE621 = if_else(is.na(SE621), 0, SE621),
    SORGSUB_2_V = if_else(is.na(SORGSUB_2_V), 0, SORGSUB_2_V),
    Payments = (SE621 + SORGSUB_2_V) / SE025
  )

# -----------------------------------------------------------------------------
# Matching function: compare farms with and without subsidy
# -----------------------------------------------------------------------------
match_and_analyze <- function(data, measure_column) {
  # Assign farms to treatment/control groups
  data <- FADN_combined_all %>%
    mutate(
      subsidy_group = case_when(
        is.na(.data[[measure_column]]) | .data[[measure_column]] == 0 ~ "No_Subsidy",
        .data[[measure_column]] > 0 ~ "With_Subsidy"
      ),
      size_class_ha = ntile(SE025, 5),    # size quantiles
      weighting_class = ntile(SYS02, 5)   # economic size quantiles
    )
  
  # Separate treatment and control groups
  with_subsidy <- data %>% filter(subsidy_group == "With_Subsidy")
  no_subsidy   <- data %>% filter(subsidy_group == "No_Subsidy")
  
  # Define matching targets
  match_targets <- with_subsidy %>%
    group_by(COUNTRY, YEAR, TF8, size_class_ha, weighting_class) %>%
    summarise(target_n = n(), .groups = "drop")
  
  # Sample matched control farms
  control_sample <- no_subsidy %>%
    inner_join(match_targets, by = c("COUNTRY", "YEAR", "TF8", "size_class_ha", "weighting_class")) %>%
    group_by(COUNTRY, YEAR, TF8, size_class_ha, weighting_class) %>%
    filter(!is.na(target_n) & n() > 0) %>%
    sample_n(size = pmin(n(), first(target_n)), replace = FALSE)
  
  # Combine groups into matched dataset
  matched_data <- bind_rows(
    with_subsidy %>% mutate(group = "With_Subsidy"),
    control_sample %>% mutate(group = "No_Subsidy")
  )
  
  # Summary statistics
  summary_stats <- matched_data %>%
    mutate(measure = measure_column) %>%
    group_by(group, COUNTRY, YEAR) %>%
    summarise(
      n_farms = n(),
      mean_nitrogen = mean(INUSE_Q, na.rm = TRUE),
      sd_nitrogen = sd(INUSE_Q, na.rm = TRUE),
      mean_cdi = mean(CDI, na.rm = TRUE),
      sd_cdi = sd(CDI, na.rm = TRUE),
      mean_grass = mean(SE028, na.rm = TRUE),
      sd_grass = sd(SE028, na.rm = TRUE),
      mean_Payments = mean(Payments, na.rm = TRUE),
      sd_Payments = sd(Payments, na.rm = TRUE),
      .groups = "drop"
    )
  
  # t-test comparisons
  t_test_results <- matched_data %>%
    mutate(measure = measure_column) %>%
    group_by(COUNTRY, YEAR) %>%
    summarise(
      t_stat_nitrogen = t.test(INUSE_Q ~ group)$statistic,
      p_value_nitrogen = t.test(INUSE_Q ~ group)$p.value,
      t_stat_cdi = t.test(CDI ~ group)$statistic,
      p_value_cdi = t.test(CDI ~ group)$p.value,
      t_stat_grass = t.test(SE028 ~ group)$statistic,
      p_value_grass = t.test(SE028 ~ group)$p.value,
      .groups = "drop"
    )
  
  return(tibble(summary_stats = list(summary_stats), t_test_results = list(t_test_results)))
}

# -----------------------------------------------------------------------------
# Run analysis for all measures, countries, and years
# -----------------------------------------------------------------------------
summary_stats_list <- list()
t_test_results_list <- list()

for (measure in measures) {
  group_keys <- FADN_combined_all %>% distinct(COUNTRY, YEAR)
  
  for (i in seq_len(nrow(group_keys))) {
    country <- group_keys$COUNTRY[i]
    year <- group_keys$YEAR[i]
    
    df_subset <- FADN_combined_all %>%
      filter(COUNTRY == country, YEAR == year)
    
    result <- match_and_analyze(df_subset, measure_column = measure)
  }    
  
  # Collect results
  summary_stats_list <- append(summary_stats_list, list(result$summary_stats[[1]] %>% mutate(measure = measure)))
  t_test_results_list <- append(t_test_results_list, list(result$t_test_results[[1]] %>% mutate(measure = measure)))
}

# Combine final results
final_summary_stats <- bind_rows(summary_stats_list)
final_t_test_results <- bind_rows(t_test_results_list)

# -----------------------------------------------------------------------------
# Save analysis results
# -----------------------------------------------------------------------------
write.csv(final_summary_stats, file.path(analysis_dir, "final_summary_stats.csv"), row.names = FALSE)
write.csv(final_t_test_results, file.path(analysis_dir, "final_t_test_results.csv"), row.names = FALSE)

# -----------------------------------------------------------------------------
# Calculate environmental benefits based on GHG emission reductions
# Parameters (EF_NITROGEN, EF_GRASS_RED, CARBON_PRICE, CDI_COEFF) are defined
# at the top of the script alongside the directory and country settings.
# See header above and docs/methodology.md for full methodological references.
# -----------------------------------------------------------------------------

# --- Pivot summary stats: With_Subsidy vs. No_Subsidy side-by-side ---
benefit_summary <- final_summary_stats %>%
  select(group, COUNTRY, YEAR, measure,
         mean_nitrogen, mean_grass, mean_cdi, mean_Payments) %>%
  pivot_wider(
    names_from  = group,
    values_from = c(mean_nitrogen, mean_grass, mean_cdi, mean_Payments)
  ) %>%
  mutate(
    # Monetary benefit from reduced nitrogen use (EUR/ha UAA)
    # Formula: (N_no_subsidy - N_with_subsidy) [kg N/ha] * PRICE_PER_KG_N [EUR/kg N]
    # Sources: IPCC (2006); Brentrup & Pallière (2008)
    benefit_nitrogen = (mean_nitrogen_No_Subsidy - mean_nitrogen_With_Subsidy) * PRICE_PER_KG_N,

    # Difference in permanent grassland share (With - No subsidy) [share of UAA]
    # Reported as raw share difference; for absolute EUR benefit multiply by
    # farm UAA [ha] * PRICE_PER_HA_GRASS [EUR/ha]
    # Source: IPCC (2006) Ch. 6 LULUCF
    benefit_grass = mean_grass_With_Subsidy - mean_grass_No_Subsidy,

    # Farm performance benefit from increased crop diversity [% of farm performance]
    # Formula: (CDI_with - CDI_no) * CDI_COEFF * 100
    # Source: Nilsson et al. (2022), doi:10.1111/1477-9552.12471
    cdi_change_percent = (mean_cdi_With_Subsidy - mean_cdi_No_Subsidy) * CDI_COEFF * 100,

    # Mean difference in total subsidy payments between groups (EUR/ha UAA)
    diff_payments = mean_Payments_With_Subsidy - mean_Payments_No_Subsidy
  ) %>%
  select(COUNTRY, YEAR, measure,
         benefit_nitrogen, benefit_grass, cdi_change_percent, diff_payments)

write.csv(benefit_summary, file.path(analysis_dir, "benefit_summary.csv"), row.names = FALSE)
