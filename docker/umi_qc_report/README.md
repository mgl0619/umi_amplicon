# UMI QC Report Docker Container

This Docker container includes Python 3.11 with the required dependencies for generating UMI QC HTML reports with Plotly visualizations.

## Dependencies Included
- Python 3.11
- plotly 5.18.0
- numpy 1.24.3
- pandas 2.0.3

## Building the Container

```bash
cd docker/umi_qc_report
docker build -t umi_qc_report:latest .
```

## Alternative: Using a Pre-built Container

If you prefer not to build a custom container, you can modify the module to use a conda environment instead by ensuring Docker is disabled in your Nextflow configuration:

```groovy
// In nextflow.config
docker.enabled = false
conda.enabled = true
```

When conda is enabled, the module will automatically create an environment from `umi_qc_html_report_environment.yml` with all required dependencies.
