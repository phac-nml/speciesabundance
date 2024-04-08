process MERGE_CSV {
    label "process_low"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/coreutils%3A8.31--h14c3975_0' :
        'biocontainers/coreutils:8.31--h14c3975_0' }"

    input:
    path(top5)

    output:
    path "merged_top5.csv",     emit: merged_top5
    path "versions.yml",        emit: versions

    //Merge CSV files, preserving the meta.ids and append content from all files
    script:
    def args = task.ext.args ?: ""

    """
    head -q -n 1 ${top5[0]} | sed '1!d' > merged_top5.csv
    tail -q -n +2 ${top5.join(' ')} >> merged_top5.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        head: \$(echo \$(head --version 2>&1) | sed 's/^.*coreutils) //; s/ .*\$//')
        tail: \$(echo \$(tail --version 2>&1) | sed 's/^.*coreutils) //; s/ .*\$//')
    END_VERSIONS
    """
}
