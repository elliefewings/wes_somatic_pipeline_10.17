#!/bin/bash

## s01_copy_and_dispatch.sb.sh
## Wes library merge pipeline
## Copy source files and dispatch samples to nodes
## SLURM submission script
## Ellie Fewings, 06Oct17

#SBATCH -J copy_and_dispatch
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --mail-type=ALL
#SBATCH --no-requeue
#SBATCH -p sandybridge

##SBATCH --qos=INTR
##SBATCH --time=00:30:00
##SBATCH -A TISCHKOWITZ-SL3

## Modules section (required, do not remove)
. /etc/profile.d/modules.sh
module purge
module load default-impi

## Set initial working folder
cd "${SLURM_SUBMIT_DIR}"

## Report settings and run the job
echo ""
echo "Job name: ${SLURM_JOB_NAME}"
echo "Allocated node: $(hostname)"
echo ""
echo "Initial working folder:"
echo "${SLURM_SUBMIT_DIR}"
echo ""
echo " ------------------ Output ------------------ "
echo ""

## Read parameters
job_file="${1}"
logs_folder="${2}"
scripts_folder="${3}"
pipeline_log="${4}"

## Do the job
log="${logs_folder}/s01_copy_and_dispatch.log"

"${scripts_folder}/s01_copy_and_dispatch.sh" \
         "${job_file}" \
         "${scripts_folder}" \
         "${pipeline_log}" &> "${log}"
