process ASSEMBLY_STUB {
    tag "$meta.id"
    label 'process_single'

    container 'docker.io/python:3.9.17'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.assembly.fa.gz"), emit: assembly
    path "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    cat <<-EOF > ${prefix}.assembly.fa
    >${meta.id}-stub-assembly
    ACGTAACCGGTTAAACCCGGGTTTAAAACCCCGGGGTTTTAAAAACCCCCGGGGGTTTTT
    EOF

    gzip -n ${prefix}.assembly.fa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        assemblystub : 0.1.0
    END_VERSIONS
    """
}
