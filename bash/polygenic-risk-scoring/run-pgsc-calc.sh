#!/bin/bash
#BSUB -J pgsc-calc   # limits concurrent jobs 
#BSUB -o logs/pgsc_calc_%I_%J.out
#BSUB -e logs/pgsc_calc_%I_%J.err
#BSUB -n 10
#BSUB -q voltron_long

set -euo pipefail
cd /project/damrauer_copd/copd-asthma-gwas-nf

# Build array of scorefile directories
SCOREFILES="/project/damrauer_copd/copd-asthma-gwas-nf/data/prscsx/scorefiles"

OUTDIR="/project/damrauer_copd/copd-asthma-gwas-nf/data/pgsc-calc/partitioned"
mkdir -p $OUTDIR

export SINGULARITY_BIND="/lsf,/project/,/appl/,/scratch/,/static"
module load apptainer
module load jdk/20.0.2
module load nextflow/23.10.0

nextflow run pgscatalog/pgsc_calc \
    -profile singularity \
    --input "/project/damrauer_shared/pmbb_shared/samplesheet_v4_damrauer_shared.csv" \
    --scorefile "${SCOREFILES}/*.txt" \
    --target_build GRCh38 \
    --outdir "$OUTDIR" \
    --run_ancestry /project/voltron/Resources/pgsc_calc/LD-reference/pgsc_HGDP+1kGP_v1.tar.zst \
    --min_overlap 0.0 \
    --genotypes_cache /project/damrauer_shared/pmbb_shared/pgsc_calc_v4_cache \
    --resume