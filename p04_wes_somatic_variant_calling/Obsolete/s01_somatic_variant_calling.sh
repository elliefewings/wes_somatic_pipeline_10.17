#!/bin/bash

# s01_somatic_variant_calling.sh
# variant_calling, add locations IDs and multiallelic flag; calculate stats for raw VCFs
# Ellie Fewings, 11Oct2017

# Stop at any error
set -e

# Read parameters
job_file="${1}"
scripts_folder="${2}"

# Update pipeline log
echo "Started s01_somatic_variant_calling: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# Set parameters
source "${scripts_folder}/a01_read_config.sh"
echo "Read settings"
echo ""

# Make folders
tmp_folder="${raw_vcf_folder}/tmp"
mkdir -p "${tmp_folder}"
mkdir -p "${vcfstats_folder}"
mkdir -p "${histograms_folder}"

# Go to working folder
init_dir="$(pwd)"
cd "${raw_vcf_folder}"

# --- Copy source bams to cluster --- #

# Progress report
echo "Started copying source data"
echo ""

# Initialise file for list of source bams
source_bams="${raw_vcf_folder}/${dataset}.list"
> "${source_bams}"

# Suspend stopping at errors
set +e

# Copy data
rsync -thrqe "ssh -x" "${data_server}:${project_location}/${project}/processed/f01_bams/*.bam" "${tmp_folder}/"
exit_code_1="${?}"

rsync -thrqe "ssh -x" "${data_server}:${project_location}/${project}/processed/f01_bams/*.bai" "${tmp_folder}/"
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

# Add bam file name to the list of source bams
echo "${tmp_folder}/*.bam" >> "${source_bams}"

# Restore stopping at errors
set -e

# Progress report
echo ""
echo "Completed copying source data: $(date +%d%b%Y_%H:%M:%S)"
echo ""
# --- Somatic variant calling --- #

# Progress report
echo "Started somatic variant calling"

# File names
raw_vcf="${tmp_folder}/${dataset}_raw.vcf"
variant_calling_log="${logs_folder}/${dataset}_variant_calling.log"

tum="${tmp_folder}/${tumour_bam}_idr_bqr.bam"
norm="${tmp_folder}/${normal_bam}_idr_bqr.bam"

# Variant calling across one sample only
"${java}" -Xmx60g -jar "${gatk}" \
  -T MuTect2 \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -maxAltAlleles "${maxAltAlleles}" \
  -stand_call_conf "${stand_call_conf}" \
  -nda \
  -I:tumor "${tum}" \
  -I:normal "${norm}" \
  -nct 30 \
  -o "${raw_vcf}" &>  "${variant_calling_log}"


# Standard call confidence is set to the GATK default (30.0)

# Multiple Alt alleles options:
# the alt alleles are not necesserely given in frequency order
# -nda : show number of discovered alt alleles
# maxAltAlleles : how many of the Alt alleles will be genotyped (default 6)

# Progress report
echo "Completed somatic variant calling: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Trim the variants --- #
# Removes variants and alleles that have not been detected in any genotype

# Progress report
echo "Started trimming variants"

# File names
trim_vcf="${tmp_folder}/${dataset}_trim.vcf"
trim_log="${logs_folder}/${dataset}_trim.log"

"${java}" -Xmx60g -jar "${gatk}" \
  -T SelectVariants \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -V "${raw_vcf}" \
  -o "${trim_vcf}" \
  --excludeNonVariants \
  --removeUnusedAlternates \
  -nt 14 &>  "${trim_log}"

# Note: 
# This trimming may not be necessary for most analyses. 
# For instance, it looked excessive in wecare analysis
# because it does not change the num of variants: 
echo "Num of variants before trimming: $(grep -v "^#" "${raw_vcf}" | wc -l)"
echo "Num of variants after trimming: $(grep -v "^#" "${trim_vcf}" | wc -l)"

# Progress report
echo "Completed trimming variants: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Add locations IDs to INFO field --- #
# To simplyfy tracing variants locations at later steps

# Progress report
echo "Started adding locations IDs to INFO field"

# File name
trim_lid_vcf="${tmp_folder}/${dataset}_trim_lid.vcf"

# Compile names for temporary files
lid_tmp1=$(mktemp --tmpdir="${tmp_folder}" "${dataset}_lid_tmp1".XXXXXX)
lid_tmp2=$(mktemp --tmpdir="${tmp_folder}" "${dataset}_lid_tmp2".XXXXXX)
lid_tmp3=$(mktemp --tmpdir="${tmp_folder}" "${dataset}_lid_tmp3".XXXXXX)
lid_tmp4=$(mktemp --tmpdir="${tmp_folder}" "${dataset}_lid_tmp4".XXXXXX)

# Prepare data witout header
grep -v "^#" "${trim_vcf}" > "${lid_tmp1}"
awk '{printf("LocID=Loc%09d\t%s\n", NR, $0)}' "${lid_tmp1}" > "${lid_tmp2}"
awk 'BEGIN {OFS="\t"} ; { $9 = $9";"$1 ; print}' "${lid_tmp2}" > "${lid_tmp3}"
cut -f2- "${lid_tmp3}" > "${lid_tmp4}"

# Prepare header
grep "^##" "${trim_vcf}" > "${trim_lid_vcf}"
echo '##INFO=<ID=LocID,Number=1,Type=String,Description="Location ID">' >> "${trim_lid_vcf}"
grep "^#CHROM" "${trim_vcf}" >> "${trim_lid_vcf}"

# Append data to header in the output file
cat "${lid_tmp4}" >> "${trim_lid_vcf}"

# Progress report
echo "Completed adding locations IDs to INFO field: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Make mask for multiallelic variants --- #

# Progress report
echo "Started making mask for multiallelic variants"

# File names
trim_lid_ma_mask_vcf="${tmp_folder}/${dataset}_trim_lid_ma_mask.vcf"
trim_lid_ma_mask_log="${logs_folder}/${dataset}_trim_lid_ma_mask.log"

# Make mask
"${java}" -Xmx60g -jar "${gatk}" \
  -T SelectVariants \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -V "${trim_lid_vcf}" \
  -o "${trim_lid_ma_mask_vcf}" \
  -restrictAllelesTo MULTIALLELIC \
  -nt 14 &>  "${trim_lid_ma_mask_log}"

# Progress report
echo "Completed making mask: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Add flag for multiallelic variants --- #

# Progress report
echo "Started adding flag for multiallelic variants"

# File names
trim_lid_ma_vcf="${tmp_folder}/${dataset}_somatic_raw.vcf"
trim_lid_ma_log="${logs_folder}/${dataset}_somatic_raw.log"

# Add flag
"${java}" -Xmx60g -jar "${gatk}" \
  -T VariantAnnotator \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -V "${trim_lid_vcf}" \
  -comp:MultiAllelic "${trim_lid_ma_mask_vcf}" \
  -o "${trim_lid_ma_vcf}" \
  -nt 14 &>  "${trim_lid_ma_log}"

# Progress report
echo "Completed adding flag for multiallelic variants: $(date +%d%b%Y_%H:%M:%S)"
echo ""

##Deleted VQSR section and histograms, not appropriate for somatic calls

# --- Calculating vcfstats for full data emitted by HC --- #

# Progress report
echo "Started vcfstats"
echo ""

# File name
vcf_stats="${vcfstats_folder}/${dataset}_raw.vchk"

# Calculate vcf stats
"${bcftools}" stats -F "${ref_genome}" "${trim_lid_ma_vcf}" > "${vcf_stats}" 
#To be done: explore -R option to focus stats on targets:
# -R "${targets_bed}" ?? 

# Plot the stats
"${plot_vcfstats}" "${vcf_stats}" -p "${vcfstats_folder}/"
echo ""

# Progress report
echo "Completed vcfstats: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Copy output to NAS --- #

# Progress report
echo "Started copying results to NAS"

# Remove temporary files from cluster
rm -fr "${tmp_folder}"

# Suspend stopping at errors
set +e

# Copy files to NAS
rsync -thrqe "ssh -x" "${raw_vcf_folder}" "${data_server}:${project_location}/${project}/" 
exit_code="${?}"

# Stop if copying failed
if [ "${exit_code}" != "0" ]  
then
  echo ""
  echo "Failed copying results to NAS"
  echo "Script terminated"
  echo ""
  exit
fi

# Restore stopping at errors
set -e

# Progress report to log on NAS
log_on_nas="${project_location}/${project}/${raw_vcf_folder}/logs/${dataset}_somatic_variant_calling.log"

ssh -x "${data_server}" "echo \"Completed copying results to NAS: $(date +%d%b%Y_%H:%M:%S)\" >> ${log_on_nas}"
ssh -x "${data_server}" "echo \"\" >> ${log_on_nas}"

# Progress report to log on HPC
echo "Completed copying results to NAS: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# Remove bulk results from cluster

#rm -fr "${logs_folder}"
#rm -fr "${vqsr_folder}"
#rm -fr "${histograms_folder}"
#rm -fr "${vcfstats_folder}"

rm -f "${source_bams}"

rm -f "${trim_lid_ma_vcf}"
rm -f "${trim_lid_ma_vcf}.idx"
rm -f "${trim_lid_ma_vcf_md5}"

# Progress report to log on NAS
ssh -x "${data_server}" "echo \"Removed bulk data and results from cluster\" >> ${log_on_nas}"
ssh -x "${data_server}" "echo \"\" >> ${log_on_nas}"

# Progress report to log on HPC
echo "Removed bulk data and results from cluster"
echo ""

# Return to the initial folder
cd "${init_dir}"
