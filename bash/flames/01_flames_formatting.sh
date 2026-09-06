#!/bin/bash
#BSUB -J flames-input[1-5]           # Job name and array index
#BSUB -o logs/flames_input_%J_%I.out
#BSUB -e logs/flames_input_%J_%I.err
#BSUB -n 1                           # Number of cores
#BSUB -R "rusage[mem=36GB]"          # Memory requirement (adjust as needed)
#BSUB -W 4:00                      # Runtime limit (hh:mm)
#BSUB -N                             # Send email at job end
#BSUB -q voltron_normal

cd /project/damrauer_copd/copd-asthma-gwas-nf

# Declare associative array (dictionary)
declare -A JOB_MAP

# Define file-pheno pairs indexed by job number
JOB_MAP[1]="/project/damrauer_copd/copd-asthma-gwas-nf/data/credible-sets/copd-all-credible-sets.txt|copd-all"
JOB_MAP[2]="/project/damrauer_copd/copd-asthma-gwas-nf/data/credible-sets/copd-afr-credible-sets.txt|copd-afr"
JOB_MAP[3]="/project/damrauer_copd/copd-asthma-gwas-nf/data/credible-sets/copd-amr-credible-sets.txt|copd-amr"
JOB_MAP[4]="/project/damrauer_copd/copd-asthma-gwas-nf/data/credible-sets/copd-eur-credible-sets.txt|copd-eur"
JOB_MAP[5]="/project/damrauer_copd/copd-asthma-gwas-nf/data/credible-sets/copd-eas-credible-sets.txt|copd-eas"
 
# Get the job index from LSB_JOBINDEX
JOB_INDEX=${LSB_JOBINDEX}

# Retrieve the paired values
if [[ -z "${JOB_MAP[$JOB_INDEX]}" ]]; then
    echo "Error: No mapping found for job index $JOB_INDEX"
    exit 1
fi

FILE=$(echo "${JOB_MAP[$JOB_INDEX]}" | cut -d'|' -f1)
PHENO=$(echo "${JOB_MAP[$JOB_INDEX]}" | cut -d'|' -f2)

echo "Processing job $JOB_INDEX: $PHENO"
echo "File: $FILE"

pixi run Rscript src/finemapping/format_flames_input.R \
    --credset "${FILE}" \
    --phenotype "${PHENO}"