# =============================================================================
# Script 1: Data preparation and analysis
# Purpose:
#   - Load and merge FADN datasets for selected countries and years
#   - Prepare variables (CDI, fertilizer use, subsidies)
#   - Match farms with and without subsidies
#   - Perform statistical analysis (mean differences, t-tests)
#   - Save outputs for visualization
# =============================================================================

# --- Load required packages ---
library(dplyr)
library(knitr)
library(ggplot2)

# --- Define directories ---
main_dir <- "N:/Green Architecture/FADN/Data"           # Input directory
analysis_dir <- "N:/Green Architecture/FADN/Analysis"  # Output directory

# --- Define countries, years, and subsidy measures of interest ---
countries <- c("DEU", "POL", "OST", "DAN", "ITA", "LTU", "NED", "HUN", "FRA")
years <- c("2021", "2022")
measures <- c("SE621", "SORGSUB_2_V")  
# SE621        = Environmental subsidies
# SORGSUB_2_V  = Organic farming subsidy

# -----------------------------------------------------------------------------
# Load and merge datasets
# -----------------------------------------------------------------------------
all_countries_years <- list()
setwd(file.path(main_dir))

for (country in countries) {
  for (year in years) {
    FADN <- read.csv(paste0(country, year, "SO.csv"))
    list_name <- paste(country, year, sep = "_")
    all_countries_years[[list_name]] <- FADN
  }
}

# Combine all datasets into one
FADN_combined <- bind_rows(all_countries_years)

# Save combined dataset for reuse
setwd(file.path(analysis_dir))
write.csv(FADN_combined, "FADN_combined_all.csv", row.names = FALSE)

# Alternatively: load pre-combined dataset
setwd(file.path(analysis_dir))
FADN_combined_all <- read.csv("FADN_combined_all.csv") %>% 
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
