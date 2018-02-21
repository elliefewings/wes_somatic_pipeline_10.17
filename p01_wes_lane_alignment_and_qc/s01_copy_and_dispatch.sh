#!/bin/bash

# s01_copy_and_dispatch.sh
# Wes lane alignment pipeline
# Copy source files and dispatch samples to nodes
# Ellie Fewings, 06Oct17

# Stop at any errors
set -e

# Read parameters
job_file="${1}"
scripts_folder="${2}"
pipeline_log="${3}"

# Update pipeline log
echo "Started s01_copy_and_dispatch: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"

# ================= Copy source files to cluster ================= #

# Progress report to the job log
echo "Started copying source fastq files to cluster"
echo ""

# Set parameters
source "${scripts_folder}/a01_read_config.sh"
echo "Read settings"
echo ""

# Copy files
mkdir -p "${source_fastq_folder}"

# Suspend stopping at errors
set +e

rsync -thrve "ssh -x" "${source_server}:${source_folder}/" "${source_fastq_folder}/" 
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

# Restore stopping at errors
set -e

# Completion message to the job log
echo ""
echo "Completed copying source fastq files to cluster: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ================= Dispatch samples to nodes for processing ================= #

# Make folders on cluster
mkdir -p "${fastqc_raw_folder}"
mkdir -p "${trimmed_fastq_folder}"
mkdir -p "${fastqc_trimmed_folder}"
mkdir -p "${bam_folder}"
mkdir -p "${flagstat_folder}"
mkdir -p "${picard_mkdup_folder}"
mkdir -p "${picard_inserts_folder}"
mkdir -p "${picard_alignment_folder}"
mkdir -p "${picard_hybridisation_folder}"
mkdir -p "${qualimap_results_folder}"
mkdir -p "${samstat_results_folder}"

# Progress update 
echo "Made working folders on cluster"
echo ""

# Get list of samples
samples_file="${source_fastq_folder}/samples.txt"
samples=$(awk '$1 != "sample" {print $1}' "${samples_file}")

# Count samples and check that all source files exist for each sample
samples_count=0

# Suspend stopping at errors
set +e

# pe data
if [ "${data_type}" == "pe" ]
then 
  while read sample_id fastq1 fastq2 md5
  do
    if [ "${sample_id}" != "sample" ]
    then
    
      # Increment samples count
      samples_count="$(( ${samples_count} + 1 ))"
    
      # fastq1
      if [ ! -e "${source_fastq_folder}/${fastq1}" ]
      then
        echo "Missed fastq1 for sample ${sample_id}"
        echo "Pipeline treminated"
        exit 1
      fi
    
      # fastq2
      if [ ! -e "${source_fastq_folder}/${fastq2}" ]
      then
        echo "Missed fastq2 for sample ${sample_id}"
        echo "Pipeline treminated"
        exit 1
      fi
    
      # md5
      if [ ! -e "${source_fastq_folder}/${md5}" ]
      then
        echo "Missed md5 for sample ${sample_id}"
        echo "Pipeline treminated"
        exit 1
      fi
      
    fi
  done < "${samples_file}"

  # Progress report
  echo "Found data for ${samples_count} ${data_type} samples"

# se data
elif [ "${data_type}" == "se" ]
then

  while read sample_id fastq md5
  do
    if [ "${sample_id}" != "sample" ]
    then
    
      # Increment samples count
      samples_count="$(( ${samples_count} + 1 ))"
    
      # fastq
      if [ ! -e "${source_fastq_folder}/${fastq1}" ]
      then
        echo "Missed fastq1 for sample ${sample_id}"
        echo "Pipeline treminated"
        exit 1
      fi
    
      # md5
      if [ ! -e "${source_fastq_folder}/${md5}" ]
      then
        echo "Missed md5 for sample ${sample_id}"
        echo "Pipeline treminated"
        exit 1
      fi
      
    fi
  done < "${samples_file}"

  # Progress report
  echo "Found data for ${samples_count} ${data_type} samples"

else

  echo "Wrong data_type: ${data_type}"
  echo "Pipeline treminated"
  exit 1

fi

# Restore stopping at errors
set -e

# Progress report
echo "Submitting samples:"
echo ""

# Set time and account for pipeline submissions
slurm_time="--time=${time_alignment_qc}"
slurm_account="--account=${account_alignment_qc}"

# For each sample
for sample in ${samples}
do

  # Start pipeline on a separate node
  sbatch "${slurm_time}" "${slurm_account}" \
         "${scripts_folder}/s02_align_and_qc.sb.sh" \
         "${sample}" \
         "${job_file}" \
         "${logs_folder}" \
         "${scripts_folder}" \
         "${pipeline_log}" \
         "${data_type}"
  
  # Progress report
  echo "${sample}"
  
done # Next sample
echo ""

# Progress update 
echo "Submitted all samples: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# Update pipeline log
echo "Detected ${samples_count} ${data_type} samples" >> "${pipeline_log}"
echo "Completed s01_copy_and_dispatch: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"