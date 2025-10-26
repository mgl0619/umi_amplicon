# fgbio FastqToBam Integration - RX Tag Fix

## Problem

The pipeline encountered a fatal error when running fgbio consensus workflow:

```
FgBioMain | Fatal] Record 'MA1:101025-AVITI-Run1-300:2517575107:2:11004:0374:1660_GGTTCATTCGAA 1/2 139b aligned to 1:1-117.' was missing the raw UMI tag 'RX'
```

**Root Cause**: fgbio requires UMI information in the `RX` tag of BAM files, but umi_tools extract stores UMI in read names only.

---

## Solution

Integrated `fgbio FastqToBam` to properly transfer UMI from read names to RX tags, following **nf-core/fastquorum best practices**.

### Workflow Changes

**Before (❌ Failed)**:
```
umi_tools extract → BWA align → fgbio GroupReadsByUmi ❌
(UMI in read names)   (no RX tag)   (ERROR: missing RX)
```

**After (✅ Works)**:
```
umi_tools extract → fgbio FastqToBam → BWA align → fgbio GroupReadsByUmi ✅
(UMI in read names)   (RX tag added)    (RX preserved)  (SUCCESS)
```

---

## Implementation Details

### 1. Module Used

**nf-core/fgbio/fastqtobam** - Official nf-core module
- Location: `modules/nf-core/fgbio/fastqtobam/main.nf`
- Container: `community.wave.seqera.io/library/fgbio:2.5.21`
- Follows fastquorum best practices

### 2. Configuration

Added to `nextflow.config`:

```groovy
withName: 'FGBIO_FASTQTOBAM' {
    ext.args = {
        def umi_len = params.umi_length ?: 12
        def read_structure = meta.single_end ? 
            "${umi_len}M+T" : 
            "${umi_len}M+T ${umi_len}M+T"
        [
            '--read-structures', read_structure,
            '--extract-umis-from-read-names'
        ].join(' ')
    }
}
```

**Read Structure Format**:
- `12M` = 12 bases of Molecular barcode (UMI)
- `+T` = rest of read is Template
- Single-end: `12M+T`
- Paired-end: `12M+T 12M+T`

### 3. Workflow Integration

In `subworkflows/local/umi_analysis.nf`:

```groovy
// Step 1: Convert FASTQ to unmapped BAM with RX tags
FGBIO_FASTQTOBAM (
    UMITOOLS_EXTRACT.out.reads  // FASTQ with UMI in read names
)

// Step 2: Align unmapped BAM (BWA preserves RX tags)
BWA_MEM_CONSENSUS (
    FGBIO_FASTQTOBAM.out.bam,
    ch_bwa_index,
    ch_fasta,
    true  // sort BAM
)

// Step 3: Group reads by UMI (now has RX tags!)
FGBIO_GROUPREADSBYUMI (
    BWA_MEM_CONSENSUS.out.bam,
    params.fgbio_group_strategy
)
```

---

## Key Features

✅ **Uses official nf-core module** - Better maintained and tested
✅ **Follows fastquorum approach** - Industry best practices
✅ **Automatic read structure** - Determined from `meta.single_end`
✅ **Extracts from read names** - `--extract-umis-from-read-names` flag
✅ **Preserves through alignment** - BWA maintains custom BAM tags
✅ **Configurable** - UMI length via `params.umi_length`

---

## How It Works

### 1. umi_tools extract
```
Input:  @READ1 SEQUENCE
Output: @READ1_NNNNNNNNNNNN SEQUENCE
```
UMI moved to read name with underscore separator.

### 2. fgbio FastqToBam
```
Input:  @READ1_NNNNNNNNNNNN SEQUENCE
Output: Unmapped BAM with RX:Z:NNNNNNNNNNNN tag
```
Extracts UMI from read name and stores in RX tag.

### 3. BWA-MEM Alignment
```
Input:  Unmapped BAM with RX tag
Output: Aligned BAM with RX tag preserved
```
BWA preserves all custom tags during alignment.

### 4. fgbio GroupReadsByUmi
```
Input:  Aligned BAM with RX tag ✅
Output: Grouped BAM for consensus calling
```
Successfully reads RX tag and groups reads by UMI.

---

## Testing

```bash
# Clean previous runs
rm -rf work/

# Run test
bash test/run_nextflow_umiamplicon_6ntsample1_fgbio.sh
```

**Expected Result**: No "missing RX tag" error, fgbio workflow completes successfully.

---

## References

- **nf-core/fastquorum**: https://nf-co.re/fastquorum
- **fgbio FastqToBam**: http://fulcrumgenomics.github.io/fgbio/tools/latest/FastqToBam.html
- **fgbio Best Practices**: https://github.com/fulcrumgenomics/fgbio/wiki/Best-Practice-Pipelines

---

## Related Files

- `modules/nf-core/fgbio/fastqtobam/main.nf` - FastqToBam module
- `subworkflows/local/umi_analysis.nf` - Workflow integration
- `nextflow.config` - FGBIO_FASTQTOBAM configuration
- `README.md` - Updated workflow documentation
- `CHANGELOG.md` - Version 1.0.2 release notes
