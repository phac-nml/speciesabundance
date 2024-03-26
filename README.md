[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A523.04.3-brightgreen.svg)](https://www.nextflow.io/)

# SpeciesAbundance Pipeline

This is the in-development nf-core-based pipeline for SpeciesAbundance.

# Input

The input to the pipeline is a standard sample sheet (passed as `--input samplesheet.csv`) that looks like:

| sample  | fastq_1         | fastq_2         |
| ------- | --------------- | --------------- |
| SampleA | file_1.fastq.gz | file_2.fastq.gz |

The structure of this file is defined in [assets/schema_input.json](assets/schema_input.json). Validation of the sample sheet is performed by [nf-validation](https://nextflow-io.github.io/nf-validation/).

# Parameters

## Mandatory

The mandatory parameters are as follows:

- `--input` : a URI to the samplesheet as specified in the [Input](#input) section.
- `--output` : to specify the output results directory.
- `--kraken2_db /path/to/kraken2database` : to specify the directory to the Kraken2 database
- `--bracken_db /path/to/brackendatabase` : to specify the directory to the Bracken database

## Optional

Additionally, you may wish to provide:

- `-profile` : to specify which profile to use (ex: `-profile singularity`)
- `-r [branch]` : to specify which GitHub branch you would like to use
- `-taxonomic_level` : to specify the taxonomic level of the bracken abundance estimation.
  - Must be one of 'S'(species)(default), 'G'(genus), 'O'(order), 'F'(family), 'P'(phylum), or 'K'(kingdom)

Other parameters (defaults from nf-core) are defined in [nextflow_schema.json](nextflow_schmea.json).

# Running

## Test Data

To run the pipeline, please run:

```bash
nextflow run phac-nml/speciesabundance -profile singularity -r dev -latest --input /path/to/samplesheet.csv --kraken2_db /path/to/kraken2_db -- bracken_db /path/to/bracken_db --outdir results
```

The pipeline output will be written to a directory named `results`. A JSON file for integrating with IRIDA Next will be written to `results/iridanext.output.json.gz` (as detailed in the [Output](#output) section)

To run the pipeline using the test profile, please run:

```bash
nextflow run phac-nml/speciesabundance -profile docker,test -r dev -latest --outdir results
```

# Output

A JSON file for loading metadata into IRIDA Next is output by this pipeline. The format of this JSON file is specified in our [Pipeline Standards for the IRIDA Next JSON](https://github.com/phac-nml/pipeline-standards#32-irida-next-json). This JSON file is written directly within the `--outdir` provided to the pipeline with the name `iridanext.output.json.gz` (ex: `[outdir]/iridanext.output.json.gz`).

(In-development) An example of the what the contents of the IRIDA Next JSON file looks like for this particular pipeline is as follows:

```
{
    "files": {
        "global": [

        ],
        "samples": {
            "SAMPLE1": [
                {
                    "path": "adjust/SAMPLE1_S_bracken_abundances.csv"
                },
                {
                    "path": "krona/SAMPLE1.html"
                },
                {
                    "path": "fastp/SAMPLE1.html"
                },
                {
                    "path": "fastp/SAMPLE1_R2_trimmed.fastq.gz"
                },
                {
                    "path": "fastp/SAMPLE1_R1_trimmed.fastq.gz"
                }
            ]
        }
    },
    "metadata": {
        "samples": {

        }
    }
}
```

Within the `files` section of this JSON file, all of the output paths are relative to the `outdir`. Therefore, `"path": "adjust/SAMPLE1_S_bracken_abundances.csv"` refers to a file located within `outdir/adjust/SAMPLE1_S_bracken_abundances.csv`.

# Legal

Copyright 2023 Government of Canada

Licensed under the MIT License (the "License"); you may not use
this work except in compliance with the License. You may obtain a copy of the
License at:

https://opensource.org/license/mit/

Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied. See the License for the
specific language governing permissions and limitations under the License.

## Derivative Work

This pipeline includes source code from a [nextflow pipeline for taxon-abundance](https://github.com/BCCDC-PHL/taxon-abundance) and an [IRIDA-plugin for SpeciesAbundance](https://github.com/Public-Health-Bioinformatics/irida-plugin-species-abundance) developed by Dan Fornika as a work of the BC Center for Disease Control Public Health Laboratory (BCCDC_PHL).

The included source code developed by Dan Fornika as a work of the BCCDC-PHL was distributed within the public domain under the [Apache Software License version 2.0](https://www.apache.org/licenses/LICENSE-2.0).

Any such source files in this project that are included from or derived from the original work by Dan Fornika will include a notice.
