#!/bin/bash

# s01_repeat_one_sample.sh
# Start alignment of one sample failed in the previous batch
# Assuming the source files have been copied and the folders structure etc created
# Ellie Fewings, 06Oct17

# Stop at any errors
set -e

# Read parameters
job_file="${1}"
scripts_folder="${2}"
sample="${3}"
run_time="${4}"

# Read job's settings
source "${scripts_folder}/a01_read_config.sh"

# Check existance of the pipeline log
pipeline_log="${logs_folder}/a00_pipeline_${project}_${library}_${lane}.log"
if [ ! -e ${pipeline_log} ]
then
  echo ""
  echo "Can not detect the pipeline log:"
  echo "${pipeline_log}"
  echo ""
  echo "Script terminated"
  echo ""
  exit 1
fi

# Read job's settings
source "${scripts_folder}/a01_read_config.sh"

# Check folders tree on cluster
if [ ! -d "${fastqc_raw_folder}" ] || \
   [ ! -d "${trimmed_fastq_folder}" ] || \
   [ ! -d "${fastqc_trimmed_folder}" ] || \
   [ ! -d "${bam_folder}" ] || \
   [ ! -d "${flagstat_folder}" ] || \
   [ ! -d "${picard_mkdup_folder}" ] || \
   [ ! -d "${picard_inserts_folder}" ] || \
   [ ! -d "${picard_alignment_folder}" ] || \
   [ ! -d "${picard_hybridisation_folder}" ] || \
   [ ! -d "${qualimap_results_folder}" ] || \
   [ ! -d "${samstat_results_folder}" ]
then
  echo ""
  echo "Can not detect the expected folders on NAS"
  echo ""
  echo "Script terminated"
  echo ""
  exit 1
fi

# Check existance of the pipeline log
pipeline_log="${logs_folder}/a00_pipeline_${project}_${library}_${lane}.log"
if [ ! -e ${samples_file} ]
then
  echo ""
  echo "Can not detect the samples file:"
  echo "${samples_file}"
  echo ""
  echo "Script terminated"
  echo ""
  exit 1
fi

# Check presence of the sample in the samples list
samples_file="${source_fastq_folder}/samples.txt"
sample_check1=$(awk -v smp="${sample}" '$1==smp' "${samples_file}")
if [ -z "${sample_check1}" ]
then
  echo ""
  echo "Can not detect sample in the samples file"
  echo ""
  echo "Script terminated"
  echo ""
  exit 1
fi

# Check absence of the sample in the log of completed samples
bam_samples_file="${lane_folder}/samples.txt"
sample_check2=$(awk -v smp="${sample}" '$1==smp' "${bam_samples_file}")
if [ ! -z "${sample_check2}" ]
then
  echo ""
  echo "Sample has been detected in the completed samples list:"
  echo "${bam_samples_file}"
  echo "Remove sample from the list of completed samples and try again"
  echo ""
  echo "Script terminated"
  echo ""
  exit 1
fi

# Prepare parameters for slurm submission
run_time="--time=${run_time}"
slurm_account="--account=${account_alignment_qc}"

# Submit job to cluster
sbatch "${run_time}" "${slurm_account}" \
       "${scripts_folder}/s02_align_and_qc.sb.sh" \
       "${sample}" \
       "${job_file}" \
       "${logs_folder}" \
       "${scripts_folder}" \
       "${pipeline_log}" \
       "${data_type}"
  
# Progress report to pipeline log
echo "" >> "${pipeline_log}"
echo "Attempting repeated alignment for ${sample}" >> "${pipeline_log}"
echo "  Requested time: ${run_time}"  >> "${pipeline_log}"
echo "  Passed basic checks" >> "${pipeline_log}"
echo "  Submitted job to HPC: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"
