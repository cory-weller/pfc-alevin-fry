#!/usr/bin/env bash
#SBATCH --time 1:00:00
#SBATCH --mem 40G
#SBATCH --nodes 1
#SBATCH --ntasks 1
#SBATCH --cpus-per-task 8
#SBATCH --gres=lscratch:250
#SBATCH --partition quick,norm



PROJDIR=$(realpath .)
MDATA=$(realpath pfc-metadata-357.csv)

# Get Job number in array, increment by 1 (accounting for header)
N=${SLURM_ARRAY_TASK_ID}
let N=${N}+1

# Extract metadta from csv
IID=$(sed -n ${N}p $MDATA | cut -d ',' -f 1)
SEX=$(sed -n ${N}p $MDATA | cut -d ',' -f 5)
COHORT=$(sed -n ${N}p $MDATA | cut -d ',' -f 9)
FASTQDIR="/data/CARD_AUX/users/wellerca/PFC-atlas-preprocessing/${COHORT}/snRNA/"
QC_BCLIST="${PROJDIR}/bc_whitelists/${IID}.txt"

TMPDIR="/lscratch/${SLURM_JOB_ID}"
OUTDIR=$(realpath OUTPUT/)

# Define index/ref dirs
if [[ ${SEX} == 'Male' ]]; then
    INDEX='/data/ADRD/human_brain_atlasing/3_fastq_processing/3_alevin_fry/inputs/af_tutorial_splici/grch38_splici_idx'
    REFDIR='/data/ADRD/human_brain_atlasing/3_fastq_processing/3_alevin_fry/inputs/transcriptome_splici_fl86'    
elif [[ ${SEX} == 'Female' ]]; then
    INDEX='/data/ADRD/human_brain_atlasing/3_fastq_processing/3_alevin_fry/inputs/af_tutorial_splici_noY/grch38_splici_idx'
    REFDIR='/data/ADRD/human_brain_atlasing/3_fastq_processing/3_alevin_fry/inputs/transcriptome_splici_fl_noY86'
fi

cd ${TMPDIR}
mkdir ${IID}

# Define read files for sample ${IID}
R1_files=($(find -L ${FASTQDIR} -name "${IID}_S*_R1_001.fastq.gz"))
R2_files=(${R1_files[@]%R1_001.fastq.gz})
R2_files=(${R2_files[@]/%/R2_001.fastq.gz})

# Note that the cellranger-arc barcode list is different than cellranger.
# As a result, we need to manually provide a --whitelist 
# Unfortunately, we do not have the barcodes.tsv output from cellranger.
# But we do have the filtered one from cellbender, which I've used.

# Build command
module load salmon/1.10.1
MYCMD=(salmon alevin \
    -i $INDEX \
    -l IU \
    -1 ${R1_files[@]} \
    -2 ${R2_files[@]} \
    --sketch \
    --chromium \
    --whitelist ${QC_BCLIST} \
    -p 8 \
    -o map \
    --tgMap $REFDIR/transcriptome_splici_fl86_t2g.tsv
)


# Save command to log
echo -e "Running CMD:\n${MYCMD[@]}\n"

# Run
${MYCMD[@]}

source myconda
mamba activate alevin-fry || { echo "ERROR: Could not actiave environment alevin-fry"; exit 1; }


########################################
# generate permit list from the cellbender output

less ${QC_BCLIST} | cut -d '-' -f 1 > whitelist.txt
alevin-fry generate-permit-list -d fw \
    -i map \
    -o quant \
    --unfiltered-pl whitelist.txt

########################################
# collate files

alevin-fry collate -t 8 \
    -i quant \
    -r map

########################################
# quantify

alevin-fry quant -t 8 \
    -i quant \
    -o $IID \
    --tg-map $REFDIR/transcriptome_splici_fl86_t2g_3col.tsv \
    --resolution cr-like-em \
    --use-mtx

########################################

rm -rf $IID/map
rm -rf $IID/quant

# Compress sparse matrix (reduces to ~ 1/3 size)
pigz ${IID}/alevin/quants.mat.mtx


# Export to permanent location
cp -r ${IID} ${OUTDIR}

cd
