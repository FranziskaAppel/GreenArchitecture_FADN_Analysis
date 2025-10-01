# GreenArchitecture_FADN_Analysis
This project analyzes the impact of different subsidies  on European farms using FADN (Farm Accountancy Data Network) data.

## Important Note on Data Access

The FADN data used in this project are **not publicly available**.  
They need to be applied for separately via the European Commission (DG AGRI) or 
the relevant national authorities.  

When requesting access, make sure that:
- All relevant variables (crops, fertilizer use, subsidies, etc.) are included in your dataset/application.
- The coverage (countries, years) matches the scope of your analysis.

The scripts in this repository assume that the required variables are present 
in the input data. Missing variables will cause errors during execution.

## Project Structure

- **Script 1: Data preparation and analysis**
  - Loads FADN datasets (multiple countries and years)
  - Prepares variables:
    - Normalizes fertilizer use (kg/ha)
    - Calculates Crop Diversity Index (CDI)
    - Processes subsidies (€/ha)
  - Matches farms with and without subsidies
  - Calculates mean values and statistical differences
  - Saves summary statistics and t-test results

- **Script 2: Visualization**
  - Reads analysis outputs
  - Creates grouped bar plots with error bars:
    - Nitrogen fertilizer use
    - Crop Diversity Index (CDI)
    - Permanent grassland share
  - Generates benefit plots by subsidy measure
  - Saves plots as `.jpg`

## Input

- Raw FADN datasets (CSV format)
- Located in a specified input directory (see script settings)

## Output

- `final_summary_stats.csv`  
- `final_t_test_results.csv`  
- Visualizations (`.jpg` files)

## Usage

1. Apply for and obtain the FADN data (with all relevant variables).  
2. Adjust input/output directories in both scripts.  
3. Run **Script 1** to prepare and analyze data.  
4. Run **Script 2** to generate plots.  

## Dependencies

Both scripts require R with the following packages:

- `dplyr`
- `ggplot2`
- `knitr`
- `grid`
