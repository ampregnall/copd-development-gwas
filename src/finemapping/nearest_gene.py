import re
from argparse import ArgumentParser
from pathlib import Path

import gwaslab as gl
import pandas as pd

parser = ArgumentParser()
parser.add_argument("--loci", type=str, help="Path to loci file")
parser.add_argument("--sumstats", type=str, help="Path to summary statistics file")
args = parser.parse_args()

# Load loci definition file
df = pd.read_csv(args.loci)

sumstats = gl.Sumstats(args.sumstats, fmt="gwaslab", other=["N_CONTRIBUTIONS"])
sumstats.data = sumstats.data[sumstats.data["rsID"].isin(df["LEAD_SNP"])]
df_nearest = sumstats.anno_gene(source="refseq", build="38")

# Save output
base = re.sub(pattern=".txt.gz", repl="", string=Path(args.sumstats).name)
out_path = f"data/lead-variants/{base}-lead-variants-annotated.txt"
df_nearest.to_csv(out_path, sep="\t")
