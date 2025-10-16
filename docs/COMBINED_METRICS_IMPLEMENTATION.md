# Combined Metrics Implementation for Merged + Unmerged Reads

## Date: October 13, 2025

## Overview

The pipeline now implements **intelligent metric combination** for samples with merged and unmerged reads. This provides the best of both worlds:
- **Independent processing**: Merged and unmerged reads are aligned and deduplicated separately
- **Combined reporting**: ONE HTML report per sample with metrics from both streams

## Implementation Details

### Workflow Logic

```groovy
// In subworkflows/local/umi_analysis.nf

if (params.merge_pairs) {
    // Group metrics by original sample ID
    ch_grouped_metrics = UMI_QC_METRICS_POSTDEDUP.out.multiqc
        .map { meta, json ->
            def original_id = meta.id.replaceAll('_(merged|unmerged)$', '')
            [original_id, meta, json]
        }
        .groupTuple(by: 0)  // Group by original sample ID
        .map { original_id, meta_list, json_list ->
            [
                [id: original_id, single_end: false],
                json_list  // [merged.json, unmerged.json]
            ]
        }
    
    UMI_QC_HTML_REPORT_POSTDEDUP(ch_grouped_metrics)
}
```

### Module Logic (UMI_QC_HTML_REPORT_POSTDEDUP)

The module detects multiple JSON files and combines them:

```python
# Check if we have multiple JSON files
json_files = "${json_files}".split()

if len(json_files) > 1:
    # Combine metrics from merged and unmerged
    
    total_reads = 0
    total_deduplicated = 0
    total_unique_umis = 0
    all_family_sizes = {}
    all_edit_distances = {}
    
    for json_file in json_files:
        # Parse each JSON
        # Accumulate totals
        # Merge distributions
    
    # Calculate combined metrics
    combined_metrics = {
        'total_reads': total_reads,
        'deduplicated_reads': total_deduplicated,
        'unique_umi_families': total_unique_umis,
        'deduplication_rate_pct': ...,
        'avg_family_size': ...,
        ...
    }
```

## Metrics Combination Strategy

### Simple Addition (Totals)
- **Total reads**: merged_total + unmerged_total
- **Deduplicated reads**: merged_dedup + unmerged_dedup
- **Unique UMI families**: merged_umis + unmerged_umis

### Distribution Merging
- **Family size distribution**: Combine counts for each family size
  ```python
  all_family_sizes[size] = merged_count[size] + unmerged_count[size]
  ```

- **Edit distance distribution**: Combine counts for each edit distance
  ```python
  all_edit_distances[dist] = merged_count[dist] + unmerged_count[dist]
  ```

### Calculated Metrics
- **Deduplication rate**: `(1 - total_dedup/total_reads) * 100`
- **Average family size**: `total_reads / total_unique_umis`
- **Singleton rate**: `families_of_size_1 / total_unique_umis * 100`
- **Error correction rate**: `UMIs_within_1_edit / total_UMI_pairs * 100`

## Output Files

### When `--merge_pairs true`

For sample `SAMPLE1`:

```
results/
├── umitools/dedup/
│   ├── SAMPLE1_merged.dedup.bam                      # Separate BAM
│   ├── SAMPLE1_merged_edit_distance.tsv              # Separate stats
│   ├── SAMPLE1_merged_per_umi.tsv
│   ├── SAMPLE1_unmerged.dedup.bam                    # Separate BAM
│   ├── SAMPLE1_unmerged_edit_distance.tsv            # Separate stats
│   └── SAMPLE1_unmerged_per_umi.tsv
│
└── umi_qc_postdedup/
    ├── SAMPLE1_merged.postdedup_qc.txt               # Separate text
    ├── SAMPLE1_merged.multiqc_data.json               # Separate JSON
    ├── SAMPLE1_unmerged.postdedup_qc.txt             # Separate text
    ├── SAMPLE1_unmerged.multiqc_data.json             # Separate JSON
    └── reports/
        └── SAMPLE1.umi_postdedup_report.html         # ✨ COMBINED HTML
```

### When `--merge_pairs false`

For sample `SAMPLE1`:

```
results/
├── umitools/dedup/
│   ├── SAMPLE1.dedup.bam                             # Single BAM
│   ├── SAMPLE1_edit_distance.tsv
│   └── SAMPLE1_per_umi.tsv
│
└── umi_qc_postdedup/
    ├── SAMPLE1.postdedup_qc.txt                      # Single text
    ├── SAMPLE1.multiqc_data.json                      # Single JSON
    └── reports/
        └── SAMPLE1.umi_postdedup_report.html         # Single HTML
```

## Benefits

### 1. Complete Molecular Counts
- No need to manually add merged + unmerged counts
- HTML report shows total molecules from both sources
- Accurate representation of library complexity

### 2. Easy Interpretation
- Single report to review instead of two
- All metrics in one place
- Automated combination logic

### 3. Separate Analysis Still Available
- Text files (`*_merged.postdedup_qc.txt`, `*_unmerged.postdedup_qc.txt`)
- BAM files (separate for merged and unmerged)
- JSON files (separate for detailed analysis)
- Can compare merged vs unmerged characteristics

### 4. Consistent with Pipeline Philosophy
- Process separately (avoid bias)
- Report together (convenience)
- Best practices for UMI analysis

## Example: Combined Metrics

### Input (Merged Metrics)
```json
{
  "total_reads": 700000,
  "deduplicated_reads": 500000,
  "unique_umi_families": 50000,
  "deduplication_rate_pct": 28.57
}
```

### Input (Unmerged Metrics)
```json
{
  "total_reads": 300000,
  "deduplicated_reads": 200000,
  "unique_umi_families": 25000,
  "deduplication_rate_pct": 33.33
}
```

### Output (Combined Metrics in HTML)
```json
{
  "total_reads": 1000000,           // 700k + 300k
  "deduplicated_reads": 700000,      // 500k + 200k
  "unique_umi_families": 75000,      // 50k + 25k
  "deduplication_rate_pct": 30.00    // Recalculated: (1-700k/1M)*100
}
```

## Validation

### Test Case 1: Both Merged and Unmerged Present
```bash
# Expected: One HTML report with combined metrics
ls results/umi_qc_postdedup/reports/
# SAMPLE1.umi_postdedup_report.html

# Expected: Two text files
ls results/umi_qc_postdedup/*.txt
# SAMPLE1_merged.postdedup_qc.txt
# SAMPLE1_unmerged.postdedup_qc.txt
```

### Test Case 2: No Merging (merge_pairs=false)
```bash
# Expected: One HTML report with single set of metrics
ls results/umi_qc_postdedup/reports/
# SAMPLE1.umi_postdedup_report.html

# Expected: One text file
ls results/umi_qc_postdedup/*.txt
# SAMPLE1.postdedup_qc.txt
```

## Implementation Files

### Modified Files
1. **`subworkflows/local/umi_analysis.nf`**
   - Added grouping logic for merged/unmerged metrics
   - Conditional HTML report generation based on `params.merge_pairs`

2. **`modules/local/umi_qc_html_report_postdedup.nf`**
   - Enhanced to accept single file or list of files
   - Logic to combine metrics from multiple JSON files
   - Merges distributions and calculates combined statistics

### Supporting Documentation
1. **`MERGED_UNMERGED_PROCESSING.md`** - Complete guide
2. **`COMBINED_METRICS_IMPLEMENTATION.md`** - This file
3. **`docs/output.md`** - Updated output descriptions

## Summary

This implementation provides:

✅ **Independent processing**: Merged and unmerged reads analyzed separately  
✅ **Combined reporting**: ONE HTML report per sample  
✅ **Complete metrics**: Total molecular counts across both streams  
✅ **Flexibility**: Separate text/JSON files still available  
✅ **User-friendly**: No manual combination needed  
✅ **Accurate**: Proper statistical combination of distributions  

The pipeline now handles merged and unmerged reads in the most scientifically sound and user-friendly way possible.

---

**Implementation Date**: 2025-10-13  
**Pipeline Version**: 1.0.1  
**Feature**: Combined Metrics for Merged + Unmerged Reads

