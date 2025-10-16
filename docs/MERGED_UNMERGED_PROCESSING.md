# Merged and Unmerged Read Processing

## Overview

When using `--merge_pairs true`, FASTP attempts to merge paired-end reads (R1+R2) into longer single-end reads. However, not all read pairs can be merged successfully. The pipeline now processes **BOTH** merged and unmerged reads separately for complete analysis coverage.

## FASTP Merging Output

FASTP with merging enabled (`-m --merged_out`) produces two outputs:

1. **Merged reads** (`*.merged.fastq.gz`): Successfully merged R1+R2 pairs
   - Single-end reads
   - Longer, more accurate sequences
   - Typical for short amplicons where R1 and R2 overlap

2. **Unmerged reads** (`*_1.fastp.fastq.gz`, `*_2.fastp.fastq.gz`): Read pairs that couldn't be merged
   - Paired-end reads (R1 and R2 separate)
   - No sufficient overlap for merging
   - Still valid and should be analyzed

## Why Process Both?

### Complete Coverage
- **Merged reads**: Provide high-quality, longer sequences
- **Unmerged reads**: Capture molecules where R1 and R2 don't overlap sufficiently
- **Combined**: Ensures no data is lost and all molecules are counted

### Example Scenario
```
Sample: SAMPLE1 with 1,000,000 read pairs

After FASTP merging:
  - Merged:   700,000 reads (70% successfully merged)
  - Unmerged: 300,000 pairs (30% couldn't merge, R1 and R2 kept separate)

If we only analyze merged reads:
  ❌ We lose 30% of the data!
  ❌ Potential bias if unmerged reads have different characteristics

If we analyze BOTH:
  ✅ All data is used
  ✅ Complete molecular coverage
  ✅ Unbiased representation
```

## Workflow Implementation

### Read Processing

```
FASTP_TRIM (with merging)
         ↓
         ├── reads_merged (70% of data)
         │   ↓
         │   SAMPLE1_merged (single-end)
         │
         └── reads (30% of data, unmerged)
             ↓
             SAMPLE1_unmerged (paired-end)

Both proceed through:
  ↓
UMI_QC_METRICS (separate for merged and unmerged)
  ↓
BWA_MEM (separate alignments)
  ↓
UMITOOLS_DEDUP (separate deduplication)
  ↓
UMI_QC_METRICS_POSTDEDUP (separate metrics)
  ↓
UMI_QC_HTML_REPORT_POSTDEDUP (separate reports)
```

### Sample Naming Convention

When `--merge_pairs true`, each sample is split into two analysis streams:

- `SAMPLE1_merged`: Contains merged reads (single-end)
- `SAMPLE1_unmerged`: Contains unmerged read pairs (paired-end)

Each stream is processed independently through the entire pipeline.

## Output Structure

```
results/
├── umi_qc/
│   ├── SAMPLE1_merged.umi_qc_metrics.txt      # Pre-dedup QC for merged
│   ├── SAMPLE1_merged_multiqc.json
│   ├── SAMPLE1_unmerged.umi_qc_metrics.txt    # Pre-dedup QC for unmerged
│   └── SAMPLE1_unmerged_multiqc.json
│
├── alignment/bam/
│   ├── SAMPLE1_merged.sorted.bam              # Merged reads alignment
│   └── SAMPLE1_unmerged.sorted.bam            # Unmerged reads alignment
│
├── umitools/dedup/
│   ├── SAMPLE1_merged.dedup.bam               # Merged deduplicated
│   ├── SAMPLE1_merged_edit_distance.tsv       # Merged UMI clustering stats
│   ├── SAMPLE1_merged_per_umi.tsv             # Merged per-UMI stats
│   ├── SAMPLE1_unmerged.dedup.bam             # Unmerged deduplicated
│   ├── SAMPLE1_unmerged_edit_distance.tsv     # Unmerged UMI clustering stats
│   └── SAMPLE1_unmerged_per_umi.tsv           # Unmerged per-UMI stats
│
└── umi_qc_postdedup/
    ├── SAMPLE1_merged.postdedup_qc.txt        # Post-dedup QC for merged
    ├── SAMPLE1_merged.multiqc_data.json        # Merged metrics (JSON)
    ├── SAMPLE1_unmerged.postdedup_qc.txt      # Post-dedup QC for unmerged
    ├── SAMPLE1_unmerged.multiqc_data.json      # Unmerged metrics (JSON)
    └── reports/
        └── SAMPLE1.umi_postdedup_report.html  # ✨ COMBINED HTML report (merged + unmerged)
```

### Key Point: Single Combined HTML Report

**Important**: The pipeline generates **ONE comprehensive HTML report** per sample that combines metrics from both merged and unmerged reads:

- **Separate processing**: Merged and unmerged reads are deduplicated independently
- **Separate text metrics**: `*_merged.postdedup_qc.txt` and `*_unmerged.postdedup_qc.txt`
- **Separate JSON metrics**: Individual MultiQC JSON files for each
- **✨ Combined HTML report**: ONE report (`SAMPLE1.umi_postdedup_report.html`) that:
  - Sums total reads across merged + unmerged
  - Combines UMI family size distributions
  - Merges edit distance distributions
  - Shows overall deduplication efficiency
  - Provides complete molecular count

## Interpreting Results

### Compare Merged vs Unmerged

1. **Deduplication Rates**
   - Compare dedup rates between merged and unmerged
   - Different rates may indicate biological differences

2. **UMI Diversity**
   - Check if merged and unmerged have similar UMI diversity
   - Significant differences may indicate technical bias

3. **Family Sizes**
   - Compare family size distributions
   - Should be similar if no bias

### Combining Results

For final molecular counts, you can:

1. **Add deduplicated reads**: `merged_count + unmerged_count`
2. **Check for overlap**: Verify no double-counting of same molecules
3. **Compare distributions**: Ensure merged and unmerged represent same library

### Example Analysis

```bash
# Check individual text metrics
cat results/umi_qc_postdedup/SAMPLE1_merged.postdedup_qc.txt    # Merged reads only
cat results/umi_qc_postdedup/SAMPLE1_unmerged.postdedup_qc.txt  # Unmerged reads only

# View COMBINED HTML report (includes both merged + unmerged)
open results/umi_qc_postdedup/reports/SAMPLE1.umi_postdedup_report.html

# This single report contains:
# - Combined total reads (merged + unmerged)
# - Combined deduplicated counts
# - Combined UMI family distributions
# - Combined edit distance distributions
# - Overall deduplication efficiency

# Compare individual BAMs if needed
samtools flagstat results/umitools/dedup/SAMPLE1_merged.dedup.bam
samtools flagstat results/umitools/dedup/SAMPLE1_unmerged.dedup.bam

# Check individual JSON metrics
cat results/umi_qc_postdedup/SAMPLE1_merged.multiqc_data.json
cat results/umi_qc_postdedup/SAMPLE1_unmerged.multiqc_data.json
```

## Configuration

### Enable Merged + Unmerged Processing (Default for Amplicons)

```bash
nextflow run main.nf \
    --input samplesheet.csv \
    --outdir results \
    --fasta reference.fasta \
    --merge_pairs true \      # Both merged and unmerged processed
    -profile conda
```

### Disable Merging (Paired-End Only)

```bash
nextflow run main.nf \
    --input samplesheet.csv \
    --outdir results \
    --fasta reference.fasta \
    --merge_pairs false \     # Only paired-end, no merging
    -profile conda
```

## Best Practices

### When to Use Merged + Unmerged Processing

✅ **Use when**:
- Amplicon sequencing with variable overlap
- Want complete coverage of all molecules
- Insert sizes vary across library
- Maximum sensitivity required

### When to Use Only Merged

❌ **Only merged** is NOT recommended because:
- Loses data from unmerged reads
- Introduces bias if unmerged reads have different characteristics
- Underestimates molecular counts

### When to Disable Merging

✅ **Disable merging** (`--merge_pairs false`) when:
- Insert sizes are longer than R1+R2 span
- No overlap between R1 and R2
- Want to analyze R1 and R2 as paired-end throughout

## Technical Details

### Channel Management

The pipeline uses Nextflow channels to split and process merged/unmerged reads:

```groovy
// Create merged reads channel
ch_merged_reads = FASTP_TRIM.out.reads_merged.map { meta, reads ->
    [
        [id: "${meta.id}_merged", single_end: true],
        reads,
        [],
        true
    ]
}

// Create unmerged reads channel
ch_unmerged_reads = FASTP_TRIM.out.reads.map { meta, reads ->
    [
        [id: "${meta.id}_unmerged", single_end: false],
        reads[0],
        reads[1],
        false
    ]
}

// Combine for processing
ch_processed_reads = ch_merged_reads.mix(ch_unmerged_reads)
```

### Meta Map Handling

- Original `meta.id`: `SAMPLE1`
- Merged `meta.id`: `SAMPLE1_merged`
- Unmerged `meta.id`: `SAMPLE1_unmerged`

The original ID is preserved for joining with `umi_tools extract` logs.

## Summary

### Key Points

1. ✅ **Both merged and unmerged reads are processed** when `--merge_pairs true`
2. ✅ **Each analysis stream is independent** (alignment, dedup, QC text/JSON)
3. ✅ **Separate BAMs and text metrics** for merged and unmerged
4. ✅ **✨ COMBINED HTML report** - ONE report per sample with merged + unmerged metrics
5. ✅ **Complete data coverage** - no molecules are lost
6. ✅ **Unbiased analysis** - both read types analyzed equally

### Benefits

- **Maximum sensitivity**: All reads are analyzed independently
- **Complete molecular counts**: Combined metrics show total (merged + unmerged)
- **Quality control**: Text metrics allow comparison of merged vs unmerged
- **Single comprehensive view**: ONE HTML report with all data combined
- **No manual merging needed**: Metrics automatically combined in HTML report
- **Separate analysis**: Can still examine merged vs unmerged via text files or BAMs
- **Best of both worlds**: Independent processing + combined reporting

---

**Implementation Date**: 2025-10-13  
**Pipeline Version**: 1.0.0  
**Feature**: Merged and Unmerged Processing

