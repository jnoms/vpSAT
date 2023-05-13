#!/usr/bin/env nextflow
nextflow.enable.dsl=2

//============================================================================//
// Set up modules
//============================================================================//
include { mmseqs2 } from './bin/modules/mmseqs2'
include { colabfold } from './bin/modules/colabfold'
include { foldseek } from './bin/modules/foldseek'

//============================================================================//
// Check params
//============================================================================//
if( (params.input_type != "fasta") && (params.input_type != "a3m")) {
  error "params.input_type must be set to 'fasta' or 'a3m'."
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
  colabfold(mmseqs2.out.a3m.filter{ it[1].size() > 0 })

}

workflow colabfold_workflow_a3m_entry {

  take: input_ch
  main:

  // Run Colabfold
  colabfold(input_ch.filter{ it[1].size() > 0 })

}

//============================================================================//
// Define main workflow
//============================================================================//
workflow {

  main:

    if ( params.input_type == "fasta" ) {
      infile_channel = sampleID_set_from_infile(params.in_files)
      reference_channel = Channel.fromPath(params.reference_fasta)

      // Add the reference to each tuple in the infile_channel
      // each tuple is now (ID, input_file, reference_fasta)
      input_ch = infile_channel.combine(reference_channel)
      colabfold_workflow(input_ch)
    }

    else if ( params.input_type == "a3m" ) {
      infile_channel = sampleID_set_from_infile(params.in_files)
      colabfold_workflow_a3m_entry(infile_channel)
    }
    

      

      
}
