#BSUB -J "flames-score[1-5]"         # Job name + array range (4 files)
#BSUB -q voltron_normal               # Job name + array range (4 files)
#BSUB -o logs/flames-score%J.out     # Stdout per array index
#BSUB -e logs/flames-score%J.err     # Stderr per array index
#BSUB -n 1
#BSUB -R "rusage[mem=8GB]"
#BSUB -W 100:00
#BSUB -N

set -euo pipefail
cd /project/damrauer_copd/copd-asthma-gwas-nf
eval "$(/appl/miniconda3-25/bin/conda shell.bash hook)"
conda activate /home/pregnall/.conda/envs/FLAMES

PHENOS=(
  "copd-all"
  "copd-afr"
  "copd-eur"
  "copd-eas"
  "copd-amr"
)

PHENO="${PHENOS[${LSB_JOBINDEX} - 1]}"
mkdir -p data/flames/"${PHENO}"/flames-scores

python /project/damrauer_shared/Users/ampregnall/ampregnall-flames/FLAMES/FLAMES.py FLAMES \
  -id data/flames/"${PHENO}"/meta/flames-index.txt \
  -o data/flames/"${PHENO}"/flames-scores