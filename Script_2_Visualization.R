# =============================================================================
# Script 2: Visualization of results
# Purpose:
#   - Create grouped bar plots from summary statistics
#   - Visualize nitrogen use, CDI, grassland, and subsidy benefits
#   - Save plots as .jpg files
# =============================================================================

# --- Load required packages ---
library(dplyr)
library(knitr)
library(ggplot2)
library(grid)

# --- Define input/output directories (adjust for your system) ---
# Desktop PC
main_dir <- "N:/nc.iamo.de/Anträge/Green Architecture/FADN/Data"
analysis_dir <- "N:/nc.iamo.de/Anträge/Green Architecture/FADN/Analysis"

# Framework Notebook
main_dir <- "C:/Users/Appel/Nextcloud2/Anträge/Green Architecture/FADN/Data"
analysis_dir <- "C:/Users/Appel/Nextcloud2/Anträge/Green Architecture/FADN/Analysis"

# --- Define countries, years, and subsidy measures of interest ---
countries <- c("DEU", "POL", "OST", "DAN", "ITA", "LTU", "NED", "HUN", "FRA")
years <- c("2021", "2022")
measures <- c("SE621", "SORGSUB_2_V")

# --- Load processed summary statistics ---
setwd(file.path(analysis_dir))
final_summary_stats <- read.csv("final_summary_stats.csv")

# -----------------------------------------------------------------------------
# Prepare dataset for plotting
# -----------------------------------------------------------------------------
year <- 2022

plot_data <- final_summary_stats %>%
  filter(YEAR == year, COUNTRY %in% countries) %>%
  mutate(
    se_nitrogen = sd_nitrogen / sqrt(n_farms),
    se_cdi = sd_cdi / sqrt(n_farms),
    se_grass = sd_grass / sqrt(n_farms)
  )

# Labels for measures and countries
measure_labels <- c(
  "SE621" = "Environmental Subsidy",
  "SORGSUB_2_V" = "Organic"
)

country_labels <- c(
  "DEU" = "DE", "POL" = "PL", "OST" = "AT", "DAN" = "DK", 
  "ITA" = "IT", "LTU" = "LT", "NED" = "NL", "HUN" = "HU", "FRA" = "FR"
)

plot_data <- plot_data %>%
  mutate(
    measure_label = recode(measure, !!!measure_labels),
    country_label = recode(COUNTRY, !!!country_labels),
    group_label = recode(group,
                         "No_Subsidy" = "Without Subsidy",
                         "With_Subsidy" = "With Subsidy")
  )

# -----------------------------------------------------------------------------
# Helper function: grouped barplot with error bars
# -----------------------------------------------------------------------------
plot_grouped_bar <- function(data, value_col, se_col, title, y_label, filename) {
  gg <- ggplot(data, aes(x = country_label, y = .data[[value_col]], fill = group_label)) +
    geom_bar(stat = "identity", position = position_dodge(width = 0.8), width = 0.7) +
    geom_errorbar(aes(ymin = .data[[value_col]] - 1.96 * .data[[se_col]],
                      ymax = .data[[value_col]] + 1.96 * .data[[se_col]]),
                  position = position_dodge(width = 0.8), width = 0.2) +
    facet_wrap(~ measure_label, ncol = 1) +
    labs(title = title, x = "", y = y_label, fill = "Group") +
    scale_fill_manual(values = c("#000083", "#FFD34E")) +  # dark blue + yellow
    theme_minimal(base_size = 14) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  # Show and save plot
  print(gg)
  ggsave(filename = file.path(analysis_dir, filename),
         plot = gg, width = 10, height = 8, dpi = 300)
}

# -----------------------------------------------------------------------------
# Create plots for nitrogen, CDI, grassland
# -----------------------------------------------------------------------------
plot_grouped_bar(plot_data, "mean_nitrogen", "se_nitrogen", 
                 "Nitrogen Fertilizer – 2022", "Nitrogen Use [kg/ha]", "Nitrogen_Fertilizer_2022.jpg")

plot_grouped_bar(plot_data, "mean_cdi", "se_cdi", 
                 "Crop Diversity Index (CDI) – 2022", "CDI", "CDI_2022.jpg")

plot_grouped_bar(plot_data, "mean_grass", "se_grass", 
                 "Permanent Grassland – 2022", "Grassland Area [share of UAA]", "Grassland_2022.jpg")

# -----------------------------------------------------------------------------
# Benefit plots (combined per measure)
# -----------------------------------------------------------------------------
benefit_data <- read.csv("benefit_summary.csv")

measure_labels <- c("SE621" = "Environmental Subsidy", "SORGSUB_2_V" = "Organic")

plot_data <- benefit_data %>%
  filter(year == 2022) %>%
  mutate(
    measure_label = measure_labels[measure],
    country_label = country_labels[COUNTRY]
  )

# Create combined plots for each measure
for (m in unique(plot_data$measure)) {
  plot_subset <- plot_data %>% filter(measure == m)
  
  p1 <- ggplot(plot_subset, aes(x = country_label, y = benefit_nitrogen)) +
    geom_bar(stat = "identity", fill = "#000083") +
    labs(title = "Benefit from Nitrogen Reduction", x = "", y = "€/ha UAA") +
    theme_minimal()
  
  p2 <- ggplot(plot_subset, aes(x = country_label, y = benefit_grass)) +
    geom_bar(stat = "identity", fill = "#FFD34E") +
    labs(title = "Benefit from Permanent Grassland", x = "", y = "€/ha UAA") +
    theme_minimal()
  
  p3 <- ggplot(plot_subset, aes(x = country_label, y = cdi_change_percent)) +
    geom_bar(stat = "identity", fill = "#44BA7E") +
    labs(title = "Benefit from CDI", x = "", y = "% of farm performance") +
    theme_minimal()
  
  p4 <- ggplot(plot_subset, aes(x = country_label, y = diff_payments)) +
    geom_bar(stat = "identity", fill = "#DD0C86") +
    labs(title = "Payments", x = "", y = "€/ha UAA") +
    theme_minimal()
  
  # Display combined layout
  grid.newpage()
  pushViewport(viewport(layout = grid.layout(4, 1)))
  print(p1, vp = viewport(layout.pos.row = 2, layout.pos.col = 1))
  print(p2, vp = viewport(layout.pos.row = 3, layout.pos.col = 1))
  print(p3, vp = viewport(layout.pos.row = 4, layout.pos.col = 1))
  print(p4, vp = viewport(layout.pos.row = 1, layout.pos.col = 1))
  
  # Save combined plot
  jpeg(filename = paste0("combined_plot_", m, "_2022.jpg"), width = 1000, height = 1500, res = 150)
  grid.newpage()
  pushViewport(viewport(layout = grid.layout(4, 1)))
  print(p1, vp = viewport(layout.pos.row = 2, layout.pos.col = 1))
  print(p2, vp = viewport(layout.pos.row = 3, layout.pos.col = 1))
  print(p3, vp = viewport(layout.pos.row = 4, layout.pos.col = 1))
  print(p4, vp = viewport(layout.pos.row = 1, layout.pos.col = 1))
  dev.off()
}