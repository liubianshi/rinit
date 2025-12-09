# Project-level .Rprofile
# This file is executed when R starts in this project directory

# First, source user-level .Rprofile if it exists (to preserve user settings)
if (file.exists("~/.Rprofile")) {
  source("~/.Rprofile")
}

# Project-specific settings --------------------------------------------

# Set CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org/"))

# General R options
options(
  stringsAsFactors = FALSE,
  max.print = 100,
  scipen = 10,
  width = 120,
  box.path = getwd()
)

# Activate renv if available
if (file.exists("renv/activate.R")) {
  source("renv/activate.R")
}

# Project startup message
.onAttach <- function(libname, pkgname) {
  msg <- paste0(
    "\n",
    "✓ Project loaded: ", basename(getwd()), "\n",
    "✓ Working directory: ", getwd(), "\n"
  )
  packageStartupMessage(msg)
}
.onAttach()

# Clean up
rm(.onAttach)
