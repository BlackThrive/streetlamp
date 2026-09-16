# Classed conditions
#
# All errors and warnings raised by streetlamp carry a package-specific class
# so that callers can handle them programmatically:
#
#   * errors:   c("streetlamp_error_<class>", "streetlamp_error", ...)
#   * warnings: c("streetlamp_warning_<class>", "streetlamp_warning", ...)
#
# Classes in use (extend the list as the package grows):
#   contract   the panel contract is missing, malformed or violated
#   coverage   force-months excluded or mismatched for coverage reasons
#   input      invalid user input
#   network    a network resource is unavailable
#   bundled    a bundled table failed to load or failed validation

lamp_abort <- function(message, class, ..., call = rlang::caller_env(),
                       .envir = parent.frame()) {
  cli::cli_abort(
    message,
    class = c(paste0("streetlamp_error_", class), "streetlamp_error"),
    ...,
    call = call,
    .envir = .envir
  )
}

lamp_warn <- function(message, class, ..., .envir = parent.frame()) {
  cli::cli_warn(
    message,
    class = c(paste0("streetlamp_warning_", class), "streetlamp_warning"),
    ...,
    .envir = .envir
  )
}

lamp_inform <- function(message, class = NULL, ..., .envir = parent.frame()) {
  cls <- c(
    if (!is.null(class)) paste0("streetlamp_message_", class),
    "streetlamp_message"
  )
  cli::cli_inform(message, class = cls, ..., .envir = .envir)
}

# Small argument checkers -----------------------------------------------------

check_string <- function(x, arg = rlang::caller_arg(x),
                         call = rlang::caller_env()) {
  if (!rlang::is_string(x)) {
    lamp_abort("{.arg {arg}} must be a single string.", "input", call = call)
  }
  invisible(x)
}

check_bool <- function(x, arg = rlang::caller_arg(x),
                       call = rlang::caller_env()) {
  if (!rlang::is_bool(x)) {
    lamp_abort("{.arg {arg}} must be `TRUE` or `FALSE`.", "input", call = call)
  }
  invisible(x)
}
