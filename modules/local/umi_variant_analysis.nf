process UMI_VARIANT_ANALYSIS {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container 'quay.io/biocontainers/mulled-v2-509311a44e1cf58d8e9a9feffc50c6b08b0a09b3:3a98c46866b5e6f237c1c24f0f83321e8f4b9f0e-0'

    input:
    tuple val(meta), path(bam), path(bai)
    val min_reads_per_umi

    output:
    tuple val(meta), path("*.txt"), emit: report
    tuple val(meta), path("*_mqc.json"), emit: multiqc
    tuple val(meta), path("*_details.json"), emit: details
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def min_reads = min_reads_per_umi ?: 2
    """
    analyze_umi_variants.py \\
        -i ${bam} \\
        -o ${prefix} \\
        --min-reads ${min_reads} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //g')
        pysam: \$(python -c "import pysam; print(pysam.__version__)")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_umi_variant_analysis.txt
    touch ${prefix}_umi_variant_analysis_mqc.json
    touch ${prefix}_umi_variant_details.json
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //g')
        pysam: \$(python -c "import pysam; print(pysam.__version__)")
    END_VERSIONS
    """
}
