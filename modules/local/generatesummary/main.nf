process GENERATE_SUMMARY {
    label 'process_single'
    container 'docker.io/python:3.9.17'

    input:
    val summaries

    output:
    path("summary.txt.gz"), emit: summary
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def sorted_summaries = summaries.sort{ it[0].id }

    // Generate summary text:
    def summary_text = "IRIDANEXTEXAMPLE Pipeline Summary\n\nSUCCESS!\n"

    // TODO: Consider the possibility of code injection.
    // Should probably be moved to file processing through Python.
    for (summary in sorted_summaries) {
        summary_text += "\n${summary[0].id}:\n"
        summary_text += "    reads.1: ${summary[1][0]}\n"
        summary_text += "    reads.2: ${summary[1][1]}\n"
        summary_text += "    assembly: ${summary[2]}\n"
    }

    version_text = "\"${task.process}\":\n    generatesummary : 0.1.0"

    """
    echo "${summary_text}" > summary.txt
    gzip -n summary.txt
    echo "${version_text}" > versions.yml
    """
}
