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

include { INPUT_CHECK      } from '../subworkflows/local/input_check'

//
// MODULES: Locally developed modules
//

include { FASTP_TRIM       } from '../modules/local/fastptrim/main'
include { KRAKEN2          } from '../modules/local/kraken2/main'
include { BRACKEN          } from '../modules/local/bracken/main'
include { FAILURE_CHECK    } from '../modules/local/failurecheck/main'
include { ADJUST_BRACKEN   } from '../modules/local/adjustbracken/main'
include { TOP_N            } from '../modules/local/topN/main'
include { BRACKEN2KRONA    } from '../modules/local/bracken2krona/main'
include { KRONA            } from '../modules/local/krona/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { CSVTK_CONCAT                } from '../modules/nf-core/csvtk/concat/main.nf'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow SpAnce {

    ch_versions = Channel.empty()

    // Track processed IDs
    def processedIDs = [] as Set

    // Create a new channel of metadata from a sample sheet
    // NB: `input` corresponds to `params.input` and associated sample sheet schema
    input = Channel.fromSamplesheet("input")
        .map { meta, fastq_1, fastq_2 ->
            // Replace spaces in 'id' with underscores
            if (meta.id) {
                meta.id = meta.id.replaceAll(/\s+/, '_')
            }
            // Ensure ID is unique by appending meta.irida_id if needed
            while (processedIDs.contains(meta.id)) {
                meta.id = "${meta.id}_${meta.irida_id}"
            }
            // Add the ID to the set of processed IDs
            processedIDs << meta.id
            // Return the adjusted tuple
            return [meta, fastq_1, fastq_2]
        }
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

    kraken_database = select_kraken_database(params.database, params.kraken2_db)
    bracken_database = select_bracken_database(params.database, params.bracken_db)

    // Create channels for single value parameters
    ch_taxonomic_level = Channel.value(params.taxonomic_level)
    ch_top_n = Channel.value(params.top_n)
    ch_kmer_len = Channel.value(params.kmer_len)

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
        ch_taxonomic_level,
        ch_kmer_len
    )
    ch_versions = ch_versions.mix(BRACKEN.out.versions)

    // Error Reporting: Create channel with sample IDs (meta) to report any errors that occured in pipeline

    samples = input.map { tuple -> tuple[0] }

    // Checks for null entires from all samples from the samplesheet.csv after processes; adjusts for single or multiple sample entries
    fastp_check = samples.join(FASTP_TRIM.out.reads, remainder: true)
                                .map { tuple ->
                                    if (tuple[1] == null) {
                                        [tuple, null]
                                    } else {
                                        tuple
                                    }
                                }
    fastp_fail = fastp_check.filter { it[1] == null }.toList()

    kraken_check = samples.join(KRAKEN2.out.report_txt, remainder: true)
                                .map { tuple ->
                                    if (tuple[1] == null) {
                                        [tuple, null]
                                    } else {
                                        tuple
                                    }
                                }
    kraken_fail = kraken_check.filter { it[1] == null }.toList()

    bracken_check = samples.join(BRACKEN.out.bracken_reports, remainder: true)
                                .map { tuple ->
                                    if (tuple[1] == null) {
                                        [tuple, null]
                                    } else {
                                        tuple
                                    }
                                }
    bracken_fail = bracken_check.filter { it[1] == null }.toList()

    FAILURE_CHECK (
        fastp_fail,
        kraken_fail,
        bracken_fail
    )

    // Continue with pipeline to adjust for unclassified reads and re-estimated total reads

    ADJUST_BRACKEN (
        KRAKEN2.out.report_txt,
        BRACKEN.out.bracken_reports,
        BRACKEN.out.bracken_output_tsv,
        BRACKEN.out.header_csv,
        ch_taxonomic_level
    )
    ch_versions = ch_versions.mix(ADJUST_BRACKEN.out.versions)

    TOP_N (
        ADJUST_BRACKEN.out.abundances,
        ch_taxonomic_level,
        ch_top_n
    )
    ch_versions = ch_versions.mix(TOP_N.out.versions)

    csv_files = TOP_N.out.topN
    ch_csvs = csv_files.map{
        meta, topN -> topN
        }.collect().map{
            topN -> [ [id:"merged_topN", irida_id: "sample"], topN]
        }

    CSVTK_CONCAT (
        ch_csvs,
        "csv",
        "csv"
    )
    ch_versions = ch_versions.mix(CSVTK_CONCAT.out.versions)

    BRACKEN2KRONA (
        ADJUST_BRACKEN.out.adjusted_report
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
    SELECT databases: Create channels of COMBINED, KRAKEN2, and BRACKEN DATABASES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def select_kraken_database(database, kraken2_db) {
    if (database) {
        kraken_database = Channel.value(file(database))
        log.debug "Selecting Kraken2 databases ${kraken_database} from '--database'."
    }
    else if (kraken2_db) {
        kraken_database = Channel.value(file(kraken2_db))
        log.debug "Selecting Kraken2 database ${kraken_database} from '--kraken2_db'."
    }
    else {
        error("Unable to select a Kraken2 database. Neither '--database' nor '--kraken2_db' were provided")
    }

    return kraken_database
}

def select_bracken_database(database, bracken_db) {

    if (database) {
        bracken_database = Channel.value(file(database))
        log.debug "Selecting Bracken database ${bracken_database} from '--database'."
    }
    else if (bracken_db) {
        bracken_database = Channel.value(file(bracken_db))
        log.debug "Selecting Braken2 database ${bracken_database} from '--bracken_db'."
    }
    else {
        error("Unable to select a Bracken database. Neither '--database' nor '--bracken_db' were provided")
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
