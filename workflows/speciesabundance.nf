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
include { TOP_5           } from "../modules/local/top5/main"
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

    kraken_database = select_kraken_database(params.kraken2_db)
    bracken_database = select_bracken_database(params.bracken_db)
    ch_taxonomic_level = Channel.value(params.taxonomic_level)

    FASTP_TRIM (
        input
    )
    ch_versions = ch_versions.mix(FASTP_TRIM.out.versions)

    KRAKEN2 (
        FASTP_TRIM.out.reads,
        kraken_database
    )
    ch_versions = ch_versions.mix(KRAKEN2.out.versions)

    BRACKEN (
        KRAKEN2.out.report_txt,
        bracken_database,
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
    ch_versions = ch_versions.mix(ADJUST_BRACKEN.out.versions)

    TOP_5 (
        ADJUST_BRACKEN.out.abundances,
        ch_taxonomic_level
    )

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
    SELECT KRAKEN2 and BRACKEN DATABASES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def select_kraken_database(kraken2_db) {

    if(kraken2_db) {
        kraken_database = Channel.value(file(kraken2_db))
        log.debug "Selecting kraken2 database ${kraken_database} from '--kraken2_db'."
    }
    else {
        error("Unable to select a kraken2 database: '--kraken2_db' was not provided")
    }

    return kraken_database
}

def select_bracken_database(bracken_db) {

    if(bracken_db) {
        bracken_database = Channel.value(file(bracken_db))
        log.debug "Selecting bracken database ${bracken_database} from '--bracken_db'."
    }
    else {
        error("Unable to select a bracken database: '--bracken_db' was not provided")
    }

    return bracken_database
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
