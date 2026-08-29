#BSUB -J "abc[1-5]"
#BSUB -n 1
#BSUB -R "rusage[mem=24GB]"
#BSUB cwd /project/damrauer_copd/copd-asthma-gwas-nf/
#BSUB -W 1:00
#BSUB -N
#BSUB -q voltron_normal

set -euo pipefail

POPS=(
  "all"
  "afr"
  "eur"
  "eas"
  "amr"
)
POP="${POPS[$LSB_JOBINDEX - 1]}"

pixi run Rscript src/finemapping/activity_by_contact.R \
    --credsets data/credible-sets/copd-"${POP}"-credible-sets.txt \
    --vep data/vep/output/copd-"${POP}"-credible-sets-annotated 