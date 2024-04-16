/*
This source file is adapted from the taxon-abundance nextflow pipeline developed by
Dan Fornika as a work of the BC Center for Disease Control Public Health Laboratory,
which was distributed as a work within the public domain under the
Apache Software License version 2.0.

This source file has been adapted to work within our pipeline.

Please refer to the README for more information.
*/
process ADJUST_BRACKEN {
    tag "$meta.id"
    label 'process_single'

    conda "conda-forge::python=3.8.3"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.8.3' :
        'biocontainers/python:3.8.3' }"

    input:
    tuple val(meta), path(report_txt)
    tuple val(meta), path(bracken_reports)
    tuple val(meta), path(bracken_output_tsv)
    tuple val(meta), path(header_csv)
    val(taxonomic_level)

    output:
    tuple val(meta), path("*_bracken_abundances.csv"),  emit: abundances
    tuple val(meta), path("*_adjusted_report.txt"),     emit: adjusted_report
    path "versions.yml",                                emit: versions

    when:
    task.ext.when == null || task.ext.when

    script: // The python script is bundled with the pipeline, in phac-nml/speciesabundance/bin/
    def args = task.ext.args ?: ""
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    adjust_bracken_percentages_for_unclassified_reads.py \\
        -k ${report_txt} \\
        -b ${bracken_reports} \\
        -a ${bracken_output_tsv} \\
        --adjusted-abundances ${meta.id}_${taxonomic_level}_bracken_abundances_unsorted_with_unclassified.csv \\
        --adjusted-report ${meta.id}_${taxonomic_level}_adjusted_report.txt

    # sort the results (including unclassified reads) in descending order and replace the file header with header_csv generated from the BRACKEN module

    tail -n+2 ${meta.id}_${taxonomic_level}_bracken_abundances_unsorted_with_unclassified.csv | \\
        sort -t ',' -nrk 7,7 | \\
        awk -F ',' 'BEGIN {OFS=FS}; {print "${meta.id}",\$0}' > ${meta.id}_${taxonomic_level}_bracken_abundances_data.csv

    cat ${header_csv} ${meta.id}_${taxonomic_level}_bracken_abundances_data.csv > ${meta.id}_${taxonomic_level}_bracken_abundances.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
