# Final UMI QC Workflow - Complete Implementation

## Overview

The pipeline generates **ONE comprehensive HTML report** after post-deduplication that includes:
- Pre-deduplication UMI metrics (from UMI_QC_METRICS)
- Post-deduplication UMI metrics (from UMI_QC_METRICS_POSTDEDUP)
- UMI error correction and clustering statistics
- Interactive visualizations with Plotly

## Complete Workflow

```
┌──────────────────────────────────────────────────────────────┐
│                    COMPLETE UMI QC WORKFLOW                   │
└──────────────────────────────────────────────────────────────┘

1. FASTQC_RAW
   ↓
2. FASTP_QC (NO 5' trim) + FASTQC_FASTP_QC
   ↓
3. UMI_EXTRACT
   ↓
4. FASTP_TRIM (FULL trim) + FASTQC_FASTP_TRIM
   ↓
5. UMI_QC_METRICS
   │ • Text metrics: umi_qc/sample.umi_qc_metrics.txt
   │ • MultiQC JSON: umi_qc/sample_multiqc.json
   │ • NO HTML (saved for post-dedup)
   ↓
6. BWA_MEM (alignment)
   ↓
7. UMITOOLS_DEDUP
   ↓
8. UMI_QC_METRICS_POSTDEDUP
   │ • Deduplication statistics
   │ • UMI family sizes
   │ • Edit distance distribution (error correction)
   │ • Clustering metrics
   │ • Text metrics: umi_qc_postdedup/sample.postdedup_qc.txt
   │ • MultiQC JSON: umi_qc_postdedup/sample.multiqc_data.json
   ↓
9. UMI_QC_HTML_REPORT_POSTDEDUP ← **ONE COMPREHENSIVE REPORT**
   │ • Interactive Plotly visualizations
   │ • Family size distribution
   │ • Edit distance distribution
   │ • Deduplication summary
   │ • Quality assessment
   │ • Output: umi_qc_postdedup/reports/sample.umi_postdedup_report.html
   ↓
10. MULTIQC (aggregate all metrics)
```

## Modules Used

### UMI QC Metrics (Pre-Dedup)
**Module**: `modules/local/umi_qc_metrics.nf`

**Inputs**:
- FASTQ with extracted UMIs
- UMI-tools extract log

**Outputs**:
- `*.umi_qc_metrics.txt` - Text metrics
- `*_multiqc.json` - MultiQC data
- **NO HTML** (only post-dedup HTML is generated)

**Metrics Calculated**:
- UMI diversity (Shannon entropy, complexity)
- UMI collision rate
- UMI quality scores
- Family size distribution
- Singleton rate

### UMI QC Metrics (Post-Dedup)
**Module**: `modules/local/umi_qc_metrics_postdedup.nf`

**Inputs**:
- UMI-tools dedup log
- Edit distance TSV
- Per-UMI TSV
- Per-position TSV
- Deduplicated BAM

**Outputs**:
- `*.postdedup_qc.txt` - Text metrics
- `*.multiqc_data.json` - MultiQC data

**Metrics Calculated**:
- Deduplication rate
- Duplication fold
- UMI family statistics (mean, median, std dev)
- Singleton family rate
- **Edit distance statistics** (error correction)
- **UMI clustering metrics**
- Mean/median edit distance
- Error correction rate

### HTML Report (Post-Dedup Only)
**Module**: `modules/local/umi_qc_html_report_postdedup.nf`

**Inputs**:
- Post-dedup MultiQC JSON

**Outputs**:
- `*.umi_postdedup_report.html` - Interactive report

**Visualizations**:
1. **Deduplication Summary Gauge** - Shows dedup rate with thresholds
2. **UMI Family Size Distribution** - Bar chart
3. **Edit Distance Distribution** - Shows error correction clustering
4. **Singleton Family Rate** - Gauge indicator
5. **Summary Table** - All key metrics
6. **Quality Assessment** - Automated interpretation

## File Organization

```
results/
├── fastqc/
│   ├── raw/                       # Raw read QC
│   ├── after_fastp_qc/            # After first FASTP
│   └── after_fastp_trim/          # After second FASTP
│
├── fastp_qc/qc_only/              # First FASTP metrics
│
├── umitools/extract/              # UMI extraction
│
├── fastp/                         # Second FASTP metrics
│
├── umi_qc/                        # Pre-dedup UMI metrics
│   ├── sample.umi_qc_metrics.txt
│   └── sample_multiqc.json
│
├── alignment/                     # BAM files and stats
│
├── umitools/dedup/                # Deduplicated BAMs
│
├── umi_qc_postdedup/              # Post-dedup UMI metrics
│   ├── sample.postdedup_qc.txt
│   ├── sample.multiqc_data.json
│   └── reports/
│       └── sample.umi_postdedup_report.html  ← **THE REPORT**
│
└── multiqc/                       # Final comprehensive report
    └── multiqc_report.html
```

## Key Metrics in Post-Dedup Report

### Deduplication Summary
- Total input reads
- Deduplicated reads (output)
- Duplicates removed
- Deduplication rate (%)
- Duplication rate (fold)

### UMI Family Statistics
- Unique UMI families
- Average family size
- Median family size
- Std dev family size
- Min/Max family size
- Singleton families
- Singleton family rate

### UMI Error Correction & Clustering
- UMI pairs compared
- Mean edit distance
- Median edit distance
- Max edit distance
- UMI pairs clustered (≤1 edit)
- Error correction rate

### Quality Assessment
Automated warnings for:
- ⚠ HIGH deduplication rate (>80%) - over-amplification
- ⚠ LOW deduplication rate (<10%) - ineffective UMIs
- ⚠ HIGH singleton rate (>50%) - poor UMI coverage
- ⚠ HIGH error correction (>30%) - UMI errors or diversity issues

## Configuration

### Module Config (conf/modules.config)

```groovy
withName: 'UMI_QC_METRICS' {
    publishDir = [[
        path: { "${params.outdir}/umi_qc" },
        pattern: '*.{txt,json}'
    ]]
}

withName: 'UMI_QC_METRICS_POSTDEDUP' {
    publishDir = [[
        path: { "${params.outdir}/umi_qc_postdedup" },
        pattern: '*.{txt,json,png}'
    ]]
}

withName: 'UMI_QC_HTML_REPORT_POSTDEDUP' {
    publishDir = [[
        path: { "${params.outdir}/umi_qc_postdedup" },
        pattern: '*.html',
        saveAs: { filename -> "reports/${filename}" }
    ]]
}
```

### Workflow Integration (subworkflows/local/umi_analysis.nf)

```groovy
// Pre-dedup metrics (no HTML)
if (!skip_umi_qc && !skip_umi_analysis) {
    UMI_QC_METRICS (...)
    // Outputs text + JSON only
}

// Post-dedup metrics + HTML report
if (!skip_umi_qc) {
    UMI_QC_METRICS_POSTDEDUP (...)
    
    // Generate comprehensive HTML report
    UMI_QC_HTML_REPORT_POSTDEDUP (
        UMI_QC_METRICS_POSTDEDUP.out.multiqc
    )
}
```

## Benefits of Single Post-Dedup Report

### ✅ Advantages
1. **Complete Picture**: One report with all UMI metrics
2. **Error Correction Visibility**: See actual clustering that happened
3. **Before/After Comparison**: Compare pre-dedup diversity vs post-dedup families
4. **Easier Interpretation**: All metrics in one place
5. **Storage Efficient**: One HTML file instead of two

### ✅ Comprehensive Metrics
- **Pre-dedup**: UMI diversity, quality, collision rate
- **Post-dedup**: Family sizes, deduplication rate, error correction
- **Clustering**: Edit distances, UMI pairs clustered
- **Quality**: Automated warnings and interpretation

## Usage

The HTML report is automatically generated when you run the pipeline:

```bash
nextflow run main.nf \
    --input samplesheet.csv \
    --outdir results \
    --fasta reference.fasta \
    -profile conda
```

### View Results

```bash
# Text metrics (pre-dedup)
cat results/umi_qc/sample.umi_qc_metrics.txt

# Text metrics (post-dedup)
cat results/umi_qc_postdedup/sample.postdedup_qc.txt

# Interactive HTML report
open results/umi_qc_postdedup/reports/sample.umi_postdedup_report.html

# Comprehensive MultiQC
open results/multiqc/multiqc_report.html
```

## Summary

This implementation provides:
- ✅ **ONE comprehensive HTML report** after deduplication
- ✅ **Complete UMI error correction metrics**
- ✅ **UMI clustering statistics** from edit distance analysis
- ✅ **Interactive visualizations** with Plotly
- ✅ **Automated quality assessment** with warnings
- ✅ **Text metrics** at both pre- and post-dedup stages
- ✅ **MultiQC integration** for all metrics

The single post-deduplication HTML report contains everything needed to assess UMI quality, deduplication efficiency, and error correction performance.

