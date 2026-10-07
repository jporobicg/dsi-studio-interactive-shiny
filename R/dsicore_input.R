## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ DSI Core: input layout, column and effort    ~ ##
## ~ detection                                    ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

## Names (after normalize_column_name()) that identify each role. Order
## matters: earlier entries win when two columns match the same role.
dsi_role_synonyms <- function() {
  list(
    year = c("year", "yr", "years", "ano", "anio", "annee", "anno", "jahr", "season",
             "fishing_year", "calendar_year", "fishing_season", "year_of_catch"),
    species = c("species", "sp", "spp", "especie", "especies", "espece", "taxon", "taxa",
                "species_name", "common_name", "scientific_name", "sci_name", "species_group",
                "group", "groups", "grupo", "stock"),
    fleet = c("fleet", "gear", "metier", "arte", "flota", "fleet_segment", "gear_type",
              "gear_group", "aparejo", "engin", "flottille", "segment", "fishery", "vessel_type"),
    catch = c("catch", "catches", "landings", "landing", "yield", "captura", "capturas",
              "desembarque", "desembarques", "captures", "capture", "prises", "harvest",
              "total_catch", "catch_weight", "nominal_catch", "retained_catch", "total_landings"),
    effort = c("effort", "esfuerzo", "fishing_effort", "nominal_effort", "total_effort",
               "effort_days", "effort_hours", "effort_trips", "effort_std", "effort_units",
               "days_fished", "fishing_days", "days_at_sea", "vessel_days", "boat_days", "kw_days",
               "trips", "n_trips", "number_of_trips", "hours", "fishing_hours", "hours_fished",
               "hooks", "sets", "hauls", "days"),
    cpue = c("cpue", "cpua", "lpue", "catch_rate", "catch_per_unit_effort", "catch_per_effort",
             "landings_per_unit_effort", "cpue_index", "cpue_std", "standardised_cpue",
             "standardized_cpue", "nominal_cpue", "abundance_index", "relative_abundance",
             "index", "indice", "abundance")
  )
}

## Trailing tokens dropped from names: units and id suffixes
dsi_name_suffixes <- c("t", "tonnes", "tonne", "tons", "ton", "mt", "kg", "kgs", "g", "lb", "lbs",
                       "code", "cd", "id", "value", "val", "raw", "num")

## Tokens that make a loose catch/effort match unsafe (rates, indices, the other role)
dsi_loose_block <- list(
  catch = c("rate", "per", "cpue", "cpua", "lpue", "index", "effort", "esfuerzo", "unit"),
  effort = c("rate", "per", "cpue", "cpua", "lpue", "index", "catch", "landings", "yield", "captura", "unit"),
  year = c("catch", "effort", "cpue"),
  cpue = character(0), species = character(0), fleet = character(0)
)

#' Normalise column names for matching
#'
#' Lower-cases, removes accents, drops text in brackets or parentheses
#' (usually units), turns punctuation and spaces into underscores and drops
#' trailing unit or id tokens such as `_t`, `_tonnes`, `_kg`, `_code`, `_id`.
#'
#' @param x Character vector of column names
#' @return Character vector of normalised names, e.g. `"Catch (t)"` -> `"catch"`
#' @export
#' @examples
#' normalize_column_name(c("Catch (t)", "gear_code", "A\u00f1o", "CPUE [kg/day]"))
normalize_column_name <- function(x) {
  x <- enc2utf8(as.character(x))
  x[is.na(x)] <- ""
  x <- chartr("\u00e1\u00e0\u00e2\u00e4\u00e3\u00e5\u00e9\u00e8\u00ea\u00eb\u00ed\u00ec\u00ee\u00ef\u00f3\u00f2\u00f4\u00f6\u00f5\u00fa\u00f9\u00fb\u00fc\u00f1\u00e7\u00c1\u00c0\u00c2\u00c4\u00c3\u00c5\u00c9\u00c8\u00ca\u00cb\u00cd\u00cc\u00ce\u00cf\u00d3\u00d2\u00d4\u00d6\u00d5\u00da\u00d9\u00db\u00dc\u00d1\u00c7",
              "aaaaaaeeeeiiiiooooouuuuncAAAAAAEEEEIIIIOOOOOUUUUNC", x)
  y <- suppressWarnings(iconv(x, "UTF-8", "ASCII//TRANSLIT", sub = ""))
  y[is.na(y)] <- x[is.na(y)]
  y <- tolower(y)
  y <- gsub("\\([^)]*\\)|\\[[^]]*\\]|\\{[^}]*\\}", " ", y)
  y <- gsub("[^a-z0-9]+", " ", y)
  tok <- strsplit(trimws(y), " +")
  vapply(tok, function(t) {
    t <- t[nzchar(t)]
    while (length(t) > 1 && t[length(t)] %in% dsi_name_suffixes) t <- t[-length(t)]
    paste(t, collapse = "_")
  }, character(1))
}

## Is `needle` (token vector) a contiguous run inside `hay`?
.contains_tokens <- function(hay, needle) {
  n <- length(needle); h <- length(hay)
  if (n == 0 || n > h) return(FALSE)
  for (i in seq_len(h - n + 1)) if (all(hay[i:(i + n - 1)] == needle)) return(TRUE)
  FALSE
}

#' Score how well a normalised name fits a role
#'
#' Scores in (3, 4] = exact synonym, (2, 3] = synonym found as whole word(s)
#' in a longer name, 0 = no match. The decimals rank synonyms (earlier is
#' better).
#' @param norm Normalised name (one string)
#' @param role One of year, species, fleet, catch, effort, cpue
#' @return Numeric score
#' @keywords internal
role_name_score <- function(norm, role) {
  syn <- dsi_role_synonyms()[[role]]
  if (!nzchar(norm)) return(0)
  i <- match(norm, syn)
  if (!is.na(i)) return(4 - i / 1000)
  tok <- strsplit(norm, "_", fixed = TRUE)[[1]]
  if (role == "cpue" && any(tok %in% c("per", "rate")) &&
      any(tok %in% c("catch", "catches", "landings", "yield", "captura"))) return(2.9)
  if (any(tok %in% dsi_loose_block[[role]])) return(0)
  ## a word of another numeric role in the name makes it ambiguous
  others <- setdiff(c("year", "catch", "effort", "cpue"), role)
  other_words <- unlist(lapply(dsi_role_synonyms()[others], function(s) s[!grepl("_", s) & nchar(s) > 3]))
  if (any(tok %in% other_words)) return(0)
  for (k in seq_along(syn)) {
    st <- strsplit(syn[k], "_", fixed = TRUE)[[1]]
    if (sum(nchar(st)) < 3) next
    if (.contains_tokens(tok, st)) return(3 - k / 1000)
  }
  0
}

## Share of non-missing values that parse as numbers
.numeric_share <- function(v) {
  if (is.numeric(v)) return(1)
  v <- as.character(v)
  ok <- !is.na(v) & nzchar(trimws(v))
  if (!any(ok)) return(0)
  mean(is.finite(suppressWarnings(as.numeric(gsub(",", "", v[ok])))))
}

.looks_like_years <- function(v) {
  y <- suppressWarnings(as.numeric(v))
  y <- y[is.finite(y)]
  length(y) > 0 && all(abs(y - round(y)) < 1e-8) && all(y >= 1800 & y <= 2200)
}

#' Match table columns to DSI roles
#'
#' Loose, name-based matching of columns to the roles year, species, fleet,
#' catch, effort and CPUE. Names are normalised with
#' [normalize_column_name()] and compared with a list of synonyms (English,
#' Spanish, French). When data are given, numeric roles must hold numbers and
#' the year must look like years; a column of years with an unrecognised name
#' is used as year with low confidence.
#'
#' @param df Data frame, or a character vector of column names
#' @return List with `map` (role -> column name), `confidence` (role ->
#'   "name", "partial" or "data"), `alternatives` (role -> other columns
#'   that matched equally well) and `confident` (TRUE when year, catch and
#'   effort were all matched by name without ambiguity)
#' @export
#' @examples
#' match_columns(c("Year", "Gear_code", "Species", "Landings (t)", "Days fished", "CPUE"))$map
match_columns <- function(df) {
  cols <- if (is.data.frame(df)) names(df) else as.character(df)
  roles <- c("year", "cpue", "catch", "effort", "species", "fleet")
  norm <- normalize_column_name(cols)
  sc <- matrix(0, nrow = length(cols), ncol = length(roles), dimnames = list(cols, roles))
  for (i in seq_along(cols)) for (r in roles) sc[i, r] <- role_name_score(norm[i], r)
  if (is.data.frame(df) && length(cols)) {
    for (i in seq_along(cols)) {
      v <- df[[i]]
      num <- .numeric_share(v) >= 0.9
      for (r in c("year", "catch", "effort", "cpue")) if (!num) sc[i, r] <- 0
      if (sc[i, "year"] > 0 && !.looks_like_years(v)) sc[i, "year"] <- 0
    }
  }
  map <- list(); conf <- character(0); alts <- list()
  s <- sc
  while (length(s) && max(s) > 0) {
    best <- which(s == max(s), arr.ind = TRUE)[1, ]
    col <- rownames(s)[best[1]]; role <- colnames(s)[best[2]]; val <- s[best[1], best[2]]
    map[[role]] <- col
    conf[[role]] <- if (val > 3) "name" else "partial"
    same_band <- rownames(s)[ceiling(s[, role]) == ceiling(val) & s[, role] > 0 & rownames(s) != col]
    if (length(same_band)) alts[[role]] <- same_band
    s <- s[-best[1], -best[2], drop = FALSE]
  }
  ## a column full of years with an unknown name
  if (is.null(map$year) && is.data.frame(df)) {
    free <- setdiff(cols, unlist(map))
    cand <- free[vapply(free, function(cn) .numeric_share(df[[cn]]) >= 0.9 && .looks_like_years(df[[cn]]) &&
                                           length(unique(stats::na.omit(df[[cn]]))) > 1, logical(1))]
    if (length(cand)) { map$year <- cand[1]; conf[["year"]] <- "data" }
  }
  ## a date column when there is no year
  if (is.null(map$year)) {
    d <- cols[norm %in% c("date", "fecha", "datum")]
    if (length(d)) map$date <- d[1]
  }
  ord <- c("year", "date", "species", "fleet", "catch", "effort", "cpue")
  map <- map[intersect(ord, names(map))]
  req <- c("year", "catch", "effort")
  confident <- all(req %in% names(map)) && all(conf[req] == "name") && !any(req %in% names(alts))
  list(map = map, confidence = conf, alternatives = alts, confident = confident)
}

## ---- Layout detection and reshaping ----

.is_year_name <- function(x) grepl("^[Xx]?(18|19|20|21)[0-9]{2}(\\.0)?$", trimws(x))
.year_from_name <- function(x) as.integer(sub("^[Xx]?([0-9]{4}).*$", "\\1", trimws(x)))

## Role (catch/effort/cpue) named by a label, or NA
.value_role_of <- function(label) {
  n <- normalize_column_name(label)
  sc <- vapply(c("catch", "effort", "cpue"), function(r) role_name_score(n, r), numeric(1))
  if (max(sc) > 2) names(sc)[which.max(sc)] else NA_character_
}

## Split "Anchovy catch (t)" style names into group + role
.split_group_role <- function(name) {
  tok <- strsplit(normalize_column_name(name), "_", fixed = TRUE)[[1]]
  syn <- dsi_role_synonyms()
  for (r in c("cpue", "catch", "effort")) {
    words <- syn[[r]][!grepl("_", syn[[r]]) & nchar(syn[[r]]) > 3]
    if (r == "cpue") words <- c("cpue", "cpua", "lpue")
    hit <- which(tok %in% words)
    if (length(hit) == 1 && length(tok) > 1) {
      raw <- trimws(gsub("\\([^)]*\\)|\\[[^]]*\\]", "", name))
      parts <- strsplit(raw, "[^[:alnum:]]+")[[1]]
      parts <- parts[nzchar(parts)]
      keep <- parts[!normalize_column_name(parts) %in% c(words, dsi_name_suffixes, "")]
      grp <- if (length(keep)) paste(keep, collapse = " ") else paste(tok[-hit], collapse = " ")
      return(list(group = grp, role = r))
    }
  }
  NULL
}

.first_non_na <- function(v) { v <- v[!is.na(v)]; if (length(v)) v[1] else NA }


## Two-row catch header: colnames = fleets (often repeating), first data row = species codes
.is_text_label <- function(x) {
  x <- trimws(as.character(x))
  if (!nzchar(x) || is.na(x)) return(FALSE)
  !is.finite(suppressWarnings(as.numeric(gsub(",", "", x))))
}

#' Does a table use a two-row fleet \u00d7 species catch header?
#'
#' After a normal read the fleet names are the column names (duplicates kept)
#' and the first data row holds species codes under each fleet.
#' @param df Data frame as read from file (`check.names = FALSE`)
#' @return TRUE when the table matches that layout
#' @keywords internal
.is_fleet_species_catch <- function(df) {
  if (nrow(df) < 2L || ncol(df) < 3L) return(FALSE)
  n <- ncol(df)
  fleets <- names(df)[-1L]
  if (any(!nzchar(fleets)) || any(.is_year_name(fleets))) return(FALSE)
  ## first data row = species labels (positional: colnames may duplicate)
  sp <- vapply(seq.int(2L, n), function(j) {
    x <- df[[j]][1L]
    if (length(x) == 0L || is.na(x)) "" else trimws(as.character(x))
  }, character(1))
  if (sum(nzchar(sp)) < 2L) return(FALSE)
  if (!all(vapply(sp[nzchar(sp)], .is_text_label, logical(1)))) return(FALSE)
  y0 <- df[[1L]][1L]
  y0_blank <- length(y0) == 0L || is.na(y0) || !nzchar(trimws(as.character(y0)))
  if (!y0_blank && .looks_like_years(y0)) return(FALSE)
  years <- df[[1L]][-1L]
  if (!.looks_like_years(years)) return(FALSE)
  TRUE
}

#' Detect the layout of an input table
#'
#' Recognises long tables (one row per year and group), a two-row fleet
#' \u00d7 species catch header, and two wide forms: years as rows with one
#' column per group, and years as column headers (1990, 1991, ...) with a
#' group column and optionally a variable column naming catch, effort or CPUE.
#'
#' @param df Data frame as read from file
#' @return List with `shape` ("long", "wide_fleet_species", "wide_years_rows"
#'   or "wide_years_cols") and details used by [reshape_to_long()]:
#'   `year_col`, `group_cols`, `value_cols`, `shared_cols`, `var_col`,
#'   `value_role` (guessed quantity of the values, or NA when the variable
#'   column or column names give it) and `value_role_certain`.
#' @export
detect_data_layout <- function(df) {
  df <- as.data.frame(df, stringsAsFactors = FALSE, check.names = FALSE)
  cols <- names(df)
  out <- list(shape = "long", year_col = NULL, group_cols = character(0), value_cols = character(0),
              shared_cols = character(0), var_col = NULL, compound = NULL,
              value_role = NA_character_, value_role_certain = TRUE)
  if (!length(cols) || !nrow(df)) return(out)

  ## two-row fleet \u00d7 species catch header (colnames = fleets, row 1 = species)
  if (.is_fleet_species_catch(df)) {
    out$shape <- "wide_fleet_species"
    out$year_col <- cols[1]
    out$value_cols <- cols[-1]
    out$group_cols <- c("fleet", "species")
    out$value_role <- "catch"
    out$value_role_certain <- TRUE
    return(out)
  }

  ## (c) years as column headers
  yc <- cols[.is_year_name(cols)]
  if (length(yc) >= 3) {
    yc <- yc[vapply(yc, function(cn) .numeric_share(df[[cn]]) >= 0.8, logical(1))]
    id <- setdiff(cols, yc)
    if (length(yc) >= 3 && length(id) >= 1) {
      var_col <- NULL
      for (cn in id) {
        vals <- unique(stats::na.omit(as.character(df[[cn]])))
        roles <- vapply(vals, .value_role_of, character(1))
        if (length(vals) >= 1 && length(vals) <= 6 && mean(!is.na(roles)) >= 0.5 &&
            sum(c("catch", "effort") %in% roles) >= 1) { var_col <- cn; break }
      }
      grp <- setdiff(id, var_col)
      grp <- grp[vapply(grp, function(cn) .numeric_share(df[[cn]]) < 0.9 ||
                                          length(unique(df[[cn]])) < nrow(df), logical(1))]
      out$shape <- "wide_years_cols"
      out$value_cols <- yc; out$group_cols <- grp; out$var_col <- var_col
      if (is.null(var_col)) {
        out$value_role <- "catch"; out$value_role_certain <- FALSE
      }
      return(out)
    }
  }

  ## (a) years as rows, one numeric column per group
  m <- match_columns(df)
  yr <- m$map$year
  if (is.null(yr)) return(out)
  rest <- setdiff(cols, yr)
  num <- rest[vapply(rest, function(cn) .numeric_share(df[[cn]]) >= 0.9, logical(1))]
  txt <- setdiff(rest, num)
  ## a text column with several values means groups are already in rows
  if (any(vapply(txt, function(cn) length(unique(stats::na.omit(df[[cn]]))) > 1, logical(1)))) return(out)
  if (anyDuplicated(df[[yr]][!is.na(df[[yr]])])) return(out)
  if (length(num) < 2) return(out)
  role_of <- vapply(num, .value_role_of, character(1))
  comp <- lapply(num, .split_group_role); names(comp) <- num
  is_comp <- !vapply(comp, is.null, logical(1))
  comp_groups <- unique(vapply(comp[is_comp], function(x) x$group, character(1)))
  if (sum(is_comp) >= 2 && length(comp_groups) >= 2) {
    out$shape <- "wide_years_rows"; out$year_col <- yr
    out$compound <- do.call(rbind, lapply(names(comp)[is_comp], function(cn)
      data.frame(column = cn, group = comp[[cn]]$group, role = comp[[cn]]$role, stringsAsFactors = FALSE)))
    out$value_cols <- names(comp)[is_comp]
    out$shared_cols <- num[!is_comp & !is.na(role_of)]
    return(out)
  }
  shared <- num[!is.na(role_of)]
  groups <- num[is.na(role_of)]
  have <- unique(stats::na.omit(role_of))
  if (all(c("catch", "effort") %in% have) || length(groups) < 2) return(out)
  missing_req <- setdiff(c("catch", "effort"), have)
  out$shape <- "wide_years_rows"; out$year_col <- yr
  out$value_cols <- groups; out$shared_cols <- shared
  out$value_role <- missing_req[1]
  out$value_role_certain <- length(missing_req) == 1
  out
}

#' Reshape a wide table to the long format used by DSI
#'
#' @param df Data frame as read from file
#' @param layout Result of [detect_data_layout()]
#' @param value_role Quantity held in the value cells when the table does not
#'   say ("catch", "effort" or "cpue"); defaults to `layout$value_role`
#' @return Long data frame with a `year` column, the group column(s)
#'   (`group` for years-as-rows tables) and one column per quantity. The
#'   attribute `reshape_note` describes what was done.
#' @export
reshape_to_long <- function(df, layout = detect_data_layout(df), value_role = NULL) {
  df <- as.data.frame(df, stringsAsFactors = FALSE, check.names = FALSE)
  if (identical(layout$shape, "long")) { attr(df, "reshape_note") <- NULL; return(df) }
  value_role <- value_role %||% layout$value_role
  if (is.na(value_role %||% NA)) value_role <- "catch"
  num <- function(v) suppressWarnings(as.numeric(if (is.numeric(v)) v else gsub(",", "", as.character(v))))

  if (layout$shape == "wide_fleet_species") {
    fleets <- names(df)[-1L]
    species <- vapply(seq_along(fleets) + 1L, function(j) {
      x <- df[[j]][1L]
      if (length(x) == 0L || is.na(x)) NA_character_ else trimws(as.character(x))
    }, character(1))
    years <- as.integer(num(df[[1L]][-1L]))
    parts <- lapply(seq_along(fleets), function(i) {
      data.frame(year = years, fleet = fleets[i], species = species[i],
                 catch = num(df[[i + 1L]][-1L]), stringsAsFactors = FALSE)
    })
    long <- as.data.frame(dplyr::bind_rows(parts), stringsAsFactors = FALSE)
    long <- long[is.finite(long$year), , drop = FALSE]
    rownames(long) <- NULL
    n_series <- nrow(unique(long[, c("fleet", "species"), drop = FALSE]))
    note <- sprintf("Reshaped from fleet \u00d7 species header: %d series \u00d7 %d years",
                    n_series, length(unique(years[is.finite(years)])))
    attr(long, "reshape_note") <- note
    return(long)
  }

  if (layout$shape == "wide_years_cols") {
    id <- c(layout$group_cols, layout$var_col)
    long <- tidyr::pivot_longer(df[, c(id, layout$value_cols), drop = FALSE], cols = dplyr::all_of(layout$value_cols),
                                names_to = "year", values_to = "value", values_transform = list(value = as.character))
    long$year <- .year_from_name(long$year)
    long$value <- num(long$value)
    if (!is.null(layout$var_col)) {
      long[[layout$var_col]] <- vapply(as.character(long[[layout$var_col]]), function(v) {
        r <- .value_role_of(v); if (is.na(r)) normalize_column_name(v) else r }, character(1))
      long <- tidyr::pivot_wider(long, names_from = dplyr::all_of(layout$var_col), values_from = "value",
                                 values_fn = .first_non_na)
    } else {
      names(long)[names(long) == "value"] <- value_role
    }
    long <- as.data.frame(long, stringsAsFactors = FALSE, check.names = FALSE)
    long <- long[, c("year", setdiff(names(long), "year")), drop = FALSE]
    ng <- if (length(layout$group_cols)) nrow(unique(df[, layout$group_cols, drop = FALSE])) else 1
    note <- sprintf("Reshaped from wide: %d %s \u00d7 %d years%s", ng, if (ng == 1) "group" else "groups",
                    length(layout$value_cols),
                    if (!is.null(layout$var_col)) sprintf(", quantities from '%s'", layout$var_col) else "")
  } else {
    yr <- layout$year_col
    base <- data.frame(year = as.integer(num(df[[yr]])), stringsAsFactors = FALSE)
    if (!is.null(layout$compound)) {
      cp <- layout$compound
      parts <- lapply(unique(cp$group), function(g) {
        d <- base; d$group <- g
        for (k in which(cp$group == g)) d[[cp$role[k]]] <- num(df[[cp$column[k]]])
        d
      })
      long <- dplyr::bind_rows(parts)
      ng <- length(unique(cp$group))
    } else {
      parts <- lapply(layout$value_cols, function(cn) {
        d <- base; d$group <- cn; d[[value_role]] <- num(df[[cn]]); d })
      long <- dplyr::bind_rows(parts)
      ng <- length(layout$value_cols)
    }
    for (cn in layout$shared_cols) {
      r <- .value_role_of(cn)
      nm <- if (!is.na(r) && !r %in% names(long)) r else cn
      long[[nm]] <- rep(num(df[[cn]]), times = ng)
    }
    long <- as.data.frame(long, stringsAsFactors = FALSE)
    note <- sprintf("Reshaped from wide: %d groups \u00d7 %d years", ng, length(unique(stats::na.omit(base$year))))
  }
  ## rows with no value at all (a group that starts later) carry nothing
  qty <- intersect(c("catch", "effort", "cpue"), names(long))
  if (length(qty)) {
    keep <- rowSums(!is.na(long[, qty, drop = FALSE])) > 0
    long <- long[keep, , drop = FALSE]; rownames(long) <- NULL
  }
  attr(long, "reshape_note") <- note
  long
}

## ---- Excel workbooks ----

#' Guess which quantity each workbook sheet holds from its name
#' @param sheets Sheet names
#' @return Named character vector (sheet -> "catch", "effort", "cpue" or NA)
#' @export
sheet_roles <- function(sheets) {
  stats::setNames(vapply(sheets, .value_role_of, character(1)), sheets)
}

## One sheet -> long table with year, group column(s) and a column named `role`
.sheet_to_long <- function(df, role) {
  lay <- detect_data_layout(df)
  if (lay$shape != "long") {
    if (identical(lay$shape, "wide_fleet_species")) {
      long <- reshape_to_long(df, lay)
      ## catch layout always yields catch; ignore role for the value column name
      keep <- intersect(names(long), c("year", "fleet", "species", "catch"))
      if (role != "catch" && "catch" %in% names(long)) {
        names(long)[names(long) == "catch"] <- role
        keep <- intersect(names(long), c("year", "fleet", "species", role))
      }
      return(list(data = long[, keep, drop = FALSE], note = attr(long, "reshape_note")))
    }
    if (!is.null(lay$var_col) || !is.null(lay$compound)) {
      long <- reshape_to_long(df, lay)
      keep <- intersect(names(long), c("year", lay$group_cols, "group", role))
      return(list(data = long[, keep, drop = FALSE], note = attr(long, "reshape_note")))
    }
    long <- reshape_to_long(df, lay, value_role = role)
    ## wide effort-by-fleet: prefer 'fleet' as the group column name
    if (role == "effort" && "group" %in% names(long) && !"fleet" %in% names(long))
      names(long)[names(long) == "group"] <- "fleet"
    keep <- intersect(names(long), c("year", lay$group_cols, "group", "fleet", role))
    return(list(data = long[, keep, drop = FALSE], note = attr(long, "reshape_note")))
  }
  m <- match_columns(df)
  if (is.null(m$map$year)) stop("No year column found in the ", role, " sheet")
  grp <- unlist(m$map[c("species", "fleet")], use.names = FALSE)
  val <- m$map[[role]]
  if (is.null(val)) {
    cand <- setdiff(names(df), c(m$map$year, grp))
    cand <- cand[vapply(cand, function(cn) .numeric_share(df[[cn]]) >= 0.9, logical(1))]
    if (length(cand) != 1) stop("Could not find the ", role, " column in its sheet")
    val <- cand
  }
  out <- data.frame(year = as.integer(df[[m$map$year]]), stringsAsFactors = FALSE)
  for (g in grp) out[[g]] <- as.character(df[[g]])
  out[[role]] <- suppressWarnings(as.numeric(df[[val]]))
  list(data = out, note = "long")
}

#' Combine catch, effort and CPUE sheets into one long table
#'
#' Each sheet may be long or wide. Sheets are joined by year and their shared
#' group columns, so a sheet without groups (one effort per year) or with a
#' fleet column only is spread over all matching rows.
#'
#' @param sheets Named list of data frames; names are roles ("catch",
#'   "effort", optional "cpue")
#' @param labels Optional sheet names for the note
#' @return Long data frame with attribute `reshape_note`
#' @export
combine_sheets <- function(sheets, labels = names(sheets)) {
  sheets <- sheets[!vapply(sheets, is.null, logical(1))]
  parts <- Map(function(d, r) .sheet_to_long(as.data.frame(d, check.names = FALSE), r), sheets, names(sheets))
  tabs <- lapply(parts, `[[`, "data")
  gcols <- lapply(tabs, function(t) setdiff(names(t), c("year", names(sheets))))
  ## align a single group column with different names (e.g. group vs species)
  ref <- gcols[[1]]
  if (length(ref) == 1) for (i in seq_along(tabs)[-1]) {
    if (length(gcols[[i]]) == 1 && gcols[[i]] != ref) names(tabs[[i]])[names(tabs[[i]]) == gcols[[i]]] <- ref
  }
  ## fleet \u00d7 species catch + fleet-level effort: rename group -> fleet when values match
  for (i in seq_along(tabs)) {
    gi <- setdiff(names(tabs[[i]]), c("year", names(sheets)))
    for (j in seq_along(tabs)) {
      if (i == j) next
      gj <- setdiff(names(tabs[[j]]), c("year", names(sheets)))
      if ("fleet" %in% gi && "group" %in% gj && !"fleet" %in% gj) {
        vals_i <- unique(stats::na.omit(as.character(tabs[[i]]$fleet)))
        vals_j <- unique(stats::na.omit(as.character(tabs[[j]]$group)))
        if (length(vals_j) && all(vals_j %in% vals_i))
          names(tabs[[j]])[names(tabs[[j]]) == "group"] <- "fleet"
      }
    }
  }
  out <- tabs[[1]]
  keys <- "year"
  for (i in seq_along(tabs)[-1]) {
    by <- intersect(setdiff(names(out), names(sheets)), setdiff(names(tabs[[i]]), names(sheets)))
    if (!"year" %in% by) stop("Sheet '", labels[i], "' has no year column to join on")
    keys <- union(keys, by)
    out <- if (length(setdiff(names(tabs[[i]]), by)) == 0) out else
      dplyr::left_join(out, tabs[[i]], by = by, relationship = "many-to-one", multiple = "first")
  }
  out <- as.data.frame(out, stringsAsFactors = FALSE)
  desc <- vapply(seq_along(parts), function(i) sprintf("'%s' (%s)", labels[i],
    if (identical(parts[[i]]$note, "long")) "long" else sub("^Reshaped from wide: ", "wide, ", parts[[i]]$note)), character(1))
  attr(out, "reshape_note") <- sprintf("Combined sheets %s by %s", paste(desc, collapse = " and "),
                                       paste(keys, collapse = " and "))
  out
}

## ---- Structure and effort level ----

.plural <- function(x) ifelse(grepl("s$", x), x, paste0(x, "s"))
.singular <- function(x) ifelse(grepl("(species|ss)$", x), x, sub("s$", "", x))
.role_label <- function(col, fallback) {
  if (is.null(col)) return(fallback)
  l <- gsub("_", " ", normalize_column_name(col))
  if (!nzchar(l)) fallback else l
}

#' Describe the structure of a mapped table
#'
#' @param df Data frame (as mapped)
#' @param map Column mapping (role -> column)
#' @return List with `structure` ("single", "groups", "fleets",
#'   "species_fleet"), counts, year range and a one-line `text`
#' @export
describe_structure <- function(df, map) {
  sp <- map$species; fl <- map$fleet
  yrs <- if (!is.null(map$year)) suppressWarnings(as.integer(df[[map$year]])) else integer(0)
  yrs <- yrs[!is.na(yrs)]
  span <- if (length(yrs)) sprintf("%d\u2013%d", min(yrs), max(yrs)) else "years unknown"
  nsp <- if (!is.null(sp)) length(unique(stats::na.omit(df[[sp]]))) else 0
  nfl <- if (!is.null(fl)) length(unique(stats::na.omit(df[[fl]]))) else 0
  if (nsp > 0 && nfl > 0) {
    ncomb <- nrow(unique(stats::na.omit(df[, c(sp, fl), drop = FALSE])))
    st <- "species_fleet"
    txt <- sprintf("%s \u00d7 %s: %d %s \u00d7 %d %s (%d series), %s", tools::toTitleCase(.role_label(sp, "species")),
                   .role_label(fl, "fleet"), nsp, .plural(.role_label(sp, "species")), nfl, .plural(.role_label(fl, "fleet")),
                   ncomb, span)
  } else if (nsp > 0 || nfl > 0) {
    col <- if (nsp > 0) sp else fl; n <- max(nsp, nfl)
    st <- if (nsp > 0) "groups" else "fleets"
    txt <- sprintf("%d %s, one series each, %s", n, if (n == 1) .role_label(col, "group") else .plural(.role_label(col, "group")), span)
  } else {
    st <- "single"; ncomb <- 1
    txt <- sprintf("Single series, %s", span)
  }
  list(structure = st, n_species = nsp, n_fleets = nfl, years = range(yrs), text = txt)
}

#' Detect at which level effort is recorded
#'
#' Checks whether effort is the same for all species within each fleet-year
#' (a fleet quantity), or for all groups within each year when there is no
#' fleet column, and suggests the matching effort semantics. A small share of
#' cells that differ is tolerated (`threshold`).
#'
#' @param df Standardised data (year, species, fleet, effort)
#' @param group_cols Grouping columns ("species", "fleet" or both)
#' @param labels Optional display names for species and fleet, e.g.
#'   `list(species = "species", fleet = "gear")`
#' @param tol Relative tolerance for equal effort values
#' @param threshold Share of cells with identical effort needed to treat
#'   effort as shared
#' @return List with `semantics`, `level` ("fleet_year", "year", "group_year"
#'   or "series"), cell counts, `n_filled`, `mixed` and a plain `message`
#' @export
detect_effort_level <- function(df, group_cols = c("species", "fleet"), labels = list(),
                                tol = 1e-6, threshold = 0.95) {
  has_sp <- "species" %in% group_cols; has_fl <- "fleet" %in% group_cols
  sp_lab <- .plural(labels$species %||% if (has_sp && !has_fl) "group" else "species")
  fl_lab <- labels$fleet %||% "fleet"
  res <- list(semantics = "per_group_year", level = "group_year", n_cells = 0L, n_const = 0L,
              n_filled = 0L, n_unfilled = 0L, n_missing = sum(!is.finite(df$effort)), mixed = FALSE,
              message = NULL)
  if (!has_sp || nrow(df) == 0) {
    res$level <- if (has_fl) "group_year" else "series"
    res$message <- if (has_fl) sprintf("Each %s has its own effort per year, used as given.", fl_lab)
                   else "Single series: effort is used as given."
    return(res)
  }
  cell <- if (has_fl) paste(df$year, df$fleet, sep = "\r") else as.character(df$year)
  fin <- is.finite(df$effort)
  st <- do.call(rbind, lapply(split(seq_len(nrow(df)), cell), function(ix) {
    e <- df$effort[ix][fin[ix]]
    data.frame(n = length(e), const = length(e) < 2 || (max(e) - min(e)) <= tol * max(abs(e), 1e-12),
               has_value = length(e) > 0, n_na = sum(!fin[ix]))
  }))
  multi <- st$n >= 2
  n_cells <- sum(multi); n_const <- sum(st$const[multi])
  res$n_cells <- n_cells; res$n_const <- n_const
  cell_word <- if (has_fl) paste0(fl_lab, "-year") else "year"
  if (n_cells == 0) {
    res$message <- sprintf("No %s has more than one %s with effort, so each keeps its own effort.",
                           cell_word, .singular(sp_lab))
    return(res)
  }
  frac <- n_const / n_cells
  if (frac >= threshold) {
    res$semantics <- "per_fleet_year"
    res$level <- if (has_fl) "fleet_year" else "year"
    res$n_filled <- sum(st$n_na[st$has_value])
    res$n_unfilled <- sum(st$n_na[!st$has_value])
    filled <- paste0(
      if (res$n_filled > 0) sprintf("; %d missing value%s filled", res$n_filled, if (res$n_filled == 1) "" else "s") else "",
      if (res$n_unfilled > 0) sprintf(". %d row%s no effort for %s %s", res$n_unfilled,
                                      if (res$n_unfilled == 1) " has" else "s have",
                                      if (res$n_unfilled == 1) "its" else "their", cell_word) else "")
    what <- if (has_fl) "fleet effort" else "one shared effort per year"
    res$message <- if (n_const == n_cells)
      sprintf("Effort is identical for all %s in each %s, so it is treated as %s%s.", sp_lab, cell_word, what, filled)
    else sprintf("Effort is identical for all %s in %d of %d %ss, so it is treated as %s (the %d others are averaged)%s.",
                 sp_lab, n_const, n_cells, cell_word, what, n_cells - n_const, filled)
    res$mixed <- n_const < n_cells
  } else {
    res$mixed <- n_const > 0.2 * n_cells
    res$message <- if (n_const == 0)
      sprintf("Effort differs between %s in every %s, so each %s keeps its own effort.", sp_lab, cell_word,
              if (has_fl) paste0(.singular(sp_lab), "-", fl_lab) else .singular(sp_lab))
    else sprintf("Effort is identical across %s in only %d of %d %ss, so each %s keeps its own effort. Check this below.",
                 sp_lab, n_const, n_cells, cell_word,
                 if (has_fl) paste0(.singular(sp_lab), "-", fl_lab) else .singular(sp_lab))
  }
  res
}

#' Read a delimited text file, guessing the delimiter
#'
#' Comma, semicolon and tab delimited files are accepted. With semicolons a
#' decimal comma is assumed.
#' @param path File path
#' @return Data frame
#' @keywords internal
read_table_file <- function(path) {
  first <- readLines(path, n = 5, warn = FALSE)
  cnt <- vapply(c(",", ";", "\t"), function(d) sum(lengths(regmatches(first, gregexpr(d, first, fixed = TRUE)))), numeric(1))
  delim <- names(cnt)[which.max(cnt)]
  loc <- if (delim == ";") readr::locale(decimal_mark = ",", grouping_mark = ".") else readr::default_locale()
  df <- readr::read_delim(path, delim = delim, locale = loc, show_col_types = FALSE, guess_max = 10000,
                          name_repair = "minimal", progress = FALSE)
  as.data.frame(df, stringsAsFactors = FALSE, check.names = FALSE)
}
