#!/bin/bash

# s01_copy_and_dispatch.sh
# Wes library preprocess
# Copy source files and dispatch samples to nodes
# Ellie Fewings, 11Oct17

# Stop at any error
set -e

# Read parameters
job_file="${1}"
scripts_folder="${2}"
pipeline_log="${3}"

# Update pipeline log
echo "Started s01_copy_and_dispatch: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"

# Progress report to the job log
echo "Copy and dispatch for preprocess"
echo "Started: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# Settings
echo "====================== Settings ======================"
echo ""

source "${scripts_folder}/a01_read_config.sh"
source "${scripts_folder}/a02_report_settings.sh"

echo "====================================================="
echo ""

# ================= Copy source dedupped bams to cluster ================= #

# Suspend stopping at errors
set +e

# Progress report
echo "Getting list of samples"
echo ""

# Copy list of lanes
rsync -thrqe "ssh -x" "${data_server}:${project_location}/${project}/${library}/merged/samples.txt" "${merged_folder}/samples.txt" 
exit_code="${?}"

# Stop if copying failed
if [ "${exit_code}" != "0" ] 
then
    echo ""
    echo "Failed getting source data from NAS"
    echo "Script terminated"
    echo ""
    exit
fi

# Progress report
echo "Copying source dedupped bams to cluster"
echo ""

# For each sample
samples=$(awk 'NR>1 {print $1}' "${merged_folder}/samples.txt")

for sample in ${samples}
do

  # Copy file
  dedup_bam_file=$(awk -v sm="${sample}" '$1==sm {print $2}' "${merged_folder}/samples.txt")
  dedup_bai_file="${dedup_bam_file%bam}bai"
  
  rsync -thrqe "ssh -x" "${data_server}:${project_location}/${project}/${library}/merged/${dedup_bam_file}" "${dedup_bam_folder}/"
  exit_code_1="${?}"
  rsync -thrqe "ssh -x" "${data_server}:${project_location}/${project}/${library}/merged/${dedup_bai_file}" "${dedup_bam_folder}/"
  exit_code_2="${?}"
  
  # Stop if copying failed
  if [ "${exit_code_1}" != "0" ] || [ "${exit_code_2}" != "0" ]  
  then
      echo ""
      echo "Failed getting source data from NAS"
      echo "Script terminated"
      echo ""
      exit
  fi

  # Progress report
  echo "${sample}"

done

# Resume stopping at errors
set -e

# ================= Dispatch samples to nodes for processing ================= #

# Progress report
echo ""
echo "Submitting samples to preprocess and making"
echo ""

# Set time and account for pipeline submissions
slurm_time="--time=${time_process}"
slurm_account="--account=${account_process}"

# For each sample
for sample in ${samples}
do

  # Start pipeline on a separate node
  sbatch "${slurm_time}" "${slurm_account}" \
       "${scripts_folder}/s02_preprocess_bams.sb.sh" \
       "${sample}" \
       "${job_file}" \
       "${logs_folder}" \
       "${scripts_folder}" \
       "${pipeline_log}"
  
  # Progress report
  echo "${sample}"
  
done # Next sample
echo ""

# Progress update 
echo "Submitted all samples: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# Update pipeline log
echo "Completed s01_copy_and_dispatch: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"