source("src/finemapping/tiled_locus_extract.R")
source("src/finemapping/finemapping-utils.R")
library(data.table)

populations <- c("eur", "afr", "amr", "eas", "all")

purrr::map(populations, function(x) {
    df_sumstats <- fread(paste0("data/meta-analysis/copd/copd-", x, ".txt.gz"))

    # Extract lead variants and loci using tiling method
    df_loci <- extract_loci_tiled(
        df = df_sumstats,
        chr_col = CHR,
        pos_col = POS,
        p_col = P,
        snp_col = SNPID,
        beta_col = BETA,
        se_col = SE,
        z_col = Z
    )

    # Subset summary statistics to only include variants within the extracted loci
    df_sumstats <- locus_extract_dtable(
        sumstats_df = df_sumstats,
        locus_df = df_loci,
        sumstats_chr_col = CHR,
        sumstats_pos_col = POS,
        locus_chr_col = chr,
        locus_start_col = start,
        locus_end_col = end
    )

    # Calculate credible sets for each locus using approximate Bayes factor method
    df_credset <- calc_credset(
        df = df_sumstats,
        locus_marker_col = locus_marker,
        effect_col = BETA,
        se_col = SE,
        samplesize_col = N,
    )

    df_credset <- df_credset |>
        dplyr::rename(
            LOCUS = locus_marker,
            CHR = chromosome,
            START = start,
            END = end,
            BF = bf,
            PIP = posterior_prob
        ) |>
        dplyr::mutate(LEAD = SNPID %in% df_loci$lead_snp) |>
        dplyr::arrange(CHR, START, -PIP)

    df_lead <- df_credset |> dplyr::filter(LEAD)

    fwrite(
        df_credset,
        glue::glue("data/credible-sets/copd-{x}-credible-sets.txt"),
        sep = "\t"
    )
    fwrite(
        df_lead,
        glue::glue("data/lead-variants/copd-{x}-lead-variants.txt"),
        sep = "\t"
    )
})
