#!/bin/bash

# Script to generate UMI QC HTML reports after main pipeline completion
echo "🎨 Generating UMI QC HTML Reports"
echo "================================="

# Check if results directory exists
if [ -z "$1" ]; then
    echo "Usage: $0 <results_directory>"
    echo "Example: $0 test_results_20251014_101801"
    exit 1
fi

RESULTS_DIR="$1"
MULTIQC_JSON_DIR="$RESULTS_DIR/umi_qc_postdedup"

# Check if multiqc JSON files exist
if [ ! -d "$MULTIQC_JSON_DIR" ]; then
    echo "❌ No UMI QC multiqc directory found: $MULTIQC_JSON_DIR"
    echo "Please run the main pipeline first to generate UMI QC metrics"
    exit 1
fi

# Find multiqc JSON files
JSON_FILES=$(find "$MULTIQC_JSON_DIR" -name "*.multiqc_data.json" -type f)

if [ -z "$JSON_FILES" ]; then
    echo "❌ No multiqc JSON files found in $MULTIQC_JSON_DIR"
    exit 1
fi

echo "📁 Found multiqc JSON files:"
echo "$JSON_FILES"

# Create HTML reports directory
HTML_REPORTS_DIR="$RESULTS_DIR/umi_qc_html_reports"
mkdir -p "$HTML_REPORTS_DIR"

echo "🎯 Generating HTML reports..."

# Process each JSON file
for json_file in $JSON_FILES; do
    sample_name=$(basename "$json_file" .multiqc_data.json)
    echo "Processing: $sample_name"
    
    # Create a temporary samplesheet for the HTML report workflow
    temp_samplesheet="$HTML_REPORTS_DIR/${sample_name}_samplesheet.csv"
    echo "sample,multiqc_json" > "$temp_samplesheet"
    echo "$sample_name,$json_file" >> "$temp_samplesheet"
    
    # Run the HTML report generation
    nextflow run generate_umi_html_report.nf \
        --input "$temp_samplesheet" \
        --outdir "$HTML_REPORTS_DIR/$sample_name" \
        -profile conda \
        -resume
    
    # Clean up temporary file
    rm "$temp_samplesheet"
done

echo ""
echo "✅ UMI QC HTML reports generated successfully!"
echo "📁 Reports available in: $HTML_REPORTS_DIR"
echo ""
echo "Generated reports:"
ls -la "$HTML_REPORTS_DIR"/*/reports/*.html 2>/dev/null || echo "No HTML reports found"

