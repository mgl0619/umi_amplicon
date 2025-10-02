# Contributing to nf-core/umi-amplicon

Thank you for your interest in contributing to nf-core/umi-amplicon! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Guidelines](#development-guidelines)
- [Testing](#testing)
- [Documentation](#documentation)
- [Release Process](#release-process)

## Code of Conduct

This project follows the [nf-core Code of Conduct](https://nf-co.re/code_of_conduct). By participating, you are expected to uphold this code.

## Getting Started

### Prerequisites

- [Nextflow](https://www.nextflow.io/) >= 23.04.0
- [Docker](https://www.docker.com/) or [Singularity](https://sylabs.io/docs/)
- [Git](https://git-scm.com/)

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/umi-amplicon.git
   cd umi-amplicon
   ```

3. Add the upstream repository:
   ```bash
   git remote add upstream https://github.com/nf-core/umi-amplicon.git
   ```

## How to Contribute

### Reporting Issues

- Use the [GitHub issue tracker](https://github.com/nf-core/umi-amplicon/issues)
- Search existing issues before creating new ones
- Use the appropriate issue template
- Provide as much detail as possible

### Suggesting Enhancements

- Use the [GitHub issue tracker](https://github.com/nf-core/umi-amplicon/issues)
- Use the "Feature Request" template
- Describe the enhancement clearly
- Explain why it would be useful

### Submitting Changes

1. Create a new branch for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes following the [Development Guidelines](#development-guidelines)

3. Test your changes thoroughly

4. Commit your changes:
   ```bash
   git add .
   git commit -m "Add your commit message"
   ```

5. Push your changes:
   ```bash
   git push origin feature/your-feature-name
   ```

6. Create a Pull Request on GitHub

## Development Guidelines

### Code Style

- Follow Nextflow best practices
- Use meaningful variable names
- Add comments for complex logic
- Follow the existing code style

### Module Development

- Use the nf-core module template
- Include proper documentation
- Add appropriate resource requirements
- Include version information

### Subworkflow Development

- Keep subworkflows focused and modular
- Use clear input/output definitions
- Include proper error handling
- Add comprehensive documentation

## Testing

### Local Testing

1. Test with the minimal test dataset:
   ```bash
   nextflow run . -profile test,docker
   ```

2. Test with the full test dataset:
   ```bash
   nextflow run . -profile test_full,docker
   ```

### Continuous Integration

- All changes are automatically tested via GitHub Actions
- Tests run on multiple Nextflow versions
- Tests run with different container engines

### Test Data

- Use the nf-core test datasets
- Ensure test data is representative
- Keep test data minimal but comprehensive

## Documentation

### Code Documentation

- Add docstrings to all functions
- Include parameter descriptions
- Add usage examples
- Document any assumptions

### User Documentation

- Update README.md for user-facing changes
- Update docs/usage.md for new parameters
- Update docs/output.md for new outputs
- Add examples for new features

### API Documentation

- Document all public functions
- Include parameter types
- Add return value descriptions
- Provide usage examples

## Release Process

### Version Bumping

- Follow [Semantic Versioning](https://semver.org/)
- Update version in nextflow.config
- Update CHANGELOG.md
- Create a GitHub release

### Release Checklist

- [ ] All tests pass
- [ ] Documentation is updated
- [ ] CHANGELOG.md is updated
- [ ] Version is bumped
- [ ] Release notes are written

## Getting Help

- Join the [nf-core Slack](https://nfcore.slack.com/)
- Use the `#umi-amplicon` channel
- Check the [documentation](https://nf-co.re/umi-amplicon)
- Open an issue for bugs or questions

## Recognition

Contributors will be recognized in:
- CHANGELOG.md
- README.md
- GitHub contributors page
- Release notes

Thank you for contributing to nf-core/umi-amplicon!
