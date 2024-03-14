process KRAKEN2 {
    tag "$meta.id"
    label 'process_medium'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-5799ab18b5fc681e75923b2450abaa969907ec98:87fc08d11968d081f3e8a37131c1f1f6715b6542-0' :
        'biocontainers/mulled-v2-5799ab18b5fc681e75923b2450abaa969907ec98:87fc08d11968d081f3e8a37131c1f1f6715b6542-0' }"

    input:
    tuple val(meta), path(reads)
    path(kraken2_db)

    output:
    tuple val(meta), path("*_kraken2_output.tsv.gz"),   emit: output_tsv
    tuple val(meta), path("*_kraken2_report.txt.gz"),      emit: report_txt
    path "versions.yml",                                emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def paired = meta.single_end ? "" : "--paired"

    """
    kraken2 \\
        --db ${kraken2_db} \\
        --threads $task.cpus \\
        --output ${meta.id}_kraken2_output.tsv \\
        --report ${meta.id}_kraken2_report.txt \\
        --gzip-compressed \\
        $paired \\
        $args \\
        $reads

    gzip ${meta.id}_kraken2_output.tsv
    gzip ${meta.id}_kraken2_report.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kraken2: \$(echo \$(kraken2 --version 2>&1) | sed 's/^.*Kraken version //; s/ .*\$//')
    END_VERSIONS
    """
}
