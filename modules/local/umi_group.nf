process UMI_GROUP {
    label 'process_high'

    conda (params.enable_conda ? "bioconda::umitools=1.1.2" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/umitools:1.1.2--pyhdfd78af_0' :
        'biocontainers/umitools:1.1.2--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(reads)
    val(umi_method)
    val(group_method)

    output:
    tuple val(meta), path("*.grouped.bam"), emit: bam
    tuple val(meta), path("*.group.log"), emit: log
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def paired = meta.single_end ? "" : "--paired"
    def umi_method = umi_method ?: "directional"
    def group_method = group_method ?: "directional"
    
    """
    #!/bin/bash
    set -euo pipefail

    echo "Grouping reads by UMI for sample: ${meta.id}"
    echo "UMI method: ${umi_method}"
    echo "Group method: ${group_method}"

    # Group reads by UMI using umi_tools group
    umi_tools \\
        group \\
        -I ${reads} \\
        -S ${prefix}.grouped.bam \\
        -L ${prefix}.group.log \\
        --method ${group_method} \\
        --umi-method ${umi_method} \\
        $paired \\
        $args

    # Generate grouping statistics
    echo "UMI Grouping Statistics for ${meta.id}" > ${prefix}.group_stats.txt
    echo "=====================================" >> ${prefix}.group_stats.txt
    
    # Extract group information from log
    if [ -f ${prefix}.group.log ]; then
        echo "Grouping log contents:" >> ${prefix}.group_stats.txt
        cat ${prefix}.group.log >> ${prefix}.group_stats.txt
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        umitools: \$( umi_tools --version | sed '/version:/!d; s/.*: //' )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.grouped.bam
    touch ${prefix}.group.log
    echo "UMI Grouping Statistics for ${meta.id}" > ${prefix}.group_stats.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        umitools: \$( umi_tools --version | sed '/version:/!d; s/.*: //' )
    END_VERSIONS
    """
}

