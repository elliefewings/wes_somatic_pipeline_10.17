#!/bin/bash

## s02_preprocess_bams.sb.sh
## Bam preprocessing for a wes sample
## SLURM submission script
## Ellie Fewings, 11Oct17

#SBATCH -J preprocess_bams
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --mail-type=ALL
#SBATCH --no-requeue
#SBATCH -p sandybridge

##SBATCH --qos=INTR
##SBATCH --time=02:00:00
##SBATCH -A TISCHKOWITZ-SL3

## Modules section (required, do not remove)
. /etc/profile.d/modules.sh
module purge
module load default-impi

## Set initial working folder
cd "${SLURM_SUBMIT_DIR}"

## Read parameters
sample="${1}"
job_file="${2}"
logs_folder="${3}"
scripts_folder="${4}"
pipeline_log="${5}"

## Report settings and run the job
echo ""
echo "Job name: ${SLURM_JOB_NAME}"
echo "Allocated node: $(hostname)"
echo ""
echo "Initial working folder:"
echo "${SLURM_SUBMIT_DIR}"
echo ""
echo "Sample: ${sample}"
echo ""
echo " ------------------ Output ------------------ "
echo ""

## Do the job
sample_log="${logs_folder}/s02_preprocess_bams_${sample}.log"
"${scripts_folder}/s02_preprocess_bams.sh" \
         "${sample}" \
         "${job_file}" \
         "${scripts_folder}" \
         "${pipeline_log}" &> "${sample_log}"
