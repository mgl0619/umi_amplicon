process ANNOTATE_BAM_WITH_UMIS {
    tag "$meta.id"
    label 'process_low'

    conda "conda-forge::python=3.11 bioconda::pysam=0.22"
    container "quay.io/biocontainers/pysam:0.22.0--py311h9b8898c_0"

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("*.annotated.bam"), emit: bam
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    #!/usr/bin/env python3
    import pysam
    import re
    
    # Open input BAM
    inbam = pysam.AlignmentFile("${bam}", "rb")
    outbam = pysam.AlignmentFile("${prefix}.annotated.bam", "wb", template=inbam)
    
    # Process each read
    for read in inbam:
        # Extract UMI from read name (format: READID_UMI)
        if '_' in read.query_name:
            parts = read.query_name.rsplit('_', 1)
            if len(parts) == 2:
                umi = parts[1]
                # Add RX tag
                read.set_tag('RX', umi, value_type='Z')
        
        outbam.write(read)
    
    inbam.close()
    outbam.close()
    
    # Index the output BAM
    pysam.index("${prefix}.annotated.bam")
    
    # Write versions
    with open("versions.yml", "w") as f:
        f.write('"${task.process}":\\n')
        f.write(f'    pysam: {pysam.__version__}\\n')
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.annotated.bam
    touch ${prefix}.annotated.bam.bai
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pysam: 0.22.0
    END_VERSIONS
    """
}
