/*
This source file is adapted from the taxon-abundance nextflow pipeline developed by
Dan Fornika as a work of the BC Center for Disease Control Public Health Laboratory,
which was distributed as a work within the public domain under the
Apache Software License version 2.0.

This source file has been adapted to work within our pipeline.

Please refer to the README for more information.
*/
process TOP_5 {
    tag "$meta.id"
    label 'process_single'

    conda "conda-forge::python=3.8.3"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.8.3' :
        'biocontainers/python:3.8.3' }"
    
    input:
    tuple val(meta), path(abundances)
    val (taxonomic_level)

    output:
    tuple val(meta), path("*_top_5.csv"),    emit: top5 
    path "versions.yml",                     emit: versions

    when:
    task.ext.when == null || task.ext.when

    script: // The python script is bundled with the pipeline, in phac-nml/speciesabundance/bin/
    def args = task.ext.args ?: ""
    def prefix = task.ext.prefix ?: "${meta.id}"

    """   
    bracken_top_n_linelist.py \\
    ${abundances} \\
    ${args} \\
    -n 5 \\
    -s ${meta.id} \\
    > ${meta.id}_${taxonomic_level}_top_5.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
