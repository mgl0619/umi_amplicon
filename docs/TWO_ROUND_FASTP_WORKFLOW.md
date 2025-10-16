# Two-Round FASTP Workflow

## Visual Workflow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          RAW FASTQ READS                                 │
│                     (UMIs at 5' end of reads)                           │
└──────────────────────────┬──────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Step 1: FASTQC_RAW                                                      │
│  • Raw read quality assessment                                           │
│  • Output: fastqc/raw/                                                   │
└──────────────────────────┬──────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Step 2: FASTP_QC (First Round - NO 5' trimming)                       │
│  ✅ Adapter trimming                                                     │
│  ✅ Quality filtering                                                    │
│  ✅ 3' end trimming (--cut_tail)                                        │
│  ✅ Poly-X trimming                                                     │
│  ❌ NO 5' trimming (--cut_front) ← CRITICAL!                           │
│                                                                          │
│  Why? UMIs are still at 5' end, must be preserved!                     │
└──────────────────────────┬──────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Step 2b: FASTQC_FASTP_QC                                               │
│  • Check quality after first filtering                                   │
│  • Output: fastqc/after_fastp_qc/                                       │
└──────────────────────────┬──────────────────────────────────────────────┘
                           │
                           │  Filtered reads (5' end intact)
                           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Step 3: UMI_EXTRACT                                                     │
│  • Extract UMI from 5' end (intact!)                                    │
│  • Move UMI to read header                                              │
│  • UMI now safe from trimming                                           │
└──────────────────────────┬──────────────────────────────────────────────┘
                           │
                           │  UMI-extracted reads (UMIs in headers)
                           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Step 4: FASTP_TRIM (Second Round - FULL trimming)                     │
│  ✅ Adapter trimming                                                     │
│  ✅ Quality filtering                                                    │
│  ✅ 5' end trimming (--cut_front) ← NOW SAFE!                          │
│  ✅ 3' end trimming (--cut_tail)                                        │
│  ✅ Poly-X trimming                                                     │
│  ✅ Read merging (for amplicons)                                        │
│                                                                          │
│  Why? UMIs are now in headers, can trim aggressively                   │
└──────────────────────────┬──────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Step 4b: FASTQC_FASTP_TRIM                                             │
│  • Check quality after full trimming and merging                        │
│  • Output: fastqc/after_fastp_trim/                                     │
└──────────────────────────┬──────────────────────────────────────────────┘
                           │
                           │  Fully trimmed, filtered, merged reads
                           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Step 5: UMI_QC_METRICS                                                  │
│  • UMI diversity analysis                                               │
│  • Family size distribution                                             │
└──────────────────────────┬──────────────────────────────────────────────┘
                           │
                           ▼
                   Continue to Alignment...
```

## Key Differences Between Rounds

### FASTP_QC (Round 1)
```bash
fastp \
    --cut_tail \              # ✅ Trim 3' only
    --trim_poly_x \           # ✅ Safe
    --qualified_quality_phred 15 \
    --unqualified_percent_limit 40 \
    --length_required 50
    # ❌ NO --cut_front
```

**Output:** `sample_qc.fastp.fastq.gz` with:
- Adapters removed
- Poor quality reads filtered
- 3' ends trimmed
- **5' ends INTACT** (UMIs preserved)

### FASTP_TRIM (Round 2)
```bash
fastp \
    --cut_front \             # ✅ NOW can trim 5'
    --cut_tail \              # ✅ Trim 3' again
    --trim_poly_x \
    --qualified_quality_phred 15 \
    --unqualified_percent_limit 40 \
    --length_required 50 \
    -m --merged_out sample.merged.fastq.gz  # ✅ Merge reads
```

**Output:** `sample.merged.fastq.gz` with:
- Fully trimmed (5' and 3')
- High quality
- Merged (for amplicons)
- **UMIs safe in headers**

## Benefits

### ✅ Advantages
1. **UMI Integrity**: UMIs never lost to 5' trimming
2. **Quality Data**: Poor quality reads/bases removed early
3. **Efficient**: 
   - First pass removes bad reads early
   - UMI extraction works on clean data
   - Second pass does final polishing
4. **QC Metrics**: Two sets of QC metrics (before/after UMI extraction)

### ❌ What We Avoid
1. **Partial UMI Loss**: 5' trimming before extraction could cut into UMI
2. **Low Quality UMIs**: Extract UMIs from already filtered reads
3. **Wasted Processing**: Don't extract UMIs from reads that will be filtered later

## File Organization

```
results/
├── fastqc/                         # FastQC outputs at each stage
│   ├── raw/                        # Step 1: Raw reads
│   │   ├── sample_raw_fastqc.html
│   │   └── sample_raw_fastqc.zip
│   ├── after_fastp_qc/             # Step 2b: After first FASTP
│   │   ├── sample_qc_fastqc.html
│   │   └── sample_qc_fastqc.zip
│   └── after_fastp_trim/           # Step 4b: After second FASTP
│       ├── sample_merged_fastqc.html
│       └── sample_merged_fastqc.zip
├── fastp_qc/                       # First FASTP (QC only)
│   └── qc_only/
│       ├── sample_qc.fastp.json
│       └── sample_qc.fastp.html
├── umitools/extract/               # UMI extraction
│   ├── sample.fastq.gz             # UMI-extracted reads
│   └── sample_extract.log
├── fastp/                          # Second FASTP (full trim)
│   ├── sample.merged.fastq.gz
│   ├── sample.fastp.json
│   └── sample.fastp.html
└── umi_qc/                         # UMI QC metrics
    ├── sample.umi_qc_metrics.txt
    └── reports/
        └── sample.umi_qc_report.html
```

## Configuration

See `conf/modules.config`:

```groovy
// First FASTP: No 5' trimming
withName: 'UMI_ANALYSIS_SUBWORKFLOW:FASTP_QC' {
    ext.args = [
        '--cut_tail',     // 3' only
        '--trim_poly_x',
        '--qualified_quality_phred', '15',
        '--unqualified_percent_limit', '40',
        '--length_required', '50'
        // NO --cut_front
    ].join(' ')
}

// Second FASTP: Full trimming
withName: 'UMI_ANALYSIS_SUBWORKFLOW:FASTP_TRIM' {
    ext.args = [
        '--cut_front',    // NOW included
        '--cut_tail',
        '--trim_poly_x',
        '--qualified_quality_phred', '15',
        '--unqualified_percent_limit', '40',
        '--length_required', '50'
    ].join(' ')
}
```

## QC at Every Step

With FastQC after each FASTP round, you get comprehensive quality tracking:

1. **FASTQC_RAW**: Baseline quality of raw reads
2. **FASTP_QC**: Filter/trim metrics (first round)
3. **FASTQC_FASTP_QC**: Quality after initial filtering (5' intact)
4. **UMI_EXTRACT**: UMI extraction statistics
5. **FASTP_TRIM**: Full trimming/merging metrics (second round)
6. **FASTQC_FASTP_TRIM**: Final quality after full processing
7. **UMI_QC_METRICS**: UMI diversity and quality

This allows you to:
- Compare quality before/after each processing step
- Identify quality improvements from filtering
- Verify UMI extraction didn't degrade quality
- Confirm final read quality before alignment

## Summary

This two-round FASTP + multi-stage FastQC strategy ensures:
- ✅ UMI sequences are never lost
- ✅ High quality data for downstream analysis
- ✅ Efficient processing
- ✅ Comprehensive QC metrics at every stage
- ✅ Quality tracking through the entire workflow
- ✅ Bioinformatics best practices

