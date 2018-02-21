#!/bin/bash

# s01_genotype_gvcfs.sh
# Genotype gvcfs, add locations and variants IDs, VQSR annotations and multiallelic flag; calculate stats for raw VCFs
# Alexey Larionov, 28Aug2016

# Stop at any error
set -e

# Read parameters
job_file="${1}"
scripts_folder="${2}"

# Update pipeline log
echo "Started s01_genotype_gvcfs: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# Set parameters
source "${scripts_folder}/a01_read_config.sh"
echo "Read settings"
echo ""

# Make folders
tmp_folder="${raw_vcf_folder}/tmp"
mkdir -p "${tmp_folder}"
mkdir -p "${vqsr_folder}"
mkdir -p "${all_vcfstats_folder}"
mkdir -p "${cln_vcfstats_folder}"
mkdir -p "${histograms_folder}"

# Go to working folder
init_dir="$(pwd)"
cd "${raw_vcf_folder}"

# --- Copy source gvcfs to cluster --- #

# Progress report
echo "Started copying source data"
echo ""

# Initialise file for list of source gvcfs
source_gvcfs="${raw_vcf_folder}/${dataset}.list"
> "${source_gvcfs}"

# Suspend stopping at errors
set +e

# For each library
for set in ${sets}
do

  # Copy data
  rsync -thrqe "ssh -x" "${data_server}:${project_location}/${project}/combined_gvcfs/${set}.g.vcf" "${tmp_folder}/"
  exit_code_1="${?}"

  rsync -thrqe "ssh -x" "${data_server}:${project_location}/${project}/combined_gvcfs/${set}.g.vcf.idx" "${tmp_folder}/"
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

  # Add gvcf file name to the list of source gvcfs
  echo "${tmp_folder}/${set}.g.vcf" >> "${source_gvcfs}"

  # Progress report
  echo "${set}"

done # next set

# Restore stopping at errors
set -e

# Progress report
echo ""
echo "Completed copying source data: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Genotype gvcfs --- #

# Progress report
echo "Started genotyping gvcfs"

# File names
raw_vcf="${tmp_folder}/${dataset}_raw.vcf"
genotyping_log="${logs_folder}/${dataset}_genotyping.log"

# Genotype
"${java}" -Xmx60g -jar "${gatk}" \
  -T GenotypeGVCFs \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -maxAltAlleles "${maxAltAlleles}" \
  -stand_call_conf "${stand_call_conf}" \
  -stand_emit_conf "${stand_emit_conf}" \
  -nda \
  -V "${source_gvcfs}" \
  -o "${raw_vcf}" \
  -nt 14 &>  "${genotyping_log}"

# Standard call confidence is set to the GATK default (30.0)

# Multiple Alt alleles options:
# the alt alleles are not necesserely given in frequency order
# -nda : show number of discovered alt alleles
# maxAltAlleles : how many of the Alt alleles will be genotyped (default 6)
  

# Progress report
echo "Completed genotyping gvcfs: $(date +%d%b%Y_%H:%M:%S)"
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
# 794680 - wecare
echo "Num of variants after trimming: $(grep -v "^#" "${trim_vcf}" | wc -l)"
# 794680 - wecare

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
awk '{printf("LocationID=Loc%09d\t%s\n", NR, $0)}' "${lid_tmp1}" > "${lid_tmp2}"
awk 'BEGIN {OFS="\t"} ; { $9 = $9";"$1 ; print}' "${lid_tmp2}" > "${lid_tmp3}"
cut -f2- "${lid_tmp3}" > "${lid_tmp4}"

# Prepare header
grep "^##" "${trim_vcf}" > "${trim_lid_vcf}"
echo '##INFO=<ID=LocationID,Number=1,Type=String,Description="Location ID">' >> "${trim_lid_vcf}"
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
trim_lid_ma_vcf="${tmp_folder}/${dataset}_trim_lid_ma.vcf"
trim_lid_ma_log="${logs_folder}/${dataset}_trim_lid_ma.log"

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

# --- Split multiallelic variants --- #
# Splits multiallelic variants to separate lanes and left-aligns indels
# Requires gatk 3.6 or later to avoid some potential problems

# Progress report
echo "Started splitting multiallelic variants"

# File names
trim_lid_ma_split_vcf="${tmp_folder}/${dataset}_trim_lid_ma_split.vcf"
trim_lid_ma_split_log="${logs_folder}/${dataset}_trim_lid_ma_split.log"

# Split ma sites
"${java}" -Xmx60g -jar "${gatk}" \
  -T LeftAlignAndTrimVariants \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -V "${trim_lid_ma_vcf}" \
  -o "${trim_lid_ma_split_vcf}" \
  --splitMultiallelics &> "${trim_lid_ma_split_log}"

# Progress report
echo "Completed splitting multiallelic variants: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Add variants IDs to INFO field --- #
# To make easier tracing split variants during the later steps

# Progress report
echo "Started adding split variants IDs to INFO field"

# File name
trim_lid_ma_split_vid_vcf="${tmp_folder}/${dataset}_trim_lid_ma_split_vid.vcf"

# Compile names for temporary files
vid_tmp1=$(mktemp --tmpdir="${tmp_folder}" "${dataset}_vid_tmp1".XXXXXX)
vid_tmp2=$(mktemp --tmpdir="${tmp_folder}" "${dataset}_vid_tmp2".XXXXXX)
vid_tmp3=$(mktemp --tmpdir="${tmp_folder}" "${dataset}_vid_tmp3".XXXXXX)
vid_tmp4=$(mktemp --tmpdir="${tmp_folder}" "${dataset}_vid_tmp4".XXXXXX)

# Prepare data witout header
grep -v "^#" "${trim_lid_ma_split_vcf}" > "${vid_tmp1}"
awk '{printf("SplitVarID=var%09d\t%s\n", NR, $0)}' "${vid_tmp1}" > "${vid_tmp2}"
awk 'BEGIN {OFS="\t"} ; { $9 = $9";"$1 ; print}' "${vid_tmp2}" > "${vid_tmp3}"
cut -f2- "${vid_tmp3}" > "${vid_tmp4}"

# Prepare header
grep "^##" "${trim_lid_ma_split_vcf}" > "${trim_lid_ma_split_vid_vcf}"
echo '##INFO=<ID=SplitVarID,Number=1,Type=String,Description="Split Variant ID">' >> "${trim_lid_ma_split_vid_vcf}"
grep "^#CHROM" "${trim_lid_ma_split_vcf}" >> "${trim_lid_ma_split_vid_vcf}"

# Append data to header in the output file
cat "${vid_tmp4}" >> "${trim_lid_ma_split_vid_vcf}"

# Progress report
echo "Completed adding split variants IDs to INFO field: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Add alt allele data from 1k ph3 (b37) --- #

# Progress report
echo "Started adding alt allele data from 1k ph3 (b37)"

# File names
trim_lid_ma_split_vid_1k_vcf="${tmp_folder}/${dataset}_trim_lid_ma_split_vid_1k.vcf"
trim_lid_ma_split_vid_1k_log="${logs_folder}/${dataset}_trim_lid_ma_split_vid_1k.log"

# Add annotations
"${java}" -Xmx60g -jar "${gatk}" \
  -T VariantAnnotator \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -V "${trim_lid_ma_split_vid_vcf}" \
  -o "${trim_lid_ma_split_vid_1k_vcf}" \
  --resource:ph3_1k "${ph3_1k_split_vcf}" \
  --expression ph3_1k.AC \
  --expression ph3_1k.AN \
  --expression ph3_1k.AF \
  --expression ph3_1k.AFR_AF \
  --expression ph3_1k.AMR_AF \
  --expression ph3_1k.EAS_AF \
  --expression ph3_1k.EUR_AF \
  --expression ph3_1k.SAS_AF \
  --resourceAlleleConcordance \
  -nt 14 &>  "${trim_lid_ma_split_vid_1k_log}"

# Notes: 
# --resourceAlleleConcordance may not be supported by gatk below v 3.6
# 1k phase 3 vcf include only PF variants, with multiallelic variants split to separate lines

# Progress report
echo "Completed adding alt allele data from 1k ph3 (b37): $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Add alt allele data from exac (b37) --- #

# Progress report
echo "Started adding alt allele data from exac (b37)"

# File names
trim_lid_ma_split_vid_1k_exac_vcf="${tmp_folder}/${dataset}_trim_lid_ma_split_vid_1k_exac.vcf"
trim_lid_ma_split_vid_1k_exac_log="${logs_folder}/${dataset}_trim_lid_ma_split_vid_1k_exac.log"

# Add annotations
"${java}" -Xmx60g -jar "${gatk}" \
  -T VariantAnnotator \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -V "${trim_lid_ma_split_vid_1k_vcf}" \
  -o "${trim_lid_ma_split_vid_1k_exac_vcf}" \
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
  --expression exac_non_TCGA.LoF \
  --expression exac_non_TCGA.LoF_filter \
  --expression exac_non_TCGA.LoF_flags \
  --expression exac_non_TCGA.LoF_info \
  --resourceAlleleConcordance \
  -nt 14 &>  "${trim_lid_ma_split_vid_1k_exac_log}"

# Notes: 
# --resourceAlleleConcordance may not be supported by gatk below v 3.6
# exac non-tcga vcf includes only PF variants, with multiallelic variants split to separate lines

# Progress report
echo "Completed adding alt allele data from exac (b37): $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Train vqsr snp model --- #

# Progress report
echo "Started training vqsr snp model"

# File names
recal_snp="${vqsr_folder}/${dataset}_snp.recal"
plots_snp="${vqsr_folder}/${dataset}_snp_plots.R"
tranches_snp="${vqsr_folder}/${dataset}_snp.tranches"
log_train_snp="${logs_folder}/${dataset}_snp_train.log"

# Train vqsr snp model
"${java}" -Xmx60g -jar "${gatk}" \
  -T VariantRecalibrator \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -input "${trim_lid_ma_split_vid_1k_exac_vcf}" \
  -resource:hapmap,known=false,training=true,truth=true,prior=15.0 "${hapmap}" \
  -resource:omni,known=false,training=true,truth=true,prior=12.0 "${omni}" \
  -resource:1000G,known=false,training=true,truth=false,prior=10.0 "${phase1_1k_hc}" \
  -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 "${dbsnp_138}" \
  -an QD -an MQ -an MQRankSum -an ReadPosRankSum -an FS -an SOR -an InbreedingCoeff \
  -recalFile "${recal_snp}" \
  -tranchesFile "${tranches_snp}" \
  -rscriptFile "${plots_snp}" \
  --target_titv 3.2 \
  -mode SNP \
  -tranche 100.0 -tranche 99.0 -tranche 97.0 -tranche 95.0 -tranche 90.0 \
  -nt 14 &>  "${log_train_snp}"

# Progress report
echo "Completed training vqsr snp model: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Apply vqsr snp model --- #

# Progress report
echo "Started applying vqsr snp model"

# File names
vqsr_snp_vcf="${tmp_folder}/${dataset}_snp_vqsr.vcf"
log_apply_snp="${logs_folder}/${dataset}_snp_apply.log"

# Apply vqsr snp model
"${java}" -Xmx60g -jar "${gatk}" \
  -T ApplyRecalibration \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -input "${trim_lid_ma_split_vid_1k_exac_vcf}" \
  -recalFile "${recal_snp}" \
  -tranchesFile "${tranches_snp}" \
  -o "${vqsr_snp_vcf}" \
  -mode SNP \
  -nt 14 &>  "${log_apply_snp}"  

# Progress report
echo "Completed applying vqsr snp model: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Train vqsr indel model --- #

# Progress report
echo "Started training vqsr indel model"

# File names
recal_indel="${vqsr_folder}/${dataset}_indel.recal"
plots_indel="${vqsr_folder}/${dataset}_indel_plots.R"
tranches_indel="${vqsr_folder}/${dataset}_indel.tranches"
log_train_indel="${logs_folder}/${dataset}_indel_train.log"

# Train model
"${java}" -Xmx60g -jar "${gatk}" \
  -T VariantRecalibrator \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -input "${vqsr_snp_vcf}" \
  -resource:mills,known=false,training=true,truth=true,prior=12.0 "${mills}" \
  -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 "${dbsnp_138}" \
  -an QD -an FS -an SOR -an ReadPosRankSum -an MQRankSum -an InbreedingCoeff \
  -recalFile "${recal_indel}" \
  -tranchesFile "${tranches_indel}" \
  -rscriptFile "${plots_indel}" \
  -tranche 100.0 -tranche 99.0 -tranche 97.0 -tranche 95.0 -tranche 90.0 \
  --maxGaussians 4 \
  -mode INDEL \
  -nt 14 &>  "${log_train_indel}"

# Progress report
echo "Completed training vqsr indel model: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Apply vqsr indel model --- #

# Progress report
echo "Started applying vqsr indel model"

# File names
out_vcf="${raw_vcf_folder}/${dataset}_raw.vcf"
out_vcf_md5="${raw_vcf_folder}/${dataset}_raw.md5"
log_apply_indel="${logs_folder}/${dataset}_indel_apply.log"

# Apply vqsr indel model
"${java}" -Xmx60g -jar "${gatk}" \
  -T ApplyRecalibration \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -input "${vqsr_snp_vcf}" \
  -recalFile "${recal_indel}" \
  -tranchesFile "${tranches_indel}" \
  -o "${out_vcf}" \
  -mode INDEL \
  -nt 14 &>  "${log_apply_indel}"  

# Make md5 file
md5sum $(basename "${out_vcf}") $(basename "${out_vcf}.idx") > "${out_vcf_md5}"

# Progress report
echo "Completed applying vqsr indel model: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Prepare data for histograms --- #

# Progress report
echo "Started preparing data for histograms"

# File names
histograms_data_txt="${histograms_folder}/${dataset}_histograms_data.txt"
histograms_data_log="${logs_folder}/${dataset}_histograms_data.log"

# Prepare data
"${java}" -Xmx60g -jar "${gatk}" \
  -T VariantsToTable \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -V "${out_vcf}" \
  -F SplitVarID -F LocationID -F FILTER -F TYPE -F MultiAllelic \
  -F CHROM -F POS -F REF -F ALT -F DP -F QUAL -F VQSLOD \
  -o "${histograms_data_txt}" \
  -AMD -raw &>  "${histograms_data_log}"  

# -AMD allow missed data
# -raw keep filtered

# Progress report
echo "Completed preparing data for histograms: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Generate histograms using R markdown script --- #

# Progress report
echo "Started making histograms"

# Prepare file names
histograms_report_html="${histograms_folder}/${dataset}_histograms_report.html"
histograms_plot_log="${logs_folder}/${dataset}_histograms_plot.log"

# Compile R script
r_script="library('rmarkdown', lib='"${r_lib_folder}"'); render('"${scripts_folder}"/r01_make_html.Rmd', params=list(dataset='"${dataset}-raw"' , working_folder='"${histograms_folder}"/' , data_file='"${histograms_data_txt}"'), output_file='"${histograms_report_html}"')"

# Execute R script
# Notes:
# Path to R was added to environment and modules required for 
# R with knitr were loaded in s01_genotype_gvcfs.sb.sh:
# module load gcc/5.2.0
# module load boost/1.50.0
# module load texlive/2015
# module load pandoc/1.15.2.1

echo "--------- Preparing html report with histograms --------- " >> "${histograms_plot_log}"
echo "" >> "${histograms_plot_log}"
"${r_bin_folder}/R" -e "${r_script}" &>> "${histograms_plot_log}"

echo "" >> "${histograms_plot_log}"

# Progress report
echo "Completed making histograms: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Calculating vcfstats for full data emitted by HC --- #

# Progress report
echo "Started vcfstats"
echo ""

# File name
vcf_stats="${all_vcfstats_folder}/${dataset}_raw.vchk"

# Calculate vcf stats
"${bcftools}" stats -F "${ref_genome}" "${out_vcf}" > "${vcf_stats}" 
#To be done: explore -R option to focus stats on targets:
# -R "${targets_bed}" ?? 

# Plot the stats
"${plot_vcfstats}" "${vcf_stats}" -p "${all_vcfstats_folder}/"
echo ""

# Progress report
echo "Completed vcfstats: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Make a "clean" copy of vcf with PF variants only --- #

# Progress report
echo "Started making clean vcf with PF variants only"

# File names
cln_vcf="${raw_vcf_folder}/${dataset}_raw_cln.vcf"
cln_vcf_md5="${raw_vcf_folder}/${dataset}_raw_cln.md5"
cln_vcf_log="${logs_folder}/${dataset}_raw_cln.log"

# Exclude filtered variants
"${java}" -Xmx60g -jar "${gatk}" \
  -T SelectVariants \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -V "${out_vcf}" \
  -o "${cln_vcf}" \
  --excludeFiltered \
  -nt 14 &>  "${cln_vcf_log}"

# Make md5 file
md5sum $(basename "${cln_vcf}") $(basename "${cln_vcf}.idx") > "${cln_vcf_md5}"

# Completion message to log
echo "Completed making clean vcf: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Calculating vcfstats after minimal HC and VQSR filters--- #

# Progress report
echo "Started vcfstats on clean data"
echo ""

# File name
vcf_stats="${cln_vcfstats_folder}/${dataset}_cln.vchk"

# Calculate vcf stats
"${bcftools}" stats -F "${ref_genome}" "${cln_vcf}" > "${vcf_stats}" 
#To be done: explore -R option to focus stats on targets:
# -R "${targets_bed}" ?? 

# Plot the stats
"${plot_vcfstats}" "${vcf_stats}" -p "${cln_vcfstats_folder}/"
echo ""

# Progress report
echo "Completed vcfstats on clean data: $(date +%d%b%Y_%H:%M:%S)"
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
set +e

# Progress report
log_on_nas="${project_location}/${project}/${dataset}_raw_vcf/logs/${dataset}_genotype_and_assess.log"

ssh -x "${data_server}" "echo \"Completed copying results to NAS: $(date +%d%b%Y_%H:%M:%S)\" >> ${log_on_nas}"
ssh -x "${data_server}" "echo \"\" >> ${log_on_nas}"

# Remove bulk results from cluster

#rm -fr "${logs_folder}"
#rm -fr "${vqsr_folder}"
#rm -fr "${histograms_folder}"
#rm -fr "${vcfstats_folder}"

rm -f "${source_gvcfs}"

rm -f "${out_vcf}"
rm -f "${out_vcf}.idx"
rm -f "${out_vcf_md5}"

rm -f "${cln_vcf}"
rm -f "${cln_vcf}.idx"
rm -f "${cln_vcf_md5}"

ssh -x "${data_server}" "echo \"Removed bulk data and results from cluster\" >> ${log_on_nas}"
ssh -x "${data_server}" "echo \"\" >> ${log_on_nas}"

# Return to the initial folder
cd "${init_dir}"
