// Trim poor quality reads from fastq input files using Fastp
process FASTP_TRIM {
    tag "$meta.id"
    label 'process_single'
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastp:0.23.4--h5f740d0_0' :
        (params.private_registry ? 'docker.io/biocontainers/fastp:v0.20.1_cv1' : 'biocontainers/fastp:0.23.4--h5f740d0_0')}"
    
    println "${container}"
    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*_trimmed.fastq.gz"),    emit: reads
    tuple val(meta), path("*.fastp.json"),          emit: json
    tuple val(meta), path("*.fastp.html"),          emit: html
    path "versions.yml",                            emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    if(meta.single_end || reads instanceof nextflow.processor.TaskPath) {
        args = args + "-i ${reads[0]} -o ${meta.id}_trimmed.fastq.gz"
    }else{
        args = args + "-i ${reads[0]} -I ${reads[1]} -o ${meta.id}_R1_trimmed.fastq.gz -O ${meta.id}_R2_trimmed.fastq.gz"
    }
    """
    fastp \\
        ${args} \\
        --json ${meta.id}.fastp.json \\
        --html ${meta.id}.fastp.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastp: \$(fastp --version 2>&1 | sed -e "s/fastp //g")
    END_VERSIONS
    """
}
