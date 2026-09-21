# Where validation runs put their downloads.
#
# Never inside the package directory: a national benchmark pulls several
# gigabytes, and the repository may sit in a synced folder. Set
# STREETLAMP_VALIDATION_CACHE to choose the location; otherwise the user cache
# directory is used.
lamp_validation_cache <- function(name) {
  root <- Sys.getenv("STREETLAMP_VALIDATION_CACHE", unset = "")
  if (!nzchar(root)) {
    root <- file.path(tools::R_user_dir("streetlamp", "cache"), "validation")
  }
  dir <- file.path(root, name)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  normalizePath(dir, winslash = "/")
}
