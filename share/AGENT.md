# Project Context & AI Instructions

## 1. Project Overview
This is an economic research project analyzing Tariff-Induced Global Value Chain Extension. 
The goal is to produce reproducible estimates using Panel Regression with Upstream/Downstream Tariff Exposure.

## 2. Tech Stack & Coding Style (MANDATORY)
* **Language:** R
* **Data Manipulation:** * `data.table` ONLY. No `dplyr`.
    * Use pipe syntax: `dt[i, j] %>% .[order(-date)]`
* **Package Management:** * Strictly use `box::use()`. 
    * Example: `box::use(data.table[...], fixest[feols])`
* **Documentation:** Quarto (`.qmd`) with LaTeX math.

## 3. Directory Structure
* `data/raw`: Immutable raw CSVs. Never edit manually.
* `data/processed`: Cleaning scripts output here (via `fwrite`).
* `doc/`: Manuscript source files (e.g., `_empirical_method.qmd`, `draft.qmd`).
* `R/`: Reusable logic/functions (modules).
* `analysis/`: Analysis scripts (e.g., `01_clean.qmd`, `02_reg.qmd`).

## 4. Tone & Language
* **Language:** Chinese (Simplified).
* **Tone:** Professional, academic, and technically precise.
* **Formatting:**
    * Minimize use of bold (`**`) or quotes for emphasis unless necessary.
    * Avoid using dashes (`-`, `—`) unless necessary.
    * For Chinese quotes, strictly use `「` and `」` instead of `“` and `”`.

## 5. Analytical Guidelines
* **Robustness:** Always include standard errors clustered at the Product (HS6) level.
* **Tables:** Use `modelsummary` for regression output.
* **Visualization:** Use `ggplot2` but import via `box::use(ggplot2[...])`.

## 6. Common Tasks
* If asked to **"Load Data"**: Look for the latest file in `data/processed` and use `fread`.
* If asked to **"Check Logs"**: Summary stats should focus on missing values and outliers in key economic variables.
