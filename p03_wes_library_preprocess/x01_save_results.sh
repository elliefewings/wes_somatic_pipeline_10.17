#!/bin/bash

# x01_save_results.sh
# Manually launch results saving
# Alexey Larionov, 27Aug2016

# Stop at any error
set -e

# Set parameters
job_file="/scratch/medgen/scripts/wes_pipeline_08.16/a01_job_templates/TEMPLATE_03_wes_library_preprocess_gvcf_v1.job"
scripts_folder="/scratch/medgen/scripts/wes_pipeline_08.16/p03_wes_library_preprocess_gvcf/"
pipeline_log="/scratch/medgen/users/eleanor/Pipeline_working_directory/gastric_Aug16/gastric/IGP_L1/processed/f00_logs/a00_pipeline.log"
logs_folder="/scratch/medgen/users/eleanor/Pipeline_working_directory/gastric_Aug16/gastric/IGP_L1/processed/f00_logs/"
slurm_time="--time=05:00:00"
slurm_account="--account=TISCHKOWITZ-SL2"

# Submit job to save results to NAS
sbatch "${slurm_time}" "${slurm_account}" \
     "${scripts_folder}/s03_save_results.sb.sh" \
     "${job_file}" \
     "${logs_folder}" \
     "${scripts_folder}" \
     "${pipeline_log}"

# Report to pipeline log
echo "Manually re-submitted job to save results to NAS" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"

