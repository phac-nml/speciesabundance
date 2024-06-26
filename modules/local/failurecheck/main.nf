process FAILURE_CHECK {
    tag "failure_check"
    label 'process_single'

    input:
    val fastp_fail
    val kraken_fail
    val bracken_fail

    output:
    path("failures_report.csv"), emit: failures_report

    exec:
    def processedIDs = [] as Set

    task.workDir.resolve("failures_report.csv").withWriter { writer ->

        // write header to the file
        writer.writeLine("sample,module,error_message")

        // Process FASTP_TRIM
        if (fastp_fail.size() > 0) {
            fastp_fail.each {
                def id = it[0].id
                if (!(id instanceof List)) {
                    id =[id]
                }
                id.each { currentId ->
                    if (!(currentId in processedIDs)) {
                        writer.writeLine("$currentId,FASTP,The input FASTQ file(s) might exhibit either a mismatch in PAIRED files; corruption in one or both SINGLE/PAIRED file(s); or file(s) may not exist in PATH provided by input samplesheet")
                        processedIDs.add(currentId)
                    }
                }
            }
        }

        // Process KRAKEN2
        if (kraken_fail.size() > 0) {
            kraken_fail.each {
                def id = it[0].id
                if (!(id instanceof List)) {
                    id = [id]
                }
                id.each { currentId ->
                    if (!(currentId in processedIDs)) {
                        writer.writeLine("$currentId,KRAKEN2,The reads may not have passed the quality control and trimming process OR the database directory may be missing required KRAKEN2 files")
                        processedIDs.add(currentId)
                    }
                }
            }
        }

        // Process BRACKEN
        if (bracken_fail.size() > 0) {
            bracken_fail.each {
                def id = it[0].id
                if (!(id instanceof List)) {
                    id = [id]
                }
                id.each { currentId ->
                    if (!(currentId in processedIDs)) {
                        writer.writeLine("$currentId,BRACKEN,The reads may have failed to classify against the selected Kraken2 database OR the database directory may be missing the Bracken distribution files")
                        processedIDs.add(currentId)
                    }
                }
            }
        }

        // If no samples fail pipeline execution:
        if (fastp_fail.isEmpty() && kraken_fail.isEmpty() && bracken_fail.isEmpty()) {
            writer.writeLine(",,No samples failed pipeline execution")
        }
    }
}
