# __PROJECT_NAME__

## Project Description

Describe your research objectives here.

## Replication Guide

This project follows a reproducible research workflow.

1. **Open Project**: Open the directory in your preferred editor (VS Code,
   RStudio, etc.).
2. **Restore Environment**: Run `renv::restore()` to install dependencies (if using renv).
3. **Prepare Data**:
   - If using DVC: Run `dvc pull`
   - Otherwise, ensure raw data is in `/data` directory.
4. **Run Analysis**:
   - Execute main script: `source("R/main.R")`
   - Or use task: `task <task-name>` (see [Task System](#task-system) below)

## Directory Structure

- `/R/`: R source code (build, analysis, check, utils)
- `/data/`: Raw data (read-only, do not modify manually)
- `/out/`: Generated outputs (ignored by git)
- `/cache/`: Cached data (ignored by git)
- `/doc/`: Documentation and manuscripts
- `/log/`: Execution logs
- `/template/`: Document templates (CSL, DOCX)
- `/tasks/`: Auto-generated task definitions for go-task (do not edit manually)

## Task System

This project uses [go-task](https://taskfile.dev) for task automation.
Tasks are defined in `config.yml` or `config.R` and automatically compiled into `tasks/r_tasks.yml`.

### Installation

```bash
# macOS / Linux (via install script)
sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin

# Arch Linux
pacman -S go-task

# macOS (Homebrew)
brew install go-task
```

### How Tasks Work

Tasks are defined in `config.yml` (or `config.R`) under a hierarchical structure.
Each leaf node with `mod` and `func` fields becomes an executable task:

```yaml
# config.yml
cache:
  data:
    my_dataset: # → task name: cache:data:my_dataset
      mod: R/build/Data # box module path (R/build/Data.R)
      func: load_data # function to call within the module
      update: null # cache update strategy (null = use existing if available)
      args: null # arguments passed to the function
```

Task names follow a colon-separated hierarchy matching the config tree depth (e.g.,
`cache:data:my_dataset`).

### Defining New Tasks

Tasks can be defined in either `config.yml` (static) or `config.R` (dynamic).
Only one is active at a time:
`config.R` takes precedence if it exists and returns a non-`NULL` value;
they are **not** merged.

**Option A: `config.yml`** — for simple, static task definitions:

```yaml
cache:
  analysis:
    regression:
      mod: R/analysis/Model # box module path (R/analysis/Model.R)
      func: run_regression # exported function to call
      update: null # cache strategy (null = skip if cache exists)
      args:
        method: lm
        controls: [age, income]
```

**Option B: `config.R`** — for dynamic task definitions (e.g., looping over datasets).
The file must return the config list as its **last expression**:

```r
# config.R
datasets <- c("survey", "panel", "census")

cache_tasks <- setNames(
  lapply(datasets, function(d) {
    list(
      mod = paste0("R/build/", d),
      func = "load_data",
      update = NULL,
      args = list(year = 2023)
    )
  }),
  datasets
)

# Last expression = return value
list(
  cache = list(
    data = cache_tasks
  )
)
```

This generates tasks `cache:data:survey`, `cache:data:panel`, `cache:data:census`.

2. Regenerate the taskfile:

   ```bash
   task build_r_tasks
   ```

   This runs `Rscript -e 'box::use(R/utils/Task); Task$write_taskfile()'`
   and updates `tasks/r_tasks.yml`.

### Running Tasks

```bash
# List all available tasks
task --list

# Run a specific task (colon-separated hierarchy)
task cache:data:my_dataset

# Run all tasks (default)
task

# Force re-run a task (ignore cache)
task --force cache:analysis:regression

# Watch for file changes and rebuild automatically
task --watch build_r_tasks
```

### Task Caching

Tasks use file-based caching via the `cache_result()` function.
Outputs are stored as `.qs` files under `cache/` following the task name hierarchy:

- `cache:data:my_dataset` → `cache/data/my_dataset/default.qs`

go-task tracks `sources` (input R module files) and `generates` (output cache files).
A task is skipped if its sources haven't changed since the last run.

### Built-in Tasks

| Task | Description |
|------|-------------|
| `build_r_tasks` | Regenerate `tasks/r_tasks.yml` from `config.yml` |

