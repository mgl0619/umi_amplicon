process UMI_CONSENSUS {
    tag "${meta.id}"
    label 'process_medium'

    conda "bioconda::pysam=0.21.0 bioconda::biopython=1.81"
    container 'quay.io/biocontainers/mulled-v2-3a59640f3fe1ed11819984087d31d68600200c3f:185a25ca79923df85b58f42deb48f5ac4481e91f-0'

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("*.consensus.fasta"), emit: consensus
    tuple val(meta), path("*.consensus_stats.txt"), emit: stats
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def min_family_size = params.min_umi_family_size ?: 2
    def min_base_quality = params.min_base_quality ?: 20
    def min_consensus_freq = params.consensus_call_fraction ?: 0.6
    """
    build_umi_consensus.py \\
        --bam ${bam} \\
        --output ${prefix}.consensus.fasta \\
        --min-family-size ${min_family_size} \\
        --min-base-quality ${min_base_quality} \\
        --min-consensus-freq ${min_consensus_freq} \\
        --stats ${prefix}.consensus_stats.txt
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
        pysam: \$(python3 -c "import pysam; print(pysam.__version__)")
        biopython: \$(python3 -c "import Bio; print(Bio.__version__)")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.consensus.fasta
    touch ${prefix}.consensus_stats.txt
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}
