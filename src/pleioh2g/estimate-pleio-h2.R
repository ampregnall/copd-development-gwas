library(pleioh2g)

PHENOTYPES <-c("COPD", "LSI", "FEV1FVC")

PHENO_LIST <- c(
  "data/sumstats-processed/genomic-sem/munge/copd-eur.sumstats.gz",
  "data/sumstats-processed/genomic-sem/munge/wootton-2019-lifetime-smoking-eur.sumstats.gz",
  "data/sumstats-processed/genomic-sem/munge/shrine-2019-fev1-fvc-eur.sumstats.gz"
)

GWAS <- lapply(1:length(PHENOTYPES), function(i) fread(PHENO_LIST[i])[!is.na(N)])
SUMSTATS <- setNames(GWAS, PHENOTYPES)

HMP3 <- '/project/voltron/Resources/eur_w_ld_chr/w_hm3.snplist'
LD_PATH <-'/project/voltron/Resources/eur_w_ld_chr/'
WLD_PATH <-'/project/voltron/Resources/eur_w_ld_chr/'

# First to determine which disease in your list is the target disease
G = 1 # Index of target disease in trait list 

SAMPLE_PREV <- c(0.1254545, NULL, NULL)
POPULATION_PREV <- c(0.106, NULL, NULL)

# Specify number of genomic-jackknife block; We use n_block = 5 as example for quick computation, but we recommand to use 200 jackknife blocks; If you don't specify this, the default number is 200.
N_BLOCK <- 200

# Specify number of Monte Carlo sampling iterations in bias correction; If you don't specify this, the default number is 1000.
SAMPLE_REP <- 1000 

post_correction_results <- pruning_pleioh2g_wrapper(
  G = G, 
  phenotype = PHENOTYPES,
  munged_sumstats = SUMSTATS, 
  ld_path = LD_PATH, 
  wld_path = WLD_PATH, 
  sample_prev = SAMPLE_PREV, 
  population_prev = POPULATION_PREV,
  n_block = N_BLOCK, 
  hmp3 = HMP3,
  sample_rep = SAMPLE_REP, 
  rg_threshold = 0.8)
