#! /bin/bash
#BSUB -J copd-mr-mega
#BSUB -n 1
#BSUB -R "rusage[mem=64GB]"
#BSUB -q voltron_normal
#BSUB -o logs/mr-mega.out
#BSUB -e logs/mr-mega.err

set -euo pipefail
module load MR-MEGA/0.2

cd /project/damrauer_copd/copd-asthma-gwas-nf

NUM_PCS=3

MR-MEGA --filelist data/mr-mega/config/copd-mrmega-config.in \
  --out data/mr-mega/copd-mrmega \
  --qt \
  --name_pos POS \
  --name_chr CHR \
  --name_n N_CASE \
  --name_beta BETA \
  --name_eaf EAF \
  --name_nea NEA \
  --name_ea EA \
  --name_marker SNPID \
  --name_se SE \
  --pc $NUM_PCS \
  --no_std_names