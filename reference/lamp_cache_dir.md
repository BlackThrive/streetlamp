# Location of the streetlamp cache

Downloaded archive snapshots, boundaries and lookups are cached on disk
so that they are fetched at most once. The cache lives under
`tools::R_user_dir("streetlamp", "cache")` unless overridden by the
option `streetlamp.cache_dir` or the environment variable
`STREETLAMP_CACHE_DIR` (the option wins). Tests and examples never write
to the default location.

## Usage

``` r
lamp_cache_dir(create = TRUE)

lamp_cache_clear(subdir = NULL)
```

## Arguments

- create:

  Create the directory if it does not exist? Default `TRUE`.

- subdir:

  Optional sub-directory to clear instead of the whole cache, for
  example `"archive"`.

## Value

The cache directory path, invisibly for `lamp_cache_clear()`.

## Examples

``` r
# Point the cache at a temporary directory for the duration of the example
old <- options(streetlamp.cache_dir = tempfile("streetlamp-cache-"))
lamp_cache_dir()
#> [1] "/tmp/RtmpCXBCb7/streetlamp-cache-1ddb44f3676b"
lamp_cache_clear()
#> Cleared 0 files from /tmp/RtmpCXBCb7/streetlamp-cache-1ddb44f3676b.
options(old)
```
