#' Extract genome-wide significant loci using a tiled scan
#'
#' @title Extract independent genome-wide significant loci via fixed-width tiles
#'
#' @description
#' Defines independent significant loci by binning the genome into fixed-width
#' tiles. Consecutive tiles that each contain at least one variant passing a
#' (lenient) secondary p-value threshold are merged into a single locus, the
#' locus is padded by one tile on each side, and the locus is retained only if
#' it contains at least one variant passing the (stringent) primary p-value
#' threshold. Returns an empty [tibble::tibble()] when no loci are found.
#'
#' This is a tiling-based alternative to [extract_loci()] (which clumps via
#' [gwasRtools::get_loci()]); it relies only on chromosome, position, and
#' p-value and does not require a reference LD panel.
#'
#' @details
#' The algorithm proceeds as follows:
#'
#' 1. Variants with `p <= p_secondary` are retained and each is assigned to the
#'    tile `pos %/% tile_size` on its chromosome.
#' 2. Runs of directly adjacent occupied tiles (no empty tile between them) on
#'    the same chromosome are merged into a core locus spanning
#'    `[tile_min * tile_size + 1, (tile_max + 1) * tile_size]`.
#' 3. Each core locus is padded by `tile_size` on both sides (the leading and
#'    trailing tiles, which by construction contain no secondary-significant
#'    variant).
#' 4. Padded loci are clamped to chromosome bounds (see `chr_bounds`) and
#'    retained only if they contain at least one variant with
#'    `p <= p_threshold`.
#'
#' A single `signal = -log10(p)` underpins both thresholding and ranking. When
#' effect-size columns (`beta_col` + `se_col`) or a z-statistic column (`z_col`)
#' are present, `signal` is recomputed from the test statistic via
#' `-(pnorm(-abs(z), log.p = TRUE) + log(2)) / log(10)` (a two-sided p-value is
#' assumed), which stays finite where the reported `p` underflows to `0` at very
#' strong loci (e.g. 9p21 or *LPA* for CAD). `z_col` takes precedence over
#' `beta_col`/`se_col`; per-row gaps fall back to the supplied `p`.
#'
#' Thresholding then branches on what is available. With a test statistic, the
#' secondary and primary gates are applied in `-log10` space
#' (`signal >= -log10(threshold)`), preserving full precision past the underflow
#' point. With only a `p` column, the exact `p <= threshold` comparison is used,
#' leaving legacy behaviour bit-for-bit unchanged. Either way the lead variant
#' is the one with the largest `signal`, reported as `lead_neglog10p`.
#'
#' The `p` column itself is optional (at least one of `p_col`, `z_col`, or
#' `beta_col`+`se_col` must be available). It is used only for reporting
#' `lead_p`: supplied values pass through as-is (and may be `0`), and when no
#' `p` column is given `lead_p` is computed as `10^(-lead_neglog10p)` (which may
#' likewise underflow to `0`, with the true magnitude preserved in
#' `lead_neglog10p`).
#'
#' Membership and bound-clamping are computed with dplyr overlap joins
#' ([dplyr::join_by()] inequality conditions), so this requires dplyr >= 1.1.0.
#' Padded loci are **not** re-merged, mirroring the reference implementation:
#' two core loci separated by a single empty tile can yield padded loci that
#' touch or overlap. Grouping is performed on the chromosome column directly, so
#' non-numeric chromosomes (e.g. `"X"`) are supported.
#'
#' @param df A data frame of GWAS summary statistics (e.g. output of
#'   [meta_analyze_ivw()]).
#' @param chr_col Bare column name for chromosome. Default `CHR`.
#' @param pos_col Bare column name for base-pair position. Default `POS_38`.
#' @param p_col Bare column name for p-value. Default `p_value`. Optional: if the
#'   column is absent (or `NULL`), the p-scale is reconstructed from the test
#'   statistic, so at least one of `p_col`, `z_col`, or `beta_col`+`se_col` must
#'   be available.
#' @param snp_col Bare column name for the variant identifier used to label the
#'   lead variant of each locus. Optional; pass `NULL` to omit. Default `RSID`.
#' @param p_threshold Primary (stringent) significance threshold; each reported
#'   locus must contain at least one variant below this value. Default `5e-8`.
#' @param p_secondary Secondary (lenient) threshold used to define tile
#'   occupancy and thus locus extent. Must be `>= p_threshold`. Default `1e-5`.
#' @param tile_size Tile width in base pairs. Default `50000`.
#' @param chr_bounds Optional data frame of allowed chromosome ranges with
#'   columns `chr`, `start`, `end` (multiple rows per chromosome are allowed,
#'   e.g. to carve out the MHC). When supplied, padded loci are clamped to the
#'   overlapping range and dropped if they overlap none; a leading `"chr"` in
#'   either source is ignored when matching. When `NULL` (default), locus starts
#'   are floored at 1 and upper bounds are left unclamped.
#' @param beta_col,se_col Optional bare column names for the effect size and its
#'   standard error, used together to derive `z = beta / se` for an
#'   underflow-safe ranking signal. Used only if both columns are present; pass
#'   `NULL` to ignore. Defaults `B` and `SE`.
#' @param z_col Optional bare column name for a precomputed z-statistic. Takes
#'   precedence over `beta_col`/`se_col` when present. Pass `NULL` to ignore.
#'   Default `z_score`.
#'
#' @return A [tibble::tibble()] with one row per locus and columns `chr`,
#'   `start`, `end`, `width`, `n_secondary` (variants below `p_secondary`),
#'   `n_primary` (variants below `p_threshold`), and—when `snp_col` is
#'   supplied—`lead_snp`, `lead_pos`, `lead_p`, and `lead_neglog10p` describing
#'   the most significant variant within the locus (ranked by `lead_neglog10p`).
#'   An empty tibble is returned when no loci are identified.
#'
#' @examples
#' \dontrun{
#' loci <- extract_loci_tiled(
#'   meta_results,
#'   p_threshold = 5e-8,
#'   p_secondary = 1e-5,
#'   tile_size   = 50000
#' )
#' }
#'
#' @importFrom cli cli_abort cli_warn cli_alert_info cli_alert_warning
#'   cli_alert_success cli_progress_step
#' @importFrom dplyr arrange coalesce count distinct filter group_by inner_join
#'   join_by left_join mutate n row_number slice_max summarise transmute ungroup
#'   select all_of
#' @importFrom rlang enquo quo_is_null as_name .data .env
#' @importFrom scales comma
#' @importFrom stats pnorm
#' @importFrom tibble tibble as_tibble
#' @importFrom tidyr replace_na
#' @export
extract_loci_tiled <- function(
    df,
    chr_col = CHR,
    pos_col = POS_38,
    p_col = p_value,
    snp_col = RSID,
    p_threshold = 5e-8,
    p_secondary = 1e-5,
    tile_size = 50000,
    chr_bounds = NULL,
    beta_col = B,
    se_col = SE,
    z_col = z_score
) {
    chr_col <- rlang::enquo(chr_col)
    pos_col <- rlang::enquo(pos_col)
    p_col <- rlang::enquo(p_col)
    snp_col <- rlang::enquo(snp_col)

    chr_col_str <- rlang::as_name(chr_col)
    pos_col_str <- rlang::as_name(pos_col)
    p_col_str <- if (!rlang::quo_is_null(p_col)) rlang::as_name(p_col) else NULL
    has_snp <- !rlang::quo_is_null(snp_col)
    snp_col_str <- if (has_snp) rlang::as_name(snp_col) else NULL

    # Optional effect-size / z columns for an underflow-safe ranking signal
    beta_col <- rlang::enquo(beta_col)
    se_col <- rlang::enquo(se_col)
    z_col <- rlang::enquo(z_col)
    beta_str <- if (!rlang::quo_is_null(beta_col)) {
        rlang::as_name(beta_col)
    } else {
        NULL
    }
    se_str <- if (!rlang::quo_is_null(se_col)) rlang::as_name(se_col) else NULL
    z_str <- if (!rlang::quo_is_null(z_col)) rlang::as_name(z_col) else NULL
    have_z <- !is.null(z_str) && z_str %in% names(df)
    have_bse <- !is.null(beta_str) &&
        !is.null(se_str) &&
        all(c(beta_str, se_str) %in% names(df))
    have_p <- !is.null(p_col_str) && p_col_str %in% names(df)

    # ---- Validate arguments -------------------------------------------------
    required_cols <- c(chr_col_str, pos_col_str, snp_col_str)
    missing_cols <- setdiff(required_cols, names(df))
    if (length(missing_cols) > 0) {
        cli::cli_abort("Missing required columns: {.field {missing_cols}}")
    }
    # A p-value is optional, but only if a test statistic is available to
    # reconstruct the p-scale from.
    if (!have_p && !have_z && !have_bse) {
        cli::cli_abort(c(
            "No source of statistical significance found.",
            "i" = "Supply a p-value ({.arg p_col}), a z-statistic ({.arg z_col}), \\
             or effect size and standard error ({.arg beta_col}/{.arg se_col})."
        ))
    }

    tile_size <- suppressWarnings(as.integer(tile_size))
    if (is.na(tile_size) || tile_size <= 0) {
        cli::cli_abort("{.arg tile_size} must be a positive integer.")
    }
    if (
        !is.numeric(p_threshold) ||
            !is.numeric(p_secondary) ||
            p_threshold <= 0 ||
            p_threshold > 1 ||
            p_secondary <= 0 ||
            p_secondary > 1
    ) {
        cli::cli_abort("p-value thresholds must lie in {.val {(0, 1]}}.")
    }
    if (p_threshold > p_secondary) {
        cli::cli_abort(
            "{.arg p_threshold} ({.val {p_threshold}}) must be \\
       <= {.arg p_secondary} ({.val {p_secondary}})."
        )
    }

    # ---- Derive an underflow-safe ranking signal (-log10 p) -----------------
    z_vec <- if (have_z) {
        suppressWarnings(as.numeric(df[[z_str]]))
    } else if (have_bse) {
        b <- suppressWarnings(as.numeric(df[[beta_str]]))
        s <- suppressWarnings(as.numeric(df[[se_str]]))
        s[!is.na(s) & s <= 0] <- NA_real_ # guard against non-positive SE
        b / s
    } else {
        NULL
    }
    p_vec <- if (have_p) suppressWarnings(as.numeric(df[[p_col_str]])) else NULL

    # signal = underflow-safe -log10(p). Prefer the test statistic; fall back to
    # the p column (per row) where the statistic is missing.
    signal_vec <- if (!is.null(z_vec)) {
        s <- neglog10p_from_z(z_vec)
        if (!is.null(p_vec)) {
            s <- dplyr::coalesce(s, -log10(p_vec))
        }
        s
    } else {
        -log10(p_vec)
    }
    # Reconstruct a p column when none was supplied, for reporting `lead_p` only
    # (may underflow to 0, exactly as a reported p would). Thresholds use the
    # canonical scale chosen below, not this value.
    if (is.null(p_vec)) {
        p_vec <- 10^(-signal_vec)
    }

    # When a test statistic is available, threshold in -log10 space so full
    # precision is retained even where p underflows. With only a p column, keep
    # the exact `p <= threshold` comparison (byte-identical to legacy behaviour).
    use_neglog <- have_z || have_bse
    neglog_secondary <- -log10(p_secondary)
    neglog_primary <- -log10(p_threshold)

    signal_src <- if (have_z) {
        "z-score"
    } else if (have_bse) {
        "beta/se"
    } else {
        "p-value"
    }

    # ---- Assemble a clean working frame -------------------------------------
    work <- df |>
        dplyr::transmute(
            chr = as.character(.data[[chr_col_str]]),
            pos = as.numeric(.data[[pos_col_str]]),
            p = .env$p_vec,
            snp = if (has_snp) {
                as.character(.data[[snp_col_str]])
            } else {
                NA_character_
            },
            signal = .env$signal_vec
        )

    initial_rows <- nrow(work)
    cli::cli_alert_info(
        "Starting with {.val {scales::comma(initial_rows)}} variants"
    )
    if (use_neglog) {
        cli::cli_alert_info(
            "Thresholding in -log10 space from {.field {signal_src}}; ranking lead variants likewise"
        )
    } else {
        cli::cli_alert_info(
            "Thresholding on supplied p-values; ranking lead variants by -log10(p)"
        )
    }

    work <- work |> dplyr::filter(!is.na(chr), !is.na(pos), !is.na(p))
    dropped <- initial_rows - nrow(work)
    if (dropped > 0) {
        cli::cli_warn(
            "Dropped {.val {scales::comma(dropped)}} rows with missing \\
       chromosome, position, or significance"
        )
    }
    if (any(work$p < 0 | work$p > 1)) {
        cli::cli_alert_warning(
            "Some p-values fall outside the expected range [0, 1]"
        )
    }

    # ---- Secondary-threshold scan: occupied tiles -> merged core loci -------
    cli::cli_progress_step(
        "Tiling variants below secondary threshold ({.val {p_secondary}})"
    )
    sec <- if (use_neglog) {
        dplyr::filter(work, signal >= neglog_secondary)
    } else {
        dplyr::filter(work, p <= p_secondary)
    }
    if (nrow(sec) == 0) {
        cli::cli_alert_warning(
            "No variants pass the secondary threshold ({.val {p_secondary}})"
        )
        return(tibble::tibble())
    }

    loci <- sec |>
        dplyr::mutate(tile = as.integer(pos %/% tile_size)) |>
        dplyr::distinct(chr, tile) |>
        dplyr::arrange(chr, tile) |>
        dplyr::group_by(chr) |>
        # A new run begins at the first tile of a chromosome or after any gap
        dplyr::mutate(run = cumsum(c(TRUE, diff(tile) > 1L))) |>
        dplyr::group_by(chr, run) |>
        dplyr::summarise(
            tile_min = min(tile),
            tile_max = max(tile),
            .groups = "drop"
        ) |>
        # Core bounds plus one tile of padding on each side
        dplyr::mutate(
            start = (tile_min - 1L) * tile_size + 1L,
            end = (tile_max + 2L) * tile_size
        ) |>
        clamp_to_bounds(chr_bounds) |>
        dplyr::mutate(locus = dplyr::row_number())

    if (nrow(loci) == 0) {
        cli::cli_alert_warning(
            "No loci remain after clamping to chromosome bounds"
        )
        return(tibble::tibble())
    }

    # ---- Annotate via interval overlap joins --------------------------------
    cli::cli_progress_step(
        "Filtering for loci with a primary-significant variant ({.val {p_threshold}})"
    )

    # Secondary variants falling inside each (padded) locus
    sec_hits <- loci |>
        dplyr::inner_join(
            sec,
            by = dplyr::join_by(chr, start <= pos, end >= pos)
        )

    n_secondary <- sec_hits |> dplyr::count(locus, name = "n_secondary")
    prim_hits <- if (use_neglog) {
        dplyr::filter(sec_hits, signal >= neglog_primary)
    } else {
        dplyr::filter(sec_hits, p <= p_threshold)
    }
    n_primary <- dplyr::count(prim_hits, locus, name = "n_primary")

    lead <- sec_hits |>
        dplyr::group_by(locus) |>
        dplyr::slice_max(signal, n = 1, with_ties = FALSE) |>
        dplyr::ungroup() |>
        dplyr::select(
            locus,
            lead_snp = snp,
            lead_pos = pos,
            lead_p = p,
            lead_neglog10p = signal
        )

    result <- loci |>
        dplyr::left_join(n_secondary, by = "locus") |>
        dplyr::left_join(n_primary, by = "locus") |>
        dplyr::left_join(lead, by = "locus") |>
        dplyr::mutate(
            n_secondary = tidyr::replace_na(n_secondary, 0L),
            n_primary = tidyr::replace_na(n_primary, 0L)
        ) |>
        dplyr::filter(n_primary > 0L) |>
        dplyr::mutate(width = end - start + 1L) |>
        # Natural ordering: numeric chromosomes first, then the rest
        dplyr::arrange(suppressWarnings(as.integer(chr)), chr, start)

    if (nrow(result) == 0) {
        cli::cli_alert_warning(
            "No loci contain a primary-significant variant (p < {.val {p_threshold}})"
        )
        return(tibble::tibble())
    }

    out_cols <- c("chr", "start", "end", "width", "n_secondary", "n_primary")
    if (has_snp) {
        out_cols <- c(
            out_cols,
            "lead_snp",
            "lead_pos",
            "lead_p",
            "lead_neglog10p"
        )
    }
    result <- dplyr::select(result, dplyr::all_of(out_cols))

    cli::cli_alert_success(
        "Identified {.val {nrow(result)}} significant {?locus/loci}"
    )
    tibble::as_tibble(result)
}

# Internal: underflow-safe two-sided -log10(p) from a z-statistic. Uses
# pnorm(log.p = TRUE) so the result stays finite for extreme |z| where the
# naive 2 * pnorm(-abs(z)) underflows to 0.
#' @noRd
#' @importFrom stats pnorm
neglog10p_from_z <- function(z) {
    -(stats::pnorm(-abs(z), log.p = TRUE) + log(2)) / log(10)
}

# Internal: clamp padded loci to optional chromosome bounds.
# When `chr_bounds` is NULL, floor starts at 1 and leave upper bounds unclamped.
# When supplied (columns chr/start/end, possibly multiple rows per chromosome),
# clamp each locus to every overlapping range via an interval-overlap join and
# drop loci overlapping none.
#' @noRd
#' @importFrom dplyr inner_join join_by mutate select transmute
clamp_to_bounds <- function(loci, chr_bounds) {
    if (is.null(chr_bounds)) {
        return(dplyr::mutate(loci, start = pmax(start, 1L)))
    }

    needed <- c("chr", "start", "end")
    if (!all(needed %in% names(chr_bounds))) {
        cli::cli_abort(
            "{.arg chr_bounds} must contain columns {.field {needed}}."
        )
    }

    norm_chr <- function(x) sub("^chr", "", as.character(x), ignore.case = TRUE)
    bounds <- chr_bounds |>
        dplyr::transmute(
            chr = norm_chr(chr),
            bstart = as.numeric(start),
            bend = as.numeric(end)
        )

    loci |>
        dplyr::mutate(chr = norm_chr(chr)) |>
        dplyr::inner_join(
            bounds,
            by = dplyr::join_by(chr, start <= bend, end >= bstart)
        ) |>
        dplyr::mutate(start = pmax(start, bstart), end = pmin(end, bend)) |>
        dplyr::select(-bstart, -bend)
}
