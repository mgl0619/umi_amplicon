# UMI Amplicon Pipeline - Documentation Index

## User Documentation

### Getting Started
- **[Quick Start Guide](../QUICK_START.md)** - Quick setup and basic usage
- **[Usage Guide](usage.md)** - Detailed usage instructions and parameters
- **[Output Guide](output.md)** - Complete description of all pipeline outputs

### Technical Documentation
- **[Two-Round FASTP Workflow](TWO_ROUND_FASTP_WORKFLOW.md)** - Detailed explanation of the two-round FASTP strategy
- **[Merged & Unmerged Processing](MERGED_UNMERGED_PROCESSING.md)** - How merged and unmerged reads are handled
- **[Combined Metrics Implementation](COMBINED_METRICS_IMPLEMENTATION.md)** - Technical details of metrics combination
- **[FASTP Commands Summary](FASTP_COMMANDS_SUMMARY.md)** - Specific FASTP commands for each round

## Pipeline Overview

The UMI Amplicon Pipeline implements best practices for UMI-tagged amplicon sequencing analysis with the following key features:

### Core Features

1. **Two-Round FASTP Strategy**
   - Round 1 (FASTP_QC): Quality filtering WITHOUT 5' trimming to preserve UMIs
   - Round 2 (FASTP_TRIM): Full trimming AFTER UMI extraction with optional read merging

2. **Multi-Stage FastQC**
   - Raw reads (before processing)
   - After first FASTP round (after QC filtering)
   - After second FASTP round (after full trimming and merging)

3. **Intelligent UMI Processing**
   - UMI extraction happens BETWEEN FASTP rounds
   - Leverages existing tool outputs to avoid redundant calculations
   - Comprehensive pre- and post-deduplication metrics

4. **Merged & Unmerged Analysis**
   - Both merged and unmerged reads processed independently
   - Separate alignment and deduplication
   - **Combined HTML report** with metrics from both streams

5. **Comprehensive QC Reporting**
   - Interactive HTML reports with Plotly visualizations
   - MultiQC integration for all QC metrics
   - Automated quality assessment with warnings

## Workflow Diagram

```
Raw FASTQ
  ↓
FastQC (raw) → FASTP_QC (no 5' trim, no merge) → FastQC (after QC)
                     ↓
              UMI Extraction (5' end intact!)
                     ↓
          FASTP_TRIM (full trim + merge) → FastQC (after trim)
                     ↓
         ┌────────────┴────────────┐
         ↓                         ↓
   Merged reads            Unmerged reads
   (single-end)           (paired-end)
         ↓                         ↓
   Alignment                 Alignment
         ↓                         ↓
   Deduplication           Deduplication
         ↓                         ↓
   UMI QC metrics          UMI QC metrics
         └────────────┬────────────┘
                      ↓
          Combined HTML Report
                (one per sample)
                      ↓
                  MultiQC
```

## Output Structure

```
results/
├── fastqc/                          # Multi-stage FastQC
│   ├── raw/
│   ├── after_fastp_qc/
│   └── after_fastp_trim/
├── fastp_qc/qc_only/                # First FASTP (no 5' trim, no merge)
├── umitools/extract/                # UMI extraction
├── fastp/                           # Second FASTP (full trim + merge)
├── umi_qc/                          # Pre-dedup UMI metrics
├── alignment/                       # Alignments (merged + unmerged)
├── umitools/dedup/                  # Deduplicated BAMs
├── umi_qc_postdedup/               # Post-dedup UMI metrics
│   └── reports/
│       └── *.html                   # Combined HTML report ⭐
└── multiqc/                         # Comprehensive QC report
```

## Quick Start

```bash
# Basic run
nextflow run main.nf \
    --input samplesheet.csv \
    --outdir results \
    --fasta reference.fasta \
    --umi_pattern 'NNNNNNNNNNNN' \
    -profile conda

# View combined UMI QC report
open results/umi_qc_postdedup/reports/SAMPLE.umi_postdedup_report.html

# View MultiQC report
open results/multiqc/multiqc_report.html
```

## Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `--input` | Samplesheet CSV | Required |
| `--outdir` | Output directory | `./results` |
| `--fasta` | Reference genome | Required |
| `--umi_pattern` | UMI pattern | `'NNNNNNNNNNNN'` (12bp) |
| `--merge_pairs` | Merge R1+R2 reads | `true` |
| `--skip_feature_counting` | Skip feature counting | `true` |

## Development Documentation

Historical and development documentation is archived in `docs/development/`.

## Support

For issues or questions:
1. Check the documentation in this directory
2. Review the [CHANGELOG](../CHANGELOG.md)
3. Check pipeline execution logs

---

**Pipeline Version**: 1.0.0  
**Last Updated**: 2025-10-13  
**Documentation Status**: Current

