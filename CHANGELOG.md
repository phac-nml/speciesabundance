# phac-nml/speciesabundance: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

- Refined the calculations within the 'adjust_brakcen_for_unclassified_reads' function to ascertain the proportions of taxonomic abundances relative to the read values adjusted following Bracken's re-estimation of abundances.

## 2.0.0 - 2024/04/18

### `Added`

- The initial release of phac-nml/speciesabundance as a Nextflow pipeline following [nf-core](https://nf-co.re/) standards.
- This pipeline will estimate the relative abundance of sequence reads originating from different species in a sample from Illumina short-read data.

### `Changed`

- Migrated SpeciesAbundance to a Nextflow pipeline, with integration testing using [nf-test](https://www.nf-test.com/).
- Updated the SpeciesAbundance release version from 1 to 2 to reflect migration from the [Galaxy-based](https://github.com/Public-Health-Bioinformatics/irida-plugin-species-abundance) pipeline.

### `Fixed`

### `Dependencies`

### `Deprecated`
