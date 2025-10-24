#!/usr/bin/env python3
"""
Analyze multi-variant UMIs to assess deduplication specificity.

This script identifies UMIs that map to multiple sequence variants and
calculates metrics to assess whether these represent true biological
variation or technical artifacts (sequencing errors, UMI collisions).
"""

import argparse
import pysam
import json
from collections import defaultdict, Counter
from pathlib import Path
import sys


def extract_umi_from_read(read):
    """Extract UMI from read name or UMI tag."""
    # Try UMI tag first (standard for umi_tools)
    if read.has_tag('RX'):
        return read.get_tag('RX')
    
    # Fall back to read name (format: readname_UMI)
    read_name = read.query_name
    if '_' in read_name:
        return read_name.split('_')[-1]
    
    return None


def get_sequence_variant(read, reference_fasta=None):
    """
    Get sequence variant identifier for a read.
    Uses MD tag or actual sequence if available.
    """
    # Use MD tag for variant calling if available
    if read.has_tag('MD'):
        md_tag = read.get_tag('MD')
        return f"{read.reference_name}:{read.reference_start}:{md_tag}"
    
    # Fall back to position + CIGAR
    return f"{read.reference_name}:{read.reference_start}:{read.cigarstring}"


def analyze_umi_variants(bam_file, output_prefix, min_reads_per_umi=2):
    """
    Analyze UMIs that map to multiple sequence variants.
    
    Args:
        bam_file: Path to BAM file (pre or post deduplication)
        output_prefix: Prefix for output files
        min_reads_per_umi: Minimum reads per UMI to consider
    """
    
    print(f"Analyzing UMI variants in {bam_file}...")
    
    # Data structures
    umi_to_variants = defaultdict(lambda: defaultdict(int))  # UMI -> {variant: count}
    umi_to_positions = defaultdict(set)  # UMI -> {genomic positions}
    umi_read_counts = Counter()  # UMI -> total reads
    
    # Read BAM file
    with pysam.AlignmentFile(bam_file, 'rb') as bam:
        for read in bam:
            if read.is_unmapped or read.is_secondary or read.is_supplementary:
                continue
            
            umi = extract_umi_from_read(read)
            if not umi:
                continue
            
            variant = get_sequence_variant(read)
            position = f"{read.reference_name}:{read.reference_start}"
            
            umi_to_variants[umi][variant] += 1
            umi_to_positions[umi].add(position)
            umi_read_counts[umi] += 1
    
    print(f"Processed {len(umi_read_counts)} unique UMIs")
    
    # Analyze multi-variant UMIs
    multi_variant_umis = []
    single_variant_umis = []
    
    for umi, variants in umi_to_variants.items():
        total_reads = umi_read_counts[umi]
        
        if total_reads < min_reads_per_umi:
            continue
        
        num_variants = len(variants)
        num_positions = len(umi_to_positions[umi])
        
        if num_variants > 1:
            # Multi-variant UMI
            variant_counts = sorted(variants.values(), reverse=True)
            major_variant_count = variant_counts[0]
            minor_variant_counts = variant_counts[1:]
            
            multi_variant_umis.append({
                'umi': umi,
                'total_reads': total_reads,
                'num_variants': num_variants,
                'num_positions': num_positions,
                'major_variant_count': major_variant_count,
                'minor_variant_counts': minor_variant_counts,
                'major_variant_fraction': major_variant_count / total_reads,
                'variants': dict(variants)
            })
        else:
            # Single-variant UMI
            single_variant_umis.append({
                'umi': umi,
                'total_reads': total_reads,
                'num_positions': num_positions
            })
    
    # Calculate metrics
    total_umis = len(single_variant_umis) + len(multi_variant_umis)
    multi_variant_rate = len(multi_variant_umis) / total_umis if total_umis > 0 else 0
    
    # Classify multi-variant UMIs
    likely_errors = []  # Minor variants are likely errors
    likely_collisions = []  # Different positions, likely UMI collision
    ambiguous = []  # Could be either
    
    for mv_umi in multi_variant_umis:
        major_frac = mv_umi['major_variant_fraction']
        num_positions = mv_umi['num_positions']
        
        # If major variant dominates (>90%), minors likely errors
        if major_frac > 0.9:
            likely_errors.append(mv_umi)
        # If multiple positions, likely UMI collision
        elif num_positions > 1:
            likely_collisions.append(mv_umi)
        else:
            ambiguous.append(mv_umi)
    
    # Summary statistics
    stats = {
        'total_umis': total_umis,
        'single_variant_umis': len(single_variant_umis),
        'multi_variant_umis': len(multi_variant_umis),
        'multi_variant_rate': multi_variant_rate,
        'likely_sequencing_errors': len(likely_errors),
        'likely_umi_collisions': len(likely_collisions),
        'ambiguous_multi_variants': len(ambiguous),
        'error_rate': len(likely_errors) / total_umis if total_umis > 0 else 0,
        'collision_rate': len(likely_collisions) / total_umis if total_umis > 0 else 0,
        'specificity': len(single_variant_umis) / total_umis if total_umis > 0 else 0
    }
    
    # Write detailed report
    report_file = f"{output_prefix}_umi_variant_analysis.txt"
    with open(report_file, 'w') as f:
        f.write("UMI Multi-Variant Analysis Report\n")
        f.write("=" * 80 + "\n\n")
        
        f.write("Summary Statistics:\n")
        f.write("-" * 80 + "\n")
        f.write(f"Total UMIs analyzed: {stats['total_umis']}\n")
        f.write(f"Single-variant UMIs: {stats['single_variant_umis']} ({stats['specificity']*100:.2f}%)\n")
        f.write(f"Multi-variant UMIs: {stats['multi_variant_umis']} ({stats['multi_variant_rate']*100:.2f}%)\n\n")
        
        f.write("Multi-variant Classification:\n")
        f.write("-" * 80 + "\n")
        f.write(f"Likely sequencing errors: {stats['likely_sequencing_errors']} ({stats['error_rate']*100:.2f}%)\n")
        f.write(f"Likely UMI collisions: {stats['likely_umi_collisions']} ({stats['collision_rate']*100:.2f}%)\n")
        f.write(f"Ambiguous cases: {stats['ambiguous_multi_variants']}\n\n")
        
        f.write(f"Deduplication Specificity: {stats['specificity']*100:.2f}%\n")
        f.write("(Percentage of UMIs mapping to a single sequence variant)\n\n")
        
        # Top multi-variant UMIs
        if multi_variant_umis:
            f.write("\nTop 20 Multi-Variant UMIs:\n")
            f.write("-" * 80 + "\n")
            sorted_mv = sorted(multi_variant_umis, key=lambda x: x['total_reads'], reverse=True)[:20]
            for i, mv in enumerate(sorted_mv, 1):
                f.write(f"\n{i}. UMI: {mv['umi']}\n")
                f.write(f"   Total reads: {mv['total_reads']}\n")
                f.write(f"   Variants: {mv['num_variants']}\n")
                f.write(f"   Positions: {mv['num_positions']}\n")
                f.write(f"   Major variant: {mv['major_variant_count']} reads ({mv['major_variant_fraction']*100:.1f}%)\n")
                f.write(f"   Minor variants: {', '.join(map(str, mv['minor_variant_counts']))}\n")
    
    print(f"Report written to {report_file}")
    
    # Write JSON for MultiQC
    json_file = f"{output_prefix}_umi_variant_analysis_mqc.json"
    mqc_data = {
        'id': 'umi_variant_analysis',
        'section_name': 'UMI Variant Analysis',
        'description': 'Analysis of multi-variant UMIs to assess deduplication specificity',
        'plot_type': 'generalstats',
        'data': {
            output_prefix: {
                'UMI Specificity (%)': stats['specificity'] * 100,
                'Multi-variant Rate (%)': stats['multi_variant_rate'] * 100,
                'Error Rate (%)': stats['error_rate'] * 100,
                'Collision Rate (%)': stats['collision_rate'] * 100
            }
        }
    }
    
    with open(json_file, 'w') as f:
        json.dump(mqc_data, f, indent=2)
    
    print(f"MultiQC JSON written to {json_file}")
    
    # Write detailed JSON
    detailed_json = f"{output_prefix}_umi_variant_details.json"
    with open(detailed_json, 'w') as f:
        json.dump({
            'summary': stats,
            'likely_errors': likely_errors[:100],  # Top 100
            'likely_collisions': likely_collisions[:100],
            'ambiguous': ambiguous[:100]
        }, f, indent=2)
    
    print(f"Detailed JSON written to {detailed_json}")
    
    return stats


def main():
    parser = argparse.ArgumentParser(
        description='Analyze multi-variant UMIs for deduplication specificity assessment'
    )
    parser.add_argument(
        '-i', '--input',
        required=True,
        help='Input BAM file (indexed)'
    )
    parser.add_argument(
        '-o', '--output-prefix',
        required=True,
        help='Output prefix for result files'
    )
    parser.add_argument(
        '--min-reads',
        type=int,
        default=2,
        help='Minimum reads per UMI to analyze (default: 2)'
    )
    
    args = parser.parse_args()
    
    # Check input file exists
    if not Path(args.input).exists():
        print(f"Error: Input file {args.input} not found", file=sys.stderr)
        sys.exit(1)
    
    # Run analysis
    stats = analyze_umi_variants(
        args.input,
        args.output_prefix,
        args.min_reads
    )
    
    print("\nAnalysis complete!")
    print(f"Deduplication Specificity: {stats['specificity']*100:.2f}%")
    print(f"Multi-variant Rate: {stats['multi_variant_rate']*100:.2f}%")


if __name__ == '__main__':
    main()
