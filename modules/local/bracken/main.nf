process BRACKEN {
    tag "$meta.id"
    label 'process_medium'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bracken:2.7--py39hc16433a_0':
        'biocontainers/bracken:2.7--py39hc16433a_0' }"

    input:
    tuple val(meta), path(report_txt)
    path(bracken_db)
    val(taxonomic_level)

    output:
    tuple val(meta), path("*_bracken.txt"),                     emit: bracken_reports
    tuple val(meta), path("*_bracken_abundances_unsorted.tsv"), emit: bracken_output_tsv
    tuple val(meta), path("bracken_abundances_header.csv"),     emit: header_csv
    path "versions.yml",                                        emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ""
    def prefix = task.ext.prefix ?: "${meta.id}"
    // WARN: Version information not provided by tool on CLI. Update version string below when bumping container versions.
    def VERSION = '2.7'

    """
    bracken \\
        ${args} \\
        -d ${bracken_db} \\
        -t $task.cpus \\
        -i ${report_txt} \\
        -w ${meta.id}_${taxonomic_level}_bracken.txt \\
        -o ${meta.id}_${taxonomic_level}_bracken_abundances_unsorted.tsv \\
        -l ${taxonomic_level}

    paste <(echo "meta.id") <(head -n 1 ${meta.id}_${taxonomic_level}_bracken_abundances_unsorted.tsv) | tr \$'\\t' ',' > bracken_abundances_header.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bracken: ${VERSION}
    END_VERSIONS
    """
}

