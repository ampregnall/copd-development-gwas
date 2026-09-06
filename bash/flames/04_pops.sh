#BSUB -J "pops[1-5]"                   
#BSUB -o logs/pops-log-%J.out     
#BSUB -e logs/pops-log-%J.err
#BSUB -n 1
#BSUB -R "rusage[mem=8GB]"
#BSUB -W 10:00
#BSUB -N

set -euo pipefail
cd /project/damrauer_copd/copd-asthma-gwas-nf
eval "$(/appl/miniconda3-25/bin/conda shell.bash hook)"
conda activate /home/pregnall/.conda/envs/pops

PHENOS=(
  "copd-all"
  "copd-afr"
  "copd-eur"
  "copd-eas"
  "copd-amr"
)


PHENO="${PHENOS[${LSB_JOBINDEX} - 1]}"
mkdir -p data/pops

python /project/damrauer_shared/Users/ampregnall/ampregnall-flames/src/pops.py \
  --gene_annot_path /project/damrauer_shared/Users/ampregnall/flames/meta/pops_features_full/gene_annot.txt \
  --feature_mat_prefix /project/damrauer_shared/Users/ampregnall/flames/meta/pops_features_full/munged_features/pops_features \
  --num_feature_chunks 116 \
  --magma_prefix data/magma/"${PHENO}"-magma \
  --control_features /project/damrauer_shared/Users/ampregnall/flames/meta/pops_features_full/control.features \
  --out_prefix data/pops/"${PHENO}"-pops