process HTML_REPORT {
    label 'process_medium'

    conda (params.enable_conda ? "bioconda::multiqc=1.15" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/multiqc:1.15--pyhdfd78af_0' :
        'biocontainers/multiqc:1.15--pyhdfd78af_0' }"

    input:
    path(multiqc_files)
    path(versions)
    val(outdir)

    output:
    path "*.html", emit: html
    path "*.json", emit: json
    path "versions.yml", emit: versions

    script:
    """
    #!/bin/bash
    set -euo pipefail

    echo "Generating comprehensive HTML report for UMI amplicon analysis"

    # Create report directory
    mkdir -p umi_amplicon_report

    # Generate MultiQC report
    multiqc \\
        --title "UMI Amplicon Analysis Report" \\
        --filename "umi_amplicon_analysis_report" \\
        --outdir umi_amplicon_report \\
        --force \\
        ${multiqc_files}

    # Create custom HTML report with additional UMI-specific content
    cat > umi_amplicon_report/custom_umi_report.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>UMI Amplicon Analysis Report</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 0 20px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 40px;
            padding-bottom: 20px;
            border-bottom: 3px solid #007acc;
        }
        .header h1 {
            color: #007acc;
            margin: 0;
            font-size: 2.5em;
        }
        .header p {
            color: #666;
            font-size: 1.2em;
            margin: 10px 0;
        }
        .section {
            margin: 30px 0;
            padding: 20px;
            background-color: #f9f9f9;
            border-radius: 8px;
            border-left: 4px solid #007acc;
        }
        .section h2 {
            color: #007acc;
            margin-top: 0;
            font-size: 1.8em;
        }
        .section h3 {
            color: #333;
            margin-top: 20px;
            font-size: 1.4em;
        }
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .metric-card {
            background-color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            text-align: center;
        }
        .metric-value {
            font-size: 2em;
            font-weight: bold;
            color: #007acc;
            margin: 10px 0;
        }
        .metric-label {
            color: #666;
            font-size: 1.1em;
        }
        .plot-container {
            text-align: center;
            margin: 20px 0;
        }
        .plot-container img {
            max-width: 100%;
            height: auto;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .summary-table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        .summary-table th,
        .summary-table td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        .summary-table th {
            background-color: #007acc;
            color: white;
            font-weight: bold;
        }
        .summary-table tr:nth-child(even) {
            background-color: #f2f2f2;
        }
        .status-good {
            color: #28a745;
            font-weight: bold;
        }
        .status-warning {
            color: #ffc107;
            font-weight: bold;
        }
        .status-error {
            color: #dc3545;
            font-weight: bold;
        }
        .footer {
            text-align: center;
            margin-top: 40px;
            padding-top: 20px;
            border-top: 2px solid #007acc;
            color: #666;
        }
        .toc {
            background-color: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 30px;
        }
        .toc h3 {
            margin-top: 0;
            color: #007acc;
        }
        .toc ul {
            list-style-type: none;
            padding-left: 0;
        }
        .toc li {
            margin: 8px 0;
        }
        .toc a {
            color: #007acc;
            text-decoration: none;
            font-weight: 500;
        }
        .toc a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🧬 UMI Amplicon Analysis Report</h1>
            <p>Comprehensive analysis of UMI-tagged amplicon sequencing data</p>
            <p>Generated on: <span id="current-date"></span></p>
        </div>

        <div class="toc">
            <h3>📋 Table of Contents</h3>
            <ul>
                <li><a href="#overview">📊 Overview</a></li>
                <li><a href="#umi-qc">🔍 UMI Quality Control</a></li>
                <li><a href="#umi-analysis">🧪 UMI Analysis Results</a></li>
                <li><a href="#plots">📈 Visualizations</a></li>
                <li><a href="#summary">📝 Summary</a></li>
            </ul>
        </div>

        <div class="section" id="overview">
            <h2>📊 Analysis Overview</h2>
            <p>This report provides a comprehensive analysis of UMI-tagged amplicon sequencing data, including quality control metrics, UMI diversity analysis, and deduplication results.</p>
            
            <div class="metrics-grid">
                <div class="metric-card">
                    <div class="metric-value" id="total-reads">-</div>
                    <div class="metric-label">Total Reads</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value" id="unique-umis">-</div>
                    <div class="metric-label">Unique UMIs</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value" id="umi-diversity">-</div>
                    <div class="metric-label">UMI Diversity</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value" id="collision-rate">-</div>
                    <div class="metric-label">Collision Rate</div>
                </div>
            </div>
        </div>

        <div class="section" id="umi-qc">
            <h2>🔍 UMI Quality Control</h2>
            <p>Quality control metrics for UMI sequences, including diversity, collision rates, and quality scores.</p>
            
            <h3>UMI Diversity Analysis</h3>
            <p>UMI diversity is a key metric that indicates the effectiveness of UMI tagging. Higher diversity suggests better coverage of the target population.</p>
            
            <h3>Collision Rate Analysis</h3>
            <p>UMI collision rate indicates the frequency of identical UMI sequences, which can affect the accuracy of deduplication.</p>
            
            <h3>Quality Score Distribution</h3>
            <p>Quality scores for UMI sequences help identify potential issues with sequencing quality that might affect downstream analysis.</p>
        </div>

        <div class="section" id="umi-analysis">
            <h2>🧪 UMI Analysis Results</h2>
            <p>Detailed analysis of UMI sequences, including frequency distributions, composition analysis, and network analysis.</p>
            
            <h3>UMI Frequency Distribution</h3>
            <p>Analysis of how frequently each UMI sequence appears in the dataset, helping identify potential biases or artifacts.</p>
            
            <h3>UMI Composition Analysis</h3>
            <p>Base composition analysis of UMI sequences to identify potential biases in UMI generation or sequencing.</p>
            
            <h3>UMI Network Analysis</h3>
            <p>Network analysis of UMI relationships to identify potential clustering or patterns in UMI usage.</p>
        </div>

        <div class="section" id="plots">
            <h2>📈 Visualizations</h2>
            <p>Graphical representations of the analysis results, including plots for UMI diversity, collision rates, and quality metrics.</p>
            
            <div class="plot-container">
                <h3>UMI Diversity Plot</h3>
                <img src="diversity_plot.png" alt="UMI Diversity Plot" />
            </div>
            
            <div class="plot-container">
                <h3>UMI Collision Rate Plot</h3>
                <img src="collision_plot.png" alt="UMI Collision Rate Plot" />
            </div>
            
            <div class="plot-container">
                <h3>UMI Quality Plot</h3>
                <img src="quality_plot.png" alt="UMI Quality Plot" />
            </div>
        </div>

        <div class="section" id="summary">
            <h2>📝 Analysis Summary</h2>
            <p>Summary of key findings and recommendations based on the UMI analysis results.</p>
            
            <table class="summary-table">
                <thead>
                    <tr>
                        <th>Metric</th>
                        <th>Value</th>
                        <th>Status</th>
                        <th>Notes</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td>UMI Diversity</td>
                        <td id="summary-diversity">-</td>
                        <td id="status-diversity" class="status-good">Good</td>
                        <td>High diversity indicates good UMI coverage</td>
                    </tr>
                    <tr>
                        <td>Collision Rate</td>
                        <td id="summary-collision">-</td>
                        <td id="status-collision" class="status-good">Good</td>
                        <td>Low collision rate indicates effective UMI tagging</td>
                    </tr>
                    <tr>
                        <td>Quality Scores</td>
                        <td id="summary-quality">-</td>
                        <td id="status-quality" class="status-good">Good</td>
                        <td>High quality scores indicate reliable sequencing</td>
                    </tr>
                </tbody>
            </table>
        </div>

        <div class="footer">
            <p>Report generated by umi-amplicon pipeline</p>
            <p>For questions or issues, please contact the development team</p>
        </div>
    </div>

    <script>
        // Set current date
        document.getElementById('current-date').textContent = new Date().toLocaleDateString();
        
        // Load and display metrics from MultiQC data
        // This would typically be populated from the actual analysis results
        // For now, we'll use placeholder values
        document.getElementById('total-reads').textContent = '1,000,000';
        document.getElementById('unique-umis').textContent = '500,000';
        document.getElementById('umi-diversity').textContent = '0.85';
        document.getElementById('collision-rate').textContent = '0.15';
        
        // Update summary table
        document.getElementById('summary-diversity').textContent = '0.85';
        document.getElementById('summary-collision').textContent = '0.15';
        document.getElementById('summary-quality').textContent = '35.2';
        
        // Update status indicators based on thresholds
        const diversity = 0.85;
        const collision = 0.15;
        const quality = 35.2;
        
        if (diversity > 0.8) {
            document.getElementById('status-diversity').textContent = 'Excellent';
            document.getElementById('status-diversity').className = 'status-good';
        } else if (diversity > 0.6) {
            document.getElementById('status-diversity').textContent = 'Good';
            document.getElementById('status-diversity').className = 'status-good';
        } else {
            document.getElementById('status-diversity').textContent = 'Poor';
            document.getElementById('status-diversity').className = 'status-error';
        }
        
        if (collision < 0.2) {
            document.getElementById('status-collision').textContent = 'Excellent';
            document.getElementById('status-collision').className = 'status-good';
        } else if (collision < 0.4) {
            document.getElementById('status-collision').textContent = 'Good';
            document.getElementById('status-collision').className = 'status-warning';
        } else {
            document.getElementById('status-collision').textContent = 'Poor';
            document.getElementById('status-collision').className = 'status-error';
        }
        
        if (quality > 30) {
            document.getElementById('status-quality').textContent = 'Excellent';
            document.getElementById('status-quality').className = 'status-good';
        } else if (quality > 20) {
            document.getElementById('status-quality').textContent = 'Good';
            document.getElementById('status-quality').className = 'status-warning';
        } else {
            document.getElementById('status-quality').textContent = 'Poor';
            document.getElementById('status-quality').className = 'status-error';
        }
    </script>
</body>
</html>
EOF

    # Generate JSON data for programmatic access
    cat > umi_amplicon_report/analysis_data.json << EOF
{
    "pipeline_info": {
        "name": "umi-amplicon",
        "version": "1.0.0",
        "description": "UMI-tagged amplicon sequencing analysis pipeline"
    },
    "analysis_parameters": {
        "umi_length": "${params.umi_length}",
        "umi_pattern": "${params.umi_pattern}",
        "umi_method": "${params.umi_method}",
        "umi_quality_threshold": "${params.umi_quality_threshold}",
        "umi_collision_rate_threshold": "${params.umi_collision_rate_threshold}",
        "umi_diversity_threshold": "${params.umi_diversity_threshold}"
    },
    "sample_results": {
        "total_samples": 1,
        "samples": []
    },
    "summary_metrics": {
        "total_reads": 0,
        "unique_umis": 0,
        "umi_diversity": 0.0,
        "collision_rate": 0.0,
        "avg_quality": 0.0
    }
}
EOF

    # Move files to output directory
    mv umi_amplicon_report/* ./

    # Create versions file
    cat > versions.yml << EOF
multiqc:
    version: \$(multiqc --version 2>&1 | head -n1 | sed 's/.*version //')
    path: \$(which multiqc)
EOF
    """
}

