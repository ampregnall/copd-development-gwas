library(argparse)
library(readr)
library(dplyr)
library(purrr)

parser <- ArgumentParser()
parser$add_argument("--credsets", help = "Path to credible set file")
parser$add_argument("--phenotype", help = "Name of phenotype")
args <- parser$parse_args()

credset <- read_delim(args$credsets)
lead <- credset |> filter(LEAD)

credset <- credset |>
    mutate(
        SNPID_FLAMES = glue::glue("{CHR}:{POS}:{EA}:{NEA}")
    )


df_credset <- credset |>
    select(locus_marker = LOCUS, cred1 = SNPID_FLAMES, prob1 = PIP) |>
    group_by(locus_marker) |>
    mutate(index = dplyr::row_number()) |>
    ungroup()

# Get the list of data frames and species names
credset_list <- df_credset %>% group_split(locus_marker)
credset_names <- map_chr(credset_list, ~ .x$locus_marker[1])

# Create full file paths
file_paths <- file.path(
    "data/flames",
    args$phenotype,
    "credsets",
    paste0(credset_names, ".txt")
)
annot_paths <- file.path(
    "data/flames",
    args$phenotype,
    "flames-annotate",
    paste0("FLAMES_annotated_", credset_names, ".txt")
)

dir.create(
    file.path("data/flames", args$phenotype, "credsets"),
    recursive = TRUE
)

dir.create(
    file.path("data/flames", args$phenotype, "flames-annotate"),
    recursive = TRUE
)

# Write files using walk2
walk2(credset_list, file_paths, function(x, y) {
    x <- select(x, index, cred1, prob1)
    write_delim(x, y, delim = "\t")
})

df_index <- tibble::tibble(
    Filename = file_paths,
    GenomicLocus = 1:nrow(lead),
    Annotfiles = annot_paths
)

lead <- lead |>
    select(chr = CHR, pos = POS, start = START, end = END) |>
    mutate(
        order = glue::glue(
            "data/flames/{args$phenotype}/credsets/{chr}:{pos}.txt"
        )
    ) |>
    mutate(
        order = factor(order, levels = file_paths)
    ) |>
    arrange(order)

lead <- lead |>
    mutate(GenomicLocus = dplyr::row_number()) |>
    select(GenomicLocus, chr, start, end)

lead_out <- glue::glue(
    "data/flames/{args$phenotype}/meta/flames-genomic-locus.txt"
)
index_out <- glue::glue("data/flames/{args$phenotype}/meta/flames-index.txt")
dir.create(dirname(lead_out), recursive = TRUE)
dir.create(dirname(index_out), recursive = TRUE)

write_delim(lead, lead_out, delim = "\t")
write_delim(df_index, index_out, delim = "\t")
