# umi-amplicon: Usage

## Table of contents

<!-- Install Atom plugin markdown-toc-auto for this ToC to auto-update on save -->
<!-- toc -->
- [Running the pipeline](#running-the-pipeline)
- [Main arguments](#main-arguments)
- [UMI Parameters](#umi-parameters)
- [Job resources](#job-resources)
- [Other command line parameters](#other-command-line-parameters)
- [Input specification](#input-specification)
- [Samplesheet format](#samplesheet-format)
- [Running the pipeline](#running-the-pipeline)
- [Core Nextflow arguments](#core-nextflow-arguments)
- [Custom configuration](#custom-configuration)
- [Running in the background](#running-in-the-background)
- [Updating the pipeline](#updating-the-pipeline)
- [Reproducibility](#reproducibility)
<!-- tocstop -->

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run umi-amplicon --input samplesheet.csv --outdir <OUTDIR> -profile <docker/singularity/conda/institutional>
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>           # Finished results (configurable, see below)
.nextflow_log      # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it'll always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull umi-amplicon
```

## Main arguments

### `--input`
You will need to design a file with information about the samples in your experiment/run before executing the pipeline. Use this parameter to specify its location. It has to be a comma-separated file with 5 columns, and a header row as shown in the examples below.

```bash
--input '[path to samplesheet file]'
```

### `--outdir`
The output directory where the results will be saved.

```bash
--outdir '[path to output directory]'
```

## UMI Parameters

### `--umi_length`
Length of UMI sequences (default: 12).

```bash
--umi_length 12
```

### `--umi_pattern`
Pattern for UMI extraction (default: NNNNNNNNNNNN).

```bash
--umi_pattern NNNNNNNNNNNN
```

### `--umi_method`
UMI extraction method: 'directional' or 'unique' (default: 'directional').

```bash
--umi_method directional
```

### `--umi_quality_threshold`
Minimum quality score for UMI bases (default: 10).

```bash
--umi_quality_threshold 10
```

### `--umi_collision_rate_threshold`
Maximum acceptable collision rate (default: 0.1).

```bash
--umi_collision_rate_threshold 0.1
```

### `--umi_diversity_threshold`
Minimum UMI diversity (default: 1000).

```bash
--umi_diversity_threshold 1000
```

## Job resources

### Automatic resubmission

Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the steps in the pipeline, if a job fails with an error (for example if it runs out of memory), the pipeline will automatically resubmit that job with higher requirements (see the `maxRetries` and `maxErrors` parameters in the [configuration file](https://github.com/umi-amplicon/blob/master/nextflow.config)).

### Custom resource requests

Wherever resource requirements are specified in the pipeline, the default can be overridden by providing custom limits. For example, if the default memory limit for a process is 12GB and you want to override it to 20GB, you can use the following parameter:

```bash
--max_memory 20.GB
```

## Other command line parameters

### `--skip_umi_qc`
Skip UMI quality control metrics.

```bash
--skip_umi_qc
```

### `--skip_umi_analysis`
Skip UMI analysis pipeline.

```bash
--skip_umi_analysis
```

### `--skip_report`
Skip HTML report generation.

```bash
--skip_report
```

## Input specification

### Samplesheet format

You will need to create a samplesheet with information about the samples you would like to analyse before running the pipeline. Use this parameter to specify its location. It has to be a comma-separated file with 5 columns, and a header row as shown in the examples below.

```bash
--input '[path to samplesheet file]'
```

#### Full samplesheet

The samplesheet can have as many columns as you desire, but there is a strict requirement for the first 5 columns to match those defined in the table below.

A final samplesheet file consisting of both single- and paired-end data may look something like the one below. This is for 6 samples, where `TREATMENT_REP1` has 2 replicates and `TREATMENT_REP3` has 2 replicates (you can also see the other columns that can be supplied):

```csv
sample,fastq_1,fastq_2
CONTROL_REP1,AEG588A1_S1_L002_R1_001.fastq.gz,AEG588A1_S1_L002_R2_001.fastq.gz
CONTROL_REP2,AEG588A2_S2_L002_R1_001.fastq.gz,AEG588A2_S2_L002_R2_001.fastq.gz
CONTROL_REP3,AEG588A3_S3_L002_R1_001.fastq.gz,
TREATMENT_REP1,AEG588A4_S4_L002_R1_001.fastq.gz,AEG588A4_S4_L002_R2_001.fastq.gz
TREATMENT_REP2,AEG588A5_S5_L002_R1_001.fastq.gz,
TREATMENT_REP3,AEG588A6_S6_L002_R1_001.fastq.gz,AEG588A6_S6_L002_R2_001.fastq.gz
```

| Column | Description |
|--------|-------------|
| `sample` | Custom sample name. This entry will be identical for multiple sequencing libraries/runs from the same sample. Spaces in sample names are automatically converted to underscores (`_`). |
| `fastq_1` | Full path to FastQ file for Illumina short reads 1. File has to be gzipped and have the extension `.fastq.gz` or `.fq.gz`. |
| `fastq_2` | Full path to FastQ file for Illumina short reads 2. File has to be gzipped and have the extension `.fastq.gz` or `.fq.gz`. For single-end samples, this can be empty. |

An [example samplesheet](../assets/samplesheet.csv) has been provided with the pipeline.

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run umi-amplicon --input samplesheet.csv --outdir <OUTDIR> -profile <docker/singularity/conda/institutional>
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>           # Finished results (configurable, see below)
.nextflow_log      # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it'll always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull umi-amplicon
```

## Core Nextflow arguments

> **NB:** These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen).

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Conda etc.) - see below.

> We highly recommend the use of Docker or Singularity containers for full pipeline reproducibility, however when this is not possible, Conda is also supported.

The pipeline also dynamically loads configurations from [https://github.com/nf-core/configs](https://github.com/nf-core/configs) when they are requested, before falling back to some 'sensible defaults' based on the `--max_memory` and `--max_cpus` specified.

The nf-core pipeline contains a `-profile test` which runs the pipeline with a minimal dataset to check that it exits successfully. This is typically used in a continuous integration testing environment and is available on both GitHub Actions and GitLab CI.

If you are unsure which profile to use, you can start with the `-profile test` to see if the pipeline runs successfully on your system, then move to `-profile docker` or `-profile singularity` for your actual analysis.

```bash
-profile test
-profile docker
-profile singularity
-profile conda
-profile <institutional>
```

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to work properly, the intermediate results must also be compatible with the new version of the pipeline.

```bash
nextflow run umi-amplicon -profile docker --input samplesheet.csv --outdir <OUTDIR> -resume
```

### `-c`

Specify the path to a specific config file (this is a core Nextflow command - see [docs](https://www.nextflow.io/docs/latest/config.html)).

```bash
-c /path/to/custom.config
```

## Custom configuration

### Resource requests

Whilst the default requirements set within the pipeline will work for most people with most data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the steps in the pipeline, if you want to change these, you can create a custom config file.

For example, to change the default number of CPUs requested for the process `UMI_QC_METRICS` from 1 to 4, you can create a custom config file as shown below.

```nextflow
process {
    withName: 'UMI_QC_METRICS' {
        cpus = 4
    }
}
```

### Tool-specific options

For a complete list of all available options, see the [configuration documentation](https://nf-co.re/umi-amplicon/parameters).

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

## Reproducibility

It is a good idea to specify a pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your analysis. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [umi-amplicon releases page](https://github.com/umi-amplicon/releases) and find the latest version number - numeric only (eg. `1.3.1`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r 1.3.1`.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future. For example, at the bottom of the MultiQC reports.

To further assist in reproducibility, you can use share and re-use [parameter files](https://nf-co.re/usage/parameters#custom-parameters-files) to repeat pipeline runs with the same settings without having to write out a command with every single parameter.

> 💡 If you wish to share such profile (such as upload as supplementary material for academic publications), make sure to NOT include cluster specific paths to files, nor institutional specific profiles.

## Core Nextflow arguments

> **NB:** These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen).

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Conda etc.) - see below.

> We highly recommend the use of Docker or Singularity containers for full pipeline reproducibility, however when this is not possible, Conda is also supported.

The pipeline also dynamically loads configurations from [https://github.com/nf-core/configs](https://github.com/nf-core/configs) when they are requested, before falling back to some 'sensible defaults' based on the `--max_memory` and `--max_cpus` specified.

The nf-core pipeline contains a `-profile test` which runs the pipeline with a minimal dataset to check that it exits successfully. This is typically used in a continuous integration testing environment and is available on both GitHub Actions and GitLab CI.

If you are unsure which profile to use, you can start with the `-profile test` to see if the pipeline runs successfully on your system, then move to `-profile docker` or `-profile singularity` for your actual analysis.

```bash
-profile test
-profile docker
-profile singularity
-profile conda
-profile <institutional>
```

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to work properly, the intermediate results must also be compatible with the new version of the pipeline.

```bash
nextflow run umi-amplicon -profile docker --input samplesheet.csv --outdir <OUTDIR> -resume
```

### `-c`

Specify the path to a specific config file (this is a core Nextflow command - see [docs](https://www.nextflow.io/docs/latest/config.html)).

```bash
-c /path/to/custom.config
```
