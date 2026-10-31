#! /bin/bash
#BSUB -J "ldsc-cts[1-4]"
#BSUB -n 1
#BSUB -R "rusage[mem=16GB]"
#BSUB -e logs/ldsc_%J_%I.err
#BSUB -o logs/ldsc_%J_%I.out
#BSUB -q voltron_normal
#BSUB -Ne

set -euo pipefail
cd /project/damrauer_shared/Users/ampregnall/hr-gwas

# Ensure this script is run as a bsub job (LSB_JOBINDEX must be set)
if [[ -z "${LSB_JOBINDEX:-}" ]]; then
    echo "ERROR: LSB_JOBINDEX is not set. Submit this script via bsub to run array jobs." >&2
    exit 1
fi

OUTDIR=data/ldsc/cell-type
mkdir -p "$OUTDIR"

SUMSTATS=(
    "data/ldsc/munge/hr-multi.sumstats.gz"
    "data/ldsc/munge/hr-multi.sumstats.gz"
    "data/ldsc/munge/hr-eur.sumstats.gz"
    "data/ldsc/munge/hr-eur.sumstats.gz"   
)

LDCTS=(
    "data/ldsc/cellex.cts"
    "data/ldsc/expression.cts"
    "data/ldsc/cellex.cts"
    "data/ldsc/expression.cts"
)

NAMES=(
    "cellex-multi"
    "expression-multi"
    "cellex-eur"
    "expression-eur"
)

pixi run --environment ldsc python src/ldsc/ldsc.py \
    --h2-cts "${SUMSTATS[$LSB_JOBINDEX - 1]}" \
    --ref-ld-chr data/ldsc/baseline_v1.2/baseline. \
	--w-ld-chr data/ldsc/weights/weights.hm3_noMHC. \
	--ref-ld-chr-cts "${LDCTS[$LSB_JOBINDEX - 1]}" \
	--out "$OUTDIR/${NAMES[$LSB_JOBINDEX - 1]}"