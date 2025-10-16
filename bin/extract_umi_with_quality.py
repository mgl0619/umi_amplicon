#!/usr/bin/env python3
"""
Extract UMI sequences with quality scores from FASTQ files
Uses original FASTQ (before extraction) and extracted FASTQ (with UMI in header)
to create a UMI-only FASTQ with sequences and quality scores

NOTE: This script processes Read 1 (R1) only, as UMI sequences are typically 
located on R1. For paired-end data, R2 does not contain UMI information.
"""

import sys
import gzip
import argparse

def extract_umi_with_quality(original_fastq, extracted_fastq, output_fastq, umi_length):
    """
    Extract UMI sequences and quality scores by matching reads between files
    
    Strategy: First read original file to build a dictionary of read_id -> (umi_seq, umi_qual)
    Then process extracted file and lookup UMI info from dictionary
    
    Args:
        original_fastq: Original FASTQ file before umi_tools extract (has UMI in sequence)
        extracted_fastq: FASTQ file after umi_tools extract (has UMI in header)
        output_fastq: Output FASTQ file with UMI sequences and quality scores only
        umi_length: Length of UMI
    """
    
    opener_orig = gzip.open if original_fastq.endswith('.gz') else open
    opener_extr = gzip.open if extracted_fastq.endswith('.gz') else open
    opener_out = gzip.open if output_fastq.endswith('.gz') else open
    
    # Step 1: Read original FASTQ and build dictionary of UMI sequences and qualities
    print("Step 1: Reading original FASTQ to extract UMI sequences and qualities...", file=sys.stderr)
    umi_dict = {}  # read_id -> (umi_seq, umi_qual)
    original_reads = 0
    
    with opener_orig(original_fastq, 'rt') as f_orig:
        while True:
            header = f_orig.readline()
            if not header:
                break
            
            seq = f_orig.readline().strip()
            plus = f_orig.readline()
            qual = f_orig.readline().strip()
            
            original_reads += 1
            
            # Extract read ID (without @)
            read_id = header.strip().split()[0][1:]
            
            # Extract UMI sequence and quality from 5' end
            if len(seq) >= umi_length and len(qual) >= umi_length:
                umi_seq = seq[:umi_length]
                umi_qual = qual[:umi_length]
                umi_dict[read_id] = (umi_seq, umi_qual)
    
    print(f"  Loaded {len(umi_dict)} UMI sequences from {original_reads} reads", file=sys.stderr)
    
    # Step 2: Process extracted FASTQ and write UMI-only FASTQ
    print("Step 2: Processing extracted FASTQ and writing UMI-only output...", file=sys.stderr)
    extracted_reads = 0
    matched_reads = 0
    mismatched_umis = 0
    missing_reads = 0
    
    with opener_extr(extracted_fastq, 'rt') as f_extr, \
         opener_out(output_fastq, 'wt') as f_out:
        
        while True:
            header = f_extr.readline()
            if not header:
                break
            
            seq = f_extr.readline().strip()
            plus = f_extr.readline()
            qual = f_extr.readline().strip()
            
            extracted_reads += 1
            
            # Extract read ID with UMI (format: READ_ID_UMI)
            read_id_with_umi = header.strip().split()[0][1:]
            
            # Extract original read ID (remove UMI suffix)
            if '_' in read_id_with_umi:
                parts = read_id_with_umi.split('_')
                header_umi = parts[-1]
                original_read_id = '_'.join(parts[:-1])
            else:
                original_read_id = read_id_with_umi
                header_umi = None
            
            # Lookup UMI info from dictionary
            if original_read_id in umi_dict:
                umi_seq, umi_qual = umi_dict[original_read_id]
                matched_reads += 1
                
                # Validate UMI matches
                if header_umi and header_umi != umi_seq:
                    mismatched_umis += 1
                    if mismatched_umis <= 10:  # Only show first 10 warnings
                        print(f"WARNING: UMI mismatch for {original_read_id}: header={header_umi}, sequence={umi_seq}", file=sys.stderr)
                
                # Write UMI-only FASTQ record
                f_out.write(f"@{read_id_with_umi}\n")
                f_out.write(f"{umi_seq}\n")
                f_out.write(plus)
                f_out.write(f"{umi_qual}\n")
            else:
                missing_reads += 1
                if missing_reads <= 10:  # Only show first 10 warnings
                    print(f"WARNING: Read {original_read_id} not found in original FASTQ", file=sys.stderr)
    
    print(f"\nSummary:", file=sys.stderr)
    print(f"  Original FASTQ: {original_reads} reads", file=sys.stderr)
    print(f"  Extracted FASTQ: {extracted_reads} reads", file=sys.stderr)
    print(f"  Matched reads: {matched_reads}", file=sys.stderr)
    print(f"  Missing reads: {missing_reads}", file=sys.stderr)
    if mismatched_umis > 0:
        print(f"  UMI mismatches: {mismatched_umis}", file=sys.stderr)
    
    return original_reads, matched_reads

def main():
    parser = argparse.ArgumentParser(
        description='Extract UMI sequences with quality scores from FASTQ files'
    )
    parser.add_argument('-i', '--original', required=True,
                        help='Original FASTQ file before umi_tools extract (can be gzipped)')
    parser.add_argument('-e', '--extracted', required=True,
                        help='Extracted FASTQ file after umi_tools extract (can be gzipped)')
    parser.add_argument('-o', '--output', required=True,
                        help='Output FASTQ file with UMI sequences only')
    parser.add_argument('-l', '--umi-length', type=int, required=True,
                        help='Length of UMI')
    
    args = parser.parse_args()
    
    extract_umi_with_quality(
        args.original,
        args.extracted,
        args.output,
        args.umi_length
    )

if __name__ == '__main__':
    main()
