source("src/finemapping/tiled_locus_extract.R")
source("src/finemapping/finemapping-utils.R")
library(data.table)
library(argparse)
library(glue)

# Add command line arguments
parser <- ArgumentParser()
parser$add_argument(
    "--sumstats",
    help = "Path to summary statistic file"
)
parser$add_argument(
    "--loci",
    help = "Path to locus definition file"
)

args <- parser$parse_args()

df_sumstats <- fread(args$sumstats)
df_loci <- fread(args$loci)

# Subset summary statistics to only include variants within the extracted loci
df_sumstats <- locus_extract_dtable(
    sumstats_df = df_sumstats,
    locus_df = df_loci,
    sumstats_chr_col = CHR,
    sumstats_pos_col = POS,
    locus_chr_col = CHR,
    locus_start_col = BP_MIN,
    locus_end_col = BP_MAX
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
    dplyr::mutate(LEAD = rsID %in% df_loci$LEAD_SNP) |>
    dplyr::arrange(CHR, START, -PIP)

out_dir <- "data/credible-sets"
out_prefix <- gsub(
    pattern = ".txt.gz",
    replacement = "",
    x = basename(args$sumstats)
)
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

fwrite(
    df_credset,
    glue("{out_dir}/{out_prefix}-credible-sets.txt"),
    sep = "\t"
)
