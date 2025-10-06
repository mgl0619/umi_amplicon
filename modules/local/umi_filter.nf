process UMI_FILTER {
    label 'process_medium'

    conda (params.enable_conda ? "bioconda::umitools=1.1.2 bioconda::samtools=1.18" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/umitools:1.1.2--pyhdfd78af_0' :
        'biocontainers/umitools:1.1.2--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(consensus_bam)
    val(min_reads_filter)
    val(min_qual_filter)
    val(max_edit_distance)

    output:
    tuple val(meta), path("*.filtered.bam"), emit: bam
    tuple val(meta), path("*.filter.log"), emit: log
    path "*.filter_stats.txt", emit: stats
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def min_reads_filter = min_reads_filter ?: 1
    def min_qual_filter = min_qual_filter ?: 0
    def max_edit_distance = max_edit_distance ?: 1
    
    """
    #!/bin/bash
    set -euo pipefail

    echo "Filtering consensus sequences for sample: ${meta.id}"
    echo "Minimum reads filter: ${min_reads_filter}"
    echo "Minimum quality filter: ${min_qual_filter}"
    echo "Maximum edit distance: ${max_edit_distance}"

    # Filter consensus sequences using umi_tools filter
    umi_tools \\
        filter \\
        -I ${consensus_bam} \\
        -S ${prefix}.filtered.bam \\
        -L ${prefix}.filter.log \\
        --min-reads ${min_reads_filter} \\
        --min-qual ${min_qual_filter} \\
        --max-edit-distance ${max_edit_distance} \\
        $args

    # Generate filtering statistics
    echo "UMI Filtering Statistics for ${meta.id}" > ${prefix}.filter_stats.txt
    echo "=====================================" >> ${prefix}.filter_stats.txt
    echo "Minimum reads filter: ${min_reads_filter}" >> ${prefix}.filter_stats.txt
    echo "Minimum quality filter: ${min_qual_filter}" >> ${prefix}.filter_stats.txt
    echo "Maximum edit distance: ${max_edit_distance}" >> ${prefix}.filter_stats.txt
    echo "" >> ${prefix}.filter_stats.txt
    
    # Extract filtering information from log
    if [ -f ${prefix}.filter.log ]; then
        echo "Filter log contents:" >> ${prefix}.filter_stats.txt
        cat ${prefix}.filter.log >> ${prefix}.filter_stats.txt
    fi

    # Calculate filtering metrics
    consensus_reads=\$(samtools view -c ${consensus_bam} 2>/dev/null || echo "0")
    filtered_reads=\$(samtools view -c ${prefix}.filtered.bam 2>/dev/null || echo "0")
    
    echo "Consensus reads: \$consensus_reads" >> ${prefix}.filter_stats.txt
    echo "Filtered reads: \$filtered_reads" >> ${prefix}.filter_stats.txt
    
    if [ "\$consensus_reads" -gt 0 ]; then
        filter_rate=\$(echo "scale=4; \$filtered_reads / \$consensus_reads" | bc -l)
        echo "Filter retention rate: \$filter_rate" >> ${prefix}.filter_stats.txt
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
    touch ${prefix}.filtered.bam
    touch ${prefix}.filter.log
    echo "UMI Filtering Statistics for ${meta.id}" > ${prefix}.filter_stats.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        umitools: \$( umi_tools --version | sed '/version:/!d; s/.*: //' )
        samtools: \$( samtools --version | head -n1 | sed 's/.*samtools //' )
    END_VERSIONS
    """
}

