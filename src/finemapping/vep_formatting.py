import argparse

import gwaslab as gl

parser = argparse.ArgumentParser(description="Convert summary statistics to VEP format")
parser.add_argument("--population", help="Input summary statistics file")
args = parser.parse_args()

sumstats = gl.Sumstats(
    f"data/credible-sets/copd-{args.population}-credible-sets.txt", fmt="gwaslab"
)
sumstats.to_format(path=f"data/vep/input/copd-{args.population}", fmt="vep")
