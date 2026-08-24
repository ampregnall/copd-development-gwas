locus_extract_dtable <- function(
  sumstats_df,
  locus_df,
  locus_size = 1e6,
  sumstats_chr_col,
  sumstats_pos_col,
  locus_chr_col,
  locus_start_col,
  locus_end_col
) {
  # Prepare locus_df
  locus_dt <- locus_df |>
    dplyr::select(
      chromosome = {{ locus_chr_col }},
      start = {{ locus_start_col }},
      end = {{ locus_end_col }}
    ) |>
    dplyr::mutate(
      chromosome = as.numeric(chromosome),
      start = as.numeric(start),
      end = as.numeric(end)
    ) |>
    dplyr::distinct(chromosome, start, end, .keep_all = TRUE) |>
    data.table::as.data.table()

  # Prepare sumstats_df
  sumstats_dt <- sumstats_df |>
    dplyr::mutate(
      start = {{ sumstats_pos_col }},
      end = {{ sumstats_pos_col }}
    ) |>
    dplyr::rename(chromosome = {{ sumstats_chr_col }}) |>
    dplyr::mutate(
      chromosome = as.numeric(chromosome),
      start = as.numeric(start),
      end = as.numeric(end)
    ) |>
    data.table::as.data.table()

  # Set keys for efficient joining
  data.table::setkey(locus_dt, chromosome, start, end)
  data.table::setkey(sumstats_dt, chromosome, start, end)

  # Efficient overlap join
  result <- data.table::foverlaps(
    sumstats_dt,
    locus_dt,
    by.x = c("chromosome", "start", "end"),
    by.y = c("chromosome", "start", "end"),
    type = "within"
  ) |>
    dplyr::filter(!is.na(start)) |> # Remove non-matching rows
    dplyr::mutate(locus_marker = glue::glue("{chromosome}:{start}:{end}")) |>
    dplyr::select(
      locus_marker,
      chromosome,
      everything(),
      -i.start,
      -i.end
    )

  return(result)
}

calc_credset <- function(
  df,
  locus_marker_col = locus_marker,
  effect_col = effect,
  se_col = std_err,
  samplesize_col = samplesize,
  cred_interval = 0.99
) {
  df |>
    dplyr::group_by({{ locus_marker_col }}) |>
    dplyr::mutate(
      bf = exp(
        0.5 * ({{ effect_col }}^2 / {{ se_col }}^2 - log({{ samplesize_col }}))
      )
    ) |>
    dplyr::mutate(posterior_prob = bf / sum(bf)) |>
    dplyr::arrange(dplyr::desc(posterior_prob)) |>
    dplyr::mutate(cum_sum = cumsum(posterior_prob)) |>
    dplyr::group_by({{ locus_marker_col }}) |>
    dplyr::filter(cum_sum <= cred_interval | posterior_prob > cred_interval) |>
    dplyr::select(-cum_sum) |>
    dplyr::ungroup()
}
