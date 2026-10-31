#BSUB -J popcorn[1-10]
#BSUB -n 1
#BSUB -q voltron_normal
#BSUB -o popcorn.%J.out
#BSUB -e popcorn.%J.err

cd /project/voltron/Resources/popcorn

POPS=("eur" "afr" "amr" "eas" "sas")

# Build flat array of all pairs
PAIRS=()
for ((i=0; i<${#POPS[@]}; i++)); do
  for ((j=i+1; j<${#POPS[@]}; j++)); do
    PAIRS+=("${POPS[$i]}:${POPS[$j]}")
  done
done
# PAIRS has 10 elements → #BSUB -J popcorn_fit[1-10]

PAIR="${PAIRS[${LSB_JOBINDEX} - 1]}"
POP1="${PAIR%%:*}"   # everything before ':'
POP2="${PAIR##*:}"   # everything after  ':'

module load apptainer
export APPTAINER_BIND="/lsf,/project/,/appl/,/scratch/,/static"

apptainer exec --home "$PWD":/home container/popcorn.sif popcorn fit \
  --sfile1 /project/damrauer_copd/copd-asthma-gwas-nf/data/popcorn/input/copd-${POP1}.txt \
  --sfile2 /project/damrauer_copd/copd-asthma-gwas-nf/data/popcorn/input/copd-${POP2}.txt \
  --cfile reference/cfiles/1000G_${POP1}_${POP2}.cscore \
  /project/damrauer_copd/copd-asthma-gwas-nf/data/popcorn/COPD_${POP1}_${POP2}.out