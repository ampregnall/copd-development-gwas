#! /bin/bash
#BSUB -J "annot[1-293]"
#BSUB -n 1
#BSUB -R "rusage[mem=12GB]"
#BSUB -e logs/annot_%J_%I.err
#BSUB -o logs/annot_%J_%I.out
#BSUB -q voltron_normal

set -euo pipefail

cd /project/damrauer_copd/copd-asthma-gwas-nf
LDSC_BASE=/project/damrauer_shared/Users/ampregnall/tools/ldsc
OUTDIR=data/ldsc/annot

if [[ -z "${LSB_JOBINDEX:-}" ]]; then
    echo "ERROR: LSB_JOBINDEX is not set. Submit this script via bsub to run array jobs." >&2
    exit 1
fi

# Deterministic, whitespace-safe file list
mapfile -t BED_FILES < <(find data/go-families/ -type f -name '*.pad50000.bed' | sort)

N=${#BED_FILES[@]}
if (( LSB_JOBINDEX < 1 || LSB_JOBINDEX > N )); then
    echo "ERROR: LSB_JOBINDEX=${LSB_JOBINDEX} out of range (found ${N} BED files)" >&2
    exit 1
fi

BED="${BED_FILES[LSB_JOBINDEX - 1]}"
NAME=$(basename "$BED" .pad50000.bed)
ANNOT_DIR="${OUTDIR}/${NAME}"
mkdir -p "$ANNOT_DIR"

echo "Task ${LSB_JOBINDEX}/${N}: ${BED} -> ${ANNOT_DIR}"

for CHROMOSOME in {1..22}; do
    pixi run --environment ldsc "${LDSC_BASE}/ldsc.py" \
        --l2 \
        --bfile "${LDSC_BASE}/assets/plink_files/1000G.EUR.hg38.${CHROMOSOME}" \
        --ld-wind-cm 1 \
        --annot "${ANNOT_DIR}/${NAME}.${CHROMOSOME}.annot.gz" \
        --thin-annot \
        --out "${ANNOT_DIR}/${NAME}.${CHROMOSOME}"
done