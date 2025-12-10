# __PROJECT_NAME__

## Project Description

Describe your research objectives here.

## Replication Guide

This project follows a reproducible research workflow.

1. **Open Project**: Open the directory in your preferred editor (VS Code, RStudio, etc.).
2. **Restore Environment**: Run `renv::restore()` to install dependencies (if using renv).
3. **Prepare Data**:
   - If using DVC: Run `dvc pull`
   - Otherwise, ensure raw data is in `/data` directory.
4. **Run Analysis**:
   - Execute main script: `source("R/main.R")`
   - Or use task: `task`

## Directory Structure

- `/R/`: R source code (build, analysis, check, utils)
- `/data/`: Raw data (read-only, do not modify manually)
- `/out/`: Generated outputs (ignored by git)
- `/cache/`: Cached data (ignored by git)
- `/doc/`: Documentation and manuscripts
- `/log/`: Execution logs
- `/template/`: Document templates (CSL, DOCX)
