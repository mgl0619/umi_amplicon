process UMI_EXTRACT_EMBEDDED {
    tag "$meta.id"
    label "process_single"

    container "quay.io/biocontainers/umi_tools:1.1.6--py311haab0aaa_0"

    input:
    tuple val(meta), path(reads)
    val umi_length
    val umi_pattern

    output:
    tuple val(meta), path("*.fastq.gz"), emit: reads
    tuple val(meta), path("*.log")     , emit: log
    tuple val(meta), path("*.umi1.fastq.gz"), emit: umi1
    tuple val(meta), path("*.umi2.fastq.gz"), emit: umi2
    path  "versions.yml"               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    if (meta.single_end) {
        """
        umi_tools \\
            extract \\
            -I $reads \\
            -S ${prefix}.umi_extract.fastq.gz \\
            --extract-method=string \\
            --bc-pattern=${umi_pattern} \\
            --log ${prefix}.umi_extract.log \\
            $args
        
        # Create dummy UMI files for single-end
        echo "@dummy" > ${prefix}.umi1.fastq.gz
        echo "N" >> ${prefix}.umi1.fastq.gz
        echo "+" >> ${prefix}.umi1.fastq.gz
        echo "I" >> ${prefix}.umi1.fastq.gz
        gzip ${prefix}.umi1.fastq
        
        cp ${prefix}.umi1.fastq.gz ${prefix}.umi2.fastq.gz
        
        # Create versions file
        cat > versions.yml << EOF
umitools:
    version: \$(umitools --version 2>&1 | head -n1 | sed 's/.*version //')
    path: \$(which umitools)
EOF
        """
    } else {
        """
        umi_tools \\
            extract \\
            -I $reads \\
            -S ${prefix}.umi_extract.fastq.gz \\
            --extract-method=string \\
            --bc-pattern=${umi_pattern} \\
            --log ${prefix}.umi_extract.log \\
            $args
        
        # Extract UMIs from the first ${umi_length} bases of each read
        # For paired-end, we'll create UMI files from the extracted sequences
        zcat ${prefix}.umi_extract.fastq.gz | \\
            awk 'NR%4==1{print \$0}' > ${prefix}.umi1_headers.txt
        zcat ${prefix}.umi_extract.fastq.gz | \\
            awk 'NR%4==2{print substr(\$0,1,'${umi_length}')}' > ${prefix}.umi1_sequences.txt
        zcat ${prefix}.umi_extract.fastq.gz | \\
            awk 'NR%4==3{print \$0}' > ${prefix}.umi1_plus.txt
        zcat ${prefix}.umi_extract.fastq.gz | \\
            awk 'NR%4==4{print substr(\$0,1,'${umi_length}')}' > ${prefix}.umi1_quality.txt
        
        # Create UMI1 file
        paste -d'\\n' ${prefix}.umi1_headers.txt ${prefix}.umi1_sequences.txt ${prefix}.umi1_plus.txt ${prefix}.umi1_quality.txt | \\
            gzip > ${prefix}.umi1.fastq.gz
        
        # For paired-end, create UMI2 file (same as UMI1 for now)
        cp ${prefix}.umi1.fastq.gz ${prefix}.umi2.fastq.gz
        
        # Clean up temporary files
        rm -f ${prefix}.umi1_headers.txt ${prefix}.umi1_sequences.txt ${prefix}.umi1_plus.txt ${prefix}.umi1_quality.txt
        
        # Create versions file
        cat > versions.yml << EOF
umitools:
    version: \$(umitools --version 2>&1 | head -n1 | sed 's/.*version //')
    path: \$(which umitools)
EOF
        """
    }

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    if (meta.single_end) {
        """
        touch ${prefix}.umi_extract.fastq.gz
        touch ${prefix}.umi_extract.log
        """
    } else {
        """
        touch ${prefix}.umi_extract.fastq.gz
        touch ${prefix}.umi_extract.log
        """
    }
}
