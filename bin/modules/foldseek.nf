//============================================================================//
// Default params
//============================================================================//
params.out_dir = "output"
params.foldseek_database = ""
params.foldseek_fields = "query,target,fident,alnlen,mismatch,gapopen,qstart,qend,tstart,tend,evalue,bits"
params.foldseek_evalue = 0.001

//============================================================================//
// Define process
//============================================================================//
process foldseek {

  tag "$sampleID"
  publishDir "$params.out_dir/foldseek", mode: "copy"

  input:
  tuple val(sampleID), file(in_pdb)

  output:
  tuple val(sampleID),
    file("${sampleID}.m8"),
    emit: tabular_result

  tuple val(sampleID),
    file("${sampleID}.html"),
    emit: html_result


  script:
  """
  $workflow.projectDir/bin/bash/foldseek.sh \
  -i ${in_pdb} \
  -o ${sampleID}.m8 \
  -d ${params.foldseek_database} \
  -f "${params.foldseek_fields}" \
  -t ${task.cpus} \
  -e ${params.foldseek_evalue} \
  -H ${sampleID}.html 

  """
}