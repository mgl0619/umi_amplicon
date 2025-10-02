process UMI_QC_METRICS {
    label 'process_medium'

    conda (params.enable_conda ? "bioconda::umitools=1.1.2" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/umitools:1.1.2--pyhdfd78af_0' :
        'biocontainers/umitools:1.1.2--pyhdfd78af_0' }"

    input:
    tuple val(sample), path(fastq_1), path(fastq_2), path(umi_1), path(umi_2)
    val(umi_length)
    val(umi_quality_threshold)
    val(umi_collision_rate_threshold)
    val(umi_diversity_threshold)

    output:
    path "*.qc_metrics.txt", emit: qc_metrics
    path "versions.yml", emit: versions
    path "*.multiqc_data.json", emit: multiqc

    script:
    def umitools_path = params.umitools_path ?: "umitools"
    def umi_length = umi_length ?: 12
    def umi_quality_threshold = umi_quality_threshold ?: 10
    def umi_collision_rate_threshold = umi_collision_rate_threshold ?: 0.1
    def umi_diversity_threshold = umi_diversity_threshold ?: 1000

    """
    #!/bin/bash
    set -euo pipefail

    echo "Processing sample: ${sample}"
    
    # Count total reads
    total_reads=\$(zcat ${fastq_1} | wc -l | awk '{print \$1/4}')
    echo "Total reads: \$total_reads" > ${sample}.qc_metrics.txt
    
    # Extract UMI sequences from UMI files
    zcat ${umi_1} | awk 'NR%4==2' > ${sample}_umi1_sequences.txt
    zcat ${umi_2} | awk 'NR%4==2' > ${sample}_umi2_sequences.txt
    
    # Calculate UMI diversity (unique UMI combinations)
    cat ${sample}_umi1_sequences.txt ${sample}_umi2_sequences.txt | \
        sort | uniq | wc -l > ${sample}_umi_diversity.txt
    umi_diversity=\$(cat ${sample}_umi_diversity.txt)
    echo "UMI diversity: \$umi_diversity" >> ${sample}.qc_metrics.txt
    
    # Calculate UMI collision rate
    total_umis=\$(cat ${sample}_umi1_sequences.txt | wc -l)
    collision_rate=\$(echo "scale=4; (\$total_umis - \$umi_diversity) / \$total_umis" | bc -l)
    echo "UMI collision rate: \$collision_rate" >> ${sample}.qc_metrics.txt
    
    # Calculate UMI quality metrics
    zcat ${umi_1} | awk 'NR%4==4' > ${sample}_umi1_quality.txt
    zcat ${umi_2} | awk 'NR%4==4' > ${sample}_umi2_quality.txt
    
    # Calculate average quality scores
    avg_quality_umi1=\$(cat ${sample}_umi1_quality.txt | tr -d '\n' | fold -w1 | awk '{print ord(\$0)-33}' | awk '{sum+=\$1; count++} END {print sum/count}')
    avg_quality_umi2=\$(cat ${sample}_umi2_quality.txt | tr -d '\n' | fold -w1 | awk '{print ord(\$0)-33}' | awk '{sum+=\$1; count++} END {print sum/count}')
    echo "Average UMI1 quality: \$avg_quality_umi1" >> ${sample}.qc_metrics.txt
    echo "Average UMI2 quality: \$avg_quality_umi2" >> ${sample}.qc_metrics.txt
    
    # Generate MultiQC data
    cat > ${sample}.multiqc_data.json << EOF
{
    "plot_data": {
        "umi_diversity": {
            "umi1_unique": $umi_diversity,
            "umi2_unique": $umi_diversity,
            "total_umis": $total_umis
        },
        "collision_rate": $collision_rate,
        "quality_metrics": {
            "avg_quality_umi1": $avg_quality_umi1,
            "avg_quality_umi2": $avg_quality_umi2
        }
    }
}
EOF

    # Clean up temporary files
    rm -f ${sample}_umi1_sequences.txt ${sample}_umi2_sequences.txt ${sample}_umi_diversity.txt
    rm -f ${sample}_umi1_quality.txt ${sample}_umi2_quality.txt

    # Create versions file
    cat > versions.yml << EOF
${umitools_path}:
    version: \$(umitools --version 2>&1 | head -n1 | sed 's/.*version //')
    path: \$(which umitools)
EOF
    """
}

