/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nf-core/umi-amplicon UMI Analysis Subworkflow
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

// Load nf-core subworkflows
include { BAM_DEDUP_UMI } from '../../subworkflows/nf-core/bam_dedup_umi/main'

// Load custom modules (for functionality not available in nf-core)
include { UMI_QC_METRICS } from '../../modules/local/umi_qc_metrics'
include { UMI_DEDUP_FASTQ } from '../../modules/local/umi_dedup_fastq'
include { UMI_ANALYSIS } from '../../modules/local/umi_analysis'

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

    // UMI QC Metrics
    if (!skip_umi_qc) {
        UMI_QC_METRICS (
            samples,
            umi_length,
            umi_quality_threshold,
            umi_collision_rate_threshold,
            umi_diversity_threshold
        )
        ch_versions = ch_versions.mix(UMI_QC_METRICS.out.versions)
        ch_multiqc_files = ch_multiqc_files.mix(UMI_QC_METRICS.out.multiqc)
    }

    // UMI Extraction using nf-core module
    // Convert samples to format expected by nf-core module
    ch_samples_for_extract = samples.map { sample, fastq_1, fastq_2, umi_1, umi_2 ->
        [
            [id: sample, single_end: false],
            [fastq_1, fastq_2]
        ]
    }
    
    UMITOOLS_EXTRACT (
        ch_samples_for_extract
    )
    ch_versions = ch_versions.mix(UMITOOLS_EXTRACT.out.versions)

    // UMI Deduplication using UMI-tools directly on FASTQ
    // This is the correct approach for amplicon sequencing
    UMI_DEDUP_FASTQ (
        UMITOOLS_EXTRACT.out.reads
    )
    ch_versions = ch_versions.mix(UMI_DEDUP_FASTQ.out.versions)

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
            fasta,
            bwa_index
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
            ch_versions,
            []
        )
        ch_versions = ch_versions.mix(MULTIQC.out.versions)
    }

    emit:
    versions = ch_versions
    multiqc = ch_multiqc_files
    extracted = UMITOOLS_EXTRACT.out.reads
    deduped = UMI_DEDUP_FASTQ.out.reads
    aligned = BWA_MEM.out.bam
    feature_counts = SUBREAD_FEATURECOUNTS.out.counts
    analysis = UMI_ANALYSIS.out.results
}