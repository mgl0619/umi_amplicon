# umi-amplicon: Output

## Introduction

This document describes the output produced by the pipeline. The output is organized in the following subdirectories:

## Pipeline Overview

The pipeline follows bioinformatics best practices with a two-round FASTP strategy:

```
Raw FASTQ 
  ↓
FastQC (raw) → FASTP_QC (no 5' trim) → FastQC (after QC)
                         ↓
                    UMI Extraction
                         ↓
              FASTP_TRIM (full trim) → FastQC (after trim)
                         ↓
            Pre-dedup UMI QC Metrics (text + JSON)
                         ↓
                    Alignment
                         ↓
                   Deduplication
                         ↓
            Post-dedup UMI QC Metrics (text + JSON)
                         ↓
          📊 UMI QC HTML Report (COMPREHENSIVE)
                         ↓
                     MultiQC
```

**Critical Workflow Features**:
- **Two-round FASTP**: First round preserves 5' end (UMIs), second round does full trimming
- **UMI extraction**: Happens between FASTP rounds after QC but before full trimming
- **Multi-stage FastQC**: QC at 3 stages (raw, after first FASTP, after second FASTP)
- **Single comprehensive HTML report**: Generated after post-deduplication with all metrics

## Output Directory Structure

```
results/
├── fastqc/                          # Quality control at multiple stages
│   ├── raw/                        # FastQC on raw reads
│   ├── after_fastp_qc/             # FastQC after first FASTP (no 5' trim)
│   └── after_fastp_trim/           # FastQC after second FASTP (full trim)
│
├── fastp_qc/qc_only/               # First FASTP round (QC without 5' trim)
│
├── umitools/extract/               # UMI extraction outputs
│
├── fastp/                          # Second FASTP round (full trimming)
│
├── umi_qc/                         # Pre-deduplication UMI QC metrics
│   ├── *.umi_qc_metrics.txt       # Text metrics
│   └── *_multiqc.json              # MultiQC-compatible JSON
│
├── alignment/                      # BWA-MEM aligned BAM files
│   ├── bam/                       # Sorted BAM files
│   ├── samtools_stats/            # Alignment statistics
│   ├── picard/                    # Picard QC metrics
│   └── mosdepth/                  # Coverage statistics
│
├── umitools/dedup/                 # Deduplicated BAM files
│
├── umi_qc_postdedup/              # Post-deduplication UMI metrics
│   ├── *.postdedup_qc.txt         # Text metrics
│   ├── *.multiqc_data.json        # MultiQC-compatible JSON
│   └── reports/
│       └── *.umi_qc_report.html  ← 📊 COMPREHENSIVE HTML REPORT (Pre-dedup + Post-dedup)
│
├── multiqc/                        # Aggregated QC report
└── pipeline_info/                  # Pipeline execution info
```

## Detailed Output Description

### FastQC (Multi-Stage)

**Output files:**
- `fastqc/raw/`
  - `*_raw_fastqc.html`: FastQC report on raw reads
  - `*_raw_fastqc.zip`: Zip archive with raw read QC data
  
- `fastqc/after_fastp_qc/`
  - `*_qc_fastqc.html`: FastQC report after first FASTP (QC round)
  - `*_qc_fastqc.zip`: Zip archive with post-QC data
  
- `fastqc/after_fastp_trim/`
  - `*_fastqc.html`: FastQC report after second FASTP (full trim)
  - `*_fastqc.zip`: Zip archive with final QC data

[FastQC](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/) gives general quality metrics about your sequenced reads. The pipeline runs FastQC at **three critical stages**:

1. **Raw reads**: Initial quality assessment before any processing
2. **After FASTP_QC**: Quality after filtering and 3' trimming (5' preserved for UMIs)
3. **After FASTP_TRIM**: Final quality after UMI extraction and full trimming

This multi-stage QC allows you to track quality changes throughout the preprocessing steps.

### UMI Extraction

**Output files:**
- `umitools/extract/`
  - `*.umi_extract.fastq.gz`: FASTQ files with UMIs moved to read headers
  - `*.umi_extract.log`: Log file with extraction statistics

**Important**: UMI extraction is performed on raw reads BEFORE quality trimming to ensure UMI sequences are not removed or truncated.

The extracted UMI is appended to the read ID in the format: `@READ_ID_UMI:SEQUENCE`

### FASTP (Two-Round Strategy)

**First Round - FASTP_QC (QC without 5' trimming):**
- `fastp_qc/qc_only/`
  - `*_qc.fastp.json`: QC metrics in JSON format
  - `*_qc.fastp.html`: QC report
  - `*_qc.fastp.log`: Processing log

**Purpose**: Quality filtering, adapter trimming, and 3' end trimming WITHOUT touching the 5' end where UMIs are located.

**Second Round - FASTP_TRIM (Full trimming after UMI extraction):**
- `fastp/`
  - `*.fastp.json`: Final QC metrics in JSON format
  - `*.fastp.html`: Final QC report
  - `*.merged.fastq.gz`: Merged reads (if --merge_pairs enabled)
  - `*.fastp.log`: Processing log

**Purpose**: Full quality trimming including 5' end (UMIs are now safely in read headers), plus optional read merging for amplicons.

[FASTP](https://github.com/OpenGene/fastp) is used for quality control, adapter trimming, and read filtering. The **two-round strategy** ensures UMIs are preserved during initial QC but allows aggressive trimming after extraction.

### Pre-Deduplication UMI QC

**Output files:**
- `umi_qc/`
  - `*.umi_qc_metrics.txt`: Comprehensive UMI quality metrics (text format)
  - `*_multiqc.json`: MultiQC-compatible JSON with plot data

**Note**: Text metrics only at this stage. The comprehensive HTML report is generated after post-deduplication.

**Metrics include:**
- **UMI Diversity**: Shannon entropy, complexity score, unique UMI count
- **Collision Rate**: Estimated probability of UMI collisions
- **Family Size Distribution**: Number of reads per UMI
- **Quality Metrics**: Mean and minimum UMI quality scores
- **Singleton Rate**: Percentage of UMIs with only one read
- **Success Rate**: Percentage of UMIs passing quality filters

These metrics help assess:
1. Whether the UMI library is sufficiently diverse
2. If UMI quality is adequate for accurate deduplication
3. Potential PCR bias (from family size distribution)
4. Expected deduplication efficiency

### Alignment

**Output files:**
- `alignment/bam/`
  - `*.sorted.bam`: Coordinate-sorted BAM files
  - `*.sorted.bam.bai`: BAM index files
- `alignment/samtools_stats/`
  - `*.stats`: Comprehensive alignment statistics
  - `*.flagstat`: Summary of alignment flags
  - `*.idxstats`: Alignment counts per reference sequence
- `alignment/picard/`
  - `*.alignment_metrics.txt`: Detailed alignment summary
  - `*.insert_size_metrics.txt`: Insert size distribution (paired-end only)

Alignment is required for accurate UMI deduplication using genomic coordinates.

### UMI Deduplication

**Output files:**
- `umitools/dedup/`
  - `*.dedup.bam`: Deduplicated BAM files (one read per molecule)
  - `*.dedup_stats.log`: Deduplication statistics
  - `*_edit_distance.tsv`: Edit distance histogram between UMIs
  - `*_per_umi.tsv`: Per-UMI statistics (counts, positions)
  - `*_umi_per_position.tsv`: UMI usage per genomic position

[UMI-tools dedup](https://umi-tools.readthedocs.io/) uses a network-based method to group UMIs accounting for PCR errors, then selects one representative read per molecule based on quality scores.

### Post-Deduplication UMI QC & Comprehensive HTML Report

**Output files:**
- `umi_qc_postdedup/`
  - `*.postdedup_qc.txt`: Deduplication performance metrics (text format)
  - `*.multiqc_data.json`: MultiQC-compatible statistics
- `umi_qc_postdedup/reports/`
  - `*.umi_qc_report.html`: **📊 Comprehensive interactive HTML report (Pre-dedup + Post-dedup)**

#### Text Metrics (*.postdedup_qc.txt)

**Deduplication Summary:**
- Total input reads
- Deduplicated output reads
- Duplicates removed
- Deduplication rate (% duplicates removed)
- Duplication rate (fold amplification)

**UMI Family Statistics:**
- Unique UMI families
- Average family size
- Median family size
- Standard deviation of family size
- Min/Max family size
- Singleton families (UMIs with only 1 read)
- Singleton family rate

**UMI Error Correction & Clustering:**
- UMI pairs compared
- Mean edit distance between UMIs
- Median edit distance
- Maximum edit distance
- UMI pairs clustered (≤1 edit distance)
- Error correction rate (% of UMIs clustered due to sequencing errors)

**Interpretation:**
Automated quality assessment with warnings for:
- ⚠ HIGH deduplication rate (>80%) - potential over-amplification
- ⚠ LOW deduplication rate (<10%) - UMIs may not be effective
- ⚠ HIGH singleton rate (>50%) - many UMIs seen only once
- ⚠ HIGH error correction (>30%) - UMI sequencing errors or diversity issues

#### Interactive HTML Report (*.umi_qc_report.html)

**This is the comprehensive HTML report with TWO sections:**
- **Section 1:** Post-UMI Extraction Metrics (Before Deduplication)
- **Section 2:** Post-Deduplication Metrics (After Deduplication)

**Section 1 includes:**
1. **Summary Metrics Table** - 7 organized metric sections:
   - Extraction Statistics (total reads, UMIs, unique UMIs, UMI length)
   - UMI Diversity (diversity ratio, Shannon entropy, complexity score)
   - UMI Collision Analysis (birthday problem calculations, expected vs observed rates)
   - Family Size Statistics (mean, median, min, max, amplification ratio)
   - Singleton Analysis (singleton count and rate)
   - Quality Metrics (mean, min, max UMI quality)
   - Performance Metrics (success rate)

2. **Interactive Visualizations:**
   - Per-position quality plot (mean with min-max range)
   - Family size distribution histogram
   - Top UMIs bar chart
   - Collision analysis comparison chart

**Section 2 includes:**
1. **Summary Metrics Table** - 3 organized sections:
   - Deduplication Summary (total reads, deduplicated reads, deduplication rate)
   - UMI Family Statistics (unique families, family sizes, singleton rate)
   - UMI Error Correction & Clustering (edit distances, error correction rate)

2. **Interactive Visualizations:**
   - UMI family size distribution
   - Top UMIs bar chart
   - Per-position quality plot

3. **Recommendations** - Automated suggestions based on metrics

**Features:**
- Interactive Plotly visualizations (hover for details, zoom, pan)
- Responsive design for viewing on any device
- Standalone HTML file (no external dependencies)
- Professional formatting with clear section headers
- Color-coded metrics (blue = normal, orange = warning, red = alert)
- Consistent structure across text files, JSON, and HTML

These metrics help assess:
1. Deduplication efficiency and molecular count accuracy
2. PCR amplification bias
3. UMI sequencing error rates
4. Clustering effectiveness (error correction)
5. Overall library complexity and coverage

### MultiQC

**Output files:**
- `multiqc/`
  - `multiqc_report.html`: Standalone HTML file with all QC metrics
  - `multiqc_data/`: Directory containing parsed data from all tools

[MultiQC](http://multiqc.info) aggregates results from all pipeline steps into a single interactive report, including:
- FastQC quality plots
- FASTP preprocessing statistics
- UMI diversity and quality metrics
- Alignment summaries
- Deduplication statistics
- Coverage plots

### Pipeline Information

**Output files:**
- `pipeline_info/`
  - `execution_report.html`: Nextflow execution report
  - `execution_timeline.html`: Timeline of process execution
  - `execution_trace.txt`: Trace file with resource usage
  - `pipeline_dag.dot`: Pipeline workflow diagram

These files provide information about pipeline execution, resource usage, and can help with troubleshooting.

## Key QC Metrics to Check

### 1. UMI Quality (Pre-Deduplication)
- **Unique UMIs**: Should be high (>1000 for typical experiments)
- **Collision Rate**: Should be low (<0.1)
- **Mean UMI Quality**: Should be >20
- **Complexity Score**: Should be >0.8 (indicates diverse UMI library)

### 2. Alignment Quality
- **Mapping Rate**: Should be >80% for good quality amplicon data
- **Properly Paired**: Should be >95% for paired-end data
- **Duplicates**: High rate expected before UMI deduplication

### 3. Deduplication Efficiency
- **Deduplication Rate**: Varies by experiment (typically 20-80%)
- **Mean Family Size**: Indicates PCR amplification level
- **Unique UMI Families**: Final molecular count

## Interpretation Guide

### Good UMI Experiment
```
✓ Unique UMIs: 5000+
✓ Collision Rate: <0.05
✓ Mean UMI Quality: >25
✓ Deduplication Rate: 40-70%
✓ Mapping Rate: >85%
```

### Warning Signs
```
⚠ Unique UMIs: <1000 (low diversity, may need more UMI length)
⚠ Collision Rate: >0.15 (high collision risk)
⚠ Mean UMI Quality: <15 (sequencing quality issue)
⚠ Deduplication Rate: <10% (unexpected, check UMI extraction)
⚠ Deduplication Rate: >95% (very high duplication, check protocol)
```

## Citations

If you use umi-amplicon for your analysis, please cite:

- **FastQC**: Andrews, S. (2010). FastQC: a quality control tool for high throughput sequence data.
- **FASTP**: Chen, S., et al. (2018). fastp: an ultra-fast all-in-one FASTQ preprocessor. Bioinformatics, 34(17), i884-i890.
- **UMI-tools**: Smith, T., et al. (2017). UMI-tools: modeling sequencing errors in Unique Molecular Identifiers to improve quantification accuracy. Genome Research, 27(3), 491-499.
- **BWA**: Li, H. and Durbin, R. (2009) Fast and accurate short read alignment with Burrows-Wheeler Transform. Bioinformatics, 25:1754-60.
- **SAMtools**: Li, H., et al. (2009). The Sequence Alignment/Map format and SAMtools. Bioinformatics, 25(16), 2078-2079.
- **Picard**: Broad Institute. Picard Toolkit. http://broadinstitute.github.io/picard/
- **MultiQC**: Ewels, P., et al. (2016). MultiQC: summarize analysis results for multiple tools and samples in a single report. Bioinformatics, 32(19), 3047-3048.
