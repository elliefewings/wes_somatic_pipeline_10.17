#!/bin/bash

# s01_hard_filter_vcf.sh
# Filtering vcf
# Ellie Fewings, 18Oct17

# Ref:
# http://gatkforums.broadinstitute.org/gatk/discussion/2806/howto-apply-hard-filters-to-a-call-set

# stop at any error
set -e

# Read parameters
job_file="${1}"
scripts_folder="${2}"

# Update pipeline log
echo "Started s01_filter_vcf: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# Set parameters
source "${scripts_folder}/a01_read_config.sh"
echo "Read settings"
echo ""

# Go to working folder
init_dir="$(pwd)"
cd "${filtered_vcf_folder}"

# --- Copy source gvcfs to cluster --- #

# Progress report
echo "Started copying source data"

# Source files and folders (on source server)
raw_vcf_folder="${dataset_name}_raw"
raw_vcf="${dataset_name}_raw.vcf"

# Intermediate files and folders on HPC
tmp_folder="${filtered_vcf_folder}/tmp"
mkdir -p "${tmp_folder}"
mkdir -p "${histograms_folder}"
mkdir -p "${vcfstats_folder}"

# --- Copy data --- #

# Suspend stopping at errors
set +e

rsync -thrqe "ssh -x" "${data_server}:${project_location}/${project}/${raw_vcf_folder}/${raw_vcf}" "${tmp_folder}/"
exit_code_1="${?}"

rsync -thrqe "ssh -x" "${data_server}:${project_location}/${project}/${raw_vcf_folder}/${raw_vcf}.idx" "${tmp_folder}/"
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

# Restore stopping at errors
set -e

# Progress report
echo "Completed copying source data: $(date +%d%b%Y_%H:%M:%S)"
echo ""


# --- Trim the variants --- #
# Removes variants and alleles that have not been detected in any genotype

# Progress report
echo "Started trimming variants"

# File names
trim_vcf="${tmp_folder}/${dataset_name}_trim.vcf"
trim_log="${logs_folder}/${dataset_name}_trim.log"

"${java}" -Xmx60g -jar "${gatk}" \
  -T SelectVariants \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -V "${tmp_folder}/${raw_vcf}" \
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
trim_lid_vcf="${tmp_folder}/${dataset_name}_trim_lid.vcf"

# Compile names for temporary files
lid_tmp1=$(mktemp --tmpdir="${tmp_folder}" "${dataset_name}_lid_tmp1".XXXXXX)
lid_tmp2=$(mktemp --tmpdir="${tmp_folder}" "${dataset_name}_lid_tmp2".XXXXXX)
lid_tmp3=$(mktemp --tmpdir="${tmp_folder}" "${dataset_name}_lid_tmp3".XXXXXX)
lid_tmp4=$(mktemp --tmpdir="${tmp_folder}" "${dataset_name}_lid_tmp4".XXXXXX)

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
trim_lid_ma_mask_vcf="${tmp_folder}/${dataset_name}_trim_lid_ma_mask.vcf"
trim_lid_ma_mask_log="${logs_folder}/${dataset_name}_trim_lid_ma_mask.log"

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
trim_lid_ma_vcf="${tmp_folder}/${dataset_name}_somatic_raw.vcf"
trim_lid_ma_log="${logs_folder}/${dataset_name}_somatic_raw.log"

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
vcf_stats="${vcfstats_folder}/${dataset_name}_raw.vchk"

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


# --- Remove filtered variants from vcf --- #

# Progress report
echo "Started removing filtered variants from vcf"

# File names
cln_vcf="${filtered_vcf_folder}/${dataset_name}_${filter_name}.vcf"
cln_vcf_md5="${filtered_vcf_folder}/${dataset_name}_${filter_name}.md5"
cln_vcf_log="${logs_folder}/${dataset_name}_${filter_name}_cln.log"

# Remove filtered variants
"${java}" -Xmx60g -jar "${gatk}" \
  -T SelectVariants \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -V "${trim_lid_ma_vcf}" \
  -o "${cln_vcf}" \
  --excludeFiltered \
  -nt 14 &>  "${cln_vcf_log}"

# Make md5 file
md5sum $(basename "${cln_vcf}") $(basename "${cln_vcf}.idx") > "${cln_vcf_md5}"

# Completion message to log
echo "Completed removing filtered variants from vcf: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- vcfstats --- #

# Progress report
echo "Started calculating vcfstats and making plots for filtered variants"
echo ""

# File names
vcf_stats="${vcfstats_folder}/${dataset_name}_${filter_name}_cln.vchk"

# Calculate vcf stats
"${bcftools}" stats -F "${ref_genome}" "${cln_vcf}" > "${vcf_stats}" 

# Plot the stats
"${plot_vcfstats}" "${vcf_stats}" -p "${vcfstats_folder}/"
echo ""

# Completion message to log
echo "Completed calculating vcf stats: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Copy results to NAS --- #

# Progress report
echo "Started copying results to NAS"

# Remove temporary data
rm -fr "${tmp_folder}"

# --- Copy files to NAS --- #

# Suppress stopping at errors
set +e

rsync -thrqe "ssh -x" "${filtered_vcf_folder}" "${data_server}:${project_location}/${project}/" 
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

# Resume stopping at errors
set -e

# Progress report to log on nas
log_on_nas="${project_location}/${project}/${dataset_name}_${filter_name}/logs/${dataset_name}_${filter_name}.log"
timestamp="$(date +%d%b%Y_%H:%M:%S)"
ssh -x "${data_server}" "echo \"Completed copying results to NAS: ${timestamp}\" >> ${log_on_nas}"
ssh -x "${data_server}" "echo \"\" >> ${log_on_nas}"

# Remove results from cluster
rm -f "${cln_vcf}"
rm -f "${cln_vcf}.idx"
rm -f "${cln_vcf_md5}"

#rm -fr "${logs_folder}"
#rm -fr "${histograms_folder}"
#rm -fr "${vcfstats_folder}"

ssh -x "${data_server}" "echo \"Removed vcfs from cluster\" >> ${log_on_nas}"
ssh -x "${data_server}" "echo \"\" >> ${log_on_nas}"

# Return to the initial folder
cd "${init_dir}"
