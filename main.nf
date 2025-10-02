#!/usr/bin/env nextflow

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nf-core/umi-amplicon Pipeline
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    UMI-tagged amplicon sequencing analysis pipeline
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

nextflow.enable.dsl = 2

def helpMessage() {
    log.info nfcoreHeader()
    log.info """
    =========================================
     nf-core/umi-amplicon v${workflow.manifest.version}
    =========================================

    Usage:
        nextflow run nf-core/umi-amplicon --input samplesheet.csv --outdir <OUTDIR> [options]

    Mandatory arguments:
        --input [file]                        Path to input samplesheet (see format below)
        --outdir [file]                       The output directory where the results will be saved

    Options:
        --genome [str]                        Name of iGenomes reference
        --fasta [file]                        Path to FASTA genome file
        --bwa_index [file]                    Path to BWA index files
        --gtf [file]                          Path to GTF annotation file
        --skip_alignment                      Skip alignment step
        --skip_feature_counting              Skip feature counting step
        --umitools_path [str]                 Path to UMI-tools installation
        --umi_length [int]                    Length of UMI sequences (default: 12)
        --umi_pattern [str]                   Pattern for UMI extraction (default: NNNNNNNNNNNN)
        --umi_method [str]                    UMI extraction method: 'directional' or 'unique' (default: 'directional')
        --umi_quality_threshold [int]         Minimum quality score for UMI bases (default: 10)
        --umi_collision_rate_threshold [float] Maximum acceptable collision rate (default: 0.1)
        --umi_diversity_threshold [int]        Minimum UMI diversity (default: 1000)
        --skip_umi_qc                         Skip UMI quality control metrics
        --skip_umi_analysis                   Skip UMI analysis pipeline
        --skip_report                         Skip HTML report generation
        --help                                Show this help message
        --version                             Show pipeline version

    Input samplesheet format:
        sample,fastq_1,fastq_2,umi_1,umi_2
        SAMPLE1,/path/to/sample1_R1.fastq.gz,/path/to/sample1_R2.fastq.gz,/path/to/sample1_UMI1.fastq.gz,/path/to/sample1_UMI2.fastq.gz
        SAMPLE2,/path/to/sample2_R1.fastq.gz,/path/to/sample2_R2.fastq.gz,/path/to/sample2_UMI1.fastq.gz,/path/to/sample2_UMI2.fastq.gz

    Citation:
        If you use nf-core/umi-amplicon for your analysis please cite it using the following doi: TBD

    Pipeline documentation:
        https://nf-co.re/umi-amplicon
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

    ${c_blue}    nf-core/umi-amplicon v${workflow.manifest.version}${c_reset}
    ${c_blue}    UMI-tagged amplicon sequencing analysis pipeline${c_reset}
    """.stripIndent()
}

// Check Nextflow version
nextflowVersion = "23.04.0"
if (workflow.nextflow.version) {
    if (!workflow.nextflow.version.startsWith("23.04") && !workflow.nextflow.version.startsWith("23.10") && !workflow.nextflow.version.startsWith("24.0")) {
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

// Set default parameters
params.umitools_path = params.umitools_path ?: "umitools"
params.umi_length = params.umi_length ?: 12
params.umi_pattern = params.umi_pattern ?: "NNNNNNNNNNNN"
params.umi_method = params.umi_method ?: "directional"
params.umi_quality_threshold = params.umi_quality_threshold ?: 10
params.umi_collision_rate_threshold = params.umi_collision_rate_threshold ?: 0.1
params.umi_diversity_threshold = params.umi_diversity_threshold ?: 1000
params.skip_umi_qc = params.skip_umi_qc ?: false
params.skip_umi_analysis = params.skip_umi_analysis ?: false
params.skip_report = params.skip_report ?: false

// Print pipeline information
log.info nfcoreHeader()
log.info "Pipeline parameters:"
log.info "  Input samplesheet: ${params.input}"
log.info "  Output directory: ${params.outdir}"
log.info "  UMI-tools path: ${params.umitools_path}"
log.info "  UMI length: ${params.umi_length}"
log.info "  UMI pattern: ${params.umi_pattern}"
log.info "  UMI method: ${params.umi_method}"
log.info "  UMI quality threshold: ${params.umi_quality_threshold}"
log.info "  UMI collision rate threshold: ${params.umi_collision_rate_threshold}"
log.info "  UMI diversity threshold: ${params.umi_diversity_threshold}"
log.info "  Skip UMI QC: ${params.skip_umi_qc}"
log.info "  Skip UMI analysis: ${params.skip_umi_analysis}"
log.info "  Skip report: ${params.skip_report}"

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
    .map { row -> [row.sample, row.fastq_1, row.fastq_2, row.umi_1, row.umi_2] }
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
        params.skip_alignment,
        params.skip_feature_counting,
        params.umi_length,
        params.umi_pattern,
        params.umi_method,
        params.umi_quality_threshold,
        params.umi_collision_rate_threshold,
        params.umi_diversity_threshold,
        params.skip_umi_qc,
        params.skip_umi_analysis,
        params.skip_report,
        params.outdir
    )
    
    ch_versions = ch_versions.mix(UMI_ANALYSIS_SUBWORKFLOW.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(UMI_ANALYSIS_SUBWORKFLOW.out.multiqc)
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

