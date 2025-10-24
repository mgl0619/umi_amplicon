process LIBRARY_COVERAGE {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/library_coverage_environment.yml"
    container 'quay.io/biocontainers/mulled-v2-f42a44964bca5225c7860882e231a7b5488b5485:47ef981087c59f79fdbcab4d9d7316e9ac2e688d-0'

    input:
    tuple val(meta), path(counts)
    path(reference_fasta)

    output:
    tuple val(meta), path("*_library_coverage.txt"), emit: coverage
    tuple val(meta), path("*_library_coverage.json"), emit: json
    tuple val(meta), path("*_distribution.png"), emit: plot
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def sample_id = meta.id
    """
    calculate_library_coverage.py \\
        --counts ${counts} \\
        --fasta ${reference_fasta} \\
        --sample-id "${sample_id}" \\
        --output-prefix ${prefix}
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)")
        matplotlib: \$(python3 -c "import matplotlib; print(matplotlib.__version__)")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_library_coverage.txt
    touch ${prefix}_library_coverage.json
    touch ${prefix}_distribution.png
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}
