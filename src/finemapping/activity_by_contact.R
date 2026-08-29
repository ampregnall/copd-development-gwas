library(data.table)
library(dplyr)
library(vroom)
library(argparse)
library(glue)

parser <- ArgumentParser()
parser$add_argument(
    "--credsets",
    help = "Path to credible set files"
)
parser$add_argument(
    "--vep",
    help = "Path to VEP annotation file"
)

args <- parser$parse_args()

df_credsets <- vroom(
    file = args$credsets,
    delim = "\t"
)

df_vep <- vroom(
    file = args$vep,
    delim = "\t",
    comment = "##"
)

df_credsets <- df_credsets |>
    left_join(df_vep, by = c("SNPID" = "#Uploaded_variation")) |>
    filter_out(
        Consequence %in% c("missense_variant", "splice_acceptor_variant")
    )

df_abc <- vroom(
    file = "AllPredictions.AvgHiC.ABC0.015.minus150.ForABCPaperV3-hg38.txt.gz",
    delim = ","
) |>
    filter_out(seqnames == "chrX") |>
    filter(ABC.Score > 0.1) |>
    mutate(chr = as.numeric(gsub("chr", "", seqnames)))

df_matches <- df_abc |>
    inner_join(
        df_credsets,
        by = join_by(chr == CHR, start <= POS, end >= POS)
    ) |>
    group_by(LOCUS) |>
    mutate(
        score = PIP * ABC.Score,
    ) |>
    group_by(LOCUS, TargetGene) |>
    summarise(sumscore = sum(score)) |>
    slice_max(sumscore, n = 1)

out_base <- gsub(
    pattern = "-credible-set.txt",
    replacement = "",
    x = basename(args$credsets)
)

fwrite(
    df_matches,
    glue(
        "data/gene-prioritization/activity-by-contact/{out_base}-activity-by-contact.txt"
    ),
    sep = "\t"
)
