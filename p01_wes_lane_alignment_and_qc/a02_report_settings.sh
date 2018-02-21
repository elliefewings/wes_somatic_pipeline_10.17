#!/bin/bash

# a02_report_settings.sh
# Report settings for wes lane alignment pipeline
# Ellie Fewings, 06Oct17

pipeline_info=$(grep "^#" "${job_file}")
pipeline_info=${pipeline_info//"# "/}

echo "------------------- Pipeline summary -----------------"
echo ""
echo "${pipeline_info}"
echo ""
echo "--------- Data location and analysis settings --------"
echo ""
echo "source_server: ${source_server}"
echo "source_folder: ${source_folder}"
echo ""
echo "results_server: ${results_server}"
echo "results_folder: ${results_folder}"
echo ""
echo "project: ${project}"
echo "library: ${library}"
echo "lane: ${lane}"
echo ""
echo "data_type: ${data_type}"
echo "run_qualimap: ${run_qualimap}"
echo "run_samstat: ${run_samstat}"
echo ""
echo "------------------- HPC settings ---------------------"
echo ""
echo "working_folder: ${working_folder}"
echo "project_folder: ${project_folder}"
echo "lane_folder: ${lane_folder}"
echo ""
echo "account_copy_in: ${account_copy_in}"
echo "time_copy_in: ${time_copy_in}"
echo ""
echo "account_alignment_qc: ${account_alignment_qc}"
echo "time_alignment_qc: ${time_alignment_qc}"
echo ""
echo "account_move_out: ${account_move_out}"
echo "time_move_out: ${time_move_out}"
echo ""
echo "----------------- Standard settings ------------------"
echo ""
echo "scripts_folder: ${scripts_folder}"
echo ""
echo "Tools"
echo "-----"
echo ""
echo "tools_folder: ${tools_folder}"
echo ""
echo "java6: ${java6}"
echo "java7: ${java7}"
echo "java8: ${java8}"
echo ""   
echo "fastqc: ${fastqc}"
echo ""
echo "cutadapt: ${cutadapt}"
echo "cutadapt_min_len: ${cutadapt_min_len}"
echo "cutadapt_trim_qual: ${cutadapt_trim_qual}"
echo ""   
echo "cutadapt_remove_adapters: ${cutadapt_remove_adapters}"
echo ""
echo "cutadapt_adapter_1: ${cutadapt_adapter_1}"
echo "cutadapt_adapter_2: ${cutadapt_adapter_2}"
echo ""
echo "bwa: ${bwa}"
echo "bwa_index: ${bwa_index}"
echo "bwa_algorithm: ${bwa_algorithm}"
echo ""   
echo "samtools: ${samtools}"
echo "samtools_folder: ${samtools_folder}"
echo ""
echo "picard: ${picard}"
echo "htsjdk: ${htsjdk}"
echo ""
echo "r_folder: ${r_folder}"
echo ""
echo "qualimap: ${qualimap}"
echo ""
echo "gnuplot: ${gnuplot}"
echo "LiberationSansRegularTTF: ${LiberationSansRegularTTF}"
echo ""
echo "samstat: ${samstat}"
echo ""
echo "Resources" 
echo "---------"
echo ""
echo "resources_folder: ${resources_folder}"
echo ""
echo "ref_genome: ${ref_genome}"
echo ""
echo "bait_set_name: ${bait_set_name}"
echo "probes_intervals: ${probes_intervals}"
echo "targets_intervals: ${targets_intervals}"
echo "targets_bed_3: ${targets_bed_3}"
echo "targets_bed_6: ${targets_bed_6}"
echo ""
echo "Working folders"
echo "---------------"
echo ""
echo "logs_folder: ${logs_folder}"
echo "source_fastq_folder: ${source_fastq_folder}"
echo "fastqc_raw_folder: ${fastqc_raw_folder}"
echo "trimmed_fastq_folder: ${trimmed_fastq_folder}"
echo "fastqc_trimmed_folder: ${fastqc_trimmed_folder}"
echo "bam_folder: ${bam_folder}"
echo "flagstat_folder: ${flagstat_folder}"
echo "picard_mkdup_folder: ${picard_mkdup_folder}"
echo "picard_inserts_folder: ${picard_inserts_folder}"
echo "picard_alignment_folder: ${picard_alignment_folder}"
echo "picard_hybridisation_folder: ${picard_hybridisation_folder}"
echo "picard_summary_folder: ${picard_summary_folder}"
echo "qualimap_results_folder: ${qualimap_results_folder}"
echo "samstat_results_folder: ${samstat_results_folder}"
echo "" 
echo "Additional parameters"
echo "---------------------"
echo ""
echo "platform: ${platform}"
echo "" 
