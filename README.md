# GreenArchitecture_FADN_Analysis

This project analyzes the impact of different agri-environmental subsidies on
European farms using FADN (Farm Accountancy Data Network) data. Environmental
benefits are quantified based on GHG emission reductions and monetised using a
carbon pricing approach. For full methodological details see
[docs/methodology.md](docs/methodology.md).

---

## Important Note on Data Access

The FADN data used in this project are **not publicly available**.  
They need to be applied for separately via the European Commission (DG AGRI) or
the relevant national authorities.

When requesting access, make sure that:
- All relevant variables (crops, fertilizer use, subsidies, etc.) are included
  in your dataset/application.
- The coverage (countries, years) matches the scope of your analysis.

The scripts in this repository assume that the required variables are present
in the input data. Missing variables will cause errors during execution.

---

## Project Structure

```
<project_root>/
├── data/                          # Raw FADN input files (not included, see above)
├── analysis/                      # Output directory (created on first run)
├── docs/
│   └── methodology.md             # Benefit calculation methodology & references
├── Script_1_Data_preparation_and_analysis.R
├── Script_2_Visualization.R
└── README.md
```

### Script 1: Data Preparation and Analysis
- Loads and merges FADN datasets (multiple countries and years)
- Prepares variables:
  - Normalizes fertilizer use (kg/ha)
  - Calculates Crop Diversity Index (CDI)
  - Processes subsidies (€/ha)
- Matches farms with and without subsidies
- Calculates mean values and statistical differences (t-tests)
- Estimates environmental benefits from GHG emission reductions
- Saves summary statistics, t-test results, and benefit summary

### Script 2: Visualization
- Reads analysis outputs
- Creates grouped bar plots with error bars:
  - Nitrogen fertilizer use
  - Crop Diversity Index (CDI)
  - Permanent grassland share
- Generates benefit plots by subsidy measure
- Saves plots as `.jpg`

---

## Input

- Raw FADN datasets in CSV format, one file per country-year
  (naming convention: `{COUNTRY}{YEAR}SO.csv`, e.g. `DEU2022SO.csv`)
- Place all input files in the `data/` folder at the project root

---

## Output

All outputs are written to the `analysis/` folder:

| File | Description |
|---|---|
| `FADN_combined_all.csv` | Merged dataset across all countries and years |
| `final_summary_stats.csv` | Mean values by group, country, year, and measure |
| `final_t_test_results.csv` | t-test statistics and p-values |
| `benefit_summary.csv` | Estimated environmental benefits by country, year, and measure |
| `*.jpg` | Visualizations (nitrogen, CDI, grassland, benefit plots) |

---

## Usage

1. Apply for and obtain the FADN data (with all relevant variables).
2. Place the raw CSV files in the `data/` folder.
3. Open the project in RStudio by double-clicking the `.Rproj` file — this sets
   the working directory automatically via `{here}`.
4. If needed, adjust the analysis parameters (emission factors, carbon price,
   countries, years) at the top of **Script 1**.
5. Run **Script 1** to prepare data, run the analysis, and calculate benefits.
6. Run **Script 2** to generate plots.

---

## Dependencies

Both scripts require R with the following packages:

| Package | Purpose |
|---|---|
| `dplyr` | Data manipulation |
| `tidyr` | Reshaping data (pivot) |
| `ggplot2` | Visualizations |
| `knitr` | Reporting utilities |
| `grid` | Plot layout (Script 2) |
| `here` | Reproducible file paths relative to project root |

Install all dependencies at once:

```r
install.packages(c("dplyr", "tidyr", "ggplot2", "knitr", "grid", "here"))
```
