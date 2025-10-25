# Fixing the Plotly Module Not Found Error in Docker

## Problem
The `UMI_QC_HTML_REPORT` process fails with `ModuleNotFoundError: No module named 'plotly'` when running with Docker because the base `quay.io/biocontainers/python:3.11` container doesn't include plotly or its dependencies (numpy, pandas).

## Solutions

### Solution 1: Build Custom Docker Container (Recommended for Docker users)

1. **Build the custom container:**
   ```bash
   cd docker/umi_qc_report
   docker build -t umi_qc_report:latest .
   ```

2. **The module is already configured to use this container** (`modules/local/umi_qc_html_report.nf` line 6)

3. **Run your pipeline:**
   ```bash
   nextflow run main.nf -profile docker [other options]
   ```

### Solution 2: Use Conda Instead of Docker (Easiest)

If you don't want to build a custom Docker container, use conda which will automatically install all dependencies:

1. **Modify your Nextflow configuration** (or use `-profile conda`):
   ```groovy
   // In nextflow.config or your profile
   docker.enabled = false
   conda.enabled = true
   ```

2. **Run your pipeline:**
   ```bash
   nextflow run main.nf -profile conda [other options]
   ```

The conda environment file (`modules/local/umi_qc_html_report_environment.yml`) already contains all required dependencies:
- python=3.11
- plotly=5.18.0
- numpy=1.24.3
- pandas=2.0.3

### Solution 3: Use a Public Multi-tool Container

Alternatively, you can modify `modules/local/umi_qc_html_report.nf` to use a public container that includes these packages. For example, using a Jupyter container:

```groovy
container "jupyter/scipy-notebook:python-3.11"
```

Or a data science container:
```groovy
container "continuumio/miniconda3:latest"
```

Then add a script section to install plotly:
```bash
pip install plotly==5.18.0
```

## Verification

After implementing any solution, verify it works:

```bash
# Test the container has plotly
docker run umi_qc_report:latest python -c "import plotly; print(plotly.__version__)"

# Or for conda
conda activate umi_qc_html_report
python -c "import plotly; print(plotly.__version__)"
```

## Current Configuration

The module (`modules/local/umi_qc_html_report.nf`) is configured to:
- Use conda environment when conda is enabled
- Use custom Docker container `umi_qc_report:latest` when Docker is enabled

Choose the solution that best fits your workflow!
