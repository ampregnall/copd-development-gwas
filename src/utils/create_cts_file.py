import glob
import os
import re

EXPERIMENTS = ["cellex", "expression"]
BACKGROUND = {
    "cellex": "all_genes_in_cellex_background",
    "expression": "all_genes_in_pseudobulk_background",
}

for experiment in EXPERIMENTS:
    files = glob.glob(f"data/ldsc/ld-scores-split/{experiment}/*.ldscore.gz")
    stubs = {os.path.basename(x).split(".")[0] for x in files}
    with open(f"data/ldsc/{experiment}.cts", mode="w") as out:
        for stub in stubs:
            cell_type = re.sub(
                "all_genes_in_cellex_|all_genes_in_pseudobulk_mean_expression", "", stub
            )
            out.write(
                f"{cell_type}\tdata/ldsc/ld-scores-split/{experiment}/{stub}.,data/ldsc/ld-scores-split/{experiment}-background/{BACKGROUND[experiment]}_L2.\n"
            )
