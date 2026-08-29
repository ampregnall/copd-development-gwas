#!/bin/bash
#BSUB -J vep[1-5]
#BSUB -n 1
#BSUB -R "rusage[mem=32GB]"
#BSUB -q voltron_normal
#BSUB -W 10:00
#BSUB -cwd /project/damrauer_copd/copd-asthma-gwas-nf/
#BSUB -o logs/vep_%J_%I.out
#BSUB -e logs/vep_%J_%I.err

export APPTAINER_BIND="/lsf,/project/,/appl/,/scratch/,/static"
module load apptainer
POPS=("all" "eur" "afr" "amr" "eas")
POP="${POPS[${LSB_JOBINDEX} - 1]}"

apptainer exec /appl/containers/vep113.sif vep \
    --cache \
    --offline \
    --pick \
    --dir /static/vepcache113 \
    --input_file data/vep/input/copd-"${POP}".vep \
    --output_file data/vep/output/copd-"${POP}"-credible-sets-annotated \
    --species homo_sapiens \
    --symbol \
    --assembly GRCh38 \
    --tab \
    --fields "Uploaded_variation,SYMBOL,Consequence,IMPACT,VARIANT_CLASS" \
    --force_overwrite \
    --no_check_variants_order