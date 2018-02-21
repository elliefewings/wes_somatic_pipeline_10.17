#!/bin/bash

# a01_read_config.sh
# Parse config file for splitting and annotating variants
# Ellie Fewings; 25Oct17

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
dataset=$(get_parameter "dataset") # e.g. IGP_L1_vqsr_shf

# =============== HPC settings ============== #

working_folder=$(get_parameter "working_folder") # e.g. /scratch/medgen/users/alexey

account_to_use=$(get_parameter "Account to use on HPC") # e.g. TISCHKOWITZ-SL2
time_to_request=$(get_parameter "Max time to request (hrs.min.sec)") # e.g. 02.00.00
time_to_request=${time_to_request//./:} # substitute dots to colons 

# ============ Standard settings ============ #

scripts_folder=$(get_parameter "scripts_folder") # e.g. /scratch/medgen/scripts/wes_pipeline_08.16/p07_wes_split_ma

# ----------- Tools ---------- #

tools_folder=$(get_parameter "tools_folder") # e.g. /scratch/medgen/tools

java=$(get_parameter "java") # e.g. java/jre1.8.0_40/bin/java
java="${tools_folder}/${java}"

gatk=$(get_parameter "gatk") # e.g. gatk/gatk-3.6-0/GenomeAnalysisTK.jar
gatk="${tools_folder}/${gatk}"

ensembl_api_folder=$(get_parameter "ensembl_api_folder") # e.g. ensembl
ensembl_version=$(get_parameter "ensembl_version") # e.g. v82
ensembl_api_folder="${tools_folder}/${ensembl_api_folder}/${ensembl_version}" # e.g. .../ensembl/v82

vep_script=$(get_parameter "vep_script") # e.g. ensembl-tools/scripts/variant_effect_predictor/variant_effect_predictor.pl
vep_script="${ensembl_api_folder}/${vep_script}"

vep_cache=$(get_parameter "vep_cache") # e.g. grch37_vep_cache
vep_cache="${ensembl_api_folder}/${vep_cache}"

# ----------- Resources ---------- #

resources_folder=$(get_parameter "resources_folder") # e.g. /scratch/medgen/resources

decompressed_bundle_folder=$(get_parameter "decompressed_bundle_folder") # e.g. gatk_bundle/b37/decompressed
decompressed_bundle_folder="${resources_folder}/${decompressed_bundle_folder}"

ref_genome=$(get_parameter "ref_genome") # e.g. human_g1k_v37.fasta
ref_genome="${decompressed_bundle_folder}/${ref_genome}"

dbsnp_138=$(get_parameter "dbsnp_138") # e.g. dbsnp_138.b37.vcf
dbsnp_138="${decompressed_bundle_folder}/${dbsnp_138}"

targets_folder=$(get_parameter "targets_folder") # e.g. illumina_nextera
targets_folder="${resources_folder}/${targets_folder}"

targets_intervals=$(get_parameter "targets_intervals") # e.g. nexterarapidcapture_exome_targetedregions_v1.2.b37.intervals
targets_intervals="${targets_folder}/${targets_intervals}"

kgen_folder=$(get_parameter "kgen_folder") # e.g. phase3_1k_release20130502/vcfs
kgen_folder="${resources_folder}/${kgen_folder}"

kgen_split_vcf=$(get_parameter "kgen_split_vcf") # e.g. ALL.wgs.phase3_shapeit2_mvncall_integrated_v5a.20130502.sites.fixed.split.vcf
kgen_split_vcf="${kgen_folder}/${kgen_split_vcf}"

exac_folder=$(get_parameter "exac_folder") # e.g. exac
exac_folder="${resources_folder}/${exac_folder}"

exac_non_tcga_split_vcf=$(get_parameter "exac_non_tcga_split_vcf") # e.g. ExAC_nonTCGA.r0.3.1.sites.vep.filt.split.vcf.gz
exac_non_tcga_split_vcf="${exac_folder}/${exac_non_tcga_split_vcf}"

# ----------- Working sub-folders ---------- #

project_folder="${working_folder}/${project}" # e.g. project1

suffix=$(get_parameter "suffix") # e.g. sma_kgen_exac

split_annotate_folder="${project_folder}/${dataset}_${suffix}"
tmp_folder="${split_annotate_folder}/tmp"
logs_folder="${split_annotate_folder}/logs"

# ----------- Additional settings ---------- #

vep_fields=$(get_parameter "vep_fields") # e.g. "SYMBOL,Consequence, ... CLIN_SIG,SIFT,PolyPhen,SYMBOL_SOURCE"