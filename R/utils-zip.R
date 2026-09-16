# Zip reading without external tools --------------------------------------------
#
# The data.police.uk archives are zip files of 1 to 2.5 GB. A zip file keeps
# its table of contents (the "central directory") at the end, so listing the
# members needs only the last few hundred kilobytes, and any single member can
# then be read on its own from its recorded offset. Both operations work on a
# local file or, through HTTP byte-range requests, on the remote archive, so a
# handful of force-month files can be fetched without downloading gigabytes.
#
# Members are DEFLATE-compressed. They are inflated by wrapping the raw stream
# in a gzip envelope built from the sizes and CRC recorded in the directory and
# calling memDecompress(), which also verifies the CRC.

zip_sig_local <- as.raw(c(0x50, 0x4b, 0x03, 0x04))
zip_sig_central <- as.raw(c(0x50, 0x4b, 0x01, 0x02))
zip_sig_eocd <- as.raw(c(0x50, 0x4b, 0x05, 0x06))
zip_sig_eocd64_locator <- as.raw(c(0x50, 0x4b, 0x06, 0x07))
zip_sig_eocd64 <- as.raw(c(0x50, 0x4b, 0x06, 0x06))

zip_u16 <- function(b, i) as.numeric(b[i]) + 256 * as.numeric(b[i + 1])
zip_u32 <- function(b, i) sum(as.numeric(b[i:(i + 3)]) * 256^(0:3))
zip_u64 <- function(b, i) sum(as.numeric(b[i:(i + 7)]) * 256^(0:7))

zip_hex32 <- function(x) {
  bytes <- as.integer((x %/% 256^(3:0)) %% 256)
  paste0(sprintf("%02x", bytes), collapse = "")
}

zip_le_bytes <- function(x, n) {
  as.raw(as.integer((x %/% 256^(0:(n - 1))) %% 256))
}

# Position of the last occurrence of a 4-byte signature, or NA.
zip_find_sig <- function(b, sig) {
  n <- length(b)
  if (n < 4) {
    return(NA_integer_)
  }
  idx <- seq_len(n - 3)
  match_all <- b[idx] == sig[1] & b[idx + 1] == sig[2]
  match_all <- match_all & b[idx + 2] == sig[3] & b[idx + 3] == sig[4]
  hits <- idx[match_all]
  if (length(hits) == 0) NA_integer_ else max(hits)
}

zip_dos_datetime <- function(ddate, dtime) {
  ISOdatetime(
    1980 + bitwShiftR(ddate, 9), bitwAnd(bitwShiftR(ddate, 5), 15),
    bitwAnd(ddate, 31), bitwShiftR(dtime, 11),
    bitwAnd(bitwShiftR(dtime, 5), 63), 2 * bitwAnd(dtime, 31),
    tz = "UTC"
  )
}

# A byte source: a local zip file or a remote URL supporting byte ranges.
lamp_zip_source <- function(x, call = rlang::caller_env()) {
  check_string(x, call = call)
  if (grepl("^https?://", x)) {
    head <- lamp_http_head(x, call = call)
    if (is.na(head$size)) {
      lamp_abort(
        "The server gave no size for {.url {x}}, so it cannot be read by range.",
        "network",
        call = call
      )
    }
    url <- head$url
    return(list(
      kind = "remote", path = url, size = head$size, etag = head$etag,
      last_modified = head$last_modified,
      read = function(from, to) lamp_http_range(url, from, to)
    ))
  }
  if (!file.exists(x)) {
    lamp_abort("Archive file {.path {x}} does not exist.", "input", call = call)
  }
  path <- normalizePath(x, winslash = "/")
  list(
    kind = "local", path = path, size = file.size(path), etag = NA_character_,
    last_modified = format(file.mtime(path), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    read = function(from, to) {
      con <- file(path, open = "rb")
      on.exit(close(con))
      seek(con, where = from, origin = "start")
      readBin(con, what = "raw", n = to - from + 1)
    }
  )
}

# List the members of a zip source: one row per member with its offset, sizes
# and CRC32, exactly as recorded in the central directory.
lamp_zip_directory <- function(source, call = rlang::caller_env()) {
  size <- source$size
  tail_len <- min(size, 66000)
  tail <- source$read(size - tail_len, size - 1)
  e <- zip_find_sig(tail, zip_sig_eocd)
  if (is.na(e)) {
    lamp_abort(
      "{.path {source$path}} is not a zip file (no end-of-directory record).",
      "input",
      call = call
    )
  }
  n_entries <- zip_u16(tail, e + 10)
  cd_size <- zip_u32(tail, e + 12)
  cd_off <- zip_u32(tail, e + 16)
  zip64 <- n_entries == 65535 || cd_size == 4294967295 || cd_off == 4294967295
  if (zip64) {
    l <- zip_find_sig(tail, zip_sig_eocd64_locator)
    if (is.na(l)) {
      lamp_abort("ZIP64 locator missing in {.path {source$path}}.", "input", call = call)
    }
    z64_off <- zip_u64(tail, l + 8)
    rec <- source$read(z64_off, z64_off + 55)
    if (!identical(rec[1:4], zip_sig_eocd64)) {
      lamp_abort("ZIP64 directory record malformed in {.path {source$path}}.", "input", call = call)
    }
    n_entries <- zip_u64(rec, 33)
    cd_size <- zip_u64(rec, 41)
    cd_off <- zip_u64(rec, 49)
  }
  cd <- source$read(cd_off, cd_off + cd_size - 1)

  member <- character(n_entries)
  method <- numeric(n_entries)
  crc32 <- character(n_entries)
  csize <- numeric(n_entries)
  usize <- numeric(n_entries)
  offset <- numeric(n_entries)
  mtime <- rep(as.POSIXct(NA, tz = "UTC"), n_entries)
  p <- 1
  for (k in seq_len(n_entries)) {
    if (!identical(cd[p:(p + 3)], zip_sig_central)) {
      lamp_abort("Central directory malformed in {.path {source$path}}.", "input", call = call)
    }
    method[k] <- zip_u16(cd, p + 10)
    dtime <- zip_u16(cd, p + 12)
    ddate <- zip_u16(cd, p + 14)
    crc32[k] <- zip_hex32(zip_u32(cd, p + 16))
    cs <- zip_u32(cd, p + 20)
    us <- zip_u32(cd, p + 24)
    nlen <- zip_u16(cd, p + 28)
    xlen <- zip_u16(cd, p + 30)
    clen <- zip_u16(cd, p + 32)
    off <- zip_u32(cd, p + 42)
    member[k] <- rawToChar(cd[(p + 46):(p + 45 + nlen)])
    if (any(c(us, cs, off) == 4294967295) && xlen >= 4) {
      extra <- cd[(p + 46 + nlen):(p + 45 + nlen + xlen)]
      q <- 1
      while (q + 3 <= length(extra)) {
        id <- zip_u16(extra, q)
        sz <- zip_u16(extra, q + 2)
        r <- q + 4
        if (id == 1) {
          if (us == 4294967295) {
            us <- zip_u64(extra, r)
            r <- r + 8
          }
          if (cs == 4294967295) {
            cs <- zip_u64(extra, r)
            r <- r + 8
          }
          if (off == 4294967295) {
            off <- zip_u64(extra, r)
          }
          break
        }
        q <- q + 4 + sz
      }
    }
    csize[k] <- cs
    usize[k] <- us
    offset[k] <- off
    mtime[k] <- zip_dos_datetime(ddate, dtime)
    p <- p + 46 + nlen + xlen + clen
  }
  Encoding(member) <- "UTF-8"
  tibble::tibble(
    member = member, method = method, crc32 = crc32, csize = csize,
    usize = usize, offset = offset, mtime = mtime
  )
}

# Read one member and return its uncompressed bytes.
lamp_zip_extract <- function(source, entry, call = rlang::caller_env()) {
  if (nrow(entry) != 1L) {
    lamp_abort("{.arg entry} must be a single directory row.", "input", call = call)
  }
  hdr <- source$read(entry$offset, entry$offset + 29)
  if (!identical(hdr[1:4], zip_sig_local)) {
    lamp_abort(
      "Local header for {.file {entry$member}} not found at its recorded offset.",
      "input",
      call = call
    )
  }
  nlen <- zip_u16(hdr, 27)
  xlen <- zip_u16(hdr, 29)
  start <- entry$offset + 30 + nlen + xlen
  if (entry$csize == 0) {
    return(raw(0))
  }
  data <- source$read(start, start + entry$csize - 1)
  if (entry$method == 0) {
    return(data)
  }
  if (entry$method != 8) {
    lamp_abort(
      "{.file {entry$member}} uses compression method {entry$method}; only DEFLATE is supported.",
      "input",
      call = call
    )
  }
  crc <- strtoi(substring(entry$crc32, c(1, 3, 5, 7), c(2, 4, 6, 8)), 16L)
  gz <- c(
    as.raw(c(0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff)),
    data,
    as.raw(rev(crc)),
    zip_le_bytes(entry$usize %% 2^32, 4)
  )
  out <- rlang::try_fetch(
    memDecompress(gz, type = "gzip"),
    error = function(e) {
      lamp_abort(
        c(
          "{.file {entry$member}} failed to decompress or its checksum did not match.",
          "i" = "The archive may have changed since it was listed; list it again."
        ),
        "input",
        call = call,
        parent = e
      )
    }
  )
  if (length(out) != entry$usize) {
    lamp_abort(
      "{.file {entry$member}} inflated to {length(out)} bytes, expected {entry$usize}.",
      "input",
      call = call
    )
  }
  out
}
