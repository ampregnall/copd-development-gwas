#!/bin/bash
#BSUB -J "magma-gene[1-5]"                    # Job name + array range (4 files)
#BSUB -o logs/magma-gene-log-%J.out     # Stdout per array index
#BSUB -e logs/magma-gene-log-%J.err     # Stderr per array index
#BSUB -n 1
#BSUB -R "rusage[mem=8GB]"
#BSUB -W 1:00
#BSUB -N

set -euo pipefail
cd /project/damrauer_copd/copd-asthma-gwas-nf

module load magma/1.07a

PHENOS=(
  "copd-all"
  "copd-afr"
  "copd-eur"
  "copd-eas"
  "copd-amr"
)

PHENO="${PHENOS[${LSB_JOBINDEX} - 1]}"

magma \
  --gene-results data/magma/"${PHENO}"-magma.genes.raw \
  --gene-covar /project/damrauer_shared/Users/ampregnall/flames/meta/gtex_v8_ts_avg_log2TPM.txt \
  --out data/magma/"${PHENO}"-magma-gtex