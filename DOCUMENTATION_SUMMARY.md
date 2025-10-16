# Documentation Summary - UMI Amplicon Pipeline

**Last Updated**: 2025-10-15  
**Pipeline Version**: 1.0.1

## Documentation Structure

### Root Directory (User-Facing)

```
├── README.md                 Main pipeline documentation
├── QUICK_START.md            Quick setup and usage guide  
├── CHANGELOG.md              Version history
└── LICENSE                   Software license
```

### docs/ Directory (Technical Documentation)

```
docs/
├── README.md                                Documentation index and navigation
├── output.md                                Complete output description
├── usage.md                                 Detailed usage instructions
├── TWO_ROUND_FASTP_WORKFLOW.md             FASTP strategy explanation
├── MERGED_UNMERGED_PROCESSING.md           Merged/unmerged read handling
├── COMBINED_METRICS_IMPLEMENTATION.md      Metrics combination details
├── FASTP_COMMANDS_SUMMARY.md               FASTP command reference
└── development/                             Archived development docs
    ├── COMPLETED_TASKS.md
    ├── IMPLEMENTATION_COMPLETE.md
    ├── PIPELINE_REVIEW_SUMMARY.md
    ├── UMI_QC_FINAL_WORKFLOW.md
    ├── VALIDATION_CHECKLIST.md
    └── WORKFLOW_COMPLETE_SUMMARY.md
```

## Documentation Guide

### For New Users

**Start here**: `QUICK_START.md`
- Quick setup instructions
- Basic usage examples
- Common parameters
- Expected outputs

### For Detailed Information

**Next**: `README.md`
- Complete pipeline overview
- Workflow description
- All parameters
- Installation guide

**Then**: `docs/output.md`
- Detailed output descriptions
- File organization
- Interpretation guidelines
- Troubleshooting

### For Technical Details

**Two-Round FASTP Strategy**: `docs/TWO_ROUND_FASTP_WORKFLOW.md`
- Visual workflow diagram
- Step-by-step explanation
- Key differences between rounds
- Benefits and rationale

**Merged & Unmerged Processing**: `docs/MERGED_UNMERGED_PROCESSING.md`
- Why both are processed
- Independent analysis streams
- Combined reporting strategy
- Output structure

**Metrics Implementation**: `docs/COMBINED_METRICS_IMPLEMENTATION.md`
- Metrics combination algorithms
- Channel management
- Validation examples
- Technical details

### For Development

**Development History**: `docs/development/`
- Implementation notes
- Validation checklists
- Review summaries
- Completed tasks

## Key Pipeline Features (Reflected in Documentation)

### 1. Two-Round FASTP Strategy

- ✅ **Round 1 (FASTP_QC)**: Quality filtering WITHOUT 5' trimming
- ✅ **UMI Extraction**: Between FASTP rounds (5' end intact!)
- ✅ **Round 2 (FASTP_TRIM)**: Full trimming AFTER UMI extraction

### 2. Multi-Stage FastQC

- ✅ **Stage 1**: Raw reads
- ✅ **Stage 2**: After FASTP_QC
- ✅ **Stage 3**: After FASTP_TRIM

### 3. Merged & Unmerged Processing

- ✅ **Independent**: Separate alignment and deduplication
- ✅ **Combined**: Single HTML report per sample
- ✅ **Complete**: No data loss, all molecules counted

### 4. Comprehensive QC

- ✅ **Pre-dedup**: UMI diversity, collision rate, quality (6 metric sections)
- ✅ **Post-dedup**: Deduplication efficiency, error correction, clustering (3 metric sections)
- ✅ **Interactive**: Plotly visualizations (family size, top UMIs, quality plots)
- ✅ **Consistent**: Text files, JSON, and HTML reports fully aligned
- ✅ **Aggregated**: MultiQC integration

## Quick Reference

### Running the Pipeline

```bash
nextflow run main.nf \
    --input samplesheet.csv \
    --outdir results \
    --fasta reference.fasta \
    --umi_pattern 'NNNNNNNN' \
    --merge_pairs true \
    -profile conda
```

### Viewing Results

```bash
# Interactive UMI QC HTML report
open results/umi_qc_metrics/html_report/SAMPLE.umi_qc_report.html

# Complete MultiQC report
open results/multiqc/multiqc_report.html

# Pipeline execution report
open results/execution_report.html

# Pipeline execution timeline
open results/execution_timeline.html
```

### Key Output Directories

```
results/
├── bwa/                       BWA index files
├── execution_report.html      Pipeline execution report
├── execution_timeline.html    Pipeline timeline visualization
├── fastp/                     Second FASTP (full trim)
│   ├── qc_5trim/             FASTP with 5' trimming
│   └── qc_no5trim/           FASTP without 5' trimming (preserves UMIs)
├── fastqc/                    Multi-stage QC
│   ├── raw/                  Raw reads QC
│   ├── after_fastp_qc/       After first FASTP QC
│   └── after_fastp_trim/     After second FASTP QC
├── multiqc/                   Comprehensive aggregated QC report
├── picard/                    Picard alignment metrics
│   └── alignment_summary/
├── samtools/                  SAMtools statistics
│   ├── flagstat/
│   ├── idxstats/
│   └── stats/
├── umi_qc_metrics/           UMI QC metrics (pre and post dedup)
│   ├── after_dedup/          Post-deduplication metrics
│   ├── before_dedup/         Pre-deduplication metrics
│   └── html_report/          ⭐ Interactive HTML reports
└── umitools/                  UMI-tools outputs
    ├── dedup/                Deduplicated BAMs
    └── extract/              UMI extraction outputs
```

## Documentation Maintenance

### Current Status

- ✅ All documentation is current and accurate
- ✅ Organized by user need (quick start → detailed → technical)
- ✅ Development history archived
- ✅ No redundant or conflicting documentation

### Future Updates

When updating the pipeline:
1. Update `CHANGELOG.md` with changes
2. Update relevant sections in `README.md`
3. Update `docs/output.md` if outputs change
4. Update technical docs (`docs/*.md`) if implementation changes
5. Update `QUICK_START.md` if basic usage changes

### Documentation Standards

- **Clear**: Use plain language, explain acronyms
- **Complete**: Cover all features and parameters
- **Current**: Keep in sync with code changes
- **Organized**: Logical structure, easy navigation
- **Examples**: Provide working examples and use cases

## Support

For questions or issues:
1. Check `QUICK_START.md` for common usage
2. Review `docs/output.md` for output interpretation
3. Check `CHANGELOG.md` for recent changes
4. Review execution logs in your output directory

---

**Contact**: See `README.md` for details  
**License**: See `LICENSE` file

