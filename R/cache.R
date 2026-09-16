#' Location of the streetlamp cache
#'
#' Downloaded archive snapshots, boundaries and lookups are cached on disk so
#' that they are fetched at most once. The cache lives under
#' `tools::R_user_dir("streetlamp", "cache")` unless overridden by the option
#' `streetlamp.cache_dir` or the environment variable `STREETLAMP_CACHE_DIR`
#' (the option wins). Tests and examples never write to the default location.
#'
#' @param create Create the directory if it does not exist? Default `TRUE`.
#'
#' @return The cache directory path, invisibly for `lamp_cache_clear()`.
#' @family cache
#' @export
#' @examples
#' # Point the cache at a temporary directory for the duration of the example
#' old <- options(streetlamp.cache_dir = tempfile("streetlamp-cache-"))
#' lamp_cache_dir()
#' lamp_cache_clear()
#' options(old)
lamp_cache_dir <- function(create = TRUE) {
  check_bool(create)
  dir <- getOption("streetlamp.cache_dir", NULL)
  if (is.null(dir) || !nzchar(dir)) {
    dir <- Sys.getenv("STREETLAMP_CACHE_DIR", unset = "")
  }
  if (!nzchar(dir)) {
    dir <- tools::R_user_dir("streetlamp", which = "cache")
  }
  check_string(dir, arg = "streetlamp.cache_dir")
  if (create && !dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }
  dir
}

#' @rdname lamp_cache_dir
#' @param subdir Optional sub-directory to clear instead of the whole cache,
#'   for example `"archive"`.
#' @export
lamp_cache_clear <- function(subdir = NULL) {
  dir <- lamp_cache_dir(create = FALSE)
  if (!is.null(subdir)) {
    check_string(subdir)
    dir <- file.path(dir, subdir)
  }
  if (dir.exists(dir)) {
    n <- length(list.files(dir,
      recursive = TRUE, all.files = TRUE,
      no.. = TRUE
    ))
    unlink(dir, recursive = TRUE, force = TRUE)
    lamp_inform("Cleared {n} file{?s} from {.path {dir}}.", class = "cache")
  } else {
    lamp_inform("Nothing to clear at {.path {dir}}.", class = "cache")
  }
  invisible(dir)
}
