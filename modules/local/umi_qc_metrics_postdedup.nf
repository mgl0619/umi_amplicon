process UMI_QC_METRICS_POSTDEDUP {
    tag "$meta.id"
    label 'process_low'

    conda "conda-forge::python=3.11 conda-forge::pandas=2.0.3"
    container "quay.io/biocontainers/pandas:2.0.3"

    input:
    tuple val(meta), path(dedup_log)
    tuple val(meta), path(edit_distance_tsv)
    tuple val(meta), path(per_umi_tsv)
    tuple val(meta), path(per_position_tsv)
    tuple val(meta), path(dedup_bam)

    output:
    tuple val(meta), path("*.postdedup_qc.txt"), emit: qc_metrics
    path "versions.yml", emit: versions
    tuple val(meta), path("*.multiqc_data.json"), emit: multiqc

    script:
    def prefix = meta.id
    """
    #!/usr/bin/env python3
    
    import json
    import re
    from pathlib import Path
    from collections import Counter, defaultdict
    import statistics
    
    # Parse deduplication log
    log_file = "${dedup_log}"
    stats = {
        'total_reads': 0,
        'unique_umis': 0,
        'deduplicated_reads': 0,
        'deduplication_rate': 0.0,
        'duplication_rate': 0.0
    }
    
    with open(log_file, 'r') as f:
        log_content = f.read()
        
        # Extract statistics from log
        # Pattern: "INFO Reads: Input Reads: 477015, Read pairs: ..."
        input_match = re.search(r'INFO Reads: Input Reads:\\s+(\\d+)', log_content)
        if input_match:
            stats['total_reads'] = int(input_match.group(1))
        
        output_match = re.search(r'INFO Number of reads out:\\s+(\\d+)', log_content)
        if output_match:
            stats['deduplicated_reads'] = int(output_match.group(1))
    
    # Calculate deduplication rate
    if stats['total_reads'] > 0:
        duplicates_removed = stats['total_reads'] - stats['deduplicated_reads']
        stats['deduplication_rate'] = (duplicates_removed / stats['total_reads']) * 100
        stats['duplication_rate'] = (stats['total_reads'] / stats['deduplicated_reads']) if stats['deduplicated_reads'] > 0 else 0
    
    # Parse UMI family sizes (per_umi_tsv)
    umi_family_sizes = []
    if Path("${per_umi_tsv}").exists():
        with open("${per_umi_tsv}", 'r') as f:
            next(f)  # Skip header
            for line in f:
                parts = line.strip().split('\\t')
                if len(parts) >= 2:
                    try:
                        count = int(parts[1])
                        umi_family_sizes.append(count)
                    except:
                        pass
    
    stats['unique_umis'] = len(umi_family_sizes)
    stats['avg_family_size'] = statistics.mean(umi_family_sizes) if umi_family_sizes else 0
    stats['median_family_size'] = statistics.median(umi_family_sizes) if umi_family_sizes else 0
    stats['max_family_size'] = max(umi_family_sizes) if umi_family_sizes else 0
    stats['min_family_size'] = min(umi_family_sizes) if umi_family_sizes else 0
    stats['stdev_family_size'] = statistics.stdev(umi_family_sizes) if len(umi_family_sizes) > 1 else 0
    
    # Singleton rate (UMI families with only 1 read)
    singletons = sum(1 for size in umi_family_sizes if size == 1)
    stats['singleton_families'] = singletons
    stats['singleton_family_rate'] = (singletons / len(umi_family_sizes) * 100) if umi_family_sizes else 0
    
    # Parse edit distance statistics (UMI error correction/clustering info)
    edit_distances = []
    cluster_sizes = []
    if Path("${edit_distance_tsv}").exists():
        with open("${edit_distance_tsv}", 'r') as f:
            header = next(f).strip().split('\\t')
            for line in f:
                parts = line.strip().split('\\t')
                if len(parts) >= 2:
                    try:
                        edit_dist = int(parts[0])
                        freq = int(parts[1])
                        edit_distances.extend([edit_dist] * freq)
                    except:
                        pass
    
    # Calculate edit distance statistics (error correction metrics)
    if edit_distances:
        stats['total_umi_pairs_compared'] = len(edit_distances)
        stats['mean_edit_distance'] = statistics.mean(edit_distances)
        stats['median_edit_distance'] = statistics.median(edit_distances)
        stats['max_edit_distance'] = max(edit_distances)
        # Count how many UMI pairs were within error correction distance
        stats['umi_pairs_clustered'] = sum(1 for d in edit_distances if d <= 1)
        stats['error_correction_rate'] = (stats['umi_pairs_clustered'] / len(edit_distances) * 100) if edit_distances else 0
    else:
        stats['total_umi_pairs_compared'] = 0
        stats['mean_edit_distance'] = 0
        stats['median_edit_distance'] = 0
        stats['max_edit_distance'] = 0
        stats['umi_pairs_clustered'] = 0
        stats['error_correction_rate'] = 0
    
    # Parse position-specific UMI usage
    position_entropy = []
    if Path("${per_position_tsv}").exists():
        with open("${per_position_tsv}", 'r') as f:
            next(f)  # Skip header
            for line in f:
                parts = line.strip().split('\\t')
                # Calculate entropy for this position if data available
                # This shows how well UMIs are distributed across positions
    
    # Write comprehensive QC metrics
    with open("${prefix}.postdedup_qc.txt", 'w') as f:
        f.write(f"Sample: ${prefix}\\n")
        f.write("=" * 70 + "\\n\\n")
        
        f.write("DEDUPLICATION SUMMARY\\n")
        f.write("-" * 70 + "\\n")
        f.write(f"Total input reads: {stats['total_reads']:,}\\n")
        f.write(f"Deduplicated reads (output): {stats['deduplicated_reads']:,}\\n")
        f.write(f"Duplicates removed: {stats['total_reads'] - stats['deduplicated_reads']:,}\\n")
        f.write(f"Deduplication rate: {stats['deduplication_rate']:.2f}%\\n")
        f.write(f"Duplication rate (fold): {stats['duplication_rate']:.2f}x\\n")
        f.write("\\n")
        
        f.write("UMI FAMILY STATISTICS\\n")
        f.write("-" * 70 + "\\n")
        f.write(f"Unique UMI families: {stats['unique_umis']:,}\\n")
        f.write(f"Average family size: {stats['avg_family_size']:.2f}\\n")
        f.write(f"Median family size: {stats['median_family_size']:.2f}\\n")
        f.write(f"Std dev family size: {stats['stdev_family_size']:.2f}\\n")
        f.write(f"Min family size: {stats['min_family_size']}\\n")
        f.write(f"Max family size: {stats['max_family_size']}\\n")
        f.write(f"Singleton families: {stats['singleton_families']:,}\\n")
        f.write(f"Singleton family rate: {stats['singleton_family_rate']:.2f}%\\n")
        f.write("\\n")
        
        f.write("UMI ERROR CORRECTION & CLUSTERING\\n")
        f.write("-" * 70 + "\\n")
        f.write(f"UMI pairs compared: {stats['total_umi_pairs_compared']:,}\\n")
        f.write(f"Mean edit distance: {stats['mean_edit_distance']:.2f}\\n")
        f.write(f"Median edit distance: {stats['median_edit_distance']:.2f}\\n")
        f.write(f"Max edit distance: {stats['max_edit_distance']}\\n")
        f.write(f"UMI pairs clustered (≤1 edit): {stats['umi_pairs_clustered']:,}\\n")
        f.write(f"Error correction rate: {stats['error_correction_rate']:.2f}%\\n")
        f.write("\\n")
        
        f.write("INTERPRETATION\\n")
        f.write("-" * 70 + "\\n")
        if stats['deduplication_rate'] > 80:
            f.write("⚠ HIGH deduplication rate (>80%) - check for over-amplification\\n")
        elif stats['deduplication_rate'] < 10:
            f.write("⚠ LOW deduplication rate (<10%) - UMIs may not be effective\\n")
        else:
            f.write("✓ Deduplication rate is within expected range\\n")
        
        if stats['singleton_family_rate'] > 50:
            f.write("⚠ HIGH singleton rate (>50%) - many UMIs seen only once\\n")
        else:
            f.write("✓ Singleton rate is acceptable\\n")
        
        if stats['error_correction_rate'] > 30:
            f.write("⚠ HIGH error correction (>30%) - UMI errors or diversity issues\\n")
        else:
            f.write("✓ Error correction rate is normal\\n")
    
    # Generate MultiQC data - organized to match text file structure
    multiqc_data = {
        "id": "${prefix}",
        "plot_type": "generalstats",
        "pconfig": {
            "namespace": "UMI Deduplication"
        },
        "data": {
            "${prefix}": {
                # DEDUPLICATION SUMMARY
                "total_reads": stats['total_reads'],
                "deduplicated_reads": stats['deduplicated_reads'],
                "duplicates_removed": stats['total_reads'] - stats['deduplicated_reads'],
                "deduplication_rate_pct": stats['deduplication_rate'],
                "duplication_rate": stats['duplication_rate'],
                
                # UMI FAMILY STATISTICS
                "unique_umi_families": stats['unique_umis'],
                "avg_family_size": stats['avg_family_size'],
                "median_family_size": stats['median_family_size'],
                "stdev_family_size": stats['stdev_family_size'],
                "min_family_size": stats['min_family_size'],
                "max_family_size": stats['max_family_size'],
                "singleton_families": stats['singleton_families'],
                "singleton_family_rate_pct": stats['singleton_family_rate'],
                
                # UMI ERROR CORRECTION & CLUSTERING
                "total_umi_pairs_compared": stats['total_umi_pairs_compared'],
                "mean_edit_distance": stats['mean_edit_distance'],
                "median_edit_distance": stats['median_edit_distance'],
                "max_edit_distance": stats['max_edit_distance'],
                "umi_pairs_clustered": stats['umi_pairs_clustered'],
                "error_correction_rate_pct": stats['error_correction_rate']
            }
        },
        "plot_data": {
            "family_size_distribution": {
                "${prefix}": dict(Counter(umi_family_sizes))
            },
            "edit_distance_distribution": {
                "${prefix}": dict(Counter(edit_distances)) if edit_distances else {}
            }
        }
    }
    
    with open("${prefix}.multiqc_data.json", 'w') as f:
        json.dump(multiqc_data, f, indent=2)
    
    # Write versions
    with open("versions.yml", 'w') as f:
        f.write('"${task.process}":\\n')
        f.write('    python: "3.11"\\n')
    """

    stub:
    def prefix = meta.id
    """
    touch ${prefix}.postdedup_qc.txt
    touch ${prefix}.multiqc_data.json
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "3.11"
    END_VERSIONS
    """
}
