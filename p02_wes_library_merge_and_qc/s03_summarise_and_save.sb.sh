#!/bin/bash

## s03_summarise_and_save.sb.sh
## Plot summary metrics for merged wes samples and save results to NAS
## SLURM submission script
## Ellie Fewings, 06Oct17

#SBATCH -J summarise_and_save
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --mail-type=ALL
#SBATCH --no-requeue
#SBATCH -p sandybridge

##SBATCH --qos=INTR
##SBATCH --time=01:00:00
##SBATCH -A TISCHKOWITZ-SL2

## Modules section (required, do not remove)
. /etc/profile.d/modules.sh
module purge
module load default-impi

## Set initial working folder
cd "${SLURM_SUBMIT_DIR}"

## Read parameters
job_file="${1}"
logs_folder="${2}"
scripts_folder="${3}"
pipeline_log="${4}"

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

## Do the job
log="${logs_folder}/s03_summarise_and_save.log"
"${scripts_folder}/s03_summarise_and_save.sh" \
         "${job_file}" \
         "${scripts_folder}" \
         "${pipeline_log}" \ &> "${log}"
