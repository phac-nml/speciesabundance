/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PRINT PARAMS SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryLog; paramsSummaryMap; fromSamplesheet  } from 'plugin/nf-validation'

def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
def summary_params = paramsSummaryMap(workflow)

// Print parameter summary log to screen
log.info logo + paramsSummaryLog(workflow) + citation

WorkflowSpeciesabundance.initialise(params, log)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK     } from '../subworkflows/local/input_check'
include { FASTP_TRIM      } from '../modules/local/fastptrim/main'
include { KRAKEN2         } from '../modules/local/kraken2/main'
include { BRACKEN         } from '../modules/local/bracken/main'
include { ADJUST_BRACKEN  } from '../modules/local/adjustbracken/main'
include { BRACKEN2KRONA   } from "../modules/local/bracken2krona/main"
include { KRONA           } from "../modules/local/krona/main"

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow SpAnce {

    ch_versions = Channel.empty()

    // Create a new channel of metadata from a sample sheet
    // NB: `input` corresponds to `params.input` and associated sample sheet schema
    input = Channel.fromSamplesheet("input")
        // Map the inputs so that they conform to the nf-core-expected "reads" format.
        // Either [meta, [fastq_1]] or [meta, [fastq_1, fastq_2]] if fastq_2 exists
        .map { meta, fastq_1, fastq_2 ->
                if (fastq_2) {
                    meta.single_end = false
                    tuple(meta, [ file(fastq_1), file(fastq_2) ])
                } else {
                    meta.single_end = true
                    tuple(meta, [ file(fastq_1) ])
                }
        }

    ch_kraken2_db = Channel.value(file("${params.kraken2_db}"))
    ch_bracken_db = Channel.value(file("${params.bracken_db}"))
    ch_taxonomic_level = Channel.value(params.taxonomic_level)

    FASTP_TRIM (
        input
    )
    ch_versions = ch_versions.mix(FASTP_TRIM.out.versions)

    KRAKEN2 (
        FASTP_TRIM.out.reads,
        ch_kraken2_db
    )
    ch_versions = ch_versions.mix(KRAKEN2.out.versions)

    BRACKEN (
        KRAKEN2.out.report_txt,
        ch_bracken_db,
        ch_taxonomic_level
    )
    ch_versions = ch_versions.mix(BRACKEN.out.versions)

    ADJUST_BRACKEN (
        KRAKEN2.out.report_txt,
        BRACKEN.out.bracken_reports,
        BRACKEN.out.bracken_output_tsv,
        BRACKEN.out.header_csv,
        ch_taxonomic_level
    )
    ch_versions = ch_versions.mix(BRACKEN.out.versions)

    BRACKEN2KRONA (
        KRAKEN2.out.report_txt
    )
    ch_versions = ch_versions.mix(BRACKEN2KRONA.out.versions)

    KRONA (
        BRACKEN2KRONA.out.krona_txt
    )
    ch_versions = ch_versions.mix(KRONA.out.versions)

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log)
    }
    NfcoreTemplate.dump_parameters(workflow, params)
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
