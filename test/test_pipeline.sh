#!/bin/bash
#
# UMI Amplicon Pipeline - Comprehensive Test Script
# 
# Tests the complete pipeline with:
# - Two-round FASTP strategy (QC without 5' trim, then full trim after UMI extraction)
# - Multi-stage FastQC (raw, after FASTP_QC, after FASTP_TRIM)
# - Merged and unmerged read processing
# - Combined UMI QC metrics in HTML report
#
# Date: 2025-10-13
# Version: 1.0.0

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print with color
print_status() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT_DIR="$(dirname "$SCRIPT_DIR")"
PIPELINE_DIR="$SCRIPT_DIR"
TEST_DATA_DIR="${PIPELINE_DIR}/test/test_data"
SAMPLESHEET="${PIPELINE_DIR}/assets/samplesheet_real_test.csv"
OUTPUT_DIR="${PIPELINE_DIR}/test_results_$(date +%Y%m%d_%H%M%S)"

# Pipeline parameters
GENOME_FASTA="${TEST_DATA_DIR}/prame_tcr_2501_nnk_reference.fasta"
UMI_PATTERN="NNNNNNNN"  # 8bp UMI
MERGE_PAIRS=true

# Print header
echo ""
echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║           UMI AMPLICON PIPELINE - COMPREHENSIVE TEST                     ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Check prerequisites
print_status "Checking prerequisites..."

if [ ! -f "$SAMPLESHEET" ]; then
    print_error "Samplesheet not found: $SAMPLESHEET"
    exit 1
fi
print_success "Samplesheet found: $SAMPLESHEET"

if [ ! -f "$GENOME_FASTA" ]; then
    print_error "Reference genome not found: $GENOME_FASTA"
    print_warning "Please ensure test data is available in ${TEST_DATA_DIR}"
    exit 1
fi
print_success "Reference genome found: $GENOME_FASTA"

# Check if nextflow is available
if ! command -v nextflow &> /dev/null; then
    print_error "Nextflow not found. Please install Nextflow."
    exit 1
fi
print_success "Nextflow found: $(nextflow -version | head -n1)"

# Check if conda is available
if ! command -v conda &> /dev/null; then
    print_warning "Conda not found. Pipeline will attempt to use containers."
else
    print_success "Conda found: $(conda --version)"
fi

# Display test configuration
echo ""
print_status "Test Configuration:"
echo "  Samplesheet:     $SAMPLESHEET"
echo "  Reference:       $GENOME_FASTA"
echo "  Output Dir:      $OUTPUT_DIR"
echo "  UMI Pattern:     $UMI_PATTERN"
echo "  Merge Pairs:     $MERGE_PAIRS"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Run the pipeline
print_status "Starting pipeline execution..."
echo ""
echo "Pipeline will:"
echo "  1. Run FastQC on raw reads"
echo "  2. Run FASTP_QC (NO 5' trimming) + FastQC"
echo "  3. Extract UMIs (5' end intact)"
echo "  4. Run FASTP_TRIM (FULL trimming) + FastQC"
echo "  5. Calculate pre-dedup UMI QC metrics"
echo "  6. Align reads (BWA-MEM)"
echo "  7. Deduplicate (umi-tools)"
echo "  8. Calculate post-dedup UMI QC metrics"
echo "  9. Generate COMBINED HTML report (merged + unmerged)"
echo "  10. Generate MultiQC report"
echo ""

# Confirm execution
read -p "Proceed with pipeline execution? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Pipeline execution cancelled"
    exit 0
fi

# Run Nextflow pipeline
print_status "Executing Nextflow pipeline..."
echo ""

START_TIME=$(date +%s)

nextflow run "${PIPELINE_DIR}/main.nf" \
    --input "$SAMPLESHEET" \
    --outdir "$OUTPUT_DIR" \
    --fasta "$GENOME_FASTA" \
    --umi_pattern "$UMI_PATTERN" \
    --merge_pairs "$MERGE_PAIRS" \
    -profile conda \
    -resume \
    -with-report "${OUTPUT_DIR}/execution_report.html" \
    -with-timeline "${OUTPUT_DIR}/execution_timeline.html" \
    -with-trace "${OUTPUT_DIR}/execution_trace.txt" \
    -with-dag "${OUTPUT_DIR}/pipeline_dag.html" \
    2>&1 | tee "${OUTPUT_DIR}/pipeline_execution.log"

EXIT_CODE=${PIPESTATUS[0]}
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    print_success "Pipeline completed successfully in ${ELAPSED} seconds!"
else
    print_error "Pipeline failed with exit code: $EXIT_CODE"
    exit $EXIT_CODE
fi

# Validate outputs
echo ""
print_status "Validating outputs..."

# Check for critical output files
SAMPLE_ID=$(grep -v "^sample" "$SAMPLESHEET" | head -n1 | cut -d',' -f1)

# FastQC outputs
check_file() {
    if [ -f "$1" ]; then
        print_success "Found: $1"
        return 0
    else
        print_error "Missing: $1"
        return 1
    fi
}

VALIDATION_FAILED=0

# FastQC at 3 stages
echo ""
print_status "Checking FastQC outputs (3 stages)..."
check_file "${OUTPUT_DIR}/fastqc/raw/${SAMPLE_ID}_raw_fastqc.html" || VALIDATION_FAILED=1
check_file "${OUTPUT_DIR}/fastqc/after_fastp_qc/${SAMPLE_ID}_qc_fastqc.html" || VALIDATION_FAILED=1
check_file "${OUTPUT_DIR}/fastqc/after_fastp_trim/${SAMPLE_ID}_merged_fastqc.html" || VALIDATION_FAILED=1

# FASTP outputs (2 rounds)
echo ""
print_status "Checking FASTP outputs (2 rounds)..."
check_file "${OUTPUT_DIR}/fastp_qc/qc_only/${SAMPLE_ID}_qc.fastp.json" || VALIDATION_FAILED=1
check_file "${OUTPUT_DIR}/fastp/${SAMPLE_ID}.fastp.json" || VALIDATION_FAILED=1

# UMI extraction
echo ""
print_status "Checking UMI extraction..."
check_file "${OUTPUT_DIR}/umitools/extract/${SAMPLE_ID}.umi_extract.log" || VALIDATION_FAILED=1

# Alignment (merged and unmerged)
echo ""
print_status "Checking alignment outputs (merged + unmerged)..."
check_file "${OUTPUT_DIR}/alignment/bam/${SAMPLE_ID}_merged.sorted.bam" || VALIDATION_FAILED=1
check_file "${OUTPUT_DIR}/alignment/bam/${SAMPLE_ID}_unmerged.sorted.bam" || VALIDATION_FAILED=1

# Deduplication (merged and unmerged)
echo ""
print_status "Checking deduplication outputs (merged + unmerged)..."
check_file "${OUTPUT_DIR}/umitools/dedup/${SAMPLE_ID}_merged.dedup.bam" || VALIDATION_FAILED=1
check_file "${OUTPUT_DIR}/umitools/dedup/${SAMPLE_ID}_unmerged.dedup.bam" || VALIDATION_FAILED=1

# UMI QC metrics (merged and unmerged text files)
echo ""
print_status "Checking UMI QC metrics (merged + unmerged text files)..."
check_file "${OUTPUT_DIR}/umi_qc_postdedup/${SAMPLE_ID}_merged.postdedup_qc.txt" || VALIDATION_FAILED=1
check_file "${OUTPUT_DIR}/umi_qc_postdedup/${SAMPLE_ID}_unmerged.postdedup_qc.txt" || VALIDATION_FAILED=1

# Combined HTML report (single report)
echo ""
print_status "Checking COMBINED HTML report..."
check_file "${OUTPUT_DIR}/umi_qc_postdedup/reports/${SAMPLE_ID}.umi_postdedup_report.html" || VALIDATION_FAILED=1

# MultiQC
echo ""
print_status "Checking MultiQC report..."
check_file "${OUTPUT_DIR}/multiqc/multiqc_report.html" || VALIDATION_FAILED=1

# Summary
echo ""
echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║                          TEST SUMMARY                                     ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

if [ $VALIDATION_FAILED -eq 0 ]; then
    print_success "ALL VALIDATIONS PASSED!"
    echo ""
    echo "Key Outputs:"
    echo "  FastQC (3 stages):     ${OUTPUT_DIR}/fastqc/"
    echo "  FASTP (2 rounds):      ${OUTPUT_DIR}/fastp_qc/ and ${OUTPUT_DIR}/fastp/"
    echo "  Alignments:            ${OUTPUT_DIR}/alignment/bam/"
    echo "  Deduplicated BAMs:     ${OUTPUT_DIR}/umitools/dedup/"
    echo "  UMI QC text metrics:   ${OUTPUT_DIR}/umi_qc_postdedup/"
    echo "  COMBINED HTML report:  ${OUTPUT_DIR}/umi_qc_postdedup/reports/${SAMPLE_ID}.umi_postdedup_report.html"
    echo "  MultiQC report:        ${OUTPUT_DIR}/multiqc/multiqc_report.html"
    echo ""
    print_status "View the combined HTML report:"
    echo "  open ${OUTPUT_DIR}/umi_qc_postdedup/reports/${SAMPLE_ID}.umi_postdedup_report.html"
    echo ""
    print_status "View the MultiQC report:"
    echo "  open ${OUTPUT_DIR}/multiqc/multiqc_report.html"
    echo ""
    
    # Display sample stats
    if [ -f "${OUTPUT_DIR}/umi_qc_postdedup/${SAMPLE_ID}_merged.postdedup_qc.txt" ]; then
        echo ""
        print_status "Merged reads statistics:"
        grep -E "(Total input|Deduplicated|Deduplication rate|Unique UMI)" \
            "${OUTPUT_DIR}/umi_qc_postdedup/${SAMPLE_ID}_merged.postdedup_qc.txt" | head -5
    fi
    
    if [ -f "${OUTPUT_DIR}/umi_qc_postdedup/${SAMPLE_ID}_unmerged.postdedup_qc.txt" ]; then
        echo ""
        print_status "Unmerged reads statistics:"
        grep -E "(Total input|Deduplicated|Deduplication rate|Unique UMI)" \
            "${OUTPUT_DIR}/umi_qc_postdedup/${SAMPLE_ID}_unmerged.postdedup_qc.txt" | head -5
    fi
    
    echo ""
    exit 0
else
    print_error "VALIDATION FAILED - Some expected outputs are missing"
    echo ""
    echo "Check the pipeline execution log for details:"
    echo "  ${OUTPUT_DIR}/pipeline_execution.log"
    echo ""
    exit 1
fi

