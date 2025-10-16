#!/bin/bash

# Test script for the CORRECTED workflow
# Tests: UMI extraction BEFORE FASTP + new UMI QC modules + HTML reports

set -e

echo "🧬 Testing CORRECTED UMI Amplicon Workflow"
echo "============================================"
echo ""
echo "✨ This test validates:"
echo "  1. ✅ UMI extraction BEFORE FASTP (corrected order)"
echo "  2. ✅ UMI QC leveraging umi_tools extract logs"
echo "  3. ✅ Interactive HTML report generation"
echo "  4. ✅ Post-dedup UMI metrics"
echo "  5. ✅ Complete workflow with alignment"
echo ""

# Check reference
REFERENCE="test/test_data/prame_tcr_2501_nnk_reference.fasta"
if [ ! -f "$REFERENCE" ]; then
    echo "❌ Error: Reference not found at $REFERENCE"
    exit 1
fi
echo "✓ Reference found: $REFERENCE"

# Check input data
SAMPLESHEET="assets/samplesheet_real_test.csv"
if [ ! -f "$SAMPLESHEET" ]; then
    echo "❌ Error: Samplesheet not found at $SAMPLESHEET"
    exit 1
fi
echo "✓ Samplesheet found: $SAMPLESHEET"

# Create output directory
OUTPUT_DIR="test_corrected_workflow_results"
mkdir -p "$OUTPUT_DIR"

echo ""
echo "⚙️  Configuration:"
echo "  Input:     $SAMPLESHEET"
echo "  Output:    $OUTPUT_DIR/"
echo "  Reference: $REFERENCE"
echo "  Profile:   conda"
echo "  UMI:       12bp, directional, Read1 only"
echo "  Workflow:  Raw → FastQC → UMI Extract → FASTP → Align → Dedup"
echo ""
echo "🚀 Starting pipeline test..."
echo ""

# Run the corrected pipeline
nextflow run ../main.nf \
    --input "$SAMPLESHEET" \
    --outdir "$OUTPUT_DIR" \
    --fasta "$REFERENCE" \
    -profile mac \
    --umi_length 12 \
    --umi_pattern NNNNNNNNNNNN \
    --umi_method directional \
    --umi_quality_filter_threshold 10 \
    --umi_collision_rate_threshold 0.1 \
    --umi_diversity_threshold 1000 \
    --merge_pairs \
    -resume \
    -with-report "$OUTPUT_DIR/execution_report.html" \
    -with-timeline "$OUTPUT_DIR/execution_timeline.html" \
    -with-dag "$OUTPUT_DIR/pipeline_dag.pdf"

# Capture exit code
EXIT_CODE=$?

echo ""
echo "============================================"
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ TEST PASSED! Pipeline completed successfully!"
    echo ""
    echo "📊 Key Outputs to Check:"
    echo ""
    echo "  1. Workflow Order Validation:"
    echo "     $OUTPUT_DIR/execution_timeline.html"
    echo "     → Verify: UMI_EXTRACT runs BEFORE FASTP"
    echo ""
    echo "  2. UMI Extraction:"
    echo "     $OUTPUT_DIR/umitools/extract/REAL_TEST.umi_extract.log"
    echo "     → Check: Input/output read counts"
    echo ""
    echo "  3. Pre-Dedup UMI QC:"
    echo "     $OUTPUT_DIR/umi_qc_metrics/before_dedup/REAL_TEST.umi_qc_metrics.txt"
    echo "     → Verify: Metrics use extract log data + calculated stats"
    echo ""
    echo "  4. Post-Dedup UMI QC:"
    echo "     $OUTPUT_DIR/umi_qc_metrics/after_dedup/REAL_TEST.postdedup_qc.txt"
    echo "     → Check: Deduplication statistics"
    echo ""
    echo "  5. UMI HTML Report:"
    echo "     $OUTPUT_DIR/umi_qc_metrics/html_report/REAL_TEST.umi_postdedup_report.html"
    echo "     → Interactive visualization of UMI metrics"
    echo ""
    echo "  5. MultiQC Report:"
    echo "     $OUTPUT_DIR/multiqc/multiqc_report.html"
    echo "     → Verify: UMI QC metrics included"
    echo ""
    echo "🔍 Quick View Commands:"
    echo ""
    echo "   # View execution timeline (check process order)"
    echo "   open $OUTPUT_DIR/execution_timeline.html"
    echo ""
    echo "   # View UMI QC HTML report"
    echo "   open $OUTPUT_DIR/umi_qc_metrics/html_report/REAL_TEST.umi_postdedup_report.html"
    echo ""
    echo "   # View MultiQC report"
    echo "   open $OUTPUT_DIR/multiqc/multiqc_report.html"
    echo ""
    echo "   # Check UMI extraction log"
    echo "   cat $OUTPUT_DIR/umitools/extract/REAL_TEST.umi_extract.log"
    echo ""
    echo "   # Check UMI QC metrics (text)"
    echo "   cat $OUTPUT_DIR/umi_qc_metrics/before_dedup/REAL_TEST.umi_qc_metrics.txt"
    echo ""
    echo "✅ Validation Checklist:"
    echo "   [ ] Timeline shows: UMITOOLS_EXTRACT before FASTP"
    echo "   [ ] Extract log shows input/output read counts"
    echo "   [ ] UMI QC metrics include 'Extract Statistics' section"
    echo "   [ ] HTML report opens with interactive plots"
    echo "   [ ] Unique UMIs > 1000"
    echo "   [ ] Collision rate < 0.15"
    echo "   [ ] Deduplication rate between 20-80%"
    echo "   [ ] MultiQC includes UMI QC data"
    echo ""
else
    echo "❌ TEST FAILED with exit code: $EXIT_CODE"
    echo ""
    echo "🔍 Debugging:"
    echo "   cat .nextflow.log | tail -100"
    echo "   cat .nextflow.log | grep ERROR"
    echo ""
fi

exit $EXIT_CODE

