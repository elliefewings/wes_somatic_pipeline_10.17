#!/bin/bash

# a01_read_config.sh
# Parse congig file for wes library merge pipeline
# Ellie Fewings, 06Oct17

# Function for reading parameters
function get_parameter()
{
	local parameter="${1}"
  local line
	line=$(awk -v p="${parameter}" 'BEGIN { FS=":" } $1 == p {print $2}' "${job_file}") 
	echo ${line} # return value
}

# === Data location and analysis settings === # 

data_server=$(get_parameter "Data server") # e.g. admin@mgqnap.medschl.cam.ac.uk
project_location=$(get_parameter "Project location") # e.g. /share/alexey

project=$(get_parameter "project") # e.g. project1
library=$(get_parameter "library") # e.g. library1
lanes=$(get_parameter "lanes") # e.g. lane1 lane2 lane3 ...

tests_set=$(get_parameter "tests_set") # full / limited

run_qualimap=$(get_parameter "run_qualimap") # yes or no
run_samstat=$(get_parameter "run_samstat") # yes or no

# =============== HPC settings ============== #

working_folder=$(get_parameter "working_folder") # e.g. /scratch/medgen/users/alexey
project_folder="${working_folder}/${project}"
library_folder="${working_folder}/${project}/${library}"

account_copy_in=$(get_parameter "Account to use for copying source files into HPC") # e.g. TISCHKOWITZ-SL2
time_copy_in=$(get_parameter "Max time requested for copying source files (hrs.min.sec)") # e.g. 00.30.00
time_copy_in=${time_copy_in//./:} # substitute dots to colons 

account_merge_qc=$(get_parameter "Account to use for merging and QC") # e.g. TISCHKOWITZ-SL2
time_merge_qc=$(get_parameter "Max time requested for merging and QC (hrs.min.sec)") # e.g. 02.00.00
time_merge_qc=${time_merge_qc//./:} # substitute dots to colons
 
account_move_out=$(get_parameter "Account to use for moving results out of HPC") # e.g. TISCHKOWITZ-SL2
time_move_out=$(get_parameter "Max time requested for moving results out of HPC (hrs.min.sec)") # e.g. 00.30.00
time_move_out=${time_move_out//./:} # substitute dots to colons

# ============ Standard settings ============ #

scripts_folder=$(get_parameter "scripts_folder") # e.g. /scratch/medgen/scripts/wes_library_merge

# ----------- Tools ---------- #

tools_folder=$(get_parameter "tools_folder") # e.g. /scratch/medgen/tools

java=$(get_parameter "java") # e.g. java/jre1.8.0_40/bin/java
java="${tools_folder}/${java}"

samtools=$(get_parameter "samtools") # e.g. samtools/samtools-1.2/bin/samtools
samtools="${tools_folder}/${samtools}"

samtools_folder=$(get_parameter "samtools_folder") # e.g. samtools/samtools-1.2/bin
samtools_folder="${tools_folder}/${samtools_folder}"
PATH="${samtools_folder}:${PATH}" # samstat needs samtools in the PATH

picard=$(get_parameter "picard") # e.g. picard/picard-2.6.0/picard.jar
picard="${tools_folder}/${picard}"

r_folder=$(get_parameter "r_folder") # e.g. r/R-3.2.0/bin
r_folder="${tools_folder}/${r_folder}"
PATH="${r_folder}:${PATH}" # picard, GATK and Qualimap need R in the PATH

qualimap=$(get_parameter "qualimap") # e.g. qualimap/qualimap_v2.1.1/qualimap.modified
qualimap="${tools_folder}/${qualimap}"

gnuplot=$(get_parameter "gnuplot") # e.g. gnuplot/gnuplot-5.0.1/bin/gnuplot
gnuplot="${tools_folder}/${gnuplot}"

LiberationSansRegularTTF=$(get_parameter "LiberationSansRegularTTF") # e.g. fonts/liberation-fonts-ttf-2.00.1/LiberationSans-Regular.ttf
LiberationSansRegularTTF="${tools_folder}/${LiberationSansRegularTTF}"

samstat=$(get_parameter "samstat") # e.g. samstat/samstat-1.5.1/bin/samstat
samstat="${tools_folder}/${samstat}"

# ----------- Resources ---------- #

resources_folder=$(get_parameter "resources_folder") # e.g. /scratch/medgen/resources

ref_genome=$(get_parameter "ref_genome") # e.g. gatk_bundle/b37/decompressed/human_g1k_v37.fasta
ref_genome="${resources_folder}/${ref_genome}"

bait_set_name=$(get_parameter "bait_set_name") # e.g. Nexera_Rapid_Capture_Exome

probes_intervals=$(get_parameter "probes_intervals") 
# e.g. illumina_nextera/nexterarapidcapture_exome_probes_v1.2.b37.intervals
probes_intervals="${resources_folder}/${probes_intervals}"

targets_intervals=$(get_parameter "targets_intervals") 
# e.g. illumina_nextera/nexterarapidcapture_exome_targetedregions_v1.2.b37.intervals
targets_intervals="${resources_folder}/${targets_intervals}"

targets_bed_3=$(get_parameter "targets_bed_3") 
# e.g. illumina_nextera/nexterarapidcapture_exome_targetedregions_v1.2.b37.bed
targets_bed_3="${resources_folder}/${targets_bed_3}"

targets_bed_6=$(get_parameter "targets_bed_6") 
# e.g. illumina_nextera/nexterarapidcapture_exome_targetedregions_v1.2.b37.6.bed
targets_bed_6="${resources_folder}/${targets_bed_6}"

# ----------- Working folders ---------- #

merged_folder="${library_folder}/merged"

logs_folder=$(get_parameter "logs_folder") # e.g. f00_logs
logs_folder="${merged_folder}/${logs_folder}"

bam_folder=$(get_parameter "bam_folder") # e.g. f01_bams
bam_folder="${merged_folder}/${bam_folder}"

flagstat_folder=$(get_parameter "flagstat_folder") # e.g. f02_metrics/f01_flagstat
flagstat_folder="${merged_folder}/${flagstat_folder}"

picard_mkdup_folder=$(get_parameter "picard_mkdup_folder") # e.g. f02_metrics/f02_picard/f01_mkdup_metrics
picard_mkdup_folder="${merged_folder}/${picard_mkdup_folder}"

picard_inserts_folder=$(get_parameter "picard_inserts_folder") # e.g. f02_metrics/f02_picard/f02_inserts_metrics
picard_inserts_folder="${merged_folder}/${picard_inserts_folder}"

picard_alignment_folder=$(get_parameter "picard_alignment_folder") # e.g. f02_metrics/f02_picard/f03_alignment_metrics
picard_alignment_folder="${merged_folder}/${picard_alignment_folder}"

picard_hybridisation_folder=$(get_parameter "picard_hybridisation_folder") # e.g. f02_metrics/f02_picard/f04_hybridisation_metrics
picard_hybridisation_folder="${merged_folder}/${picard_hybridisation_folder}"

picard_summary_folder=$(get_parameter "picard_summary_folder") # e.g. f02_metrics/f02_picard/f05_metrics_summaries
picard_summary_folder="${merged_folder}/${picard_summary_folder}"

qualimap_results_folder=$(get_parameter "qualimap_results_folder") # e.g. f02_metrics/f03_qualimap
qualimap_results_folder="${merged_folder}/${qualimap_results_folder}"

samstat_results_folder=$(get_parameter "samstat_results_folder") # e.g. f02_metrics/f04_samstat
samstat_results_folder="${merged_folder}/${samstat_results_folder}"

gatk_diagnose_targets_folder=$(get_parameter "gatk_diagnose_targets_folder") # e.g. f02_metrics/f05_gatk/f01_diagnose_targets
gatk_diagnose_targets_folder="${merged_folder}/${gatk_diagnose_targets_folder}"

gatk_depth_of_coverage_folder=$(get_parameter "gatk_depth_of_coverage_folder") # e.g. f02_metrics/f05_gatk/f02_depth_of_coverage
gatk_depth_of_coverage_folder="${merged_folder}/${gatk_depth_of_coverage_folder}"
