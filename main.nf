#!/usr/bin/env nextflow
nextflow.enable.dsl=2

//============================================================================//
// Set up modules
//============================================================================//
include { mmseqs2 } from './bin/modules/mmseqs2'



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

//   // Map using minimap
//   if (params.aligner == "Minimap2")
//     aligned = Minimap2(input_ch)
//   else if (params.aligner == "STAR")
//     error "For Nanopore reads, MUST use Minimap2 aligner."

//   // Slide the bed
//   slide_bed(aligned.bed)

//   // Generate spans
//   bed_to_span_NANOPORE(slide_bed.out.slid_bed)

//   // Calculate coverage
//   bam_coverage(aligned.bam)

//   // ------------------------------------------------------------ //
//   // ORF ANALYSIS
//   // ------------------------------------------------------------ //

//   // Predict ORFs with prodigal
//   prodigal(aligned.fasta)

//   // Extract ORFs
//   aligned.fasta
//     .join(prodigal.out.prodigal_out) |\
//     prodigal_to_orfs_direct

//   // Align with diamond
//   prodigal_to_orfs_direct.out.pr_orfs |\
//     diamond

//   // Generate ORF report
//   diamond.out.diamond_out
//     .join(slide_bed.out.slid_bed)
//     .join(bed_to_span_NANOPORE.out.spans) |\
//     characterize_ORFs
}

//============================================================================//
// Define main workflow
//============================================================================//
workflow {

  main:
    input_ch = sampleID_set_from_infile(params.in_fasta)

    colabfold_workflow(input_ch)
}