#' Location of the streetlamp cache
#'
#' Downloaded archive files, boundaries and lookups are cached on disk so that
#' each is fetched once. By default the cache is a directory inside the
#' session's temporary directory: it is deleted when R closes, and nothing is
#' written to your file space.
#'
#' To keep downloads between sessions, which is worth doing before building a
#' national panel of several gigabytes, choose a directory and set it with the
#' option `streetlamp.cache_dir` or the environment variable
#' `STREETLAMP_CACHE_DIR` (the option wins). The conventional place is the
#' user cache directory, for example in `.Rprofile`:
#'
#' ```
#' options(streetlamp.cache_dir = tools::R_user_dir("streetlamp", "cache"))
#' ```
#'
#' `lamp_cache_clear()` deletes the cache, or one sub-directory of it.
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
    # CRAN policy: nothing is written outside the session's temporary
    # directory unless the user has chosen a location
    dir <- file.path(tempdir(), "streetlamp-cache")
    lamp_inform(
      c(
        "Caching downloads for this session only.",
        "i" = paste(
          "To keep them between sessions, set the {.code streetlamp.cache_dir}",
          "option or {.envvar STREETLAMP_CACHE_DIR}; see {.fun lamp_cache_dir}."
        )
      ),
      class = "cache",
      .frequency = "once",
      .frequency_id = "streetlamp_session_cache"
    )
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
