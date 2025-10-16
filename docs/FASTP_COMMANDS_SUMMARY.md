# FASTP Command Summary

## Workflow Order

```
Raw Reads → FastQC → FASTP_QC (no trim) → UMI Extract → FASTP_TRIM (with trim) → Alignment → Dedup
```

## Step 2: FASTP_QC (Initial QC and filtering, NO 5' trimming)

**Purpose:** QC, filter, and trim reads BUT preserve the 5' end where UMIs are located.

**Command for paired-end:**
```bash
fastp \
    --in1 sample_qc_1.fastq.gz \
    --in2 sample_qc_2.fastq.gz \
    --out1 sample_qc_1.fastp.fastq.gz \
    --out2 sample_qc_2.fastp.fastq.gz \
    --json sample_qc.fastp.json \
    --html sample_qc.fastp.html \
    --thread 4 \
    --detect_adapter_for_pe \
    --cut_tail \
    --trim_poly_x \
    --qualified_quality_phred 15 \
    --unqualified_percent_limit 40 \
    --length_required 50 \
    2> sample_qc.fastp.log
```

**Key Parameters:**
- ❌ NO `--cut_front`: **CRITICAL** - preserves UMI sequences at 5' end
- ✅ `--cut_tail`: Trim 3' end based on quality (safe)
- ✅ `--trim_poly_x`: Remove poly-X tails (safe)
- ✅ `--qualified_quality_phred 15`: Quality filtering (safe)
- ✅ `--unqualified_percent_limit 40`: Filter poor quality reads (safe)
- ✅ `--length_required 50`: Length filtering (safe)
- ✅ Adapter trimming enabled by default (safe)

**Output:** 
- Filtered/trimmed reads (3' only): `*.fastp.fastq.gz`
- QC metrics: `*.fastp.json`, `*.fastp.html`

---

## Step 4: FASTP_TRIM (Full Quality Trimming, AFTER UMI extraction)

**Purpose:** Full trimming and filtering including 5' end. UMIs are now safely in read headers.

**Command for paired-end with merging:**
```bash
fastp \
    --in1 sample_1.fastq.gz \
    --in2 sample_2.fastq.gz \
    --out1 sample_1.fastp.fastq.gz \
    --out2 sample_2.fastp.fastq.gz \
    --json sample.fastp.json \
    --html sample.fastp.html \
    -m --merged_out sample.merged.fastq.gz \
    --thread 4 \
    --detect_adapter_for_pe \
    --cut_front \
    --cut_tail \
    --trim_poly_x \
    --qualified_quality_phred 15 \
    --unqualified_percent_limit 40 \
    --length_required 50 \
    2> sample.fastp.log
```

**Key Parameters:**
- `--cut_front`: Trim low quality bases from 5' end (NOW SAFE - UMIs are in headers)
- `--cut_tail`: Trim low quality bases from 3' end
- `--trim_poly_x`: Remove poly-X tails (poly-A, poly-T, poly-G, poly-C)
- `--qualified_quality_phred 15`: Minimum quality score for a "good" base
- `--unqualified_percent_limit 40`: Max % of bases below quality threshold
- `--length_required 50`: Minimum read length after trimming
- `-m --merged_out`: Merge overlapping paired-end reads (for amplicons)

**Output:** 
- Trimmed/filtered reads: `*.fastp.fastq.gz` (or `*.merged.fastq.gz` if merging)
- QC metrics: `*.fastp.json`, `*.fastp.html`

---

## Why This Order Matters

### ❌ WRONG Order (Original):
```
Raw Reads → UMI Extract → FASTP (with --cut_front) 
                          ↑
                          Problem: --cut_front removes 5' bases
                          UMIs might not be fully extracted!
```

### ✅ CORRECT Order (Updated):
```
Raw Reads → FASTP_QC (NO --cut_front) → UMI Extract → FASTP_TRIM (FULL trimming)
            ↑                            ↑              ↑
            Filter/3' trim only          Safe extract   Now can trim 5' end!
```

## Benefits

1. **FASTP_QC**: 
   - Remove adapters, low quality reads, trim 3' ends
   - **Preserve 5' end** where UMIs are located
   - Get baseline QC metrics

2. **UMI Extract**: 
   - Extract UMIs from intact 5' end
   - Move UMIs to read headers (safe from trimming)

3. **FASTP_TRIM**: 
   - Full quality trimming including 5' end
   - No risk of losing UMIs (they're in headers now)

This ensures:
- UMI sequences are never lost to quality trimming
- We have "before and after" QC metrics
- Maximum data quality for downstream analysis

