process UMI_CONSENSUS {
    label 'process_high'

    conda (params.enable_conda ? "bioconda::umitools=1.1.2" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/umitools:1.1.2--pyhdfd78af_0' :
        'biocontainers/umitools:1.1.2--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(grouped_bam)
    val(consensus_method)
    val(min_reads)
    val(min_qual)

    output:
    tuple val(meta), path("*.consensus.bam"), emit: bam
    tuple val(meta), path("*.consensus.log"), emit: log
    path "*.consensus_stats.txt", emit: stats
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def consensus_method = consensus_method ?: "directional"
    def min_reads = min_reads ?: 1
    def min_qual = min_qual ?: 0
    
    """
    #!/bin/bash
    set -euo pipefail

    echo "Calling consensus sequences for sample: ${meta.id}"
    echo "Consensus method: ${consensus_method}"
    echo "Minimum reads per group: ${min_reads}"
    echo "Minimum quality: ${min_qual}"

    # Call consensus using umi_tools consensus
    umi_tools \\
        consensus \\
        -I ${grouped_bam} \\
        -S ${prefix}.consensus.bam \\
        -L ${prefix}.consensus.log \\
        --method ${consensus_method} \\
        --min-reads ${min_reads} \\
        --min-qual ${min_qual} \\
        $args

    # Generate consensus statistics
    echo "UMI Consensus Statistics for ${meta.id}" > ${prefix}.consensus_stats.txt
    echo "=====================================" >> ${prefix}.consensus_stats.txt
    echo "Consensus method: ${consensus_method}" >> ${prefix}.consensus_stats.txt
    echo "Minimum reads per group: ${min_reads}" >> ${prefix}.consensus_stats.txt
    echo "Minimum quality: ${min_qual}" >> ${prefix}.consensus_stats.txt
    echo "" >> ${prefix}.consensus_stats.txt
    
    # Extract consensus information from log
    if [ -f ${prefix}.consensus.log ]; then
        echo "Consensus log contents:" >> ${prefix}.consensus_stats.txt
        cat ${prefix}.consensus.log >> ${prefix}.consensus_stats.txt
    fi

    # Calculate consensus metrics
    total_groups=\$(samtools view -c ${grouped_bam} 2>/dev/null || echo "0")
    consensus_reads=\$(samtools view -c ${prefix}.consensus.bam 2>/dev/null || echo "0")
    
    echo "Total grouped reads: \$total_groups" >> ${prefix}.consensus_stats.txt
    echo "Consensus reads: \$consensus_reads" >> ${prefix}.consensus_stats.txt
    
    if [ "\$total_groups" -gt 0 ]; then
        consensus_rate=\$(echo "scale=4; \$consensus_reads / \$total_groups" | bc -l)
        echo "Consensus rate: \$consensus_rate" >> ${prefix}.consensus_stats.txt
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        umitools: \$( umi_tools --version | sed '/version:/!d; s/.*: //' )
        samtools: \$( samtools --version | head -n1 | sed 's/.*samtools //' )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.consensus.bam
    touch ${prefix}.consensus.log
    echo "UMI Consensus Statistics for ${meta.id}" > ${prefix}.consensus_stats.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        umitools: \$( umi_tools --version | sed '/version:/!d; s/.*: //' )
        samtools: \$( samtools --version | head -n1 | sed 's/.*samtools //' )
    END_VERSIONS
    """
}

