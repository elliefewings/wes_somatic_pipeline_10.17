#!/bin/bash

# s03_results.sh
# Save results to NAS
# Ellie Fewings, 11Oct17

# Stop at any error
set -e

# Read parameters
job_file="${1}"
scripts_folder="${2}"
pipeline_log="${3}"

# Update pipeline log
echo "Started making summaries and plots for merged wes samples: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"

# Set environment and start job log
echo "Saving procecced bams to NAS"
echo "Started: $(date +%d%b%Y_%H:%M:%S)"
echo ""

source "${scripts_folder}/a01_read_config.sh"
echo "Read settings"
echo ""

# Get list of samples
samples=$(awk 'NR>1 {print $1}' "${merged_folder}/samples.txt")

# Suspend stopping at errors
set +e

# Copy processed bamss
rsync -thrve "ssh -x" "${processed_folder}" "${data_server}:${project_location}/${project}/${library}/"
exit_code_1="${?}"

# Stop if copying failed
if [ "${exit_code_1}" != "0" ] || \
   [ "${exit_code_2}" != "0" ]
then
  echo ""
  echo "Failed copying results to NAS"
  echo "Script terminated"
  echo ""
  exit
fi

# Resume stopping at errors
set -e

# Progress messages
echo ""
echo "Completed saving results to NAS: $(date +%d%b%Y_%H:%M:%S)"
echo ""
echo "Completed all tasks"
echo ""

echo "Saved results to NAS: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"
echo "Done all pipeline tasks" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"

# Update logs on NAS
scp -qp "${logs_folder}/s03_save_results.log" "${data_server}:${project_location}/${project}/${library}/processed/f00_logs/s03_save_results.log"
scp -qp "${pipeline_log}" "${data_server}:${project_location}/${project}/${library}/processed/f00_logs/a00_pipeline.log" 

# Remove bulk results from cluster 
rm -fr "${proc_bam_folder}"
rm -fr "${dedup_bam_folder}"


# Update logs on NAS
ssh -x "${data_server}" "echo \"Removed bulk data from cluster\" >> ${project_location}/${project}/${library}/processed/f00_logs/s03_save_results.log"
ssh -x "${data_server}" "echo \"Removed bulk data from cluster\" >> ${project_location}/${project}/${library}/processed/f00_logs/a00_pipeline.log"
