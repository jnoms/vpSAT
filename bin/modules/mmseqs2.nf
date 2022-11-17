//============================================================================//
// Default params
//============================================================================//
params.out_dir = "output"
params.reference_fasta = ""

//============================================================================//
// Define process
//============================================================================//
process mmseqs2 {

  tag "$sampleID"
  publishDir "$params.out_dir/mmseqs2", mode: "copy"

  input:
  tuple val(sampleID), file(in_fasta), file(reference_fasta)

  output:
  tuple val(sampleID),
    file("${sampleID}.a3m"),
    emit: a3m

  script:
  """
  mmseqs.sh \
  -q ${in_fasta} \
  -s ${reference_fasta} \
  -o ${sampleID}.a3m \
  -n ${sampleID} \
  -t ${task.cpus}
  """
}