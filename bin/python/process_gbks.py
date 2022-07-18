# ---------------------------------------------------------------------------- #
# Packages and function import
# ---------------------------------------------------------------------------- #

from Bio import SeqIO, Seq
from Bio.Seq import Seq
from Bio.SeqRecord import SeqRecord
from ete3 import NCBITaxa
ncbi = NCBITaxa()
import pathlib
import os
import argparse
import re

# ---------------------------------------------------------------------------- #
# Input arguments
# ---------------------------------------------------------------------------- #
def get_args():
    parser = argparse.ArgumentParser(
        description="""
            This script parses genpept files (from NCBI) to yield fasta(s) with
            protein information. This script is useful because 1) it handles
            multiproteins and 2) it reformats sequence headers to a reliable
            format. This script can output fastas into a single output file, 
            separate output files (one file per protein), or separate output
            files in different directories based on viral family. This script
            uses ETE3 to yield taxonID from the genpept species name - this
            usually works, but not always.

            For point 1:
            NCBI often contains a protein entry for both a polyprotein AND its
            constituent mature peptides. Or, sometimes it only contains an 
            entry for the polyprotein. This script identifies polyproteins that 
            have mature_peptide fields. If the mature_peptide fields contain 
            a protein_id feature, it suggests that the mature_peptides are
            present separately in the input. Thus, the polypeptide is skipped.
            If a polyprotein has mature_peptide fields that don't have a
            protein_id feature, the polyprotien is split and the mature_peptides
            are output. 
            
            For point 2:
            The header for each fasta is
            >protein-name__accession__virus-name__taxonID. If the output is
            specified as separate output files, the file names will be
            protein-name__accession__virus-name__taxonID.fasta
            
            
            IMPORTANT ASSUMPTION: In the case there are protein_id 
            features, make sure that the substituent mature peptides are indeed 
            present as separate entires in the input!!
            """
    )

    # Required arguments
    parser.add_argument(
        "-i",
        "--input_genpept_file",
        type=str,
        required=True,
        default="",
        help="""
        Path to the input genpept file.
        """,
    )

    # Outputs - only one is required. Multiple can be entered.
    parser.add_argument(
        "-s",
        "--single_output_file_path",
        type=str,
        required=False,
        default="",
        help="""
        If specified, all sequences are written to a file at this path.
        """,
    )
    parser.add_argument(
        "-m",
        "--multiple_file_output_dir_base",
        type=str,
        required=False,
        default="",
        help="""
        IF specified, all sequences are written to separate files, one per 
        sequence. This is the path to the directory in which all files will
        be written.
        """,
    )
    parser.add_argument(
        "-f",
        "--multiple_files_by_family_output_dir_base",
        type=str,
        required=False,
        default="",
        help="""
        If specified, all sequences are written to one file per family. Files
        are sorted into a directory based on their viral family. Structure is
        multiple_files_by_family_output_dir_base/family.fasta
        """,
    )

    args = parser.parse_args()

    # Validate inputs
    if (args.single_output_file_path == "" and
        args.multiple_file_output_dir_base == "" and
        args.multiple_files_by_family_output_dir_base == ""
    ):
        msg = "At least one of multiple_file_output_dir_base, "
        msg += "multiple_file_output_dir_base, or "
        msg += "multiple_files_by_family_output_dir_base must be input!"
        raise ValueError(msg)

    # Deal with formatting the dirnames if not followed by /
    if not args.multiple_file_output_dir_base.endswith("/"):
        args.multiple_file_output_dir_base += "/"
    if not args.multiple_files_by_family_output_dir_base.endswith("/"):
        args.multiple_files_by_family_output_dir_base += "/"

    return args

# ---------------------------------------------------------------------------- #
# ETE3 functions and constants
# ---------------------------------------------------------------------------- #
prefix_dictionary = {
    'superkingdom': 'sk__',
    'kingdom': 'k__',
    'phylum': 'p__',
    'class': 'c__',
    'order': 'o__',
    'family': 'f__',
    'genus': 'g__',
    'species': 's__',
    'strain': 'st__'
    }


def name_to_taxID(name):
    """
    Given name, returns taxonID. If the name taxonID can't be found,
    will try to strip any following numbers from the name. Otherwise,
    will return X.
    """
    try:
        return ncbi.get_name_translator([name])[name][0]
    except:
        # Try to repair by stripping any numbers from the end of the name
        name = name.rstrip('0123456789').rstrip(" ")
        try:
            return ncbi.get_name_translator([name])[name][0]
        except:
            return "X"

def get_level(taxonID):
    level = list(ncbi.get_rank([taxonID]).values())

    #Unknown taxonID would yield [], which can't be indexed by [0] to get the string
    if level == []:
        level = "UNKNOWN"
    else:
        level = level[0]
    return level

def get_name(taxonID):
    name = list(ncbi.get_taxid_translator([taxonID]).values())

    #Unknown taxonID would yield [], which can't be indexed by [0] to get the string
    if name == []:
        name = "UNKNOWN"
    else:
        name = name[0]

    name = name.replace(" ", "_")
    return name

def get_lineage(taxonID):
    try:
        lineage = ncbi.get_lineage(taxonID)
    except ValueError:
        print("Cannot find taxonID " + str(taxonID))
        lineage = [taxonID]
    if lineage == None:
        lineage = [0]

    return lineage

def get_cannonical_lineage(taxonID, prefix_dictionary):

    # Get a list of lineage and a list of their ranks
    lineage = get_lineage(taxonID)
    levels = [get_level(taxon) for taxon in lineage]

    cannonical_lineage = []
    # Iterate over each of the levels in prefix dictionary
    for level, prefix in prefix_dictionary.items():


        # If the level isn't here, it is unknown
        if not level in set(levels):
            cannonical_lineage.append(0)
            continue

        # Get the taxon name
        index = levels.index(level)
        taxon = lineage[index]
        name = get_name(taxon)

        # Report it out with the lineage
        cannonical_lineage.append(prefix + name)

    return cannonical_lineage

# ---------------------------------------------------------------------------- #
# Script Functions
# ---------------------------------------------------------------------------- #
def add_family(gb_records):
    gb_records_w_family = gb_records.copy()

    for gb_record in gb_records_w_family:
        
        description = gb_record.description
        name = gb_record.name
        seq = gb_record.seq
        organism = gb_record.annotations["organism"]
        taxonID = name_to_taxID(organism)
        
        # First record taxonID
        gb_record.taxonID = taxonID
        
        # Find lineage and family. Note that family is the name, not taxonID
        lineage = get_cannonical_lineage(taxonID, prefix_dictionary)
        family = [level for level in lineage if str(level).startswith("f__")]
        if family == []:
            gb_record.family = "unknown_family"
        else:
            family = family[0].strip(prefix_dictionary["family"])
            gb_record.family = family

    return gb_records_w_family


def clean_up_gb_records(gb_records):
    cleaned_gb_records = gb_records.copy()

    for gb_record in cleaned_gb_records:
        name = gb_record.name
        seq = gb_record.seq
        description = gb_record.description
        organism = gb_record.annotations["organism"]
        
        # Clean up description - currently also has organism in brackets
        description = description.split("[")[0].rstrip(" ")
        
        # Remove bannded characters from description and organism
        
        # Replace ' with nothing
        description = description.replace("'", "")
        organism = organism.replace("'", "")
        
        # Replace ( and ) with dash
        description = description.replace("(", "-")
        description = description.replace(")", "-")
        organism = organism.replace("(", "-")
        organism = organism.replace(")", "-")
        
        # Replace ^ with dash
        description = description.replace("^", "-")
        organism = organism.replace("^", "-")
        
        # Replace ; with nothing
        description = description.replace(";", "")
        organism = organism.replace(";", "")

        # Replace / with _
        description = description.replace("/", "_")
        name = name.replace("/", "_")
        organism = organism.replace("/", "_")

        # Replace spaces with _. Also handle multiple subsequent spaces
        description = re.sub('\s+', '_', description)
        name = re.sub('\s+', '_', name)
        organism = re.sub('\s+', '_', organism)

        # Make sure each description, name, and organism only has one _ in a row
        description = description.replace("__", "_")
        name = name.replace("__", "_")
        organism = organism.replace("__", "_")
        
        # Save into the gb objects
        gb_record = gb_record
        gb_record.description = description
        gb_record.annotations["organism"] = organism
        gb_record.name = name
    
    return cleaned_gb_records

# Main
def main():
    args = get_args()
    
    # Read in genbank file
    # ------------------------------------------------------------------------ #
    gb_records = []
    for gb_record in SeqIO.parse(open(args.input_genpept_file, "r"), "genbank"):
        gb_records.append(gb_record)

    # Identifiy polyproteins
    # ------------------------------------------------------------------------ #
    gb_records_not_polyproteins = []
    gb_records_polyproteins = []
    for gb_record in gb_records:
        name = gb_record.name
        seq = gb_record.seq
        description = gb_record.description
        organism = gb_record.annotations["organism"]
        
        # Extract features
        features = gb_record.features
        
        # Check for mature peptide features
        mat_peptide_features = [feature for feature in features if feature.type=="mat_peptide"]
        
        # Determien if there are mature peptide features with or without protein_ids
        mat_peptide_features_with_pr_id = []
        mat_peptide_features_without_pr_id = []
        if len(mat_peptide_features) > 0:
            
            # Assumption - mat_peptide_features will either all have a protein_id 
            # or all will not have a protein_id. Need to keep track and raise an
            # error if there is a mix.
            detected_a_protein_id = False
            detected_no_protein_id = False
            
            for mat_peptide_feature in mat_peptide_features:
                protein_id = mat_peptide_feature.qualifiers.get("protein_id", "")
                if protein_id == "":
                    detected_no_protein_id = True
                    mat_peptide_features_without_pr_id.append(mat_peptide_feature)
                else:
                    detected_a_protein_id = True
                    mat_peptide_features_with_pr_id.append(mat_peptide_feature)
                    
            # Based on the assumption, raise an error if there are both features with
            # and without protein_id's
            if detected_a_protein_id == True and detected_no_protein_id == True:
                msg = "Apparently some mat_peptides in {} have protein_id's and".format(name)
                msg += " some don't. Deal with this."
                raise ValueError(msg)
                
        # If there are no mat_peptides with a pr ID, and no mat_peptides without a pr
        # id (and thus have to been processed separately), save it out
        if len(mat_peptide_features_with_pr_id) == 0 and len(mat_peptide_features_without_pr_id) == 0:
            gb_records_not_polyproteins.append(gb_record)
        
        # Then write out the gb_records that have mat_peptides without protein id's, and
        # which therefore must be processed separately
        elif len(mat_peptide_features_without_pr_id) > 0:
            gb_records_polyproteins.append(gb_record)
            
        # This continue isn't programatically required. But, the gb_records that make it here are
        # polyproteins whose constitutent mat_peptides all have protein_id's and are thus separately
        # represented in the database. These records are excluded from further analysis
        else:
            continue
    
    # Split polyproteins into substituent mature peptides
    # ------------------------------------------------------------------------ #
    gb_records_polyprotein_peptides = []
    for gb_record in gb_records_polyproteins:
        
        name = gb_record.name
        seq = gb_record.seq
        description = gb_record.description
        organism = gb_record.annotations["organism"]
        
        features = gb_record.features
        mat_peptide_features = [feature for feature in features if feature.type=="mat_peptide"]
        
        for mat_peptide_feature in mat_peptide_features:
            mat_peptide_description = mat_peptide_feature.qualifiers.get("product")[0]
            mat_peptide_name = name + "_" + mat_peptide_description
            mat_peptide_seq = mat_peptide_feature.extract(seq)
        
            mat_peptide_seq_record = SeqRecord(seq = mat_peptide_seq,
                                            name = mat_peptide_name,
                                            description = mat_peptide_description)
            mat_peptide_seq_record.annotations["organism"] = organism
            gb_records_polyprotein_peptides.append(mat_peptide_seq_record)

    # Consolidate all gb_records
    all_gb_records = gb_records_polyprotein_peptides + gb_records_not_polyproteins

    # Add family information
    all_gb_records = add_family(all_gb_records)
    
    # Make sure that the descriptions and name of each gb entry doesn't have banned characters
    all_gb_records = clean_up_gb_records(all_gb_records)

    # Write fastas to output
    # ------------------------------------------------------------------------ #
    if args.single_output_file_path != "":

        out_dir = os.path.dirname(args.single_output_file_path)
        pathlib.Path(out_dir).mkdir(parents=True, exist_ok=True)

        with open(args.single_output_file_path, "w") as outfile:
            for gb_record in all_gb_records:
                description = gb_record.description
                name = gb_record.name
                seq = gb_record.seq
                organism = gb_record.annotations["organism"]
                taxonID = gb_record.taxonID

                header = ">{}__{}__{}__{}".format(description, name, organism, taxonID)

                # Make sure the delimiter, __, only is present three times
                if header.count("__") != 3:
                    msg = "The description, name, organism, or taxonID in the header "
                    msg += "Contains a double underscore (__)! Need to remove it because "
                    msg += "__ is currently used as a delimiter."
                    msg += " The problematic header is {}".format(header)
                    raise ValueError(msg)

                outfile.write("{}\n{}\n".format(header, seq))

    if args.multiple_file_output_dir_base != "/":
        pathlib.Path(args.multiple_file_output_dir_base).mkdir(parents=True, exist_ok=True)

        for gb_record in all_gb_records:
            description = gb_record.description
            name = gb_record.name
            seq = gb_record.seq
            organism = gb_record.annotations["organism"]
            taxonID = gb_record.taxonID

            header = ">{}__{}__{}__{}".format(description, name, organism, taxonID)

            # Make sure the delimiter, __, only is present three times
            if header.count("__") != 3:
                msg = "The description, name, organism, or taxonID in the header "
                msg += "Contains a double underscore (__)! Need to remove it because "
                msg += "__ is currently used as a delimiter"
                raise ValueError(msg)
            
            # Write to separate file
            separated_file_path = args.multiple_file_output_dir_base + "{}__{}__{}__{}.fasta".format(description, name, organism, taxonID)
            with open(separated_file_path, "w") as separate_outfile:
                separate_outfile.write("{}\n{}\n".format(header, seq))

    if args.multiple_files_by_family_output_dir_base != "/":
        pathlib.Path(args.multiple_files_by_family_output_dir_base).mkdir(parents=True, exist_ok=True)

        for gb_record in all_gb_records:
            description = gb_record.description
            name = gb_record.name
            seq = gb_record.seq
            organism = gb_record.annotations["organism"]
            taxonID = gb_record.taxonID

            header = ">{}__{}__{}__{}".format(description, name, organism, taxonID)

            # Make sure the delimiter, __, only is present three times
            if header.count("__") != 3:
                msg = "The description, name, organism, or taxonID in the header "
                msg += "Contains a double underscore (__)! Need to remove it because "
                msg += "__ is currently used as a delimiter"
                raise ValueError(msg)
            
            # Write to separate family files
            family_file_path = args.multiple_files_by_family_output_dir_base + "{}.fasta".format(gb_record.family)
            with open(family_file_path, "a") as family_outfile:
                family_outfile.write("{}\n{}\n".format(header, seq))


if __name__ == "__main__":
    main()