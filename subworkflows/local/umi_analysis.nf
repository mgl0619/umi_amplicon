/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    umi-amplicon UMI Analysis Subworkflow
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    UMI-tagged amplicon sequencing analysis subworkflow
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Load nf-core modules
include { FASTP as FASTP_QC } from '../../modules/nf-core/fastp/main'
include { FASTP as FASTP_TRIM } from '../../modules/nf-core/fastp/main'
include { FASTQC as FASTQC_RAW } from '../../modules/nf-core/fastqc/main'
include { FASTQC as FASTQC_FASTP_QC } from '../../modules/nf-core/fastqc/main'
include { FASTQC as FASTQC_FASTP_TRIM } from '../../modules/nf-core/fastqc/main'
include { MULTIQC } from '../../modules/nf-core/multiqc/main'
include { UMITOOLS_EXTRACT } from '../../modules/nf-core/umitools/extract/main'
include { BWA_MEM } from '../../modules/nf-core/bwa/mem/main'
include { BWA_INDEX } from '../../modules/nf-core/bwa/index/main'
include { SUBREAD_FEATURECOUNTS } from '../../modules/nf-core/subread/featurecounts/main'

// Load nf-core subworkflows and modules for BAM processing
include { SAMTOOLS_INDEX } from '../../modules/nf-core/samtools/index/main'
include { SAMTOOLS_INDEX as SAMTOOLS_INDEX_DEDUP } from '../../modules/nf-core/samtools/index/main'
include { SAMTOOLS_STATS } from '../../modules/nf-core/samtools/stats/main'
include { SAMTOOLS_FLAGSTAT } from '../../modules/nf-core/samtools/flagstat/main'
include { SAMTOOLS_IDXSTATS } from '../../modules/nf-core/samtools/idxstats/main'
include { SAMTOOLS_IDXSTATS as SAMTOOLS_IDXSTATS_DEDUP } from '../../modules/nf-core/samtools/idxstats/main'
include { PICARD_COLLECTALIGNMENTSUMMARYMETRICS } from '../../modules/nf-core/picard/collectalignmentsummarymetrics/main'
include { PICARD_COLLECTINSERTSIZEMETRICS } from '../../modules/nf-core/picard/collectinsertsizemetrics/main'
include { MOSDEPTH } from '../../modules/nf-core/mosdepth/main'

// Load UMI deduplication module
include { UMITOOLS_DEDUP } from '../../modules/nf-core/umitools/dedup/main'

// Load UMI grouping module
include { UMITOOLS_GROUP } from '../../modules/nf-core/umitools/group/main'

// Load custom modules (for functionality not available in nf-core)
include { EXTRACT_UMI_QUALITY } from '../../modules/local/extract_umi_quality'
include { UMI_QC_METRICS_POSTUMIEXTRACT } from '../../modules/local/umi_qc_metrics_postumiextract'
include { UMI_QC_METRICS_POSTDEDUP } from '../../modules/local/umi_qc_metrics_postdedup'
include { UMI_QC_HTML_REPORT } from '../../modules/local/umi_qc_html_report'
include { LIBRARY_COVERAGE } from '../../modules/local/library_coverage'

workflow UMI_ANALYSIS_SUBWORKFLOW {
    take:
    samples // channel: [ val(sample), path(fastq_1), path(fastq_2), val(is_single_end) ]
    fasta
    bwa_index
    gtf
    umi_length
    umi_pattern
    umi_method
    umi_quality_filter_threshold
    umi_collision_rate_threshold
    umi_diversity_threshold
    group_strategy
    consensus_strategy
    min_reads
    min_fraction
    error_rate_pre_umi
    max_edit_distance
    min_base_quality
    outdir

    main:
    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    // Step 1: FastQC on RAW reads (before any processing)
    ch_samples_for_fastqc_raw = samples.map { sample, fastq_1, fastq_2, is_single_end ->
        [
            [id: "${sample}_raw", single_end: is_single_end],
            is_single_end ? [fastq_1] : [fastq_1, fastq_2]
        ]
    }
    
    FASTQC_RAW (
        ch_samples_for_fastqc_raw
    )
    ch_versions = ch_versions.mix(FASTQC_RAW.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC_RAW.out.html.map { meta, files -> files }.flatten())

    // Step 2: FASTP QC without trimming (initial QC on raw reads)
    // This provides QC metrics without removing any bases that might contain UMIs
    // NOTE: We pass raw reads here, not extracted reads
    ch_samples_for_fastp_qc = samples.map { sample, fastq_1, fastq_2, is_single_end ->
        [
            [id: "${sample}_qc", single_end: is_single_end],
            is_single_end ? [fastq_1] : [fastq_1, fastq_2],
            []  // adapter_fasta (empty for auto-detection)
        ]
    }
    
    // FASTP_QC: QC, filter, and 3' trim (NO 5' trimming to preserve UMIs)
    // Performs adapter trimming, quality filtering, 3' end trimming
    // but preserves 5' end where UMIs are located
    FASTP_QC (
        ch_samples_for_fastp_qc,
        false,  // discard_trimmed_pass
        false,  // save_trimmed_fail
        false   // save_merged - CRITICAL: no merging in QC step to preserve read pairs
    )
    ch_versions = ch_versions.mix(FASTP_QC.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(FASTP_QC.out.json.map { meta, files -> files }.flatten())
    
    // Step 2b: FastQC after FASTP_QC (check quality after first filtering)
    ch_samples_for_fastqc_after_qc = FASTP_QC.out.reads.map { meta, reads ->
        [
            meta,  // Keep the "_qc" suffix in the ID
            reads
        ]
    }
    
    FASTQC_FASTP_QC (
        ch_samples_for_fastqc_after_qc
    )
    ch_versions = ch_versions.mix(FASTQC_FASTP_QC.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC_FASTP_QC.out.html.map { meta, files -> files }.flatten())
    
    // Step 3: UMI Extraction (uses FASTP_QC filtered reads)
    // CRITICAL: Extract UMIs from the filtered reads (5' end is intact)
    // UMI extraction must happen BEFORE full 5' trimming
    // Use FASTP_QC filtered reads for UMI extraction
    // Remove the "_qc" suffix from meta.id to get original sample name
    ch_samples_for_extract = FASTP_QC.out.reads.map { meta, reads ->
        def original_id = meta.id.replaceAll('_qc$', '')
        [
            [id: original_id, single_end: meta.single_end],
            reads
        ]
    }
    
    UMITOOLS_EXTRACT (
        ch_samples_for_extract
    )
    ch_versions = ch_versions.mix(UMITOOLS_EXTRACT.out.versions)
    
    // Step 3b: Extract UMI sequences with quality scores
    // NOTE: Only processes R1 (Read 1) since UMI is on R1 only
    // Combines original (FASTP_QC) and extracted (UMITOOLS_EXTRACT) reads
    // to create UMI-only FASTQ with sequences and base-by-base quality scores
    ch_for_umi_quality = ch_samples_for_extract
        .join(UMITOOLS_EXTRACT.out.reads, by: 0)
        .map { meta, original_reads, extracted_reads ->
            [meta, original_reads, extracted_reads]
        }
    
    EXTRACT_UMI_QUALITY (
        ch_for_umi_quality,
        umi_length
    )
    ch_versions = ch_versions.mix(EXTRACT_UMI_QUALITY.out.versions)
        
    // Step 3c: UMI QC Metrics - Calculate immediately after UMI extraction
    // Uses reads AFTER quality filtering and UMI extraction, but BEFORE 5' trimming
    // This ensures metrics reflect the actual data used for downstream analysis
    // Use UMITOOLS_EXTRACT output (after FASTP_QC and UMI extraction)
    // Extract R1 only for UMI QC metrics
    ch_samples_for_qc = UMITOOLS_EXTRACT.out.reads
        .map { meta, reads ->
            def r1 = reads instanceof List ? reads[0] : reads
            [meta, r1]  // Use R1 for UMI QC
        }
    
    // Combine with extract logs and UMI-only FASTQ
    // Join all three channels by meta
    ch_qc_input = ch_samples_for_qc
        .join(UMITOOLS_EXTRACT.out.log, by: 0)  // Join extract log
        .join(EXTRACT_UMI_QUALITY.out.umi_fastq, by: 0)  // Join UMI-only FASTQ
    
    // ch_qc_input now has structure: [meta, fastq, log, umi_fastq]
    UMI_QC_METRICS_POSTUMIEXTRACT (
        ch_qc_input,  // Pass all inputs as single tuple
        umi_length,
        umi_quality_filter_threshold,
        umi_collision_rate_threshold,
        umi_diversity_threshold
    )
    ch_versions = ch_versions.mix(UMI_QC_METRICS_POSTUMIEXTRACT.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(UMI_QC_METRICS_POSTUMIEXTRACT.out.multiqc.map { meta, json -> json })
    
    // Use extracted reads for downstream processing
    ch_reads_for_fastp_trim = UMITOOLS_EXTRACT.out.reads

    // Step 4: FASTP with full trimming - Complete preprocessing including 5' trimming
    // Now that UMIs are safely extracted and moved to read headers, we can trim 5' end too
    ch_samples_for_fastp_trim = ch_reads_for_fastp_trim.map { meta, reads ->
        [
            meta,
            reads,
            []  // adapter_fasta (empty for auto-detection)
        ]
    }
    
    FASTP_TRIM (
        ch_samples_for_fastp_trim,
        false,  // discard_trimmed_pass
        false,  // save_trimmed_fail
        false   // save_merged - NO merging for optimal UMI dedup
    )
    ch_versions = ch_versions.mix(FASTP_TRIM.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(FASTP_TRIM.out.json.map { meta, files -> files }.flatten())
    
    // Step 4b: FastQC after FASTP_TRIM (check quality after full trimming)
    // Keep as paired-end for best UMI deduplication
    FASTQC_FASTP_TRIM (
        FASTP_TRIM.out.reads
    )
    ch_versions = ch_versions.mix(FASTQC_FASTP_TRIM.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC_FASTP_TRIM.out.html.map { meta, files -> files }.flatten())
    
    // Step 5: Keep reads as paired-end for optimal UMI deduplication
    // FASTP --correction already fixed overlapping bases without merging
    // This maintains paired-end structure which UMI-tools dedup uses effectively
    ch_processed_reads = FASTP_TRIM.out.reads.map { meta, reads ->
        [
            meta,  // Keep original meta
            reads instanceof List ? reads[0] : reads,  // R1
            reads instanceof List && reads.size() > 1 ? reads[1] : [],  // R2 (empty if single-end)
            reads instanceof List && reads.size() > 1 ? false : true  // is_single_end
        ]
    }

    // Note: UMI QC Metrics are now calculated immediately after UMITOOLS_EXTRACT (Step 3c)
    // This was moved earlier in the workflow for better logical flow

    // Alignment to reference sequences
    // NOTE: Alignment must happen BEFORE UMI deduplication
    // umi_tools dedup requires aligned BAM files with genomic coordinates
    // Create BWA index if not provided
    if (!bwa_index) {
        def fasta_file = file(fasta)
        ch_fasta_for_index = Channel.of([[id: fasta_file.baseName], fasta_file])
        BWA_INDEX (
            ch_fasta_for_index
        )
        ch_bwa_index = BWA_INDEX.out.index
        ch_versions = ch_versions.mix(BWA_INDEX.out.versions)
    } else {
        ch_bwa_index = bwa_index
    }
    
    // Use processed reads (after FASTP) for alignment
    ch_samples_for_align = ch_processed_reads.map { meta, fastq_1, fastq_2, is_single_end ->
        [
            meta,
            is_single_end ? [fastq_1] : [fastq_1, fastq_2]
        ]
    }
    
    // Prepare fasta as a channel with meta
    def fasta_file = file(fasta)
    ch_fasta = Channel.of([[id: fasta_file.baseName], fasta_file])
    
    BWA_MEM (
        ch_samples_for_align,
        ch_bwa_index,
        ch_fasta,
        true  // sort_bam parameter - BWA_MEM sorts with samtools
    )
    ch_versions = ch_versions.mix(BWA_MEM.out.versions)
    
    // Index the sorted BAM files
    SAMTOOLS_INDEX (
        BWA_MEM.out.bam
    )
    ch_versions = ch_versions.mix(SAMTOOLS_INDEX.out.versions)
    
    // Combine BAM and BAI for statistics
    ch_bam_bai_for_stats = BWA_MEM.out.bam
        .join(SAMTOOLS_INDEX.out.bai, by: 0)
        .map { meta, bam, bai -> [meta, bam, bai] }
    
    // Generate alignment statistics
    SAMTOOLS_STATS (
        ch_bam_bai_for_stats,
        ch_fasta
    )
    ch_versions = ch_versions.mix(SAMTOOLS_STATS.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(SAMTOOLS_STATS.out.stats.map { meta, files -> files }.flatten())
    
    SAMTOOLS_FLAGSTAT (
        ch_bam_bai_for_stats
    )
    ch_versions = ch_versions.mix(SAMTOOLS_FLAGSTAT.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(SAMTOOLS_FLAGSTAT.out.flagstat.map { meta, files -> files }.flatten())
    
    SAMTOOLS_IDXSTATS (
        ch_bam_bai_for_stats
    )
    ch_versions = ch_versions.mix(SAMTOOLS_IDXSTATS.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(SAMTOOLS_IDXSTATS.out.idxstats.map { meta, files -> files }.flatten())
    
    // Picard CollectAlignmentSummaryMetrics - Detailed alignment metrics
    PICARD_COLLECTALIGNMENTSUMMARYMETRICS (
        BWA_MEM.out.bam,
        ch_fasta
    )
    ch_versions = ch_versions.mix(PICARD_COLLECTALIGNMENTSUMMARYMETRICS.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(PICARD_COLLECTALIGNMENTSUMMARYMETRICS.out.metrics.map { meta, files -> files }.flatten())
    
    // Picard CollectInsertSizeMetrics - Insert size distribution (for paired-end only)
    // Only run if reads are NOT merged (i.e., kept as paired-end)
    if (!params.merge_pairs) {
        PICARD_COLLECTINSERTSIZEMETRICS (
            BWA_MEM.out.bam
        )
        ch_versions = ch_versions.mix(PICARD_COLLECTINSERTSIZEMETRICS.out.versions)
        ch_multiqc_files = ch_multiqc_files.mix(PICARD_COLLECTINSERTSIZEMETRICS.out.metrics.map { meta, files -> files }.flatten())
    }
    
    // mosdepth - Fast coverage calculation
    // Skip on macOS due to conda package availability issues
    def is_mac = System.getProperty("os.name").toLowerCase().contains("mac")
    if (!params.skip_mosdepth && !is_mac) {
        ch_bam_bai_bed = BWA_MEM.out.bam
            .join(SAMTOOLS_INDEX.out.bai, by: 0)
            .map { meta, bam, bai -> [meta, bam, bai, []] }  // Add empty bed file
        
        MOSDEPTH (
            ch_bam_bai_bed,
            ch_fasta
        )
        ch_versions = ch_versions.mix(MOSDEPTH.out.versions)
        ch_multiqc_files = ch_multiqc_files.mix(MOSDEPTH.out.global_txt.map { meta, files -> files }.flatten())
        ch_multiqc_files = ch_multiqc_files.mix(MOSDEPTH.out.summary_txt.map { meta, files -> files }.flatten())
    } else if (is_mac && !params.skip_mosdepth) {
        log.info "INFO: Skipping mosdepth on macOS due to conda package availability"
    }
    
    // Combine BAM and BAI for grouping and deduplication
    ch_bam_bai = BWA_MEM.out.bam
        .join(SAMTOOLS_INDEX.out.bai, by: 0)
        .map { meta, bam, bai -> [meta, bam, bai] }
    
    // UMI Grouping - inspect UMI groups before deduplication
    // Creates grouped BAM and groups.tsv for inspection
    UMITOOLS_GROUP (
        ch_bam_bai,
        true,  // create_bam - output grouped BAM file
        true   // get_group_info - output groups.tsv file
    )
    ch_versions = ch_versions.mix(UMITOOLS_GROUP.out.versions)
    
    // UMI Deduplication on aligned BAM files using umi-tools
    UMITOOLS_DEDUP (
        ch_bam_bai,
        true  // get_output_stats - generate deduplication statistics
    )
    ch_versions = ch_versions.mix(UMITOOLS_DEDUP.out.versions)
    
    // Post-deduplication UMI QC metrics
    UMI_QC_METRICS_POSTDEDUP (
        UMITOOLS_DEDUP.out.log,
        UMITOOLS_DEDUP.out.tsv_edit_distance,
        UMITOOLS_DEDUP.out.tsv_per_umi,
        UMITOOLS_DEDUP.out.tsv_umi_per_position,
        UMITOOLS_DEDUP.out.bam
    )
    ch_versions = ch_versions.mix(UMI_QC_METRICS_POSTDEDUP.out.versions)
    
    // Index deduplicated BAM files for count generation
    SAMTOOLS_INDEX_DEDUP (
        UMITOOLS_DEDUP.out.bam
    )
    ch_versions = ch_versions.mix(SAMTOOLS_INDEX_DEDUP.out.versions)
    
    // Generate reference counts from deduplicated BAM files
    ch_dedup_bam_bai = UMITOOLS_DEDUP.out.bam
        .join(SAMTOOLS_INDEX_DEDUP.out.bai, by: 0)
        .map { meta, bam, bai -> [meta, bam, bai] }
    
    SAMTOOLS_IDXSTATS_DEDUP (
        ch_dedup_bam_bai
    )
    ch_versions = ch_versions.mix(SAMTOOLS_IDXSTATS_DEDUP.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(SAMTOOLS_IDXSTATS_DEDUP.out.idxstats.map { meta, files -> files }.flatten())
    
    // Generate HTML report from both pre-dedup and post-dedup metrics
    // Combine pre-dedup text, pre-dedup JSON, and post-dedup JSON for comprehensive report
    ch_combined_metrics = UMI_QC_METRICS_POSTUMIEXTRACT.out.qc_metrics
        .join(UMI_QC_METRICS_POSTUMIEXTRACT.out.multiqc, by: 0)
        .join(UMI_QC_METRICS_POSTDEDUP.out.multiqc, by: 0)
        .map { meta, pre_txt, pre_json, post_json ->
            [meta, pre_txt, pre_json, post_json]
        }
    
    UMI_QC_HTML_REPORT (
        ch_combined_metrics
    )
    ch_versions = ch_versions.mix(UMI_QC_HTML_REPORT.out.versions)
    
    // Gene-level counting with featureCounts (if GTF provided)
    // Uses deduplicated BAM for accurate gene expression quantification
    if (gtf) {
        ch_dedup_bam_gtf = UMITOOLS_DEDUP.out.bam.map { meta, bam -> [meta, bam, gtf] }
        
        SUBREAD_FEATURECOUNTS (
            ch_dedup_bam_gtf
        )
        ch_versions = ch_versions.mix(SUBREAD_FEATURECOUNTS.out.versions)
        ch_multiqc_files = ch_multiqc_files.mix(SUBREAD_FEATURECOUNTS.out.summary)
        
        // Calculate library coverage from featureCounts output
        LIBRARY_COVERAGE (
            SUBREAD_FEATURECOUNTS.out.counts,
            fasta
        )
        ch_versions = ch_versions.mix(LIBRARY_COVERAGE.out.versions)
        ch_multiqc_files = ch_multiqc_files.mix(LIBRARY_COVERAGE.out.json.map { meta, json -> json })
    }

    // MultiQC Report - comprehensive report with all QC metrics
    // Prepare MultiQC config
    ch_multiqc_config = Channel.fromPath("${projectDir}/assets/multiqc_config.yaml", checkIfExists: true)
    
    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.collect().ifEmpty([]),  // multiqc_config
        [],  // extra_multiqc_config
        [],  // multiqc_logo
        [],  // replace_names
        []   // sample_names
    )
    ch_versions = ch_versions.mix(MULTIQC.out.versions)

    emit:
    versions = ch_versions
    multiqc = ch_multiqc_files
    extracted = UMITOOLS_EXTRACT.out.reads
    processed = ch_processed_reads
    aligned = BWA_MEM.out.bam
    grouped_bam = UMITOOLS_GROUP.out.bam
    groups_tsv = UMITOOLS_GROUP.out.tsv
    group_log = UMITOOLS_GROUP.out.log
    deduped = UMITOOLS_DEDUP.out.bam
    feature_counts = gtf ? SUBREAD_FEATURECOUNTS.out.counts : Channel.empty()
    library_coverage = gtf ? LIBRARY_COVERAGE.out.coverage : Channel.empty()
    umi_html_report = UMI_QC_HTML_REPORT.out.html_report
    dedup_idxstats = SAMTOOLS_IDXSTATS_DEDUP.out.idxstats
}