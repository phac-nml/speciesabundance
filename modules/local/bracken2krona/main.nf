process BRACKEN2KRONA {
    tag "$meta.id"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/krakentools:1.2--pyh5e36f6f_0':
        'biocontainers/krakentools:1.2--pyh5e36f6f_0' }"

    input:
    tuple val(meta), path(adjusted_report)

    output:
    tuple val(meta), path("*.txt"), emit: krona_txt
    path "versions.yml",            emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    // Version information not provided by tool on CLI. Please update this string when bumping container versions.
    def VERSION = '1.2'

    """
    kreport2krona.py \\
        $args \\
        -r ${adjusted_report} \\
        -o ${prefix}.txt \\
        --intermediate-ranks

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kreport2krona.py: ${VERSION}
    END_VERSIONS
    """
}
