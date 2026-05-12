# Benefit Calculation Methodology

This document describes the assumptions, parameters, and references underlying
the environmental benefit calculations in `Script_1_Data_preparation_and_analysis.R`.

---

## Overview

Environmental benefits are estimated by quantifying the reduction in greenhouse
gas (GHG) emissions associated with selected agri-environmental measures and
translating these reductions into monetary terms using a carbon price. Three
indicators are covered: nitrogen fertilizer use, permanent grassland area, and
crop diversity (CDI).

---

## 1. Nitrogen Fertilizer Use

**Indicator:** Mean nitrogen use (kg N/ha UAA) — subsidy group vs. control group  
**Benefit metric:** `benefit_nitrogen` — monetary saving in EUR/ha UAA

### Emission factor

A total life-cycle emission factor of **9.91 kg CO₂-eq per kg N** is applied,
composed as follows:

| Component | kg CO₂-eq / kg N | Source |
|---|---|---|
| Direct N₂O emissions | 4.68 | IPCC (2006), Ch. 11, Tier 1 default |
| Indirect — volatilisation | 0.47 | IPCC (2006), Table 11.3 |
| Indirect — leaching & runoff | 1.05 | IPCC (2006), Table 11.3 |
| Fertilizer production | 3.70 | Brentrup & Pallière (2008) |
| **Total** | **9.91** | |

### Formula

```
benefit_nitrogen [EUR/ha] =
    (mean_N_no_subsidy − mean_N_with_subsidy) [kg N/ha]
    × 9.91 [kg CO₂-eq/kg N]
    × 0.07 [EUR/kg CO₂]
```

This yields a saving of **€0.6937 per kg N reduced**.

### References

- IPCC (2006). *2006 IPCC Guidelines for National Greenhouse Gas Inventories,
  Volume 4: Agriculture, Forestry and Other Land Use*, Chapter 11
  (N₂O Emissions from Managed Soils).
  [https://www.ipcc-nggip.iges.or.jp/public/2006gl/vol4.html](https://www.ipcc-nggip.iges.or.jp/public/2006gl/vol4.html)
- Brentrup, F. & Pallière, C. (2008). *GHG emissions and energy efficiency in
  European nitrogen fertiliser production and use*. Proceedings 639,
  International Fertiliser Society, York, UK.

---

## 2. Permanent Grassland Area

**Indicator:** Permanent grassland as share of UAA (SE028/SE025) — subsidy group vs. control group  
**Benefit metric:** `benefit_grass` — difference in grassland share (With − No subsidy)

### Emission factors

IPCC Tier 1 default values for temperate climates:

| Land use | kg CO₂-eq / ha / year | Source |
|---|---|---|
| Arable land | 1,194.676 | IPCC (2006), Ch. 6 |
| Permanent grassland | 781.35 | IPCC (2006), Ch. 6 |
| **Net reduction per ha converted** | **413.326** | |

### Note on monetisation

`benefit_grass` is reported as the **raw difference in grassland share**
(With_Subsidy − No_Subsidy). To convert to a monetary value at farm level:

```
EUR benefit [per farm] =
    benefit_grass [share] × farm_UAA [ha]
    × 413.326 [kg CO₂-eq/ha/year]
    × 0.07 [EUR/kg CO₂]
```

This yields a saving of **€28.93 per additional hectare of permanent grassland**.

### Reference

- IPCC (2006). *2006 IPCC Guidelines for National Greenhouse Gas Inventories,
  Volume 4*, Chapter 6 (Land Use, Land-Use Change, and Forestry — LULUCF).
  [https://www.ipcc-nggip.iges.or.jp/public/2006gl/vol4.html](https://www.ipcc-nggip.iges.or.jp/public/2006gl/vol4.html)

---

## 3. Crop Diversity Index (CDI)

**Indicator:** CDI (1 − Herfindahl Index across crop areas) — subsidy group vs. control group  
**Benefit metric:** `cdi_change_percent` — percentage change in farm performance

### Coefficient

Following Nilsson et al. (2022), a coefficient of **0.102** is applied,
indicating a **10.2% increase in farm performance per one-unit increase in CDI**.
This effect is used as a proxy for the farm-level economic benefit of
crop diversification.

### Formula

```
cdi_change_percent [%] =
    (mean_CDI_with_subsidy − mean_CDI_no_subsidy)
    × 0.102 × 100
```

### Reference

- Nilsson, P., Röös, E., Tidåker, P., & Ivarsson, E. (2022). Crop diversity and
  farm performance: Evidence from Swedish farm-level data. *Journal of
  Agricultural Economics*, 73(3), 799–818.
  [https://doi.org/10.1111/1477-9552.12471](https://doi.org/10.1111/1477-9552.12471)

---

## 4. Carbon Price

All GHG reductions are monetised at **€70 per tonne CO₂** (= €0.07 per kg CO₂).

This value reflects the EU ETS price range and social cost estimates used in
European agricultural policy impact assessments during the 2022/2023 reference
period. As the EU ETS price is volatile, users should verify the current price
and adjust `CARBON_PRICE` in the script accordingly if replicating this analysis
at a different point in time.

| Parameter | Value |
|---|---|
| Carbon price | €70 / tonne CO₂ |
| = | €0.07 / kg CO₂ |
| EUR per kg N reduced | €0.6937 |
| EUR per ha grassland gained | €28.93 |

---

## 5. Subsidy Payments Difference

**Benefit metric:** `diff_payments` — difference in mean total payments (EUR/ha UAA)

```
diff_payments [EUR/ha] =
    mean_Payments_with_subsidy − mean_Payments_no_subsidy
```

Total payments (`Payments`) are defined in Script 1 as
`(SE621 + SORGSUB_2_V) / SE025`, i.e., the sum of environmental and organic
farming subsidies normalised by utilised agricultural area.

---

## Variable Reference

| Variable in CSV | Description | Unit |
|---|---|---|
| `benefit_nitrogen` | Monetary GHG saving from N reduction | EUR/ha UAA |
| `benefit_grass` | Difference in permanent grassland share | share of UAA |
| `cdi_change_percent` | Farm performance change via CDI increase | % |
| `diff_payments` | Difference in subsidy payments | EUR/ha UAA |
| `COUNTRY` | Country code (FADN) | — |
| `YEAR` | Reference year | — |
| `measure` | Subsidy measure (`SE621` or `SORGSUB_2_V`) | — |
