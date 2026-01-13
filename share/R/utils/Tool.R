box::use(R/utils/Logger[logger_factory])
LOG <- logger_factory("Tools")

#' Conditional Value Selection with Multiple Fallbacks
#'
#' Returns the first non-NULL value from a sequence of arguments.
#' This function provides a concise way to handle NULL values with multiple
#' fallback defaults, similar to the coalesce operation in SQL.
#'
#' @param ... Any number of values to check. Can be of any type.
#'   The function evaluates arguments from left to right and returns
#'   the first non-NULL value encountered.
#'
#' @return Returns the first non-NULL argument. If all arguments are NULL,
#'   returns NULL.
#'
#' @examples
#' ifthen(NULL, 5)              # Returns 5
#' ifthen(10, 5)                # Returns 10
#' ifthen(NA, "default")        # Returns NA (not NULL)
#' ifthen(0, 1)                 # Returns 0 (not NULL)
#' ifthen(NULL, NULL, "third")  # Returns "third"
#' ifthen(NULL, NULL, NULL)     # Returns NULL
#'
#' @export
ifthen <- function(...) {
  # Capture all arguments as a list for efficient iteration
  args <- list(...)

  # Early return if no arguments provided
  if (length(args) == 0L) {
    return(NULL)
  }

  # Iterate through arguments and return first non-NULL value
  for (arg in args) {
    if (!is.null(arg)) return(arg)
  }

  # Return NULL if all arguments are NULL
  NULL
}

#' Execute a Function from a Dynamically Loaded Box Module
#'
#' This function dynamically loads a specified module using `box`, retrieves a
#' specific function from it, and executes that function with the provided
#' arguments.
#'
#' @param mod A character string specifying the module path or name.
#' @param func A character string specifying the function name to retrieve from the module.
#' @param args A list of arguments to pass to the function.
#'
#' @return The result of the executed function, or `NULL` if an error occurs.
#' @export
execute_box_mod_func <- function(mod, func, args) {
  stopifnot(is.character(mod), is.character(func), is.list(args))

  loaded <- tryCatch(
    {
      box_expr <- sprintf("box::use(%s[%s])", mod, func)
      eval(parse(text = box_expr), envir = environment())
    },
    error = function(e) {
      LOG$error(glue::glue("Failed to load module '{mod}': {e$message}"))
    }
  )

  # Retrieve the function object from the current environment
  func_obj <- get(func, envir = environment())

  # Validate that the retrieved object is indeed a function
  if (!is.function(func_obj)) {
    LOG$error(glue::glue("'{func}' from module '{mod}' is not a function."))
  }

  # Execute the function with provided arguments
  tryCatch(
    do.call(func_obj, args),
    error = function(e) {
      LOG$error(glue::glue("Error executing '{func}': {e$message}"))
    }
  )
}
