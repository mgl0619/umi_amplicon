process EXTRACT_UMI_QUALITY {
    tag "$meta.id"
    label 'process_low'

    conda "conda-forge::python=3.11"
    container "quay.io/biocontainers/python:3.11"

    input:
    tuple val(meta), path(original_reads), path(extracted_reads)  // Original and extracted FASTQ
    val(umi_length)

    output:
    tuple val(meta), path("*.umi_only.fastq.gz"), emit: umi_fastq
    path "versions.yml"                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    // NOTE: Only process R1 (Read 1) since UMI is typically on R1 only
    // For paired-end data, R2 does not contain UMI information
    def original_r1 = original_reads instanceof List ? original_reads[0] : original_reads
    def extracted_r1 = extracted_reads instanceof List ? extracted_reads[0] : extracted_reads
    """
    extract_umi_with_quality.py \\
        -i ${original_r1} \\
        -e ${extracted_r1} \\
        -o ${prefix}.umi_only.fastq.gz \\
        -l ${umi_length}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
