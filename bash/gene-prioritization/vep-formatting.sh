#BSUB -J "format-vep[1-5]"                   
#BSUB -o logs/pops-log-%J.out     
#BSUB -e logs/pops-log-%J.err
#BSUB -n 1
#BSUB -R "rusage[mem=8GB]"
#BSUB -cwd /project/damrauer_copd/copd-asthma-gwas-nf/
#BSUB -W 10:00
#BSUB -N
#BSUB -q voltron_normal


set -euo pipefail
cd /project/damrauer_copd/copd-asthma-gwas-nf
eval "$(/appl/miniconda3-25/bin/conda shell.bash hook)"
conda activate /home/pregnall/.conda/envs/gwaslab

POPS=("all" "afr" "eur" "eas" "amr")
POP="${POPS[${LSB_JOBINDEX} - 1]}"

python src/finemapping/vep_formatting.py --population "${POP}"