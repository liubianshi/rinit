box::use(R/utils/logger[logger_factory])
LOG <- logger_factory("cache")

#' Execute Task Function
#'
#' Dynamically loads and executes a function from a specified module.
#'
#' @param mod Character string specifying the module path.
#' @param func Character string specifying the function name.
#' @param args List of arguments to pass to the function.
#'
#' @return The result of the function execution.
execute_task_func <- function(mod, func, args) {
  # Dynamically load module and function
  tryCatch(
    {
      box_expr <- sprintf("box::use(%s[%s])", mod, func)
      eval(parse(text = box_expr), envir = parent.frame())
    },
    error = function(e) {
      LOG$error("Failed to load module {mod}: {e$message}")
      return(invisible(NULL))
    }
  )

  # Retrieve and execute the loaded function
  func_obj <- get(func, envir = parent.frame())

  if (!is.function(func_obj)) {
    LOG$error("`{func}` is not a function.")
    return(invisible(NULL))
  }

  do.call(func_obj, args)
}

#' Validate Information Metadata
#'
#' Checks if the provided information object contains valid metadata by verifying
#' that the object itself and its required components (mod and func) are not NULL.
#'
#' @param info A list or object containing metadata with 'mod' and 'func' components.
#'
#' @return A logical value: TRUE if all required components are present and not NULL,
#'   FALSE otherwise.
#'
#' @examples
#' valid_info_metadata(list(mod = "module", func = "function"))
#' valid_info_metadata(list(mod = NULL, func = "function"))
#' valid_info_metadata(NULL)
valid_info_metadata <- function(info) {
  # Check if info is not NULL and contains non-NULL mod and func components
  !is.null(info) && !is.null(info$mod) && !is.null(info$func)
}

#' Cache and Retrieve Task Results
#'
#' Executes a task defined in the configuration file and caches its result.
#' Supports hierarchical task definitions and automatic cache invalidation.
#'
#' @param task Character string specifying the task path (colon-separated hierarchy).
#' @param update Logical or expression to determine cache update behavior. Default is NULL.
#'
#' @return The cached result of the task execution, or NULL if an error occurs.
#' @export
#'
#' @examples
#' \dontrun{
#' cache_result("data:processing:clean")
#' cache_result("model:train", update = TRUE)
#' }
cache_result <- function(task, update = NULL) {
  # Initialize logger

  # Parse task path into hierarchical keys
  keys <- strsplit(task, ":", fixed = TRUE)[[1]]

  # Navigate CONFIG structure to retrieve metadata
  CONFIG <- lbs::ifthen(CONFIG, yaml::read_yaml("config.yml"))
  info <- Reduce(function(meta, key) meta[[key]], keys, init = CONFIG)

  # Validate metadata completeness
  if (!valid_info_matedata(info)) {
    LOG$error("Invalid or incomplete metadata for task: {task}")
    return(invisible(NULL))
  }

  # Construct cache file path
  target_path <- local({
    target_dir <- do.call(file.path, as.list(keys[-length(keys)]))

    # Ensure cache directory exists
    if (!dir.exists(target_dir)) {
      dir.create(target_dir, recursive = TRUE)
    }

    target_filename <- paste0(keys[length(keys)], ".qs")
    file.path(target_dir, target_filename)
  })

  # Load caching utility
  box::use(utils/cache[cache_result = result])

  # Execute and cache function results with error handling
  result <- tryCatch(
    {
      cached <- cache_result(
        execute_task_func(info$mod, info$func, if (!is.null(info$args)) info$args else list()),
        target_path,
        if (!is.null(update)) update else info$update
      )

      LOG$info("Task '{task}' cached successfully at '{target_path}'")
      cached
    },
    error = function(e) {
      LOG$error("Caching failed for task '{task}': {e$message}")
      NULL
    }
  )

  result
}

#' Fetch Cached Task Result
#'
#' Convenience wrapper for retrieving cached task results.
#'
#' @param task Character string specifying the task path (colon-separated hierarchy).
#' @param update Logical indicating whether to force cache update. Default is FALSE.
#'
#' @return The cached result of the task execution.
#'
#' @examples
#' \dontrun{
#' fetch_cached("data:processing:clean")
#' fetch_cached("model:train", update = TRUE)
#' }
fetch_cached <- function(task, update = FALSE) {
  cache_result(task, update)
}
