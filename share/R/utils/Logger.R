#' Create a Logger Factory
#'
#' This function creates a logger object with methods for different log levels.
#' Each log message is prefixed with a custom identifier.
#'
#' @param prefix A character string to prepend to all log messages.
#'
#' @return A list containing four logging functions:
#'   \itemize{
#'     \item \code{info}: Logs informational messages
#'     \item \code{warn}: Logs warning messages
#'     \item \code{error}: Logs error messages and stops execution
#'     \item \code{debug}: Logs debug messages (only if logger.debug option is TRUE)
#'   }
#'
#' @examples
#' logger <- logger_factory("MyApp")
#' logger$info("Application started")
#' logger$warn("Low memory")
#'
#' # Enable debug logging
#' options(logger.debug = TRUE)
#' logger$debug("Variable x = 5")
#'
#' @export
logger_factory <- function(prefix) {
  # Validate input
  if (!is.character(prefix) || length(prefix) != 1L) {
    stop("prefix must be a single character string", call. = FALSE)
  }

  # Only apply ANSI color codes when outputting to an interactive terminal
  use_color <- isatty(stderr())

  colorize <- function(text, code) {
    if (use_color) paste0("\033[", code, "m", text, "\033[0m") else text
  }

  fmt_prefix <- paste0(" ", if (use_color) paste0("\033[4m", prefix, "\033[0m") else prefix)

  fmt_msg <- function(level, color_code, msg) {
    paste0(colorize(level, color_code), fmt_prefix, ": ", msg)
  }

  # Return list of logging methods
  structure(
    list(
      info = function(msg) message(fmt_msg("[INFO]", 34, msg)),
      warn = function(msg) message(fmt_msg("[WARN]", 33, msg)),
      error = function(msg) stop("\n", fmt_msg("[ERROR]", 31, msg), call. = FALSE),
      debug = function(msg) {
        if (isTRUE(getOption("logger.debug", FALSE))) {
          message(fmt_msg("[DEBUG]", 90, msg))
        }
      }
    ),
    class = "logger"
  )
}
