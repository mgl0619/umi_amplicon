#!/usr/bin/env python3
"""
Calculate library coverage metrics from featureCounts output.

Metrics include:
- Library coverage (% of reference sequences detected)
- Evenness metrics (Shannon entropy, Simpson index, Pielou's evenness)
- Count distribution statistics and plots
"""

import argparse
import json
import sys
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend
import matplotlib.pyplot as plt
import seaborn as sns


def count_fasta_sequences(fasta_file):
    """Count total number of sequences in reference FASTA."""
    count = 0
    with open(fasta_file, 'r') as f:
        for line in f:
            if line.startswith('>'):
                count += 1
    return count


def parse_featurecounts(counts_file):
    """
    Parse featureCounts output and extract feature counts.
    
    Returns:
        dict: Dictionary mapping feature_id to count
    """
    feature_counts = {}
    
    with open(counts_file, 'r') as f:
        for line in f:
            # Skip comment and header lines
            if line.startswith('#') or line.startswith('Geneid'):
                continue
            
            parts = line.strip().split('\t')
            if len(parts) < 7:
                continue
                
            feature_id = parts[0]
            count = int(parts[6])  # Last column is the count
            feature_counts[feature_id] = count
    
    return feature_counts


def calculate_evenness_metrics(counts):
    """
    Calculate evenness metrics for count distribution.
    
    Args:
        counts: List or array of counts (non-zero values)
    
    Returns:
        dict: Dictionary with evenness metrics
    """
    counts = np.array([c for c in counts if c > 0])
    
    if len(counts) == 0:
        return {
            'shannon_entropy': 0,
            'simpson_index': 0,
            'pielou_evenness': 0,
            'gini_coefficient': 0
        }
    
    # Shannon entropy and Pielou's evenness
    total = np.sum(counts)
    proportions = counts / total
    shannon_entropy = -np.sum(proportions * np.log(proportions))
    max_entropy = np.log(len(counts))
    pielou_evenness = shannon_entropy / max_entropy if max_entropy > 0 else 0
    
    # Simpson index (1 - D, where D is Simpson's dominance)
    simpson_d = np.sum(proportions ** 2)
    simpson_index = 1 - simpson_d
    
    # Gini coefficient (inequality measure)
    sorted_counts = np.sort(counts)
    n = len(counts)
    cumsum = np.cumsum(sorted_counts)
    gini = (2 * np.sum((np.arange(1, n + 1)) * sorted_counts)) / (n * np.sum(sorted_counts)) - (n + 1) / n
    
    return {
        'shannon_entropy': float(shannon_entropy),
        'simpson_index': float(simpson_index),
        'pielou_evenness': float(pielou_evenness),
        'gini_coefficient': float(gini)
    }


def plot_count_distribution(feature_counts, output_prefix, sample_id):
    """
    Create distribution plots for feature counts.
    
    Args:
        feature_counts: Dictionary of feature_id -> count
        output_prefix: Prefix for output files
        sample_id: Sample identifier
    """
    counts = np.array(list(feature_counts.values()))
    detected_counts = counts[counts > 0]
    
    # Set style
    sns.set_style("whitegrid")
    
    # Create figure with subplots
    fig, axes = plt.subplots(2, 2, figsize=(12, 10))
    fig.suptitle(f'Library Coverage Analysis: {sample_id}', fontsize=14, fontweight='bold')
    
    # 1. Histogram of detected counts (log scale)
    ax1 = axes[0, 0]
    if len(detected_counts) > 0:
        ax1.hist(detected_counts, bins=50, edgecolor='black', alpha=0.7)
        ax1.set_xlabel('Read Count', fontsize=10)
        ax1.set_ylabel('Number of Features', fontsize=10)
        ax1.set_title('Distribution of Read Counts (Detected Features)', fontsize=11)
        ax1.set_yscale('log')
    else:
        ax1.text(0.5, 0.5, 'No detected features', ha='center', va='center')
        ax1.set_title('Distribution of Read Counts', fontsize=11)
    
    # 2. Cumulative distribution
    ax2 = axes[0, 1]
    if len(detected_counts) > 0:
        sorted_counts = np.sort(detected_counts)[::-1]
        cumsum = np.cumsum(sorted_counts)
        cumsum_pct = 100 * cumsum / cumsum[-1]
        ax2.plot(range(1, len(sorted_counts) + 1), cumsum_pct, linewidth=2)
        ax2.set_xlabel('Number of Features (ranked)', fontsize=10)
        ax2.set_ylabel('Cumulative % of Reads', fontsize=10)
        ax2.set_title('Cumulative Read Distribution', fontsize=11)
        ax2.grid(True, alpha=0.3)
        
        # Add reference lines
        ax2.axhline(y=50, color='r', linestyle='--', alpha=0.5, label='50%')
        ax2.axhline(y=80, color='orange', linestyle='--', alpha=0.5, label='80%')
        ax2.legend()
    else:
        ax2.text(0.5, 0.5, 'No detected features', ha='center', va='center')
        ax2.set_title('Cumulative Read Distribution', fontsize=11)
    
    # 3. Top 20 features bar plot
    ax3 = axes[1, 0]
    if len(detected_counts) > 0:
        top_features = sorted(feature_counts.items(), key=lambda x: x[1], reverse=True)[:20]
        feature_names = [f[0][:20] for f in top_features]  # Truncate long names
        feature_values = [f[1] for f in top_features]
        
        y_pos = np.arange(len(feature_names))
        ax3.barh(y_pos, feature_values, alpha=0.7)
        ax3.set_yticks(y_pos)
        ax3.set_yticklabels(feature_names, fontsize=8)
        ax3.invert_yaxis()
        ax3.set_xlabel('Read Count', fontsize=10)
        ax3.set_title('Top 20 Features by Read Count', fontsize=11)
    else:
        ax3.text(0.5, 0.5, 'No detected features', ha='center', va='center')
        ax3.set_title('Top 20 Features', fontsize=11)
    
    # 4. Coverage summary box
    ax4 = axes[1, 1]
    ax4.axis('off')
    
    total_refs = len(feature_counts)
    detected_refs = len(detected_counts)
    coverage_pct = (detected_refs / total_refs * 100) if total_refs > 0 else 0
    total_counts = np.sum(detected_counts) if len(detected_counts) > 0 else 0
    
    evenness = calculate_evenness_metrics(detected_counts)
    
    summary_text = f"""
    Library Coverage Summary
    {'=' * 40}
    
    Total reference sequences: {total_refs:,}
    Detected sequences: {detected_refs:,}
    Coverage: {coverage_pct:.2f}%
    
    Total read counts: {total_counts:,}
    Mean counts (detected): {np.mean(detected_counts):.2f if len(detected_counts) > 0 else 0}
    Median counts (detected): {np.median(detected_counts):.2f if len(detected_counts) > 0 else 0}
    
    Evenness Metrics:
    Shannon entropy: {evenness['shannon_entropy']:.3f}
    Simpson index: {evenness['simpson_index']:.3f}
    Pielou's evenness: {evenness['pielou_evenness']:.3f}
    Gini coefficient: {evenness['gini_coefficient']:.3f}
    """
    
    ax4.text(0.1, 0.9, summary_text, transform=ax4.transAxes,
             fontsize=9, verticalalignment='top', fontfamily='monospace',
             bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.3))
    
    plt.tight_layout()
    plt.savefig(f'{output_prefix}_distribution.png', dpi=300, bbox_inches='tight')
    plt.close()


def write_output_files(feature_counts, total_refs, sample_id, output_prefix):
    """
    Write text and JSON output files with coverage metrics.
    
    Args:
        feature_counts: Dictionary of feature_id -> count
        total_refs: Total number of reference sequences
        sample_id: Sample identifier
        output_prefix: Prefix for output files
    """
    counts = np.array(list(feature_counts.values()))
    detected_counts = counts[counts > 0]
    detected_refs = len(detected_counts)
    coverage_pct = (detected_refs / total_refs * 100) if total_refs > 0 else 0
    total_counts = int(np.sum(detected_counts)) if len(detected_counts) > 0 else 0
    
    evenness = calculate_evenness_metrics(detected_counts)
    
    # Write text output
    with open(f'{output_prefix}_library_coverage.txt', 'w') as f:
        f.write(f"Sample: {sample_id}\n")
        f.write(f"Total reference sequences: {total_refs}\n")
        f.write(f"Detected reference sequences: {detected_refs}\n")
        f.write(f"Library coverage: {coverage_pct:.2f}%\n")
        f.write(f"Total read counts: {total_counts}\n")
        f.write(f"Mean counts per detected feature: {np.mean(detected_counts):.2f if len(detected_counts) > 0 else 0}\n")
        f.write(f"Median counts per detected feature: {np.median(detected_counts):.2f if len(detected_counts) > 0 else 0}\n")
        f.write(f"\nEvenness Metrics:\n")
        f.write(f"Shannon entropy: {evenness['shannon_entropy']:.4f}\n")
        f.write(f"Simpson index: {evenness['simpson_index']:.4f}\n")
        f.write(f"Pielou's evenness: {evenness['pielou_evenness']:.4f}\n")
        f.write(f"Gini coefficient: {evenness['gini_coefficient']:.4f}\n")
    
    # Write JSON output for MultiQC
    top_features = dict(sorted(feature_counts.items(), key=lambda x: x[1], reverse=True)[:20])
    
    json_data = {
        "sample_id": sample_id,
        "total_reference_sequences": total_refs,
        "detected_reference_sequences": detected_refs,
        "library_coverage_percent": round(coverage_pct, 2),
        "total_read_counts": total_counts,
        "mean_counts_per_detected_feature": round(float(np.mean(detected_counts)), 2) if len(detected_counts) > 0 else 0,
        "median_counts_per_detected_feature": round(float(np.median(detected_counts)), 2) if len(detected_counts) > 0 else 0,
        "evenness_metrics": evenness,
        "top_20_features": top_features
    }
    
    with open(f'{output_prefix}_library_coverage.json', 'w') as f:
        json.dump(json_data, f, indent=2)


def main():
    parser = argparse.ArgumentParser(description='Calculate library coverage metrics from featureCounts output')
    parser.add_argument('--counts', required=True, help='featureCounts output file')
    parser.add_argument('--fasta', required=True, help='Reference FASTA file')
    parser.add_argument('--sample-id', required=True, help='Sample identifier')
    parser.add_argument('--output-prefix', required=True, help='Output file prefix')
    
    args = parser.parse_args()
    
    # Count total reference sequences
    total_refs = count_fasta_sequences(args.fasta)
    print(f"Total reference sequences: {total_refs}")
    
    # Parse featureCounts output
    feature_counts = parse_featurecounts(args.counts)
    detected_refs = sum(1 for c in feature_counts.values() if c > 0)
    print(f"Detected reference sequences: {detected_refs}")
    
    # Calculate coverage
    coverage_pct = (detected_refs / total_refs * 100) if total_refs > 0 else 0
    print(f"Library coverage: {coverage_pct:.2f}%")
    
    # Create distribution plots
    plot_count_distribution(feature_counts, args.output_prefix, args.sample_id)
    print(f"Distribution plot saved: {args.output_prefix}_distribution.png")
    
    # Write output files
    write_output_files(feature_counts, total_refs, args.sample_id, args.output_prefix)
    print(f"Output files written: {args.output_prefix}_library_coverage.txt/json")


if __name__ == '__main__':
    main()
