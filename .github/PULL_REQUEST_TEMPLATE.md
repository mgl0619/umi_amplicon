## PR checklist

- [ ] This comment contains a description of changes (if not, please submit another pull request).
- [ ] If you've fixed a bug or added code that should be tested, add tests!
- [ ] If you've added a new tool - have you followed the pipeline conventions in the [contribution docs](https://github.com/nf-core/umi-amplicon/tree/master/.github/CONTRIBUTING.md)
- [ ] If necessary, also make a PR to the nf-core/umi-amplicon _branch_ on the [nf-core/test-datasets](https://github.com/nf-core/test-datasets) repository.
- [ ] Make sure your code lints (e.g. `nf-core lint`).
- [ ] Ensure the test suite passes (`nextflow run . -profile test,docker`).
- [ ] Usage documentation in `docs/usage.md` has been updated in the same PR.
- [ ] Output documentation in `docs/output.md` has been updated in the same PR.
- [ ] `CHANGELOG.md` has been updated in the same PR.
- [ ] `README.md` has been updated (if applicable).

## Description

<!--
Write a short description of your changes here.
-->

## Type of change

<!--
Please delete options that are not relevant.
-->

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] This change requires a documentation update

## How Has This Been Tested?

<!--
Please describe the tests that you ran to verify your changes. Provide instructions so we can reproduce. Please also list any relevant details for your test configuration:

- [ ] Test A
- [ ] Test B
-->

## Checklist:

- [ ] My code follows the style guidelines of this project
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
