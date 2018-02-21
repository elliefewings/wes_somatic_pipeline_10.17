#!/bin/bash

# s03_summarise_qc.sh
# Plot summary metrics for merged wes samples and save results to NAS
# Ellie Fewings, 06Oct17

# Stop at any error
set -e

# Notes:
# Tested with gnuplot 5.0 (may not work with older gnuplot versions)
# Requires ssh connection to be established with -X option
# Requires LiberationSans-Regular.ttf font (included in tools/config)

# Read parameters
job_file="${1}"
scripts_folder="${2}"
pipeline_log="${3}"

# Update pipeline log
echo "Started making summaries and plots for merged wes samples: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"

# ------------------------------------------------- #
#                    Start job log                  #
# ------------------------------------------------- #

echo "Making summaries and plots for merged wes samples"
echo "Started: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------------------------------------------------- #
#                    Set environment                #
# ------------------------------------------------- #

echo "====================== Settings ======================"
echo ""

source "${scripts_folder}/a01_read_config.sh"
source "${scripts_folder}/a02_report_settings.sh"

echo "====================================================="
echo ""

# Get list of samples
merged_samples_file="${merged_folder}/samples.txt"
samples=$(awk 'NR>1 {print $1}' "${merged_samples_file}")

# ------------------------------------------------- #
#                     Flagstats                     #
# ------------------------------------------------- #

# --------------- Make summary table ---------------#

# Make header
flagstats_summary="${flagstat_folder}/flagstats_summary.txt"
header="sample\ttotal_reads\tsecondary\tsupplementary\tduplicates\tmapped\tpaired_in_sequencong\tread1\tread2\tproperly_paired\twith_itself_and_mate_mapped\tsingletons\twith_mate_mapped_to_a_different_chr\twith_mate_mapped_to_a_different_chr_mapq5"
echo -e "${header}" > "${flagstats_summary}" 

# For each sample
for sample in $samples
do

  # flagstats metrics file name
  flagstats_file="${sample}_flagstat.txt"
  flagstats="${flagstat_folder}/${flagstats_file}"

  # Initialise list of metrics
  metrics="${sample}"

  # Fill list of metrics
  while read metric etc
  do
    metrics="${metrics}\t${metric}"
  done < "${flagstats}"

  # Add sample to summary file
  echo -e "${metrics}" >> "${flagstats_summary}"

done

# ------------------- Make plot ------------------- #

# Parameters
plot_file="${flagstat_folder}/flagstats_summary.png"
title="${project} ${library} merged: Samtools flagststs"
ylabel="Read counts"

# gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set style histogram clustered
set style fill solid border
set yrange [0:] 
set xtics rotate out
set key out horizontal center bottom
set title "'"${title}"'"
set ylabel "'"${ylabel}"'"
set decimal locale
set format y "'"%'.0f"'"
set output "'"${plot_file}"'"
plot "'"${flagstats_summary}"'" using "'"total_reads"'":xtic(1) title "'"Total"'", \
     "'"${flagstats_summary}"'" using "'"with_itself_and_mate_mapped"'":xtic(1) title "'"Mapped in pairs"'", \
     "'"${flagstats_summary}"'" using "'"duplicates"'":xtic(1) title "'"Duplicates"'"'

# Plotting (discard message about setting decimal sign)
"${gnuplot}" <<< "${gpl_script}" &>/dev/null

# Progress report
echo "Made summary table and plot for samtools flagststs"
echo ""

# ------------------------------------------------- #
#                 Picard mkdup stats                #
# ------------------------------------------------- #

# Make picard summary folder
mkdir -p "${picard_summary_folder}"

# Note: 
# Picard changes the stats headers from version to version.
# In this pipeline update I manually incerted headers for the required Picard version (2.60)
# Later it might be possible to improve it by picking it from a stat file directly, e.g. like this:
# grep -A1 "## METRICS CLASS" $stat_file | tail -n 1

# For full tests set
if [ "${tests_set}" == "full" ]
then

  # --------------- Make summary table ---------------#
  
  # Make header
  mkdup_summary="${picard_summary_folder}/r01_picard_mkdup_summary.txt"
  header="LIBRARY	UNPAIRED_READS_EXAMINED	READ_PAIRS_EXAMINED	SECONDARY_OR_SUPPLEMENTARY_RDS	UNMAPPED_READS	UNPAIRED_READ_DUPLICATES	READ_PAIR_DUPLICATES	READ_PAIR_OPTICAL_DUPLICATES	PERCENT_DUPLICATION	ESTIMATED_LIBRARY_SIZE"
  echo -e "SAMPLE\t${header}" > "${mkdup_summary}" 
  
  # Collect data
  for sample in $samples
  do
    # Stats file name
    stats_file="${picard_mkdup_folder}/${sample}_mkdup.txt"
    
    # Get mkdup stats
    stats=$(awk '/^LIBRARY/ {getline; print}' "${stats_file}")
  
    # Add stats to the summary table
    echo -e "${sample}\t${stats}" >> "${mkdup_summary}"
    
  done
  
  # ------------------- Make plot ------------------- #
  
  # Parameters
  plot_file="${picard_summary_folder}/r01_picard_duplication_rates.png"
  title="${project} ${library} merged: Duplication rates"
  ylabel="Fractoin"
  
  # Gnuplot script
  gpl_script='
  set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
  set style data histogram
  set style fill solid border
  set yrange [0:1] 
  set xtics rotate out
  unset key
  set title "'"${title}"'"
  set ylabel "'"${ylabel}"'"
  set output "'"${plot_file}"'"
  plot "'"${mkdup_summary}"'" using "'"PERCENT_DUPLICATION"'":xtic(1)'
  
  # Plotting
  "${gnuplot}" <<< "${gpl_script}"
  
  # Progress report
  echo "Made summary table and plot for picard mkdup duplication rates"

fi

# Omit plotting picard mkdup duplication rates for the limited tests set
if [ "${tests_set}" == "limited" ]
then

  # Progress report
  echo "Omitted plotting picard mkdup duplication rates for the limited tests set"

fi

# ------------------------------------------------- #
#              Picard mkdup histograms              #
# ------------------------------------------------- #

# For full tests set
if [ "${tests_set}" == "full" ]
then
  
  # --------------- Make summary table ---------------#
  
  # Make header
  mkdup_histograms="${picard_summary_folder}/r02_picard_mkdup_histograms.txt"
  header="x"
  for sample in $samples
  do
    header=$(echo -e "${header}\t${sample}")
  done
  
  echo -e "${header}" > "${mkdup_histograms}" 
  
  # Collect data
  for x in {1..10}
  do
    
    # Row name
    stats="x${x}"
    
    # For each sample
    for sample in $samples
    do
    
      # Stats file name
      stats_file="${picard_mkdup_folder}/${sample}_mkdup.txt"
      
      # Get stats
      stat=$(awk -v s="${x}.0" '$1==s {print $2}' "${stats_file}")
      stats=$(echo -e "${stats}\t${stat}")
      
    done # next sample
  
    # Add stats to the file
    echo -e "${stats}" >> "${mkdup_histograms}"
      
  done
  
  # ------------------- Make plot ------------------- #
  
  # Parameters
  plot_file="${picard_summary_folder}/r02_picard_mkdup_histograms.png"
  title="${project} ${library} merged: mkdup histograms"
  ylabel="Multiples of output"
  xlabel="Multiples of sequencing"
  
  # Change new lines to spaces (required for gnuplot)
  samples_list=$(echo ${samples})
  
  # Gnuplot script
  gpl_script='
  set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
  set xtics rotate out
  unset key
  set title "'"${title}"'"
  set ylabel "'"${ylabel}"'"
  set xlabel "'"${xlabel}"'"
  set output "'"${plot_file}"'"
  plot for [s in "'"${samples_list}"'"] "'"${mkdup_histograms}"'" using s:xtic(1) with lines linewidth 3'
  
  # Plotting
  "${gnuplot}" <<< "${gpl_script}"
  
  # Progress report
  echo "Made summary table and plot for picard mkdup histograms"
  
fi

# Omit plotting picard mkdup histograms for the limited tests set
if [ "${tests_set}" == "limited" ]
then

  # Progress report
  echo "Omitted picard mkdup histograms for the limited tests set"

fi

# ------------------------------------------------- #
#                Picard insert sizes                #
# ------------------------------------------------- #

# For full tests set
if [ "${tests_set}" == "full" ]
then

  # --------------- Make summary table ---------------#
  
  # Make header
  inserts_summary="${picard_summary_folder}/r03_picard_inserts_summary.txt"
  header="MEDIAN_INSERT_SIZE	MEDIAN_ABSOLUTE_DEVIATION	MIN_INSERT_SIZE	MAX_INSERT_SIZE	MEAN_INSERT_SIZE	STANDARD_DEVIATION	READ_PAIRS	PAIR_ORIENTATION	WIDTH_OF_10_PERCENT	WIDTH_OF_20_PERCENT	WIDTH_OF_30_PERCENT	WIDTH_OF_40_PERCENT	WIDTH_OF_50_PERCENT	WIDTH_OF_60_PERCENT	WIDTH_OF_70_PERCENT	WIDTH_OF_80_PERCENT	WIDTH_OF_90_PERCENT	WIDTH_OF_99_PERCENT	SAMPLE	LIBRARY	READ_GROUP"
  echo -e "SAMPLE\t${header}" > "${inserts_summary}" 
  
  # Collect data
  for sample in $samples
  do
  
    # Stats file name
    stats_file="${picard_inserts_folder}/${sample}_insert_sizes.txt"
    
    # Get stats
    stats=$(awk '/^MEDIAN_INSERT_SIZE/{getline; print}' "${stats_file}")
  
    # Add stats to the file
    echo -e "${sample}\t${stats}" >> "${inserts_summary}"
    
  done
  
  # ------------------- Make plot ------------------- #
  
  # Parameters
  plot_file="${picard_summary_folder}/r03_picard_inserts_summary.png"
  title="${project} ${library} merged: Inserts sizes"
  ylabel="Base pairs"
  
  # Gnuplot script
  gpl_script='
  set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
  set style data histogram
  set style fill solid border
  set yrange [0:] 
  set xtics rotate out
  unset key
  set title "'"${title}"'"
  set ylabel "'"${ylabel}"'"
  set output "'"${plot_file}"'"
  plot "'"${inserts_summary}"'" using "'"MEDIAN_INSERT_SIZE"'":xtic(1)'
  
  # Plotting
  "${gnuplot}" <<< "${gpl_script}"
  
  # Progress report
  echo "Made summary table and plot for picard insert sizes"

fi

# Omit plotting insert sizes for the limited tests set
if [ "${tests_set}" == "limited" ]
then

  # Progress report
  echo "Omitted plotting insert sizes for the limited tests set"

fi

# ------------------------------------------------- #
#         Picard alignment summary metrics          #
# ------------------------------------------------- #

# --------------- Make summary table ---------------#

# For full tests set
if [ "${tests_set}" == "full" ]
then

  # Make header
  picard_as_metrics="${picard_summary_folder}/r04_picard_alignment_metrics.txt"
  header="CATEGORY	TOTAL_READS	PF_READS	PCT_PF_READS	PF_NOISE_READS	PF_READS_ALIGNED	PCT_PF_READS_ALIGNED	PF_ALIGNED_BASES	PF_HQ_ALIGNED_READS	PF_HQ_ALIGNED_BASES	PF_HQ_ALIGNED_Q20_BASES	PF_HQ_MEDIAN_MISMATCHES	PF_MISMATCH_RATE	PF_HQ_ERROR_RATE	PF_INDEL_RATE	MEAN_READ_LENGTH	READS_ALIGNED_IN_PAIRS	PCT_READS_ALIGNED_IN_PAIRS	BAD_CYCLES	STRAND_BALANCE	PCT_CHIMERAS	PCT_ADAPTER	SAMPLE	LIBRARY	READ_GROUP"
  echo -e "SAMPLE\t${header}" > "${picard_as_metrics}" 

  # Select data
  data_to_plot="PAIR"

  # Collect data
  for sample in $samples
  do
  
    # Stats file name
    stats_file="${picard_alignment_folder}/${sample}_as_metrics.txt"
    
    # Get stats
    stats=$(grep "^${data_to_plot}" "${stats_file}")
  
    # Add stats to the file
    echo -e "${sample}\t${stats}" >> "${picard_as_metrics}"
    
  done

  # ------------------- Make plot ------------------- #
  
  # Parameters
  plot_file="${picard_summary_folder}/r04_picard_read_counts.png"
  title="${project} ${library} merged: picard AS-metrics and mkdup"
  ylabel="Read counts"
  
  # gnuplot script
  gpl_script='
  set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
  set style data histogram
  set style histogram clustered
  set style fill solid border
  set yrange [0:] 
  set xtics rotate out
  set key out horizontal center bottom
  set title "'"${title}"'"
  set ylabel "'"${ylabel}"'"
  set decimal locale
  set format y "'"%'.0f"'"
  set output "'"${plot_file}"'"
  plot "'"${picard_as_metrics}"'" using "'"TOTAL_READS"'":xtic(1) title "'"Total"'", \
       "'"${picard_as_metrics}"'" using "'"READS_ALIGNED_IN_PAIRS"'":xtic(1) title "'"Aligned in pairs"'", \
       "'"${mkdup_summary}"'" using "'"READ_PAIR_DUPLICATES"'":xtic(1) title "'"Pairs of duplicates"'"'
  
  # Plotting (discard message about setting decimal sign)
  "${gnuplot}" <<< "${gpl_script}" &>/dev/null
  
  # Progress report
  echo "Made summary table and plot for picard alignment summary"

fi

# Omit picard alignment summary for the limited tests set
if [ "${tests_set}" == "limited" ]
then

  # Progress report
  echo "Omitted plotting picard alignment summary metrics for the limited tests set"

fi

# ------------------------------------------------- #
#      Picard hybridisation selection metrics       #
# ------------------------------------------------- #


# --------------- Make summary table ---------------#

# Make header
picard_hs_metrics="${picard_summary_folder}/r05_picard_hybridisation_metrics.txt"
header="BAIT_SET	GENOME_SIZE	BAIT_TERRITORY	TARGET_TERRITORY	BAIT_DESIGN_EFFICIENCY	TOTAL_READS	PF_READS	PF_UNIQUE_READS	PCT_PF_READS	PCT_PF_UQ_READS	PF_UQ_READS_ALIGNED	PCT_PF_UQ_READS_ALIGNED	PF_BASES_ALIGNED	PF_UQ_BASES_ALIGNED	ON_BAIT_BASES	NEAR_BAIT_BASES	OFF_BAIT_BASES	ON_TARGET_BASES	PCT_SELECTED_BASES	PCT_OFF_BAIT	ON_BAIT_VS_SELECTED	MEAN_BAIT_COVERAGE	MEAN_TARGET_COVERAGE	MEDIAN_TARGET_COVERAGE	PCT_USABLE_BASES_ON_BAIT	PCT_USABLE_BASES_ON_TARGET	FOLD_ENRICHMENT	ZERO_CVG_TARGETS_PCT	PCT_EXC_DUPE	PCT_EXC_MAPQ	PCT_EXC_BASEQ	PCT_EXC_OVERLAP	PCT_EXC_OFF_TARGET	FOLD_80_BASE_PENALTY	PCT_TARGET_BASES_1X	PCT_TARGET_BASES_2X	PCT_TARGET_BASES_10X	PCT_TARGET_BASES_20X	PCT_TARGET_BASES_30X	PCT_TARGET_BASES_40X	PCT_TARGET_BASES_50X	PCT_TARGET_BASES_100X	HS_LIBRARY_SIZE	HS_PENALTY_10X	HS_PENALTY_20X	HS_PENALTY_30X	HS_PENALTY_40X	HS_PENALTY_50X	HS_PENALTY_100X	AT_DROPOUT	GC_DROPOUT	HET_SNP_SENSITIVITY	HET_SNP_Q	SAMPLE	LIBRARY	READ_GROUP"
echo -e "SAMPLE\t${header}" > "${picard_hs_metrics}" 

# Collect data
for sample in $samples
do

  # Stats file name
  stats_file="${picard_hybridisation_folder}/${sample}_hs_metrics.txt"
  
  # Get stats
  stats=$(grep "^${bait_set_name}" "${stats_file}")

  # Add stats to the file
  echo -e "${sample}\t${stats}" >> "${picard_hs_metrics}"
  
done

# ------------------- Selected  and on target plot ------------------- #

# Parameters
plot_file="${picard_summary_folder}/r05_picard_on_targets.png"
title="${project} ${library} merged: Selected and on target bases"
ylabel="Fraction of sequenced bases"

# gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set style histogram clustered
set style fill solid border
set key out horizontal center bottom
set yrange [0:1] 
set xtics rotate out
set title "'"${title}"'"
set ylabel "'"${ylabel}"'"
set output "'"${plot_file}"'"
plot "'"${picard_hs_metrics}"'" using "'"PCT_SELECTED_BASES"'":xtic(1) title "'"Selected"'", \
     "'"${picard_hs_metrics}"'" using "'"PCT_USABLE_BASES_ON_TARGET"'":xtic(1) title "'"On targets"'"'

# Plotting
"${gnuplot}" <<< "${gpl_script}"

# ------------------- Selected  and on target plot ------------------- #

# Parameters
plot_file="${picard_summary_folder}/r06_picard_10x20x50x100.png"
title="${project} ${library} merged: Bases covered at x-fold"
ylabel="Fraction of target bases"

# gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set style histogram clustered
set style fill solid border
set key out horizontal center bottom
set yrange [0:1] 
set xtics rotate out
set ylabel "'"${ylabel}"'"
set title "'"${title}"'"
set output "'"${plot_file}"'"
plot \
     "'"${picard_hs_metrics}"'" using "'"PCT_TARGET_BASES_10X"'":xtic(1) title "'"10x"'" with lines linewidth 3, \
     "'"${picard_hs_metrics}"'" using "'"PCT_TARGET_BASES_20X"'":xtic(1) title "'"20x"'" with lines linewidth 3, \
     "'"${picard_hs_metrics}"'" using "'"PCT_TARGET_BASES_50X"'":xtic(1) title "'"50x"'" with lines linewidth 3, \
     "'"${picard_hs_metrics}"'" using "'"PCT_TARGET_BASES_100X"'":xtic(1) title "'"100x"'" with lines linewidth 3'

# Plotting
"${gnuplot}" <<< "${gpl_script}"


# ------------------- Enrichment efficiency plot ------------------- #

# Parameters
plot_file="${picard_summary_folder}/r07_picard_enrichment_efficiency.png"
title="${project} ${library} merged: Enrichment efficiency"
ylabel="Fold"

# gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set style fill solid border
set yrange [0:] 
set xtics rotate out
unset key
set title "'"${title}"'"
set ylabel "'"${ylabel}"'"
set output "'"${plot_file}"'"
plot "'"${picard_hs_metrics}"'" using "'"FOLD_ENRICHMENT"'":xtic(1)'

# Plotting
"${gnuplot}" <<< "${gpl_script}"

# ------------------- Mean tgt coverage ------------------- #

# Parameters
plot_file="${picard_summary_folder}/r08_picard_tgt_coverage.png"
title="${project} ${library} merged: Mean target coverage"
ylabel="Fold"

# gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set style fill solid border
set yrange [0:] 
set xtics rotate out
unset key
set title "'"${title}"'"
set ylabel "'"${ylabel}"'"
set output "'"${plot_file}"'"
plot "'"${picard_hs_metrics}"'" using "'"MEAN_TARGET_COVERAGE"'":xtic(1)'

# Plotting
"${gnuplot}" <<< "${gpl_script}"

# Progress report
echo "Made summary table and plots for picard hybridisation selection summary"
echo ""

# ------- Qualimap multi-sample summary ------- #

if [ "${run_qualimap}" == "yes" ] 
then

    # Progress report
    echo "Started multi-sample qualimap"
    
    # Make folder for qualimap multi-sample results
    qualimap_summary_folder="${qualimap_results_folder}/summary"
    mkdir -p "${qualimap_summary_folder}"
    
    # Make samples list for qualimap multi-sample run
    samples_list="${qualimap_summary_folder}/samples.list"
    >"${samples_list}"
    
    for sample in ${samples}
    do
      echo -e "${sample}\t${qualimap_results_folder}/${sample}" >> "${samples_list}"
    done
    
    # Variable to reset default memory settings for qualimap
    export JAVA_OPTS="-Xms1G -Xmx60G"
    
    # Start qualimap
    qualimap_log="${qualimap_summary_folder}/summary.log"
    "${qualimap}" multi-bamqc \
      --data "${samples_list}" \
      -outdir "${qualimap_summary_folder}" &> "${qualimap_log}"
    
    # Progress report
    echo "Completed multi-sample qualimap"
    echo ""

elif [ "${run_qualimap}" == "no" ] 
then
    # Progress report
    echo "Omitted qualimap summary"
    echo ""
else
    # Error message
    echo "Wrong qualimap setting: ${run_qualimap}"
    echo "Should be yes or no"
    echo "Qualimap summary omitted"
    echo ""
fi

# ------- Report progress ------- #

# Completion message to the job log
echo "Completed summaries and plots for merged wes samples: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# Update pipeline log
echo "Completed making summaries and plots for merged wes samples: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"

# ------- Remove unnecessary samples lists ------- #

for lane in ${lanes}
do
  rm -f "${merged_folder}/${lane}_samples.txt" 
done

# ------- Save results to NAS ------- #

# Suspend stopping at errors
set +e

# Progress report
echo "Started saving results to NAS"

# Copy files
rsync -thrve "ssh -x" "${merged_folder}" "${data_server}:${project_location}/${project}/${library}/"
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

# Progress messages
echo ""
echo "Completed saving results to NAS: $(date +%d%b%Y_%H:%M:%S)"
echo ""
echo "Completed all tasks"
echo ""

echo "Saved results to NAS: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"
echo "Done all pipeline tasks" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"

# Update logs on NAS
scp -qp "${logs_folder}/s03_summarise_and_save.log" "${data_server}:${project_location}/${project}/${library}/merged/f00_logs/s03_summarise_and_save.log"
scp -qp "${pipeline_log}" "${data_server}:${project_location}/${project}/${library}/merged/f00_logs/a00_pipeline_${project}_${library}.log" 

# Remove bams from cluster
rm -fr "${bam_folder}" 

# Update logs on NAS
ssh -x "${data_server}" "echo \"Removed bams from cluster\" >> ${project_location}/${project}/${library}/merged/f00_logs/s03_summarise_and_save.log"
ssh -x "${data_server}" "echo \"Removed bams from cluster\" >> ${project_location}/${project}/${library}/merged/f00_logs/a00_pipeline_${project}_${library}.log"
