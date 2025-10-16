process UMI_QC_METRICS_POSTUMIEXTRACT {
    tag "$meta.id"
    label 'process_medium'

    conda "conda-forge::python=3.11"
    container "quay.io/biocontainers/python:3.11"

    input:
    tuple val(meta), path(fastq), path(extract_log), path(umi_fastq)  // extracted reads, log, and UMI-only FASTQ
    val(umi_length)
    val(umi_quality_filter_threshold)
    val(umi_collision_rate_threshold)
    val(umi_diversity_threshold)

    output:
    tuple val(meta), path("*.umi_qc_metrics.txt"), emit: qc_metrics
    path "versions.yml", emit: versions
    tuple val(meta), path("*_multiqc.json"), emit: multiqc

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def sample = meta.id
    """
    #!/usr/bin/env python3
    
    # Leverage existing tool outputs and calculate additional UMI QC metrics
    import sys
    import re
    import json
    sys.path.insert(0, '${projectDir}/bin')
    
    from calculate_umi_metrics import parse_fastq_with_umi, parse_umi_only_fastq, calculate_metrics
    
    # Step 1: Parse umi_tools extract log for basic statistics
    extract_stats = {}
    print(f"Parsing umi_tools extract log: ${extract_log}", file=sys.stderr)
    with open("${extract_log}", 'r') as f:
        log_content = f.read()
        # Extract input/output reads from log
        input_match = re.search(r'INFO Input Reads:\\s+(\\d+)', log_content)
        if input_match:
            extract_stats['input_reads'] = int(input_match.group(1))
        
        output_match = re.search(r'INFO Reads output:\\s+(\\d+)', log_content)
        if output_match:
            extract_stats['output_reads'] = int(output_match.group(1))
        
        # Extract quality filtered reads
        quality_filtered_match = re.search(r'INFO filtered: umi quality:\\s+(\\d+)', log_content)
        if quality_filtered_match:
            extract_stats['quality_filtered'] = int(quality_filtered_match.group(1))
        else:
            extract_stats['quality_filtered'] = 0
    
    print(f"Extract stats: {extract_stats}", file=sys.stderr)
    
    # Step 2: Parse FASTQ with extracted UMIs for UMI counts
    print(f"Analyzing UMI counts in: ${fastq}", file=sys.stderr)
    umi_counts, _, total_reads = parse_fastq_with_umi("${fastq}")
    
    # Step 3: Parse UMI-only FASTQ for quality scores
    print(f"Analyzing UMI quality scores in: ${umi_fastq}", file=sys.stderr)
    umi_qualities, total_umis_with_quality = parse_umi_only_fastq("${umi_fastq}")
    print(f"Loaded quality scores for {len(umi_qualities)} unique UMIs", file=sys.stderr)
    
    # Step 4: Calculate comprehensive metrics
    metrics = calculate_metrics(umi_counts, umi_qualities, total_reads, ${umi_length})
    
    # Step 4: Merge with extract stats
    if extract_stats:
        metrics['extract_input_reads'] = extract_stats.get('input_reads', total_reads)
        metrics['extract_output_reads'] = extract_stats.get('output_reads', total_reads)
        metrics['quality_filtered_reads'] = extract_stats.get('quality_filtered', 0)
        if extract_stats.get('input_reads'):
            metrics['extract_pass_rate'] = extract_stats['output_reads'] / extract_stats['input_reads']
            if metrics['quality_filtered_reads'] > 0:
                metrics['quality_filter_rate'] = metrics['quality_filtered_reads'] / extract_stats['input_reads']
    
    # Write metrics to file
    with open("${sample}.umi_qc_metrics.txt", 'w') as f:
        f.write(f"Sample: ${sample}\\n")
        f.write("=" * 60 + "\\n\\n")
        
        # UMI Extraction Statistics (from umi_tools extract log)
        if extract_stats:
            f.write("UMI Extraction Statistics:\\n")
            f.write(f"  Input reads during Extraction: {metrics.get('extract_input_reads', 'N/A'):,}\\n")
            f.write(f"  Output reads after Extraction: {metrics.get('extract_output_reads', 'N/A'):,}\\n")
            if metrics.get('quality_filtered_reads', 0) > 0:
                f.write(f"  Quality filtered reads during Extraction: {metrics['quality_filtered_reads']:,}\\n")
                if 'quality_filter_rate' in metrics:
                    f.write(f"  Quality filter rate during Extraction: {metrics['quality_filter_rate']:.2%}\\n")
            if 'extract_pass_rate' in metrics:
                f.write(f"  Pass rate during Extraction: {metrics['extract_pass_rate']:.2%}\\n")
            f.write("\\n")
        
        f.write("Extraction Statistics:\\n")
        f.write(f"  Total reads analyzed: {metrics['total_reads']:,}\\n")
        f.write(f"  Total UMIs: {metrics['total_umis']:,}\\n")
        f.write(f"  Unique UMIs: {metrics['unique_umis']:,}\\n")
        f.write(f"  UMI length: {metrics['umi_length']}\\n\\n")
        
        f.write("UMI Diversity:\\n")
        f.write(f"  Diversity ratio: {metrics['diversity_ratio']:.4f}\\n")
        f.write(f"  Shannon entropy: {metrics['shannon_entropy']:.4f}\\n")
        f.write(f"  Complexity score: {metrics['complexity_score']:.4f}\\n\\n")
        
        f.write("UMI Collision Analysis (Birthday Problem):\\n")
        f.write(f"  UMI space (m = 4^{${umi_length}}): {4**${umi_length}:,}\\n")
        f.write(f"  Starting molecules (n): {metrics['unique_umis']:,}\\n")
        f.write(f"  Expected num unique UMIs: {metrics.get('expected_num_unique_umis', 0):.1f}\\n")
        f.write(f"  Expected num colliding pairs: {metrics.get('expected_num_colliding_pairs', 0):.2f}\\n")
        f.write(f"  Expected fraction molecules colliding: {metrics.get('expected_fraction_molecules_colliding', 0):.4f} ({metrics.get('expected_fraction_molecules_colliding', 0)*100:.2f}%)\\n")
        f.write(f"  Probability of at least one UMI collision: {metrics.get('prob_at_least_one_umi_collision', 0):.6f}\\n")
        f.write(f"  Expected duplicate rate for UMI before PCR (random collision): {metrics.get('expected_duplicate_rate', 0):.4f} ({metrics.get('expected_duplicate_rate', 0)*100:.2f}%)\\n")
        f.write(f"  Observed duplication rate (PCR + collision): {metrics['observed_collision_rate']:.4f} ({metrics['observed_collision_rate']*100:.2f}%)\\n\\n")
        
        f.write("Family Size Statistics:\\n")
        f.write(f"  Mean family size: {metrics['mean_family_size']:.2f}\\n")
        f.write(f"  Median family size: {metrics['median_family_size']:.0f}\\n")
        f.write(f"  Min family size: {metrics['min_family_size']}\\n")
        f.write(f"  Max family size: {metrics['max_family_size']}\\n")
        f.write(f"  Amplification ratio: {metrics['amplification_ratio']:.2f}\\n\\n")
        
        f.write("Singleton Analysis:\\n")
        f.write(f"  Singleton count: {metrics['singleton_count']:,}\\n")
        f.write(f"  Singleton rate: {metrics['singleton_rate']:.4f}\\n\\n")
        
        f.write("Quality Metrics:\\n")
        f.write(f"  Mean UMI quality: {metrics['mean_umi_quality']:.2f}\\n")
        f.write(f"  Min UMI quality: {metrics['min_umi_quality']:.2f}\\n")
        f.write(f"  Max UMI quality: {metrics.get('max_umi_quality', 0):.2f}\\n")
        
        # Per-position quality
        if metrics.get('per_position_quality'):
            f.write("\\n  Per-Position Quality Scores:\\n")
            f.write("    Pos  Mean   Min   Max\\n")
            f.write("    " + "-" * 24 + "\\n")
            for pos_data in metrics['per_position_quality']:
                f.write(f"    {pos_data['position']:3d}  {pos_data['mean_quality']:5.1f}  {pos_data['min_quality']:4.0f}  {pos_data['max_quality']:4.0f}\\n")
        f.write("\\n")
        
        f.write("Performance Metrics:\\n")
        f.write(f"  Success rate: {metrics['success_rate']:.4f}\\n")
        
        # QC checks
        f.write("\\nQC Checks:\\n")
        if metrics['observed_collision_rate'] > ${umi_collision_rate_threshold}:
            f.write(f"  WARNING: High observed duplication rate ({metrics['observed_collision_rate']:.4f} > ${umi_collision_rate_threshold})\\n")
        if metrics.get('expected_duplicate_rate', 0) > ${umi_collision_rate_threshold}:
            f.write(f"  WARNING: High expected duplicate rate ({metrics['expected_duplicate_rate']:.4f} > ${umi_collision_rate_threshold})\\n")
        if metrics['unique_umis'] < ${umi_diversity_threshold}:
            f.write(f"  WARNING: Low UMI diversity ({metrics['unique_umis']} < ${umi_diversity_threshold})\\n")
        if metrics['mean_umi_quality'] < ${umi_quality_filter_threshold}:
            f.write(f"  WARNING: Low UMI quality ({metrics['mean_umi_quality']:.2f} < ${umi_quality_filter_threshold})\\n")
    
    # Prepare data for MultiQC
    family_sizes = list(umi_counts.values())
    family_size_dist = {}
    for size in range(1, min(max(family_sizes) + 1, 101) if family_sizes else 1):
        family_size_dist[size] = family_sizes.count(size)
    
    top_umis = dict(list(umi_counts.most_common(20)))
    
    # Write MultiQC JSON - organized to match text file structure
    multiqc_data = {
        "id": f"umi_qc_${sample}",
        "plot_type": "generalstats",
        "pconfig": {
            "namespace": "UMI QC Metrics"
        },
        "data": {
            "${sample}": {
                # UMI Extraction Statistics
                "extract_input_reads": metrics.get('extract_input_reads', metrics['total_reads']),
                "extract_output_reads": metrics.get('extract_output_reads', metrics['total_reads']),
                "extract_pass_rate": metrics.get('extract_pass_rate', 1.0),
                "quality_filtered_reads": metrics.get('quality_filtered_reads', 0),
                "quality_filter_rate": metrics.get('quality_filter_rate', 0.0),
                
                # Extraction Statistics
                "total_reads": metrics['total_reads'],
                "total_umis": metrics['total_umis'],
                "unique_umis": metrics['unique_umis'],
                "umi_length": metrics['umi_length'],
                
                # UMI Diversity
                "diversity_ratio": metrics['diversity_ratio'],
                "shannon_entropy": metrics['shannon_entropy'],
                "complexity_score": metrics['complexity_score'],
                
                # UMI Collision Analysis (Birthday Problem)
                "expected_num_unique_umis": metrics.get('expected_num_unique_umis', 0),
                "expected_num_colliding_pairs": metrics.get('expected_num_colliding_pairs', 0),
                "expected_fraction_molecules_colliding": metrics.get('expected_fraction_molecules_colliding', 0),
                "prob_at_least_one_umi_collision": metrics.get('prob_at_least_one_umi_collision', 0),
                "expected_duplicate_rate": metrics.get('expected_duplicate_rate', 0),
                "observed_collision_rate": metrics['observed_collision_rate'],
                
                # Family Size Statistics
                "mean_family_size": metrics['mean_family_size'],
                "median_family_size": metrics['median_family_size'],
                "min_family_size": metrics['min_family_size'],
                "max_family_size": metrics['max_family_size'],
                "amplification_ratio": metrics['amplification_ratio'],
                
                # Singleton Analysis
                "singleton_count": metrics['singleton_count'],
                "singleton_rate": metrics['singleton_rate'],
                
                # Quality Metrics
                "mean_umi_quality": metrics['mean_umi_quality'],
                "min_umi_quality": metrics['min_umi_quality'],
                "max_umi_quality": metrics.get('max_umi_quality', 0),
                
                # Performance Metrics
                "success_rate": metrics['success_rate']
            }
        },
        "plot_data": {
            "family_size_distribution": {
                "${sample}": family_size_dist
            },
            "top_umis": {
                "${sample}": top_umis
            }
        }
    }
    
    with open("${sample}_multiqc.json", 'w') as f:
        json.dump(multiqc_data, f, indent=2)
    
    # Write versions
    with open("versions.yml", 'w') as f:
        f.write('"${task.process}":\\n')
        f.write('    python: "3.11"\\n')
    
    print(f"Metrics written for ${sample}", file=sys.stderr)
    """

    stub:
    """
    touch ${sample}.umi_qc_metrics.txt
    touch ${sample}_multiqc.json
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "3.11"
    END_VERSIONS
    """
}

