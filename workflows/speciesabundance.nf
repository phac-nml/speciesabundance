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
include { INPUT_CHECK          } from '../subworkflows/local/input_check'
include { GENERATE_SAMPLE_JSON } from '../modules/local/generatesamplejson/main'
include { SIMPLIFY_IRIDA_JSON  } from '../modules/local/simplifyiridajson/main'
include { IRIDA_NEXT_OUTPUT    } from '../modules/local/iridanextoutput/main'
include { ASSEMBLY_STUB        } from '../modules/local/assemblystub/main'
include { GENERATE_SUMMARY     } from '../modules/local/generatesummary/main'
include { FASTP_TRIM           } from '../modules/local/fastptrim/main'
include { KRAKEN2              } from '../modules/local/kraken2/main'

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

    ch_kraken2_db = Channel.fromPath( "${params.kraken2_db}", type: 'dir')

    FASTP_TRIM (
        input
    )
    ch_versions = ch_versions.mix(FASTP_TRIM.out.versions)

    KRAKEN2 (
        FASTP_TRIM.out.reads.combine(ch_kraken2_db)
    )
    ch_versions = ch_versions.mix(KRAKEN2.out.versions)

    ASSEMBLY_STUB (
        input
    )
    ch_versions = ch_versions.mix(ASSEMBLY_STUB.out.versions)

    // A channel of tuples of ({meta}, [read[0], read[1]], assembly)
    ch_tuple_read_assembly = input.join(ASSEMBLY_STUB.out.assembly)

    GENERATE_SAMPLE_JSON (
        ch_tuple_read_assembly
    )
    ch_versions = ch_versions.mix(GENERATE_SAMPLE_JSON.out.versions)

    GENERATE_SUMMARY (
        ch_tuple_read_assembly.collect{ [it] }
    )
    ch_versions = ch_versions.mix(GENERATE_SUMMARY.out.versions)

    SIMPLIFY_IRIDA_JSON (
        GENERATE_SAMPLE_JSON.out.json
    )
    ch_versions = ch_versions.mix(SIMPLIFY_IRIDA_JSON.out.versions)
    ch_simplified_jsons = SIMPLIFY_IRIDA_JSON.out.simple_json.map { meta, data -> data }.collect() // Collect JSONs

    IRIDA_NEXT_OUTPUT (
        samples_data=ch_simplified_jsons
    )
    ch_versions = ch_versions.mix(IRIDA_NEXT_OUTPUT.out.versions)

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
