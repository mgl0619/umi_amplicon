#!/usr/bin/env python3
"""
Build consensus sequences from UMI-grouped reads.
Simple and fast consensus calling for each UMI family.
"""

import pysam
import argparse
from collections import defaultdict
from Bio import SeqIO
from Bio.Seq import Seq
from Bio.SeqRecord import SeqRecord
import sys

def group_reads_by_umi_tools(bam_file, min_family_size=2):
    """
    Group reads using umi_tools group output tags
    umi_tools group adds BX (UMI) and UG (group ID) tags
    """
    bam = pysam.AlignmentFile(bam_file, 'rb')
    umi_groups = defaultdict(list)
    
    for read in bam:
        if read.is_unmapped or read.is_secondary or read.is_supplementary:
            continue
        
        # Use UG tag (group ID) from umi_tools group
        if read.has_tag('UG'):
            group_id = read.get_tag('UG')
        # Fallback: use BX (UMI) + position
        elif read.has_tag('BX'):
            group_id = f"{read.get_tag('BX')}_{read.reference_name}_{read.reference_start}"
        # Fallback: use RX tag
        elif read.has_tag('RX'):
            group_id = f"{read.get_tag('RX')}_{read.reference_name}_{read.reference_start}"
        else:
            continue
        
        umi_groups[group_id].append(read)
    
    bam.close()
    
    # Filter by minimum family size
    filtered_groups = {k: v for k, v in umi_groups.items() if len(v) >= min_family_size}
    
    print(f"Total groups before filtering: {len(umi_groups)}", file=sys.stderr)
    print(f"Groups after min_family_size filter: {len(filtered_groups)}", file=sys.stderr)
    
    return filtered_groups

def build_consensus(reads, min_base_quality=20, min_consensus_freq=0.6):
    """
    Build simple consensus sequence from reads
    Uses majority voting at each position
    """
    if not reads:
        return None, None
    
    # Get max read length
    max_length = max(len(r.query_sequence) for r in reads if r.query_sequence)
    
    # Position-wise base counts
    position_bases = defaultdict(lambda: defaultdict(int))
    
    for read in reads:
        if not read.query_sequence or not read.query_qualities:
            continue
        
        seq = read.query_sequence
        qual = read.query_qualities
        
        for pos, (base, q) in enumerate(zip(seq, qual)):
            if q >= min_base_quality:
                position_bases[pos][base] += 1
    
    # Build consensus
    consensus_seq = []
    consensus_qual = []
    
    for pos in range(max_length):
        if pos not in position_bases or not position_bases[pos]:
            consensus_seq.append('N')
            consensus_qual.append(0)
            continue
        
        # Get most common base
        base_counts = position_bases[pos]
        total = sum(base_counts.values())
        most_common = max(base_counts.items(), key=lambda x: x[1])
        
        # Check consensus threshold
        freq = most_common[1] / total
        if freq >= min_consensus_freq:
            consensus_seq.append(most_common[0])
            # Quality = -10*log10(1-freq), capped at 60
            qual_score = min(60, int(-10 * (-0.001 if freq >= 0.999 else (1 - freq))))
            consensus_qual.append(qual_score)
        else:
            consensus_seq.append('N')
            consensus_qual.append(0)
    
    return ''.join(consensus_seq), consensus_qual

def write_consensus_fasta(umi_groups, output_file, min_base_quality=20, min_consensus_freq=0.6):
    """Write consensus sequences to FASTA"""
    records = []
    stats = {
        'total_groups': len(umi_groups),
        'consensus_generated': 0,
        'failed': 0
    }
    
    for group_id, reads in umi_groups.items():
        consensus_seq, consensus_qual = build_consensus(reads, min_base_quality, min_consensus_freq)
        
        if not consensus_seq or len(consensus_seq) == 0:
            stats['failed'] += 1
            continue
        
        # Get info from first read
        first_read = reads[0]
        chrom = first_read.reference_name if first_read.reference_name else 'unknown'
        pos = first_read.reference_start if first_read.reference_start else 0
        
        # Get UMI from tags
        umi = 'unknown'
        if first_read.has_tag('BX'):
            umi = first_read.get_tag('BX')
        elif first_read.has_tag('RX'):
            umi = first_read.get_tag('RX')
        
        # Create record
        record_id = f"{group_id}"
        avg_qual = sum(consensus_qual) / len(consensus_qual) if consensus_qual else 0
        description = f"umi={umi} chrom={chrom} pos={pos} reads={len(reads)} avg_qual={avg_qual:.1f}"
        
        record = SeqRecord(
            Seq(consensus_seq),
            id=record_id,
            description=description
        )
        records.append(record)
        stats['consensus_generated'] += 1
    
    # Write FASTA
    SeqIO.write(records, output_file, 'fasta')
    
    return stats

def write_consensus_fastq(umi_groups, output_file, min_base_quality=20, min_consensus_freq=0.6):
    """Write consensus sequences to FASTQ with quality scores"""
    records = []
    stats = {
        'total_groups': len(umi_groups),
        'consensus_generated': 0,
        'failed': 0
    }
    
    for group_id, reads in umi_groups.items():
        consensus_seq, consensus_qual = build_consensus(reads, min_base_quality, min_consensus_freq)
        
        if not consensus_seq or len(consensus_seq) == 0:
            stats['failed'] += 1
            continue
        
        # Get info from first read
        first_read = reads[0]
        chrom = first_read.reference_name if first_read.reference_name else 'unknown'
        pos = first_read.reference_start if first_read.reference_start else 0
        
        # Get UMI from tags
        umi = 'unknown'
        if first_read.has_tag('BX'):
            umi = first_read.get_tag('BX')
        elif first_read.has_tag('RX'):
            umi = first_read.get_tag('RX')
        
        # Create FASTQ record with quality scores
        record_id = f"{group_id}"
        description = f"umi={umi} chrom={chrom} pos={pos} reads={len(reads)}"
        
        record = SeqRecord(
            Seq(consensus_seq),
            id=record_id,
            description=description,
            letter_annotations={"phred_quality": consensus_qual}
        )
        records.append(record)
        stats['consensus_generated'] += 1
    
    # Write FASTQ
    SeqIO.write(records, output_file, 'fastq')
    
    return stats

def main():
    parser = argparse.ArgumentParser(
        description='Build consensus sequences from UMI-grouped BAM (umi_tools group output)'
    )
    parser.add_argument('--bam', required=True, help='Input BAM file (from umi_tools group)')
    parser.add_argument('--output', required=True, help='Output consensus file')
    parser.add_argument('--format', choices=['fasta', 'fastq'], default='fasta',
                       help='Output format: fasta or fastq (default: fasta)')
    parser.add_argument('--min-family-size', type=int, default=2,
                       help='Minimum reads per UMI family (default: 2)')
    parser.add_argument('--min-base-quality', type=int, default=20,
                       help='Minimum base quality (default: 20)')
    parser.add_argument('--min-consensus-freq', type=float, default=0.6,
                       help='Minimum frequency for consensus base (default: 0.6)')
    parser.add_argument('--stats', help='Output statistics file')
    
    args = parser.parse_args()
    
    print(f"Reading umi_tools group output from {args.bam}...", file=sys.stderr)
    umi_groups = group_reads_by_umi_tools(args.bam, args.min_family_size)
    print(f"Found {len(umi_groups)} UMI groups (>={args.min_family_size} reads)", file=sys.stderr)
    
    print(f"Building consensus sequences ({args.format} format)...", file=sys.stderr)
    
    if args.format == 'fastq':
        stats = write_consensus_fastq(
            umi_groups,
            args.output,
            args.min_base_quality,
            args.min_consensus_freq
        )
    else:
        stats = write_consensus_fasta(
            umi_groups,
            args.output,
            args.min_base_quality,
            args.min_consensus_freq
        )
    
    print(f"\nConsensus Statistics:", file=sys.stderr)
    print(f"  Total UMI groups: {stats['total_groups']}", file=sys.stderr)
    print(f"  Consensus generated: {stats['consensus_generated']}", file=sys.stderr)
    print(f"  Failed: {stats['failed']}", file=sys.stderr)
    
    # Write stats file
    if args.stats:
        with open(args.stats, 'w') as f:
            f.write(f"Total UMI groups: {stats['total_groups']}\n")
            f.write(f"Consensus sequences generated: {stats['consensus_generated']}\n")
            f.write(f"Failed: {stats['failed']}\n")
            f.write(f"Success rate: {stats['consensus_generated']/stats['total_groups']*100:.1f}%\n")

if __name__ == '__main__':
    main()
