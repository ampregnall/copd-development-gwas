#BSUB -J "annotate-nearest-gene[1-5]"
#BSUB -o "logs/annotate-nearest-gene-%J.out"
#BSUB -e "logs/annotate-nearest-gene-%J.err"
#BSUB -R "rusage[mem=12GB]"
#BSUB -cwd /project/damrauer_copd/copd-asthma-gwas-nf/
#BSUB -W 1:00
#BSUB -N 
#BSUB -q voltron_normal

set -euo pipefail
eval "$(/appl/miniconda3-25/bin/conda shell.bash hook)"
conda activate /home/pregnall/.conda/envs/gwaslab

POPS=("all" "afr" "eur" "eas" "amr")
POP="${POPS[${LSB_JOBINDEX} - 1]}"

python src/finemapping/nearest_gene.py \
    --loci data/tiled-loci/copd-"${POP}"-tiled-loci.txt \
    --sumstats data/meta-analysis/copd/copd-"${POP}".txt.gz