process FAILURE_CHECK{
    tag "failure_check"
    label 'process_low'

    input:
    val failures

    output:
    path("failures_report.csv"),    emit: failures_report

    exec:
    task.workDir.resolve("failures_report.csv").withWriter { writer ->

        writer.writeLine("sample,error_message") // header

        if (failures.size() > 0) {
            failures.each {writer.writeLine "${it[0].id},The input sample(s) failed to progress through the pipeline"}
        }
    }

}
