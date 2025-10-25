#!/usr/bin/env nextflow

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    umi-amplicon Pipeline
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    UMI-tagged amplicon sequencing analysis pipeline
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

nextflow.enable.dsl = 2

def helpMessage() {
    log.info nfcoreHeader()
    log.info """
    =========================================
     umi-amplicon v${workflow.manifest.version}
    =========================================

    Usage:
        nextflow run umi-amplicon --input samplesheet.csv --fasta <FASTA> --outdir <OUTDIR> [options]

    Mandatory arguments:
        --input [file]                        Path to input samplesheet (see format below)
        --fasta [file]                        Path to FASTA reference genome file
        --outdir [file]                       The output directory where the results will be saved (default: ./results)

    Reference options:
        --bwa_index [file]                    Path to BWA index directory (if not provided, will be generated)
        --gtf [file]                          Path to GTF annotation file (required for feature counting)

    UMI parameters:
        --umi_length [int]                    Length of UMI sequences (default: 12)
        --umi_pattern [str]                   Pattern for UMI extraction (default: NNNNNNNNNNNN)
        --umi_method [str]                    UMI deduplication method: 'directional', 'unique', 'cluster', 'adjacency' (default: 'directional')
        --umi_quality_filter_threshold [int]  Quality filter threshold for UMI bases (default: 15)
        --umi_collision_rate_threshold [float] Maximum acceptable collision rate (default: 0.1)
        --umi_diversity_threshold [int]       Minimum expected UMI diversity (default: 1000)
        --max_edit_distance [int]             Maximum edit distance for UMI clustering (default: 1)
        --min_base_quality [int]              Minimum base quality for filtering (default: 20)

    Workflow options:
        --skip_fgbio                          Skip fgbio consensus workflow (run only umi_tools dedup) (default: false)
        --skip_mosdepth                       Skip mosdepth coverage analysis (default: false)

    fgbio consensus parameters:
        --fgbio_group_strategy [str]          UMI grouping strategy: 'adjacency', 'identity', 'edit', 'paired' (default: 'adjacency')
        --fgbio_min_reads [int]               Minimum reads to form consensus (default: 1)
        --fgbio_min_baseq [int]               Minimum base quality for consensus calling (default: 20)

    Other options:
        --help                                Show this help message
        --version                             Show pipeline version

    Input samplesheet format:
        # Paired-end samples
        sample,fastq_1,fastq_2
        SAMPLE1,/path/to/sample1_R1.fastq.gz,/path/to/sample1_R2.fastq.gz
        
        # Single-end samples (fastq_2 can be empty or omitted)
        sample,fastq_1,fastq_2
        SAMPLE2,/path/to/sample2_R1.fastq.gz,

    Default workflow:
        - Runs BOTH umi_tools dedup AND fgbio consensus for comprehensive analysis
        - Use --skip_fgbio for faster processing (umi_tools only)
        - Both methods produce: BAM files, variant analysis, feature counts, coverage metrics

    """.stripIndent()
}

def nfcoreHeader() {
    // Log colors ANSI codes
    c_red = "\033[0;31m"
    c_green = "\033[0;32m"
    c_yellow = "\033[1;33m"
    c_blue = "\033[0;34m"
    c_purple = "\033[0;35m"
    c_cyan = "\033[0;36m"
    c_reset = "\033[0m"
    return """
    ${c_red}        ___           ___           ___           ___           ___           ___     ${c_reset}
    ${c_red}       /\\  \\         /\\  \\         /\\  \\         /\\  \\         /\\  \\         /\\  \\    ${c_reset}
    ${c_red}      /::\\  \\       /::\\  \\       /::\\  \\       /::\\  \\       /::\\  \\       /::\\  \\   ${c_reset}
    ${c_red}     /:/\\:\\  \\     /:/\\:\\  \\     /:/\\:\\  \\     /:/\\:\\  \\     /:/\\:\\  \\     /:/\\:\\  \\  ${c_reset}
    ${c_red}    /:/ /::\\  \\   /:/ /::\\  \\   /:/ /::\\  \\   /:/ /::\\  \\   /:/ /::\\  \\   /:/ /::\\  \\ ${c_reset}
    ${c_red}   /:/_/:/\\:\\__\\ /:/_/:/\\:\\__\\ /:/_/:/\\:\\__\\ /:/_/:/\\:\\__\\ /:/_/:/\\:\\__\\ /:/_/:/\\:\\__\\${c_reset}
    ${c_red}   \\:\\/:/  \\/__/ \\:\\/:/  \\/__/ \\:\\/:/  \\/__/ \\:\\/:/  \\/__/ \\:\\/:/  \\/__/ \\:\\/:/  \\/__/${c_reset}
    ${c_red}    \\::/__/       \\::/__/       \\::/__/       \\::/__/       \\::/__/       \\::/__/      ${c_reset}
    ${c_red}     \\:\\  \\        \\:\\  \\        \\:\\  \\        \\:\\  \\        \\:\\  \\        \\:\\  \\     ${c_reset}
    ${c_red}      \\:\\__\\        \\:\\__\\        \\:\\__\\        \\:\\__\\        \\:\\__\\        \\:\\__\\    ${c_reset}
    ${c_red}       \\/__/         \\/__/         \\/__/         \\/__/         \\/__/         \\/__/     ${c_reset}

    ${c_blue}    umi-amplicon v${workflow.manifest.version}${c_reset}
    ${c_blue}    UMI-tagged amplicon sequencing analysis pipeline${c_reset}
    """.stripIndent()
}

// Check Nextflow version
nextflowVersion = "23.04.0"
if (workflow.nextflow.version) {
    def versionString = workflow.nextflow.version.toString()
    if (!versionString.startsWith("23.04") && !versionString.startsWith("23.10") && !versionString.startsWith("24.0")) {
        log.warn "WARNING: This pipeline has been tested with Nextflow versions 23.04.0, 23.10.0 and 24.0.0. You are running version ${workflow.nextflow.version}."
    }
} else {
    log.warn "WARNING: This pipeline has been tested with Nextflow versions 23.04.0, 23.10.0 and 24.0.0. You are running an unknown version."
}

// Check if help is requested
if (params.help) {
    helpMessage()
    exit 0
}

// Check if version is requested
if (params.version) {
    log.info nfcoreHeader()
    exit 0
}

// Check if input samplesheet is provided
if (!params.input) {
    log.error "ERROR: Input samplesheet not specified!"
    helpMessage()
    exit 1
}

// Check if output directory is provided
if (!params.outdir) {
    log.error "ERROR: Output directory not specified!"
    helpMessage()
    exit 1
}

// Check if input samplesheet exists
if (!file(params.input).exists()) {
    log.error "ERROR: Input samplesheet does not exist: ${params.input}"
    exit 1
}

// Check if output directory exists and is writable
if (!params.outdir) {
    log.error "ERROR: Output directory not specified!"
    exit 1
}

// Create output directory if it doesn't exist
if (!file(params.outdir).exists()) {
    log.info "Creating output directory: ${params.outdir}"
    file(params.outdir).mkdirs()
}

// Check if output directory is writable
if (!file(params.outdir).canWrite()) {
    log.error "ERROR: Output directory is not writable: ${params.outdir}"
    exit 1
}

// Note: Default parameters are set in nextflow.config
// No need to set defaults here as they're already defined in config

// Print pipeline information
log.info nfcoreHeader()
log.info "Pipeline parameters:"
log.info "  Input samplesheet: ${params.input}"
log.info "  Output directory: ${params.outdir}"
log.info "  FASTA reference: ${params.fasta}"
log.info "  GTF annotation: ${params.gtf ?: 'Not provided'}"
log.info ""
log.info "UMI parameters:"
log.info "  UMI length: ${params.umi_length}"
log.info "  UMI pattern: ${params.umi_pattern}"
log.info "  UMI method: ${params.umi_method}"
log.info "  Quality filter threshold: ${params.umi_quality_filter_threshold}"
log.info "  Collision rate threshold: ${params.umi_collision_rate_threshold}"
log.info "  Diversity threshold: ${params.umi_diversity_threshold}"
log.info ""
log.info "Workflow options:"
log.info "  Skip fgbio: ${params.skip_fgbio}"
log.info "  Skip mosdepth: ${params.skip_mosdepth}"
log.info ""
log.info "fgbio consensus parameters:"
log.info "  Group strategy: ${params.fgbio_group_strategy}"
log.info "  Min reads: ${params.fgbio_min_reads}"
log.info "  Min base quality: ${params.fgbio_min_baseq}"

// Load nf-core modules
include { FASTQC } from './modules/nf-core/fastqc/main'
include { MULTIQC } from './modules/nf-core/multiqc/main'

include { UMITOOLS_EXTRACT } from './modules/nf-core/umitools/extract/main'
include { BWA_MEM } from './modules/nf-core/bwa/mem/main'
include { BWA_INDEX } from './modules/nf-core/bwa/index/main'
include { SUBREAD_FEATURECOUNTS } from './modules/nf-core/subread/featurecounts/main'

// Load nf-core subworkflows
include { BAM_DEDUP_UMI } from './subworkflows/nf-core/bam_dedup_umi/main'

// Load custom subworkflows
include { UMI_ANALYSIS_SUBWORKFLOW } from './subworkflows/local/umi_analysis'

// Load samplesheet
Channel
    .fromPath(params.input)
    .splitCsv(header: true, sep: ',')
    .map { row -> 
        def fastq_2 = row.fastq_2 ?: ''
        def is_single_end = fastq_2 == '' || fastq_2 == null
        
        // Validate and output file information
        log.info "Processing sample: ${row.sample}"
        log.info "  Read 1: ${row.fastq_1}"
        
        // Validate R1 exists
        if (!file(row.fastq_1).exists()) {
            log.error "ERROR: Read 1 file does not exist: ${row.fastq_1}"
            exit 1
        }
        log.info "  ✓ Read 1 file exists (${file(row.fastq_1).size()} bytes)"
        
        // Validate R2 if paired-end
        if (!is_single_end) {
            log.info "  Read 2: ${fastq_2}"
            if (!file(fastq_2).exists()) {
                log.error "ERROR: Read 2 file does not exist: ${fastq_2}"
                exit 1
            }
            log.info "  ✓ Read 2 file exists (${file(fastq_2).size()} bytes)"
            log.info "  Mode: Paired-end"
        } else {
            log.info "  Mode: Single-end"
        }
        log.info ""
        
        [row.sample, row.fastq_1, fastq_2, is_single_end]
    }
    .set { ch_samples }

// Main workflow
workflow {
    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    // UMI Analysis Subworkflow
    UMI_ANALYSIS_SUBWORKFLOW (
        ch_samples,
        params.fasta,
        params.bwa_index,
        params.gtf,
        params.umi_length,
        params.outdir
    )
    
    ch_versions = ch_versions.mix(UMI_ANALYSIS_SUBWORKFLOW.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(UMI_ANALYSIS_SUBWORKFLOW.out.multiqc)
    
    // MultiQC report
    MULTIQC (
        ch_multiqc_files.collect(),
        [],  // multiqc_config
        [],  // extra_multiqc_config  
        [],  // multiqc_logo
        [],  // replace_names
        []   // sample_names
    )
    ch_versions = ch_versions.mix(MULTIQC.out.versions)
}

// Workflow completion
workflow.onComplete {
    log.info nfcoreHeader()
    log.info "Pipeline completed successfully!"
    log.info "Results are available in: ${params.outdir}"
}

// Workflow error handling
workflow.onError {
    log.error "Pipeline failed with error: ${workflow.errorMessage}"
    exit 1
}

