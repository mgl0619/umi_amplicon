# Count Generation from Deduplicated BAM Files

## Overview

After UMI deduplication, the pipeline generates two types of count files from deduplicated BAM files:

1. **Reference-level counts** (always generated): Uses `samtools idxstats` for read counts per reference sequence
2. **Gene-level counts** (optional): Uses `featureCounts` for read counts per gene/feature (requires GTF file)

## Output Files

### IDXStats Files (`*.idxstats`)
- **Location**: `results/counts/deduplicated/`
- **Format**: Tab-separated values (TSV)
- **Columns**:
  1. `reference_name`: Name of the reference sequence
  2. `sequence_length`: Length of the reference sequence (bp)
  3. `mapped_reads`: Number of deduplicated reads aligned to this reference
  4. `unmapped_reads`: Number of unmapped reads (always 0 for mapped references)

**Example**:
```
reference1	500	1234	0
reference2	750	5678	0
reference3	600	910	0
*	0	0	42
```

**Note**: The `*` line represents unmapped reads. For simple counting, use column 3 (mapped_reads) for each reference.

### Gene-Level Counts (featureCounts)
- **Location**: `results/counts/gene_level/`
- **Generated**: Only when `--gtf` parameter is provided
- **Files**:
  - `{sample}.featureCounts.txt`: Main count matrix
  - `{sample}.featureCounts.txt.summary`: Alignment summary statistics

**Count Matrix Format**:
```
Geneid    Chr    Start    End    Strand    Length    {sample}.bam
gene1     chr1   1000     2000   +         1000      523
gene2     chr1   3000     5000   -         2000      1847
gene3     chr2   1000     3000   +         2000      92
```

**Summary Format**:
```
Status                           {sample}.bam
Assigned                         15234
Unassigned_Unmapped             42
Unassigned_NoFeatures           823
Unassigned_Ambiguity            156
```

## Workflow Integration

The count generation steps are integrated into the UMI analysis workflow:

1. **UMI Extraction** → Extract UMIs from raw reads
2. **Alignment** → Align reads to reference sequences
3. **UMI Deduplication** → Remove PCR duplicates using UMI information
4. **Index Deduplicated BAM** → Create BAM index for deduplicated files
5. **Generate Reference Counts** → `samtools idxstats` (always run)
6. **Generate Gene Counts** → `featureCounts` (if GTF provided)

## Use Cases

### Reference-Level Counts (samtools idxstats)
- **Quantifying amplicon abundance** across multiple reference sequences
- **Comparing representation** between different targets
- **Quality control** for multi-amplicon experiments
- **Simple read counting** without annotation

### Gene-Level Counts (featureCounts)
- **Gene expression quantification** for RNA-seq or targeted panels
- **Differential expression analysis** (DESeq2, edgeR, etc.)
- **Feature-level counting** (exons, transcripts, genes)
- **Annotation-aware quantification** with strand information

## Usage

### Reference-level counts only (no GTF):
```bash
nextflow run main.nf -profile conda \
  --input samples.csv \
  --fasta reference.fa \
  --outdir results
```
**Output**: `results/counts/deduplicated/*.idxstats`

### Both reference and gene-level counts (with GTF):
```bash
nextflow run main.nf -profile conda \
  --input samples.csv \
  --fasta reference.fa \
  --gtf annotation.gtf \
  --outdir results
```
**Output**: 
- `results/counts/deduplicated/*.idxstats` (reference-level)
- `results/counts/gene_level/*.featureCounts.txt` (gene-level)

## Module Information

### Reference Counts
- **Module**: `SAMTOOLS_IDXSTATS_DEDUP`
- **Tool**: `samtools idxstats`
- **Container**: `quay.io/biocontainers/samtools:1.22.1--h96c455f_0`

### Gene Counts
- **Module**: `SUBREAD_FEATURECOUNTS`
- **Tool**: `featureCounts` (from Subread package)
- **Container**: `quay.io/biocontainers/subread:2.0.1--hed695b0_0`
