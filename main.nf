#!/usr/bin/env nextflow
nextflow.enable.dsl=2

//============================================================================//
// Set up modules
//============================================================================//
include { mmseqs2 } from './bin/modules/mmseqs2'
include { colabfold } from './bin/modules/colabfold'

//============================================================================//
// Validate inputs
//============================================================================//
if( (params.workflow != "colabfold") && (params.workflow != "foldseek")) {
  error "params.workflow must be set to 'colabfold' or 'foldseek'."
}

//============================================================================//
// Defining functions
//============================================================================//
def sampleID_set_from_infile(input) {
  // The purpose of this function is to take an input list of file paths and
  // to return a channel of sets of structure basename:file_path.
  sample_set = []
  for (String item : file(input)) {
    file = file(item)
    name = file.baseName

    // This will handle .fastq.gz and .fq.gz... baseName above only removes
    // the last suffix.
    if (name.endsWith(".fastq") | name.endsWith(".fq") )
      name = name.take(name.lastIndexOf('.'))

    sample_set.add([name, file])
  }
  ch = Channel.from(tuple(sample_set))
  return ch
}

//============================================================================//
// Define workflows
//============================================================================//
workflow colabfold_workflow {

  take: input_ch
  main:

  // Align via mmseqs2 and generate an a3m MSA file.
  mmseqs2(input_ch)

  // Run Colabfold
  colabfold(mmseqs2.out.a3m)

}

workflow foldseek_workflow {
  take: input_ch
  main:

  // Run foldseek of each query against the input database
  foldseek(input_ch)

}

//============================================================================//
// Define main workflow
//============================================================================//
workflow {

  main:
    input_ch = sampleID_set_from_infile(params.in_files)

    if ( params.workflow == "colabfold" )
      colabfold_workflow(input_ch)
    else if ( params.in_fastq_type == "foldseek" )
      foldseek_workflow(input_ch)
}