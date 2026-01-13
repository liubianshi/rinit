#' Cache Evaluation Result
#'
#' Evaluates R expressions and caches the result to a file. Automatically
#' handles directory creation and supports both QS and RDS formats.
#'
#' @param expressions An R expression or block of expressions to evaluate.
#'   Variables created within a block `{...}` will be local to the evaluation
#'   environment and not leak into the caller, unless `<<-` is used.
#' @param file Character. The cache filename. If no directory component is
#'   provided, the file is saved in a 'cache' subdirectory (created if needed).
#'   Must end in `.qs` or `.rds`.
#' @param update Logical. If `TRUE`, forces re-evaluation and updates the cache.
#'
#' @return The result of the evaluated expressions.
#' @export
result <- function(expressions, file, update = FALSE) {
  # Validate file extension
  ext <- tolower(tools::file_ext(file))
  if (!ext %in% c("qs", "rds")) {
    stop("Invalid file extension. Please use '.qs' or '.rds'.")
  }

  # Return cached result if available
  if (file.exists(file) && !isTRUE(update)) {
    if (ext == "qs") {
      if (!requireNamespace("qs", quietly = TRUE)) {
        stop("Package 'qs' is not installed.")
      }
      return(qs::qread(file))
    } else {
      return(readRDS(file))
    }
  }

  # Evaluate expressions in a clean environment inheriting from caller
  # This prevents temporary variables inside 'expressions' from leaking
  env <- new.env(parent = parent.frame())
  res <- eval(substitute(expressions), envir = env)

  # Write to cache
  tryCatch(
    {
      if (ext == "qs") {
        qs::qsave(res, file)
      } else {
        saveRDS(res, file)
      }
    },
    error = function(e) {
      warning("Failed to write cache file '", file, "': ", e$message)
    }
  )

  return(res)
}
