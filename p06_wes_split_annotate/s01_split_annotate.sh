#!/bin/bash

# s01_split_annotate.sh
# Split and annotate variants
# Ellie Fewings; 25Oct17

# Stop at any error
set -e

# Read parameters
job_file="${1}"
scripts_folder="${2}"

# Update pipeline log
echo "Started s01_split_ma: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# Set parameters
source "${scripts_folder}/a01_read_config.sh"
echo "Read settings"
echo ""

# Go to working folder
init_dir="$(pwd)"
cd "${split_annotate_folder}"

# --- Copy source gvcfs to cluster --- #

# Progress report
echo "Started copying source data"

# Source files and folders (on source server)
source_vcf_folder="${dataset}"
source_vcf="${dataset}.vcf"

# Suspend stopping at errors
set +e

rsync -thrqe "ssh -x" "${data_server}:${project_location}/${project}/${source_vcf_folder}/${source_vcf}" "${tmp_folder}/"
exit_code_1="${?}"

rsync -thrqe "ssh -x" "${data_server}:${project_location}/${project}/${source_vcf_folder}/${source_vcf}.idx" "${tmp_folder}/"
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

# --- Split multiallelic variants --- #
# Splits multiallelic variants to separate lanes and left-aligns indels

# File names
source_vcf="${tmp_folder}/${source_vcf}"
split_vcf="${tmp_folder}/${dataset}_split.vcf"
split_log="${logs_folder}/${dataset}_split.log"

# Progress report
echo "Started splitting multiallelic variants"
echo "Num of variants before splitting:"
grep -v "^#" "${source_vcf}" | wc -l
echo ""

# Split ma sites
"${java}" -Xmx60g -jar "${gatk}" \
  -T LeftAlignAndTrimVariants \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -V "${source_vcf}" \
  -o "${split_vcf}" \
  --splitMultiallelics &> "${split_log}"

# Progress report
echo "Completed splitting multiallelic variants: $(date +%d%b%Y_%H:%M:%S)"
echo "Num of variants after splitting: "
grep -v "^#" "${split_vcf}" | wc -l
echo ""

# --- Clean vcf after splitting multiallelic variants --- #

# Progress report
echo "Started cleaning vcf after splitting multiallelic variants"
echo ""

# Set file names
split_cln_vcf="${tmp_folder}/${dataset}_split_cln.vcf"
sma_head="${tmp_folder}/sma_vcf_header.txt"
sma_tab="${tmp_folder}/sma_vcf_tab.txt"
sma_tab_cln1="${tmp_folder}/sma_vcf_tab_cln1.txt"
sma_tab_cln2="${tmp_folder}/sma_vcf_tab_cln2.txt"

# Get vcf header and table
grep "^#" "${split_vcf}" > "${sma_head}"
grep -v "^#" "${split_vcf}" > "${sma_tab}"

# Remove variants with * in ALT 
# (* in ALT is not suitable for VEP)
awk '$5 != "*"' "${sma_tab}" > "${sma_tab_cln1}"
echo "Num of variants after removing * in ALT: "
cat "${sma_tab_cln1}" | wc -l
echo ""


# Merge header and filtered body of the vcf file
cat "${sma_head}" "${sma_tab_cln1}" > "${split_cln_vcf}"

# Progress
echo "Completed cleaning after splitting: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Add variants IDs to INFO field --- #
# To make easier tracing split variants during the later steps

# Progress report
echo "Started adding split variants IDs to INFO field"

# File name
split_cln_vid_vcf="${tmp_folder}/${dataset}_split_cln_vid.vcf"

# Compile names for temporary files
vid_tmp1=$(mktemp --tmpdir="${tmp_folder}" "${dataset}_vid_tmp1".XXXXXX)
vid_tmp2=$(mktemp --tmpdir="${tmp_folder}" "${dataset}_vid_tmp2".XXXXXX)
vid_tmp3=$(mktemp --tmpdir="${tmp_folder}" "${dataset}_vid_tmp3".XXXXXX)
vid_tmp4=$(mktemp --tmpdir="${tmp_folder}" "${dataset}_vid_tmp4".XXXXXX)

# Prepare data witout header
grep -v "^#" "${split_cln_vcf}" > "${vid_tmp1}"
awk '{printf("SplitVarID=Var%09d\t%s\n", NR, $0)}' "${vid_tmp1}" > "${vid_tmp2}"
awk 'BEGIN {OFS="\t"} ; { $9 = $9";"$1 ; print}' "${vid_tmp2}" > "${vid_tmp3}"
cut -f2- "${vid_tmp3}" > "${vid_tmp4}"

# Prepare header
grep "^##" "${split_cln_vcf}" > "${split_cln_vid_vcf}"
echo '##INFO=<ID=SplitVarID,Number=1,Type=String,Description="Split Variant ID">' >> "${split_cln_vid_vcf}"
grep "^#CHROM" "${split_cln_vcf}" >> "${split_cln_vid_vcf}"

# Append data to header in the output file
cat "${vid_tmp4}" >> "${split_cln_vid_vcf}"

# Progress report
echo "Completed adding split variants IDs to INFO field: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Add alt allele data from 1k ph3 (b37) --- #

# Progress report
echo "Started adding alt allele data from kgen (ph3, b37)"

# File names
split_cln_vid_kgen_vcf="${tmp_folder}/${dataset}_split_cln_vid_kgen.vcf"
split_cln_vid_kgen_log="${logs_folder}/${dataset}_split_cln_vid_kgen.log"

# Add annotations
"${java}" -Xmx60g -jar "${gatk}" \
  -T VariantAnnotator \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -V "${split_cln_vid_vcf}" \
  -o "${split_cln_vid_kgen_vcf}" \
  -A ChromosomeCounts \
  -A Coverage \
  --resource:kgen "${kgen_split_vcf}" \
  --expression kgen.AC \
  --expression kgen.AN \
  --expression kgen.AF \
  --expression kgen.AFR_AF \
  --expression kgen.AMR_AF \
  --expression kgen.EAS_AF \
  --expression kgen.EUR_AF \
  --expression kgen.SAS_AF \
  --resourceAlleleConcordance \
  -nt 14 &>  "${split_cln_vid_kgen_log}"

# Notes: 
# --resourceAlleleConcordance may not be supported by gatk below v 3.6
# 1k phase 3 vcf include only PF variants, with multiallelic variants split to separate lines

# Progress report
echo "Completed adding alt allele data from 1k ph3 (b37): $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Add alt allele data from exac (non-tcga, b37) and IDs from dbSNP_138 --- #

# Progress report
echo "Started adding alt allele data from exac (non-tcga, b37) and IDs from dbSNP_138"

# File names
split_cln_vid_kgen_exac_vcf="${tmp_folder}/${dataset}_sma_kgen_exac.vcf"
split_cln_vid_kgen_exac_log="${logs_folder}/${dataset}_split_cln_vid_kgen_exac.log"

# Add annotations
"${java}" -Xmx60g -jar "${gatk}" \
  -T VariantAnnotator \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -V "${split_cln_vid_kgen_vcf}" \
  -o "${split_cln_vid_kgen_exac_vcf}" \
  --resource:exac_non_TCGA "${exac_non_tcga_split_vcf}" \
  --expression exac_non_TCGA.AF \
  --expression exac_non_TCGA.AC \
  --expression exac_non_TCGA.AN \
  --expression exac_non_TCGA.AC_FEMALE \
  --expression exac_non_TCGA.AN_FEMALE \
  --expression exac_non_TCGA.AC_MALE \
  --expression exac_non_TCGA.AN_MALE \
  --expression exac_non_TCGA.AC_Adj \
  --expression exac_non_TCGA.AN_Adj \
  --expression exac_non_TCGA.AC_Hom \
  --expression exac_non_TCGA.AC_Het \
  --expression exac_non_TCGA.AC_Hemi \
  --expression exac_non_TCGA.AC_AFR \
  --expression exac_non_TCGA.AN_AFR \
  --expression exac_non_TCGA.Hom_AFR \
  --expression exac_non_TCGA.Het_AFR \
  --expression exac_non_TCGA.Hemi_AFR \
  --expression exac_non_TCGA.AC_AMR \
  --expression exac_non_TCGA.AN_AMR \
  --expression exac_non_TCGA.Hom_AMR \
  --expression exac_non_TCGA.Het_AMR \
  --expression exac_non_TCGA.Hemi_AMR \
  --expression exac_non_TCGA.AC_EAS \
  --expression exac_non_TCGA.AN_EAS \
  --expression exac_non_TCGA.Hom_EAS \
  --expression exac_non_TCGA.Het_EAS \
  --expression exac_non_TCGA.Hemi_EAS \
  --expression exac_non_TCGA.AC_FIN \
  --expression exac_non_TCGA.AN_FIN \
  --expression exac_non_TCGA.Hom_FIN \
  --expression exac_non_TCGA.Het_FIN \
  --expression exac_non_TCGA.Hemi_FIN \
  --expression exac_non_TCGA.AC_NFE \
  --expression exac_non_TCGA.AN_NFE \
  --expression exac_non_TCGA.Hom_NFE \
  --expression exac_non_TCGA.Het_NFE \
  --expression exac_non_TCGA.Hemi_NFE \
  --expression exac_non_TCGA.AC_SAS \
  --expression exac_non_TCGA.AN_SAS \
  --expression exac_non_TCGA.Hom_SAS \
  --expression exac_non_TCGA.Het_SAS \
  --expression exac_non_TCGA.Hemi_SAS \
  --expression exac_non_TCGA.AC_OTH \
  --expression exac_non_TCGA.AN_OTH \
  --expression exac_non_TCGA.Hom_OTH \
  --expression exac_non_TCGA.Het_OTH \
  --expression exac_non_TCGA.Hemi_OTH \
  --dbsnp "${dbsnp_138}" \
  --resourceAlleleConcordance \
  -nt 14 &>  "${split_cln_vid_kgen_exac_log}"

# Notes: 
# --resourceAlleleConcordance may not be supported by gatk below v 3.6
# exac non-tcga vcf includes only PF variants, with multiallelic variants split to separate lines

# Progress report
echo "Completed adding alt allele data from exac and dbSNP: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Run vep script --- #

# Progress report
echo "Started VEP for full vcf file"

# Configure PERL5LIB for VEP
PERL5LIB="${ensembl_api_folder}/BioPerl-1.6.1"
PERL5LIB="${PERL5LIB}:${ensembl_api_folder}/ensembl/modules"
PERL5LIB="${PERL5LIB}:${ensembl_api_folder}/ensembl-compara/modules"
PERL5LIB="${PERL5LIB}:${ensembl_api_folder}/ensembl-variation/modules"
PERL5LIB="${PERL5LIB}:${ensembl_api_folder}/ensembl-funcgen/modules"
export PERL5LIB

# Set file names
vep_vcf="${split_annotate_folder}/${dataset}_${suffix}.vcf"
vep_stats="${split_annotate_folder}/${dataset}_${suffix}.html"
vep_script_log="${logs_folder}/${dataset}_vep_script.log"
vep_md5="${split_annotate_folder}/${dataset}_${suffix}.md5"

# Run script with vcf output
perl "${vep_script}" \
  -i "${split_cln_vid_kgen_exac_vcf}" \
  -o "${vep_vcf}" --vcf \
  --stats_file "${vep_stats}" \
  --cache --offline --dir_cache "${vep_cache}" \
  --pick --allele_number --check_existing --check_alleles \
  --symbol --gmaf --sift b --polyphen b \
  --fields "${vep_fields}" --vcf_info_field "ANN" \
  --force_overwrite --fork 14 --no_progress \
  &> "${vep_script_log}"

# Progress report
echo "Completed writing vep annotations to vcf file: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# Make md5 file for full vep-annotated vcf (we are in split_annotate_folder)
md5sum $(basename "${vep_vcf}") > "${vep_md5}"

# --- Copy results to NAS --- #

# Progress report
echo "Started copying results to NAS"

# Remove temporary data
rm -fr "${tmp_folder}"

# --- Copy files to NAS --- #

# Suppress stopping at errors
set +e

rsync -thrqe "ssh -x" "${split_annotate_folder}" "${data_server}:${project_location}/${project}/" 
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
log_on_nas="${project_location}/${project}/${dataset}_${suffix}/logs/${dataset}_${suffix}.log"
timestamp="$(date +%d%b%Y_%H:%M:%S)"
ssh -x "${data_server}" "echo \"Completed copying results to NAS: ${timestamp}\" >> ${log_on_nas}"
ssh -x "${data_server}" "echo \"\" >> ${log_on_nas}"

echo "Completed copying results to NAS: ${timestamp}"
echo ""

# Remove results from cluster
#rm -fr "${logs_folder}"
#rm -f "${vep_stats}"
rm -f "${vep_vcf}"
rm -f "${vep_md5}"

ssh -x "${data_server}" "echo \"Removed vcfs from cluster\" >> ${log_on_nas}"
ssh -x "${data_server}" "echo \"\" >> ${log_on_nas}"

echo "Removed vcfs from cluster"
echo ""

# Return to the initial folder
cd "${init_dir}"
