#!/bin/bash
#BSUB -J "magma[1-5]"  
#BSUB -o logs/magma-%J-%I.out
#BSUB -e logs/magma-%J-%I.err
#BSUB -n 1
#BSUB -R "rusage[mem=16GB]"
#BSUB -W 24:00
#BSUB -N
#BSUB -q voltron_normal

set -euo pipefail
cd /project/damrauer_copd/copd-asthma-gwas-nf

# Define phenotypes
PHENOS=(
  "copd-all"
  "copd-afr"
  "copd-eur"
  "copd-eas"
  "copd-amr"
)

# Get the phenotype for this job index
PHENO="${PHENOS[${LSB_JOBINDEX} - 1]}"
echo "Processing phenotype: ${PHENO}"

module load magma/1.07a

magma --bfile /project/voltron/Resources/MAGMA/1000G_GRCh38/1000G_all_hg38 \
        --gene-annot /project/voltron/Resources/MAGMA/1000G_GRCh38/GRCh38.genes.ensg.genes.annot \
        --pval "data/magma/${PHENO}-magma-input.txt" use=SNP,P ncol=N \
        --gene-model snp-wise=mean \
        --out "data/magma/${PHENO}-magma"

echo "MAGMA analysis complete for ${PHENO}"