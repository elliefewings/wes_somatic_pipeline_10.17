#!/bin/bash

# a00_start_pipeline.sh
# Start splitting and annotating variants
# Ellie Fewings; 25Oct17

## Read parameter
job_file="${1}"
scripts_folder="${2}"

# Read job's settings
source "${scripts_folder}/a01_read_config.sh"

# Make working folders and start log
mkdir -p "${split_annotate_folder}"
mkdir -p "${tmp_folder}"
mkdir -p "${logs_folder}"
log="${logs_folder}/${dataset}_${suffix}.log"

echo "WES: splitting and annotating variants" > "${log}"
echo "${set_id}" >> "${log}" 
echo "Started: $(date +%d%b%Y_%H:%M:%S)" >> "${log}"
echo "" >> "${log}" 

echo "====================== Settings ======================" >> "${log}"
echo "" >> "${log}"

source "${scripts_folder}/a02_report_settings.sh" >> "${log}"

echo "=================== Pipeline steps ===================" >> "${log}"
echo "" >> "${log}"

# Submit job
slurm_time="--time=${time_to_request}"
slurm_account="--account=${account_to_use}"

sbatch "${slurm_time}" "${slurm_account}" \
  "${scripts_folder}/s01_split_annotate.sb.sh" \
  "${job_file}" \
  "${scripts_folder}" \
  "${log}"

# Update pipeline log
echo "" >> "${log}"
echo "Submitted s01_split_annotate: $(date +%d%b%Y_%H:%M:%S)" >> "${log}"
echo "" >> "${log}"