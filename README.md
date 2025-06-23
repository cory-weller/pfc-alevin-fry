# README

Run once to set up environment
```bash
source myconda
mamba create -n alevin-fry
mamba activate alevin-fry
mamba install -c bioconda alevin-fry
```

Run once to generate barcode whitelists (result of Adam's final QC filters)
```bash
mkdir -p bc_whitelists
cut -d ',' -f 8,9  rna_cell_metadata.csv | \
awk -F ',' 'NR>1 {s="bc_whitelists/"$2".txt";  print $1 > s}'
```


Submit jobs:
```bash
sbatch --array=1-357 alevin-fry.sh
```
