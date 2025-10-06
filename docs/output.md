# umi-amplicon: Output

## Table of contents

<!-- Install Atom plugin markdown-toc-auto for this ToC to auto-update on save -->
<!-- toc -->
- [Introduction](#introduction)
- [Pipeline overview](#pipeline-overview)
- [Output structure](#output-structure)
- [UMI QC Metrics](#umi-qc-metrics)
- [UMI Extraction](#umi-extraction)
- [UMI Deduplication](#umi-deduplication)
- [UMI Analysis](#umi-analysis)
- [HTML Report](#html-report)
- [MultiQC Report](#multiqc-report)
- [Pipeline information](#pipeline-information)
<!-- tocstop -->

## Introduction

This document describes the output produced by the pipeline. Most of the plots are taken from the MultiQC report, which summarises results across all samples.

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

## Pipeline overview

The umi-amplicon pipeline is built using [Nextflow](https://www.nextflow.io)
and processes data using the following steps:

- [UMI QC Metrics](#umi-qc-metrics) - Quality control metrics for UMI sequences
- [UMI Extraction](#umi-extraction) - Extract UMI sequences from raw data
- [UMI Deduplication](#umi-deduplication) - Remove duplicate reads based on UMI sequences
- [UMI Analysis](#umi-analysis) - Advanced analysis of UMI sequences
- [HTML Report](#html-report) - Comprehensive HTML report with visualizations

## Output structure

```
results/
├── umi_qc/
│   ├── sample1/
│   │   ├── umi_qc_metrics.html
│   │   ├── umi_qc_metrics.txt
│   │   └── umi_qc_plots/
│   └── sample2/
│       ├── umi_qc_metrics.html
│       ├── umi_qc_metrics.txt
│       └── umi_qc_plots/
├── umi_extract/
│   ├── sample1/
│   │   ├── extracted_R1.fastq.gz
│   │   ├── extracted_R2.fastq.gz
│   │   └── extraction_stats.txt
│   └── sample2/
│       ├── extracted_R1.fastq.gz
│       ├── extracted_R2.fastq.gz
│       └── extraction_stats.txt
├── umi_dedup/
│   ├── sample1/
│   │   ├── deduped_R1.fastq.gz
│   │   ├── deduped_R2.fastq.gz
│   │   └── deduplication_stats.txt
│   └── sample2/
│       ├── deduped_R1.fastq.gz
│       ├── deduped_R2.fastq.gz
│       └── deduplication_stats.txt
├── umi_analysis/
│   ├── sample1/
│   │   ├── umi_analysis.html
│   │   ├── umi_analysis.txt
│   │   └── umi_analysis_plots/
│   └── sample2/
│       ├── umi_analysis.html
│       ├── umi_analysis.txt
│       └── umi_analysis_plots/
├── report/
│   ├── umi_amplicon_report.html
│   └── multiqc_report.html
└── pipeline_info/
    ├── execution_report.html
    ├── execution_timeline.html
    ├── execution_trace.txt
    └── pipeline_dag.svg
```

## UMI QC Metrics

<details markdown="1">
<summary>Output files</summary>

- `umi_qc/`
  - `{sample}/umi_qc_metrics.html` - HTML report with QC metrics
  - `{sample}/umi_qc_metrics.txt` - Text file with QC metrics
  - `{sample}/umi_qc_plots/` - Directory containing QC plots

</details>

The UMI QC metrics provide comprehensive quality control information for UMI sequences:

- **UMI Diversity**: Measures the uniqueness of UMI sequences
- **Collision Rate**: Calculates the frequency of identical UMI sequences
- **Quality Scores**: Analyzes the quality of UMI sequences
- **Length Distribution**: Examines UMI length patterns
- **Composition Analysis**: Studies base composition of UMI sequences

## UMI Extraction

<details markdown="1">
<summary>Output files</summary>

- `umi_extract/`
  - `{sample}/extracted_R1.fastq.gz` - Extracted R1 reads
  - `{sample}/extracted_R2.fastq.gz` - Extracted R2 reads
  - `{sample}/extraction_stats.txt` - Extraction statistics

</details>

The UMI extraction step extracts UMI sequences from raw sequencing data:

- **Pattern-based Extraction**: Flexible UMI pattern recognition
- **Quality Filtering**: Removes low-quality UMI sequences
- **Extraction Statistics**: Comprehensive statistics on extraction process

## UMI Deduplication

<details markdown="1">
<summary>Output files</summary>

- `umi_dedup/`
  - `{sample}/deduped_R1.fastq.gz` - Deduplicated R1 reads
  - `{sample}/deduped_R2.fastq.gz` - Deduplicated R2 reads
  - `{sample}/deduplication_stats.txt` - Deduplication statistics

</details>

The UMI deduplication step removes duplicate reads based on UMI sequences:

- **Directional Deduplication**: Removes duplicates using directional approach
- **Quality Threshold Filtering**: Filters based on quality scores
- **Deduplication Statistics**: Comprehensive statistics on deduplication process

## UMI Analysis

<details markdown="1">
<summary>Output files</summary>

- `umi_analysis/`
  - `{sample}/umi_analysis.html` - HTML report with analysis results
  - `{sample}/umi_analysis.txt` - Text file with analysis results
  - `{sample}/umi_analysis_plots/` - Directory containing analysis plots

</details>

The UMI analysis step provides advanced analysis of UMI sequences:

- **UMI Frequency Distribution**: Analysis of UMI frequency patterns
- **UMI Network Analysis**: Identifies relationships between UMI sequences
- **UMI Composition Analysis**: Studies base composition of UMI sequences
- **Quality Metrics**: Comprehensive quality metrics

## HTML Report

<details markdown="1">
<summary>Output files</summary>

- `report/umi_amplicon_report.html` - Comprehensive HTML report

</details>

The HTML report provides a comprehensive overview of the analysis:

- **Interactive Visualizations**: Dynamic visualizations for exploration
- **Quality Plots**: Visual representation of quality metrics
- **Network Plots**: Graphical representation of UMI relationships
- **Heatmaps**: Matrix visualization of UMI frequencies

## MultiQC Report

<details markdown="1">
<summary>Output files</summary>

- `report/multiqc_report.html` - MultiQC report

</details>

The MultiQC report aggregates results from all samples:

- **Quality Control Summary**: Overview of QC metrics across all samples
- **Sample Comparison**: Comparison of metrics between samples
- **Interactive Plots**: Interactive visualizations for exploration

## Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - `execution_report.html` - Nextflow execution report
  - `execution_timeline.html` - Nextflow execution timeline
  - `execution_trace.txt` - Nextflow execution trace
  - `pipeline_dag.svg` - Pipeline DAG (Directed Acyclic Graph)

</details>

The pipeline information provides details about the execution:

- **Execution Report**: Detailed information about pipeline execution
- **Timeline**: Timeline of pipeline execution
- **Trace**: Detailed trace of pipeline execution
- **DAG**: Visual representation of the pipeline workflow
