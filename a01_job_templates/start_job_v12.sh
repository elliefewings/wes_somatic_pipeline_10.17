#!/bin/bash

# start_job.sh
# Start job described in the job file
# Started: Alexey Larionov, 2015
# Last updated: Alexey Larionov, 24Jan2017
# Version: 12

# Use: 
# start_job.sh job_file
# start_job.sh job_file repeat sample time

# Get job file
job_description="${1}"
job_type="${2}"
sample="${3}"
run_time="${4}"
etc="${5}"

# --- Check input for the job description file --- #

# Check that an job_description has been provided
if [ -z "${job_description}" ]
then
  echo "" 
  echo "No job file given"
  echo "" 
  echo "Standard use:"
  echo "start_job.sh job_file"
  echo ""
  echo "Use in repeat mode:"
  echo "start_job.sh job_file repeat sample time"
  echo ""  
  echo "Script terminated"
  echo ""
  exit 1
fi

# Help message
if [ "${job_description}" == "-h" ] || [ "${job_description}" == "--help" ]
then
  echo ""
  echo "Start data analysis described in the job file"
  echo ""
  echo "Standard use:"
  echo "start_job.sh job_file"
  echo ""
  echo "Use in repeat mode:"
  echo "start_job.sh job_file repeat sample time"
  echo ""  
  exit
fi

# Make full file name for the job description file
job_file="$(pwd)/${job_description}"

# Check that job description file exists
if [ ! -e "${job_file}" ]
then
  echo "" 
  echo "Job file ${job_file} does not exist"
  echo ""  
  echo "Standard use:"
  echo "start_job.sh job_file"
  echo ""
  echo "Use in repeat mode:"
  echo "start_job.sh job_file repeat sample time"
  echo ""
  echo "Script terminated"
  echo ""
  exit 1
fi

# Check the job description file format (just check the first line only)
read line1 < "${job_file}"
if [ "${line1}" != "Job description file for wes lane alignment and QC" ] && \
   [ "${line1}" != "Job description file for wes library merge pipeline" ] && \
   [ "${line1}" != "Job description file for bams preprocessing for a wes library" ] && \
   [ "${line1}" != "Job description file for somatic variant calling" ] && \
   [ "${line1}" != "Job description file for genotyping gvcfs and VQSR filtering" ] && \
   [ "${line1}" != "Job description file for hard filtering" ] && \
   [ "${line1}" != "Job description file to split and annotate VCF" ] && \
   [ "${line1}" != "Job description file for data export" ]
then
  echo "" 
  echo "Unexpected format of the job file ${job_file}"
  echo ""
  echo "Standard use:"
  echo "start_job.sh job_file"
  echo ""
  echo "Use in repeat mode:"
  echo "start_job.sh job_file repeat sample time"
  echo ""
  echo "Script terminated"
  echo "" 
  exit 1
fi

# -------- Check input for repeat jobs --------- #

if [ "${job_type}" == "repeat" ]
then
  if [ "${line1}" != "Job description file for wes lane alignment and QC" ] && \
     [ "${line1}" != "Job description file for wes library merge pipeline" ] && \
     [ "${line1}" != "Job description file for bams preprocessing and making gvcfs for a wes library" ]
  then
    echo "" 
    echo "Repeating one sample is not applicable to this step of the pipeline"
    echo ""
    echo "Use:"
    echo "start_job.sh job_file"
    echo ""
    echo "Script terminated"
    echo "" 
    exit 1
  fi
fi

if [ ! -z "${job_type}" ] && [ "${job_type}" != "repeat" ]
then
  echo "Unexpected job type: ${job_type}"
  echo ""
  echo "Standard use:"
  echo "start_job.sh job_file"
  echo ""
  echo "Use in repeat mode:"
  echo "start_job.sh job_file repeat sample time"
  echo ""
  echo "Script terminated"
  exit 1
fi

if [ "${job_type}" == "repeat" ] && [ -z "${sample}" ]
  then
  echo "No sample is given to repeat"
  echo ""
  echo "Standard use:"
  echo "start_job.sh job_file"
  echo ""
  echo "Use in repeat mode:"
  echo "start_job.sh job_file repeat sample time"
  echo ""
  echo "Script terminated"
  exit 1
fi

if [ "${job_type}" == "repeat" ] && [ -z "${run_time}" ]
  then
  echo "No time is given to repeat run"
  echo ""
  echo "Standard use:"
  echo "start_job.sh job_file"
  echo ""
  echo "Use in repeat mode:"
  echo "start_job.sh job_file repeat sample time"
  echo ""
  echo "Script terminated"
  exit 1
fi

check_time=$(grep '^[0-2][0-9]:[0-6][0-9]:[0-6][0-9]$' <<< "${run_time}")
if [ "${job_type}" == "repeat" ] && [ -z "${check_time}" ]
  then
  echo "Wrong time format"
  echo "Should be hh:mm"
  echo ""
  echo "Standard use:"
  echo "start_job.sh job_file"
  echo ""
  echo "Use in repeat mode:"
  echo "start_job.sh job_file repeat sample time"
  echo ""
  echo "Script terminated"
  exit 1
fi

if [ "${job_type}" == "repeat" ] && [ ! -z "${etc}" ]
  then
  echo "Unexpected parameter(s) in the command line"
  echo ""
  echo "Standard use:"
  echo "start_job.sh job_file"
  echo ""
  echo "Use in repeat mode:"
  echo "start_job.sh job_file repeat sample time"
  echo ""
  echo "Script terminated"
  exit 1
fi

# ------------ Start pipeline ------------ #

# Get scripts folder from the job file
scripts_folder=$(awk '$1=="scripts_folder:" {print $2}' "${job_file}")

# Repeat-one-sample job
if [ "${job_type}" == "repeat" ]
then
  
  # Start script name 
  start_script="x01_repeat_one_sample.sh"

  # Ask user to confirm the job before launching
  
  echo ""
  echo "Requested job:"
  echo ""
  echo "Job launching script: ${scripts_folder}/${start_script}"
  echo "Job description file: ${job_file}"
  echo "Job type: ${job_type}"
  echo "Sample: ${sample}"
  echo "Time: ${run_time}"
  echo ""
  echo "Start this job? y/n"
  read user_choice
  
  if [ "${user_choice}" != "y" ]
  then
    echo ""
    echo "Script terminated"
    echo ""
    exit
  fi
  
  # Start the job
  echo ""
  "${scripts_folder}/${start_script}" "${job_file}" "${scripts_folder}" "${sample}" "${run_time}" 
  echo ""

# A standard batch run
else

  # Get start script name from the job file
  start_script=$(awk '$1=="start_script:" {print $2}' "${job_file}")
  
  # Ask user to confirm the job before launching
  
  echo ""
  echo "Requested job:"
  echo ""
  echo "Pipeline launching script: ${scripts_folder}/${start_script}"
  echo "Job description file: ${job_file}"
  echo ""
  echo "Start this job? y/n"
  read user_choice
  
  if [ "${user_choice}" != "y" ]
  then
    echo ""
    echo "Script terminated"
    echo ""
    exit
  fi
  
  # Start the job
  echo ""
  "${scripts_folder}/${start_script}" "${job_file}" "${scripts_folder}" 
  echo ""

fi
