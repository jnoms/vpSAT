//============================================================================//
// Default params
//============================================================================//
params.out_dir = "output"
params.reference_fasta = ""
params.COLABFOLD_num_recycles = 3

//============================================================================//
// Define process
//============================================================================//
process colabfold {

  tag "$sampleID"
  publishDir "$params.out_dir/colabfold", mode: "copy"

  input:
  tuple val(sampleID), file(in_a3m)

  output:
  tuple val(sampleID),
    file("${sampleID}.pdb"),
    emit: structure

  tuple val(sampleID),
    file("colabfold_output_dir/*"),
    emit: colabfold_dir

  script:
  """
  $workflow.projectDir/bin/bash/colabfold.sh \
  -i ${in_a3m} \
  -d colabfold_output_dir \
  -o ${sampleID}.pdb \
  -n ${params.COLABFOLD_num_recycles}
  """
}