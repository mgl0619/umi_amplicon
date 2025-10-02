process UMI_ANALYSIS {
    label 'process_high'

    conda (params.enable_conda ? "bioconda::umitools=1.1.2 bioconda::seqtk=1.4" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/umitools:1.1.2--pyhdfd78af_0' :
        'biocontainers/umitools:1.1.2--pyhdfd78af_0' }"

    input:
    path(deduped_fastq)
    val(umi_method)

    output:
    path "*.analysis_results.txt", emit: results
    path "versions.yml", emit: versions
    path "*.multiqc_data.json", emit: multiqc

    script:
    def umitools_path = params.umitools_path ?: "umitools"
    def umi_method = umi_method ?: "directional"

    """
    #!/bin/bash
    set -euo pipefail

    # Get sample name from input file
    sample=\$(basename ${deduped_fastq} .deduped.fastq.gz)
    echo "Performing UMI analysis for sample: \$sample"

    # Extract UMI sequences and calculate basic statistics
    zcat ${deduped_fastq} | awk 'NR%4==1' | sed 's/.*UMI://' | sed 's/ .*//' > \${sample}_umis.txt
    
    # Calculate basic UMI statistics
    total_reads=\$(cat \${sample}_umis.txt | wc -l)
    unique_umis=\$(cat \${sample}_umis.txt | sort | uniq | wc -l)
    umi_diversity=\$(echo "scale=4; \$unique_umis / \$total_reads" | bc -l)
    
    echo "UMI Analysis Results for \$sample" > \${sample}.analysis_results.txt
    echo "=================================" >> \${sample}.analysis_results.txt
    echo "Total reads: \$total_reads" >> \${sample}.analysis_results.txt
    echo "Unique UMI sequences: \$unique_umis" >> \${sample}.analysis_results.txt
    echo "UMI diversity: \$umi_diversity" >> \${sample}.analysis_results.txt
    echo "" >> \${sample}.analysis_results.txt

    # Calculate UMI frequency distribution
    cat \${sample}_umis.txt | sort | uniq -c | sort -nr > \${sample}_umi_freq.txt
    echo "UMI frequency distribution:" >> \${sample}.analysis_results.txt
    head -20 \${sample}_umi_freq.txt >> \${sample}.analysis_results.txt
    echo "" >> \${sample}.analysis_results.txt

    # Calculate UMI collision rate
    collision_rate=\$(echo "scale=4; (\$total_reads - \$unique_umis) / \$total_reads" | bc -l)
    echo "UMI collision rate: \$collision_rate" >> \${sample}.analysis_results.txt
    echo "" >> \${sample}.analysis_results.txt

    # Generate MultiQC data
    cat > \${sample}.multiqc_data.json << EOF
{
    "plot_data": {
        "umi_analysis": {
            "total_reads": $total_reads,
            "unique_umis": $unique_umis,
            "umi_diversity": $umi_diversity,
            "collision_rate": $collision_rate
        }
    }
}
EOF

    # Clean up temporary files
    rm -f \${sample}_umis.txt \${sample}_umi_freq.txt

    # Create versions file
    cat > versions.yml << EOF
${umitools_path}:
    version: \$(umitools --version 2>&1 | head -n1 | sed 's/.*version //')
    path: \$(which umitools)
EOF
    """
}

