# umi-amplicon: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2025-10-15

### Changed

- **UMI QC Metrics Consistency**: Aligned all metric outputs (text files, JSON, HTML reports) to have identical structure and ordering
  - Pre-dedup metrics now organized into 6 clear sections: Extraction Statistics, UMI Diversity, UMI Collision Analysis, Family Size Statistics, Singleton Analysis, Quality Metrics
  - Post-dedup metrics organized into 3 sections: Deduplication Summary, UMI Family Statistics, UMI Error Correction & Clustering
  - Section comments added to JSON outputs for better readability
  
- **HTML Report Improvements**:
  - Removed "UMI Extraction Statistics" section from HTML summary table (kept in text files)
  - Removed gauge plot visualization (Key Performance Indicators section)
  - Created separate summary table functions for pre-dedup and post-dedup metrics
  - Enhanced `create_pre_dedup_section()` to use comprehensive metrics table with 4 interactive visualizations

### Removed

- **Redundant Metrics**: Removed "specificity" metric as it was identical to "diversity_ratio"
- **Gauge Plots**: Removed semi-circular gauge visualizations from HTML reports for cleaner presentation

### Fixed

- **Metric Naming**: Fixed "Expected duplicate rate" label in text files to clarify it's for UMI before PCR (random collision)
- **QC Checks**: Updated warning messages to use correct metric names (e.g., "observed duplication rate" instead of "collision rate")

## [1.0.0] - 2024-01-01

### Added

- Initial release of umi-amplicon
- UMI QC Metrics analysis
- UMI Extraction functionality
- UMI Deduplication capabilities
- UMI Analysis pipeline
- HTML Report generation
- MultiQC integration
- Docker and Singularity support
- Conda environment support
- Comprehensive documentation
- GitHub Actions CI/CD
- Test profiles for validation

### Changed

- N/A

### Fixed

- N/A

### Dependencies

- Nextflow >= 23.04.0
- UMI-tools
- FastQC
- MultiQC
- Python 3.8+
- R 4.0+

### Deprecated

- N/A

### Removed

- N/A

### Security

- N/A
