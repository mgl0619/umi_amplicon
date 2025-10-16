# Complete Two-Round FASTP Workflow with Multi-Stage QC

## Overview

The pipeline now implements a sophisticated two-round FASTP strategy with comprehensive QC at every stage to ensure UMI integrity and high-quality data.

## Complete Workflow Steps

```
┌──────────────────────────────────────────────────────────────┐
│              Complete Workflow Implementation                 │
└──────────────────────────────────────────────────────────────┘

1. RAW FASTQ READS
   ↓
2. FASTQC_RAW (raw reads QC)
   ↓ Output: fastqc/raw/
   ↓
3. FASTP_QC (First round - NO 5' trim)
   ✅ Adapter trimming
   ✅ Quality filtering
   ✅ 3' trimming (--cut_tail)
   ❌ NO 5' trimming (preserves UMIs)
   ↓ Output: fastp_qc/qc_only/
   ↓
4. FASTQC_FASTP_QC (check after first filter)
   ↓ Output: fastqc/after_fastp_qc/
   ↓
5. UMI_EXTRACT (extract intact UMIs)
   ↓ Output: umitools/extract/
   ↓
6. FASTP_TRIM (Second round - FULL trimming)
   ✅ Adapter trimming
   ✅ Quality filtering  
   ✅ 5' AND 3' trimming (--cut_front + --cut_tail)
   ✅ Read merging
   ↓ Output: fastp/
   ↓
7. FASTQC_FASTP_TRIM (check final quality)
   ↓ Output: fastqc/after_fastp_trim/
   ↓
8. UMI_QC_METRICS (UMI diversity analysis)
   ↓ Output: umi_qc/
   ↓
9. UMI_QC_HTML_REPORT (interactive report)
   ↓ Output: umi_qc/reports/
   ↓
10. BWA_MEM (alignment)
    ↓
11. UMITOOLS_DEDUP (deduplication)
    ↓
12. UMI_QC_METRICS_POSTDEDUP
    ↓
13. MULTIQC (comprehensive report)
```

## Key Implementation Features

### Module Aliases
```groovy
// Three FastQC instances for different stages
include { FASTQC as FASTQC_RAW }         from '../../modules/nf-core/fastqc/main'
include { FASTQC as FASTQC_FASTP_QC }    from '../../modules/nf-core/fastqc/main'
include { FASTQC as FASTQC_FASTP_TRIM }  from '../../modules/nf-core/fastqc/main'

// Two FASTP instances with different parameters
include { FASTP as FASTP_QC }            from '../../modules/nf-core/fastp/main'
include { FASTP as FASTP_TRIM }          from '../../modules/nf-core/fastp/main'
```

### Configuration Highlights

**FASTP_QC (conf/modules.config):**
```groovy
withName: 'UMI_ANALYSIS_SUBWORKFLOW:FASTP_QC' {
    ext.args = [
        '--cut_tail',                      // ✅ Trim 3' end
        '--trim_poly_x',                   // ✅ Poly-X trimming
        '--qualified_quality_phred', '15',
        '--unqualified_percent_limit', '40',
        '--length_required', '50'
        // ❌ NO --cut_front (preserves 5' UMIs)
    ].join(' ')
}
```

**FASTP_TRIM (conf/modules.config):**
```groovy
withName: 'UMI_ANALYSIS_SUBWORKFLOW:FASTP_TRIM' {
    ext.args = [
        '--cut_front',                     // ✅ NOW can trim 5' end
        '--cut_tail',
        '--trim_poly_x',
        '--qualified_quality_phred', '15',
        '--unqualified_percent_limit', '40',
        '--length_required', '50'
    ].join(' ')
}
```

### FastQC Output Organization
```groovy
// Raw reads
withName: 'UMI_ANALYSIS_SUBWORKFLOW:FASTQC_RAW' {
    publishDir = [[
        path: { "${params.outdir}/fastqc" },
        saveAs: { filename -> "raw/${filename}" }
    ]]
}

// After first FASTP
withName: 'UMI_ANALYSIS_SUBWORKFLOW:FASTQC_FASTP_QC' {
    publishDir = [[
        path: { "${params.outdir}/fastqc" },
        saveAs: { filename -> "after_fastp_qc/${filename}" }
    ]]
}

// After second FASTP
withName: 'UMI_ANALYSIS_SUBWORKFLOW:FASTQC_FASTP_TRIM' {
    publishDir = [[
        path: { "${params.outdir}/fastqc" },
        saveAs: { filename -> "after_fastp_trim/${filename}" }
    ]]
}
```

## Results Directory Structure

```
results/
├── fastqc/
│   ├── raw/                          # Raw read QC
│   │   ├── sample_raw_fastqc.html
│   │   └── sample_raw_fastqc.zip
│   ├── after_fastp_qc/               # After first FASTP
│   │   ├── sample_qc_fastqc.html
│   │   └── sample_qc_fastqc.zip
│   └── after_fastp_trim/             # After second FASTP
│       ├── sample_merged_fastqc.html
│       └── sample_merged_fastqc.zip
├── fastp_qc/qc_only/                 # First FASTP metrics
│   ├── sample_qc.fastp.json
│   └── sample_qc.fastp.html
├── umitools/extract/                 # UMI extraction
│   ├── sample.fastq.gz
│   └── sample_extract.log
├── fastp/                            # Second FASTP metrics
│   ├── sample.merged.fastq.gz
│   ├── sample.fastp.json
│   └── sample.fastp.html
├── umi_qc/                           # Pre-dedup UMI QC
│   ├── sample.umi_qc_metrics.txt
│   ├── sample_multiqc.json
│   └── reports/
│       └── sample.umi_qc_report.html
├── alignment/                        # Alignment outputs
│   ├── bam/
│   ├── samtools_stats/
│   └── picard/
├── umitools/dedup/                   # Deduplication
│   ├── sample.dedup.bam
│   └── sample_dedup.log
├── umi_qc_postdedup/                 # Post-dedup UMI QC
│   └── sample.postdedup_metrics.json
└── multiqc/                          # Final comprehensive report
    ├── multiqc_report.html
    └── multiqc_data/
```

## Quality Tracking at Each Stage

| Stage | Tool | Purpose | Key Metrics |
|-------|------|---------|-------------|
| 1 | FASTQC_RAW | Baseline | Raw read quality, adapter content |
| 2 | FASTP_QC | Filter (no 5' trim) | Filtered reads, adapters removed |
| 3 | FASTQC_FASTP_QC | Verify filtering | Quality after 3' trim, 5' intact |
| 4 | UMI_EXTRACT | Extract UMIs | UMI extraction stats |
| 5 | FASTP_TRIM | Full trimming | Final filtering, merging |
| 6 | FASTQC_FASTP_TRIM | Final QC | Quality of processed reads |
| 7 | UMI_QC_METRICS | UMI analysis | Diversity, collision rate, families |

## Benefits of This Approach

### ✅ UMI Integrity
- UMI sequences never lost to 5' trimming
- UMIs extracted from filtered (but intact) reads
- Complete UMI preservation guaranteed

### ✅ Data Quality
- Poor quality reads filtered early
- Low quality bases removed at both ends
- High-quality reads for alignment

### ✅ Comprehensive QC
- Quality metrics at 7 stages
- Track quality changes through workflow
- Identify issues at any step
- Compare before/after metrics

### ✅ Efficiency
- Filter poor reads before UMI extraction
- Don't waste time extracting from bad reads
- Optimal resource usage

### ✅ Reproducibility
- Clear module organization
- Separate configurations for each stage
- Well-documented workflow
- nf-core best practices

## Configuration Files

- **Workflow**: `subworkflows/local/umi_analysis.nf`
- **Module config**: `conf/modules.config`
- **Main pipeline**: `main.nf`
- **Documentation**: 
  - `README.md`
  - `TWO_ROUND_FASTP_WORKFLOW.md`
  - `FASTP_COMMANDS_SUMMARY.md`

## Commands Generated

### First FASTP (FASTP_QC)
```bash
fastp \
    --in1 sample_qc_1.fastq.gz \
    --in2 sample_qc_2.fastq.gz \
    --out1 sample_qc_1.fastp.fastq.gz \
    --out2 sample_qc_2.fastp.fastq.gz \
    --cut_tail \
    --trim_poly_x \
    --qualified_quality_phred 15 \
    --unqualified_percent_limit 40 \
    --length_required 50
    # NO --cut_front
```

### Second FASTP (FASTP_TRIM)
```bash
fastp \
    --in1 sample_1.fastq.gz \
    --in2 sample_2.fastq.gz \
    --out1 sample_1.fastp.fastq.gz \
    --out2 sample_2.fastp.fastq.gz \
    -m --merged_out sample.merged.fastq.gz \
    --cut_front \
    --cut_tail \
    --trim_poly_x \
    --qualified_quality_phred 15 \
    --unqualified_percent_limit 40 \
    --length_required 50
```

## Summary

This implementation represents bioinformatics best practices:

1. **Two-round FASTP** ensures UMI integrity
2. **Multi-stage FastQC** provides comprehensive quality tracking
3. **Modular design** allows easy customization
4. **Clear configuration** makes parameters transparent
5. **Organized outputs** facilitate analysis and troubleshooting

The workflow is ready for production use with high-quality UMI-tagged amplicon sequencing data.

