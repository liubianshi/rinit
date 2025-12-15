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
#'     \item \code{warning}: Logs warning messages
#'     \item \code{error}: Logs error messages and stops execution
#'     \item \code{debug}: Logs debug messages (only if logger.debug option is TRUE)
#'   }
#'
#' @examples
#' logger <- logger_factory("MyApp")
#' logger$info("Application started")
#' logger$warning("Low memory")
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

  # Pre-format prefix for efficiency
  prefix_fmt <- paste0(" l033[4m", prefix, "\033[0m")

  # Return list of logging methods
  structure(
    list(
      info = function(msg) {
        message("\033[34m[INFO]", prefix_fmt, ": \033[0m", msg)
      },
      warn = function(msg) {
        warning("\033[33m[WARN]", prefix_fmt, ": \033[0m", msg, call. = FALSE)
      },
      error = function(msg) {
        stop("\n\033[31m[ERROR]", prefix_fmt, ": \033[0m", msg, call. = FALSE)
      },
      debug = function(msg) {
        if (isTRUE(getOption("logger.debug", FALSE))) {
          message("\033[90m[DEBUG]", prefix_fmt, ": \033[0m", msg)
        }
      }
    ),
    class = "logger"
  )
}
