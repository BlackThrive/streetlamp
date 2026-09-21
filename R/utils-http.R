# HTTP layer -------------------------------------------------------------------
#
# All network access goes through these helpers so that tests can mock them
# (with testthat::local_mocked_bindings()) and so that every failure surfaces
# as a classed `streetlamp_error_network` condition with a plain message.
# Setting the environment variable STREETLAMP_OFFLINE=true makes every network
# call fail immediately, which is how CI guarantees that checks, tests and
# examples never touch the network.

lamp_offline <- function() {
  isTRUE(as.logical(Sys.getenv("STREETLAMP_OFFLINE", unset = "false")))
}

lamp_user_agent <- function() {
  sprintf(
    "streetlamp/%s (https://github.com/Mustapha-Wasseja/streetlamp)",
    utils::packageVersion("streetlamp")
  )
}

# `retry_on_failure` is what makes this useful. Without it `req_retry()` only
# retries transient HTTP statuses, and a dropped connection ends the request.
# Building a national panel is several thousand byte-range requests against
# one host, where a reset partway through is ordinary rather than exceptional,
# and losing the whole run to one of them is not acceptable. Anything already
# fetched is cached, so a retry costs a few seconds, not the run.
lamp_request <- function(url) {
  httr2::request(url) |>
    httr2::req_user_agent(lamp_user_agent()) |>
    httr2::req_timeout(600) |>
    httr2::req_retry(
      max_tries = 5,
      retry_on_failure = TRUE,
      backoff = function(i) min(2^i, 30)
    )
}

lamp_perform <- function(req, what, call = rlang::caller_env()) {
  if (lamp_offline()) {
    lamp_abort(
      c(
        "Network access is disabled by {.envvar STREETLAMP_OFFLINE}.",
        "i" = "Could not fetch {what}."
      ),
      "network",
      call = call
    )
  }
  rlang::try_fetch(
    httr2::req_perform(req),
    error = function(e) {
      lamp_abort(
        c(
          "Could not fetch {what}.",
          "i" = "Check the connection and try again; anything already cached is still usable."
        ),
        "network",
        call = call,
        parent = e
      )
    }
  )
}

# HEAD request: final URL (after redirects), size and validators.
lamp_http_head <- function(url, call = rlang::caller_env()) {
  req <- httr2::req_method(lamp_request(url), "HEAD")
  resp <- lamp_perform(req, what = paste0("the headers of ", url), call = call)
  list(
    url = resp$url,
    size = as.numeric(httr2::resp_header(resp, "content-length", NA)),
    etag = httr2::resp_header(resp, "etag", NA_character_),
    last_modified = httr2::resp_header(resp, "last-modified", NA_character_),
    accept_ranges = httr2::resp_header(resp, "accept-ranges", NA_character_)
  )
}

# Byte-range GET: bytes `from` to `to` inclusive (zero-based).
lamp_http_range <- function(url, from, to, call = rlang::caller_env()) {
  req <- httr2::req_headers(
    lamp_request(url),
    Range = sprintf("bytes=%.0f-%.0f", from, to)
  )
  what <- sprintf("bytes %.0f to %.0f of %s", from, to, url)
  resp <- lamp_perform(req, what = what, call = call)
  if (httr2::resp_status(resp) != 206L) {
    lamp_abort(
      c(
        "The server did not honour a byte-range request for {.url {url}}.",
        "i" = "Status {httr2::resp_status(resp)}; the archive cannot be read selectively."
      ),
      "network",
      call = call
    )
  }
  body <- httr2::resp_body_raw(resp)
  expected <- to - from + 1
  if (length(body) != expected) {
    lamp_abort(
      "Range response held {length(body)} bytes but {expected} were expected.",
      "network",
      call = call
    )
  }
  body
}

# Plain GET returning the body as a single string.
lamp_http_get_text <- function(url, call = rlang::caller_env()) {
  resp <- lamp_perform(lamp_request(url), what = url, call = call)
  httr2::resp_body_string(resp)
}
