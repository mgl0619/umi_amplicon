/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    umi-amplicon UMI Analysis Subworkflow
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    UMI-tagged amplicon sequencing analysis subworkflow
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Load nf-core modules
include { FASTQC } from '../../modules/nf-core/fastqc/main'
include { MULTIQC } from '../../modules/nf-core/multiqc/main'
include { UMITOOLS_EXTRACT } from '../../modules/nf-core/umitools/extract/main'
include { BWA_MEM } from '../../modules/nf-core/bwa/mem/main'
include { BWA_INDEX } from '../../modules/nf-core/bwa/index/main'
include { SUBREAD_FEATURECOUNTS } from '../../modules/nf-core/subread/featurecounts/main'

// Load fgbio modules
include { FGBIO_FASTQTOBAM } from '../../modules/nf-core/fgbio/fastqtobam/main'
include { FGBIO_GROUPREADSBYUMI } from '../../modules/nf-core/fgbio/groupreadsbyumi/main'
include { FGBIO_CALLMOLECULARCONSENSUSREADS } from '../../modules/nf-core/fgbio/callmolecularconsensusreads/main'
include { FGBIO_CALLDUPLEXCONSENSUSREADS } from '../../modules/nf-core/fgbio/callduplexconsensusreads/main'

// Load local modules
include { UMI_EXTRACT_EMBEDDED } from '../../modules/local/umi_extract_embedded'

// Load nf-core subworkflows
include { BAM_DEDUP_UMI } from '../../subworkflows/nf-core/bam_dedup_umi/main'

// Load custom modules (for functionality not available in nf-core)
include { UMI_QC_METRICS } from '../../modules/local/umi_qc_metrics'
include { UMI_DEDUP_FASTQ } from '../../modules/local/umi_dedup_fastq'
include { UMI_ANALYSIS } from '../../modules/local/umi_analysis'

// Load UMI-tools modules
include { UMI_GROUP } from '../../modules/local/umi_group'
include { UMI_CONSENSUS } from '../../modules/local/umi_consensus'
include { UMI_FILTER } from '../../modules/local/umi_filter'

// Note: fgbio modules are not available in nf-core modules yet
// Using UMI-tools modules for UMI processing

workflow UMI_ANALYSIS_SUBWORKFLOW {
    take:
    samples // channel: [ val(sample), path(fastq_1), path(fastq_2), path(umi_1), path(umi_2) ]
    fasta
    bwa_index
    gtf
    skip_alignment
    skip_feature_counting
    umi_length
    umi_pattern
    umi_method
    umi_quality_threshold
    umi_collision_rate_threshold
    umi_diversity_threshold
    umi_tool
    group_strategy
    consensus_strategy
    min_reads
    min_fraction
    error_rate_pre_umi
    max_edit_distance
    min_base_quality
    skip_umi_qc
    skip_umi_analysis
    skip_report
    outdir

    main:
    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    // FastQC for quality control
    ch_samples_for_fastqc = samples.map { sample, fastq_1, fastq_2, umi_1, umi_2 ->
        [
            [id: sample, single_end: false],
            [fastq_1, fastq_2]
        ]
    }
    
    FASTQC (
        ch_samples_for_fastqc
    )
    ch_versions = ch_versions.mix(FASTQC.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.html)

    // UMI Extraction - Handle both separate UMI files and embedded UMIs
    ch_samples_for_extract = samples.map { sample, fastq_1, fastq_2, umi_1, umi_2 ->
        [
            [id: sample, single_end: false],
            [fastq_1, fastq_2]
        ]
    }
    
    // For embedded UMIs, use the embedded extraction module
    // Check if UMI files are empty (embedded UMIs)
    UMI_EXTRACT_EMBEDDED (
        ch_samples_for_extract,
        umi_length,
        umi_pattern
    )
    ch_versions = ch_versions.mix(UMI_EXTRACT_EMBEDDED.out.versions)

    // UMI QC Metrics - Use extracted UMI files
    if (!skip_umi_qc) {
        // Create samples with extracted UMI files
        ch_samples_with_umis = UMI_EXTRACT_EMBEDDED.out.reads
            .combine(UMI_EXTRACT_EMBEDDED.out.umi1, by: 0)
            .combine(UMI_EXTRACT_EMBEDDED.out.umi2, by: 0)
            .map { meta, reads, umi1, umi2 ->
                [meta.id, reads, reads, umi1, umi2]
            }
        
        UMI_QC_METRICS (
            ch_samples_with_umis,
            umi_length,
            umi_quality_threshold,
            umi_collision_rate_threshold,
            umi_diversity_threshold
        )
        ch_versions = ch_versions.mix(UMI_QC_METRICS.out.versions)
        ch_multiqc_files = ch_multiqc_files.mix(UMI_QC_METRICS.out.multiqc)
    }

    // UMI Processing - Choose between UMI-tools and fgbio
    if (umi_tool == "umitools") {
        // UMI-tools workflow: Extract → Dedup → Group → Consensus → Filter
        def extracted_reads = UMI_EXTRACT_EMBEDDED.out.reads
        UMI_DEDUP_FASTQ (
            extracted_reads
        )
        ch_versions = ch_versions.mix(UMI_DEDUP_FASTQ.out.versions)
        
    } else if (umi_tool == "fgbio") {
        // fgbio workflow: Extract → FastQToBam → Group → Consensus → Filter
        log.info "Using fgbio modules for UMI processing"
        
        // Convert FASTQ to BAM with UMI extraction
        ch_samples_for_fastqtobam = samples.map { sample, fastq_1, fastq_2, umi_1, umi_2 ->
            [
                [id: sample, single_end: false],
                [fastq_1, fastq_2]
            ]
        }
        
        FGBIO_FASTQTOBAM (
            ch_samples_for_fastqtobam
        )
        ch_versions = ch_versions.mix(FGBIO_FASTQTOBAM.out.versions)
        
        // Group reads by UMI
        FGBIO_GROUPREADSBYUMI (
            FGBIO_FASTQTOBAM.out.bam
        )
        ch_versions = ch_versions.mix(FGBIO_GROUPREADSBYUMI.out.versions)
        
        // Call molecular consensus
        FGBIO_CALLMOLECULARCONSENSUSREADS (
            FGBIO_GROUPREADSBYUMI.out.bam
        )
        ch_versions = ch_versions.mix(FGBIO_CALLMOLECULARCONSENSUSREADS.out.versions)
        
    } else {
        log.error "ERROR: Invalid UMI tool specified: ${umi_tool}. Must be 'umitools' or 'fgbio'"
        exit 1
    }

    // Alignment to reference sequences (optional)
    if (!skip_alignment) {
        ch_samples_for_align = UMI_DEDUP_FASTQ.out.reads.map { meta, reads ->
            [
                meta,
                reads
            ]
        }
        
        BWA_MEM (
            ch_samples_for_align,
            bwa_index,
            fasta,
            true  // sort_bam parameter
        )
        ch_versions = ch_versions.mix(BWA_MEM.out.versions)
        
        // Feature counting for multiple reference sequences
        if (!skip_feature_counting) {
            SUBREAD_FEATURECOUNTS (
                BWA_MEM.out.bam,
                gtf
            )
            ch_versions = ch_versions.mix(SUBREAD_FEATURECOUNTS.out.versions)
            ch_multiqc_files = ch_multiqc_files.mix(SUBREAD_FEATURECOUNTS.out.summary)
        }
    }

    // UMI Analysis
    if (!skip_umi_analysis) {
        UMI_ANALYSIS (
            UMI_DEDUP_FASTQ.out.reads,
            umi_method
        )
        ch_versions = ch_versions.mix(UMI_ANALYSIS.out.versions)
        ch_multiqc_files = ch_multiqc_files.mix(UMI_ANALYSIS.out.multiqc)
    }

    // MultiQC Report
    if (!skip_report) {
        MULTIQC (
            ch_multiqc_files,
            [],  // multiqc_config
            [],  // extra_multiqc_config
            [],  // multiqc_logo
            [],  // replace_names
            []   // sample_names
        )
        ch_versions = ch_versions.mix(MULTIQC.out.versions)
    }

    emit:
    versions = ch_versions
    multiqc = ch_multiqc_files
    extracted = UMI_EXTRACT_EMBEDDED.out.reads
    deduped = UMI_DEDUP_FASTQ.out.reads
    aligned = skip_alignment ? Channel.empty() : BWA_MEM.out.bam
    feature_counts = skip_feature_counting ? Channel.empty() : SUBREAD_FEATURECOUNTS.out.counts
    analysis = UMI_ANALYSIS.out.results
}