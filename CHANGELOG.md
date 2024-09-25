# phac-nml/speciesabundance: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Development

### `Changed`

- Added the ability to include a `sample_name` column in the input samplesheet.csv. Allows for compatibility with IRIDA-Next input configuration [PR24](https://github.com/phac-nml/speciesabundance/pull/24)
  - `sample_name` special characters will be replaced with `"_"`
  - If no `sample_name` is supplied in the column sample will be used
  - To avoid repeat values for `sample_name` all `sample_name` values will be suffixed with the unique `sample` value from the input file

## 2.1.1 - 2024/05/02

### `Changed`

- Enabled checking for existence of database files in JSON Schema to avoid issues with staging non-existent files in Azure.

## 2.1.0 - 2024/05/01

### `Added`

- The ability to handle errors that occur during quality trimming, alignment to selected database, and taxon abundance estimation. These errors will be reported in `failure/failures_report.csv`.

### `Changed`

- Refined the calculations within the 'adjust_bracken_for_unclassified_reads' function to ascertain the proportions of taxonomic abundances relative to the read values adjusted following Bracken's re-estimation of abundances.

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

[2.0.0]: https://github.com/phac-nml/speciesabundance/releases/tag/2.0.0
[2.1.0]: https://github.com/phac-nml/speciesabundance/releases/tag/2.1.0
[2.1.1]: https://github.com/phac-nml/speciesabundance/releases/tag/2.1.1
