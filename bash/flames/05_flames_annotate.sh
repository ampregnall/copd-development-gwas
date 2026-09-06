#BSUB -J "flames-annotate[1-5]"     
#BSUB -q voltron_normal               # Job name + array range (4 files)
#BSUB -o logs/flames-annotate-%I-%J.out     # Stdout per array index
#BSUB -e logs/flames-annotate-%I-%J.err     # Stderr per array index
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

python /project/damrauer_shared/Users/ampregnall/ampregnall-flames/FLAMES/FLAMES.py annotate \
  -o data/flames-annotate \
  -a /project/damrauer_shared/Users/ampregnall/flames/meta/Annotation_data \
  -p data/pops/"${PHENO}"-pops.preds \
  -m data/magma/"${PHENO}"-magma.genes.out \
  -mt data/magma/"${PHENO}"-magma-gtex.gsa.out \
  -id data/flames/"${PHENO}"/meta/flames-index.txt \
  --build GRCh38 \
  --credset_95 False