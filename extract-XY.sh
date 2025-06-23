#!/usr/bin/env bash
#SBATCH --cpus-per-task 4
#SBATCH --ntasks 1
#SBATCH --nodes 1
#SBATCH --time 1:00:00
#SBATCH --mem 24G
#SBATCH --gres lscratch:50

OUTDIR='/data/CARD_AUX/users/wellerca/PFC-atlas-preprocessing/XY_BAMS/'
cd $OUTDIR

N=${SLURM_ARRAY_TASK_ID}
let N=${N}+1

IID=$(sed -n ${N}p ../pfc-metadata-357.csv | cut -d ',' -f 1)
echo "Running sample: ${IID}"

BAM="/data/CARD_AUX/users/wellerca/PFC-atlas-preprocessing/CELLRANGER/${IID}/gex_possorted_bam.bam"

XY_BAM="${IID}_XY.bam"
UNMAPPED_BAM="${IID}_unmapped.bam"
FINAL_BAM="${IID}_XY_plus_unmapped.bam"

TMPDIR="/lscratch/${SLURM_JOB_ID}"
cd $TMPDIR

module load samtools/1.21

samtools index -@ 4 $BAM


# Get unmapped reads
samtools view -@ 4 -f 4 --bam $BAM > ${UNMAPPED_BAM}

# Get X and Y reads
samtools view -@ 4 --bam $BAM chrX chrY > ${XY_BAM}

# Merge
samtools merge -@ 4 -o - ${XY_BAM} ${UNMAPPED_BAM} | \
    samtools sort -o ${FINAL_BAM} - && \
    rm ${XY_BAM} ${UNMAPPED_BAM}

cp ${FINAL_BAM} ${OUTDIR}
