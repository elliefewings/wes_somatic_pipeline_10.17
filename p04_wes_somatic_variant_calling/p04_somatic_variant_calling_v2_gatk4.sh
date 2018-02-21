#!/bin/bash

#p01_somatic_variant_calling.sh
# variant_calling, add locations IDs and multiallelic flag; calculate stats for raw VCFs
# Ellie Fewings, 11Oct2017

#Running:
#./p04_somatic_variant_calling.sh dataset tumour normal source_location results_location


#Arguments
dataset="$1" #e.g. macT_Aug17

tumour_bam="$2" #e.g. IHCAP_8_01_T
normal_bam="$3" #e.g. IHCAP_8_01_GM

loc="$4" #e.g. /share/libs/IGP_L1/processed/f01_bams
results="$5" #e.g. /share/Eleanor

#Check arguments
if [ $# -lt 5 ]; then
  echo 1>&2 "$0: not enough arguments."
  echo "Somatic variant calling:"
  echo "./p04_somatic_variant_calling.sh dataset tumour normal source_location results_location"
  echo "dataset: The name you want to give your set of bams e.g. macT_Aug17"
  echo "tumour: The name of your tumour sample e.g. IHCAP_8_01_T"
  echo "normal: The name of your normal sample e.g. IHCAP_8_01_GM"
  echo "source location: Location of bam files on mgqnap2 e.g. /share/libs/IGP_L1/processed/f01_bams"
  echo "results location: Location on mgqnap2 to store results e.g. /share/Eleanor"
  exit 2
elif [ $# -gt 5 ]; then
  echo 1>&2 "$0: too many arguments"
  echo "Somatic variant calling:"
  echo "./p04_somatic_variant_calling.sh dataset tumour normal source_location results_location"
  echo "dataset: The name you want to give your set of bams e.g. macT_Aug17"
  echo "tumour: The name of your tumour sample e.g. IHCAP_8_01_T"
  echo "normal: The name of your normal sample e.g. IHCAP_8_01_GM"
  echo "source location: Location of bam files on mgqnap2 e.g. /share/libs/IGP_L1/processed/f01_bams"
  echo "results location: Location on mgqnap2 to store results e.g. /share/Eleanor"
  exit 2
fi

#Set log and directories
set_dir="/home/$USER/mtgroup_share/users/$USER/Somatic_variant_calling/${dataset}_raw"
source_dir="${set_dir}/source_data"

mkdir -p ${source_dir}

log="${set_dir}/${dataset}_variant_calling.log"

#Start logging
echo "Started s01_somatic_variant_calling: $(date +%d%b%Y_%H:%M:%S)" >> ${log}
echo "" >> ${log}
echo "Dataset: ${dataset}" >> ${log}
echo "" >> ${log}
echo "Tumour: ${tumour_bam}" >> ${log}
echo "Normal: ${normal_bam}" >> ${log}
echo "" >> ${log}
echo "Location of source data: ${loc}" >> ${log}
echo "Location of results: ${results}/${dataset}_raw" >> ${log}


#Copy data from MGQNAP2
echo "Started copying source data" >> ${log}
echo "" >> ${log}

rsync -thrqe "ssh -x" "admin@mgqnap2.medschl.cam.ac.uk:${loc}/${tumour_bam}*" "${source_dir}/" >> ${log}

rsync -thrqe "ssh -x" "admin@mgqnap2.medschl.cam.ac.uk:${loc}/${normal_bam}*" "${source_dir}/" >> ${log}

echo "Finished copying source data" >> ${log}
echo "" >> ${log}

# File names
raw_vcf="${set_dir}/${dataset}_unfiltered.vcf"

variant_calling_log="${set_dir}/${dataset}_variant_calling.log"

tum="${source_dir}/${tumour_bam}_idr_bqr.bam"
norm="${source_dir}/${normal_bam}_idr_bqr.bam"

#Set whisperwind variables
gatk_launch="/analysis/mtgroup_share/tools/gatk/gatk-4.beta.5/gatk-launch"
ref_ww="/home/$USER/mtgroup_share/resources/gatk_bundle/b37/decompressed/human_g1k_v37.fasta"
targets_ww="/home/$USER/mtgroup_share/resources/illumina_nextera/nexterarapidcapture_exome_targetedregions_v1.2.b37.intervals"

#Write to log
echo "Started somatic variant calling: $(date +%d%b%Y_%H:%M:%S)" >> "${log}"

# Variant calling across one sample only
"${gatk_launch}" Mutect2 \
  -R "${ref_ww}" \
  -L "${targets_ww}" -ip 10 \
  -maxAltAlleles 6 \
  -A DepthPerAlleleBySample \
  -A BaseQuality \
  -A Coverage \
  -nda \
  -I "${tum}" \
  -tumor ${tumour_bam} \
  -I "${norm}" \
  -normal ${normal_bam} \
  -O "${raw_vcf}" &>>  "${log}"

#Write to log
echo "Finished somatic variant calling: $(date +%d%b%Y_%H:%M:%S)" >> "${log}"

echo "Started mutect2 filtering: $(date +%d%b%Y_%H:%M:%S)" >> "${log}"

#Filter mutect2 output

filt_vcf="${set_dir}/${dataset}_raw.vcf"

"${gatk_launch}" FilterMutectCalls \
  -V "${raw_vcf}" \
  --tumor_lod 4 \
  -O "${filt_vcf}" &>>  "${log}"

echo "Finished mutect2 filtering: $(date +%d%b%Y_%H:%M:%S)" >> "${log}"

#Copy data to MGQNAP2
echo "Started copying data back to MGQNAP2" >> ${log}
echo "" >> ${log}

rsync -thrqe "ssh -x" "${set_dir}"  "admin@mgqnap2.medschl.cam.ac.uk:${results}" >> ${log}

echo "Finished copying data back to MGQNAP2" >> ${log}
echo "" >> ${log}
echo "Finished somatic variant calling pipeline: $(date +%d%b%Y_%H:%M:%S)" >> "${log}"

