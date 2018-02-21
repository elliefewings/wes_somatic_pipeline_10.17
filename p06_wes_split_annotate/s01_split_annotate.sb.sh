#!/bin/bash

## s01_split_annotate.sb.sh
## Wes: split and annotate variants
## SLURM submission script
## Ellie Fewings; 25Oct17

#SBATCH -J split_annotate
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
scripts_folder="${2}"
log="${3}"

## Do the job, direct output to the log
"${scripts_folder}/s01_split_annotate.sh" \
         "${job_file}" \
         "${scripts_folder}" &>> "${log}"
