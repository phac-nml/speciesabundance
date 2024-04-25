process FAILURE_CHECK {
    tag "failure_check"
    label 'process_low'

    input:
    val fastp_fail
    val kraken_fail
    val bracken_fail

    output:
    path("failures_report.csv"), emit: failures_report

    exec:
    def processedIDs = [:]
    def writer = task.workDir.resolve("failures_report.csv").newWriter()
    // write header to the file
    writer.writeLine("sample,module,error_message")

    // Process FASTP_TRIM
    if (fastp_fail.size() > 0) {
        fastp_fail.each {
            def id = it[0].id
            if (!processedIDs.containsKey(id)) {
                writer.writeLine("$id,FASTP,The input FASTQ file(s) might exhibit either a mismatch in PAIRED files; corruption in one or both SINGLE/PAIRED file(s); or do not exist in provided PATH")
                processedIDs[id] = true
            }
        }
    }
    // Process KRAKEN2
    if (kraken_fail.size() > 0) {
        kraken_fail.each {
            def id = it[0].id
            if (!processedIDs.containsKey(id)) {
                writer.writeLine("$id,KRAKEN2,The reads may not have passed the quality control and trimming process")
                processedIDs[id] = true
            }
        }
    }
    // Process BRACKEN
    if (bracken_fail.size() > 0) {
        bracken_fail.each {
            def id = it[0].id
            if (!processedIDs.containsKey(id)) {
                writer.writeLine("$id,BRACKEN,The reads may have failed to classify against the selected Kraken2 database OR the database directory may be missing the Bracken distribution files")
                processedIDs[id] = true
            }
        }
    }
    writer.close()
}
