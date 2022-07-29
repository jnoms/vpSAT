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
import itertools


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

    return args

# ---------------------------------------------------------------------------- #
# Constants
# ---------------------------------------------------------------------------- #
minimum_uncovered_polypeptide_length = 50

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
def read_gb_file(infile):
    """
    Returns a list of entries. Each entry is a biopython SeqFeature.
    """
    gb_records = []
    for gb_record in SeqIO.parse(open(infile, "r"), "genbank"):
        gb_records.append(gb_record)
    return gb_records


def split_polyproteins(gb_records, minimum_uncovered_polypeptide_length=50):
    """
    Returns a list of gb_records where polyprotiens have been split up. 
    Polyproteins are defined as proteins where there is a mat_peptide field.
    In the event that the mat_peptide fields do not entirely cover the record
    sequence, the remaining uncovered sequence is also output as a separate
    record if it is greater than minimum_uncovered_polypeptide_length.
    """
    def set_to_ranges(i):
        """
        Minor function to convert a set of positions to a series of ranges.
        For example, a set {0, 1, 2, 4, 5, 10, 12, 13, 14} would yield
        [(0, 2), (4, 5), (10, 10), (12, 14)].
        
        Note, must use list() function on the result to convert it to a list -
        it is output as a generator.
        """
        for a, b in itertools.groupby(enumerate(i), lambda pair: pair[1] - pair[0]):
            b = list(b)
            yield b[0][1], b[-1][1]
    
    result_gb_records = []
    for gb_record in gb_records:
            name = gb_record.name
            seq = gb_record.seq
            description = gb_record.description
            organism = gb_record.annotations["organism"]

            # Extract features
            features = gb_record.features

            # Check for mature peptide features
            mat_peptide_features = [feature for feature in features if feature.type=="mat_peptide"]

            # If there are no mature peptides, just add the gb_record to the output
            if len(mat_peptide_features) == 0:
                result_gb_records.append(gb_record)
                continue

            # Parse the mature peptides and write them out.
            covered_locations = set()
            for mat_peptide_feature in mat_peptide_features:
                mat_peptide_description = mat_peptide_feature.qualifiers.get("product")[0]
                mat_peptide_name = mat_peptide_feature.qualifiers.get("protein_id", [name + "_" + mat_peptide_description])[0]
                mat_peptide_seq = mat_peptide_feature.extract(seq)
                
                # remove the version (e.g. .1) from the name
                mat_peptide_name = mat_peptide_name.split(".")[0]

                mat_peptide_seq_record = SeqRecord(seq = mat_peptide_seq,
                                                name = mat_peptide_name,
                                                description = mat_peptide_description)
                mat_peptide_seq_record.annotations["organism"] = organism
                result_gb_records.append(mat_peptide_seq_record)

                # Also keep track of the locations that have been convered
                location = mat_peptide_feature.location
                covered_locations.update(set(range(location.start, location.end)))

            # Determine if the entire polyprotein is covered
            not_covered = set(range(len(seq))) - covered_locations

            # If not all of the polyprotien was covered, write the remaining sequence
            # as a new entry
            if not_covered != set():
                uncovered_ranges = list(set_to_ranges(not_covered))
                for uncovered_range in uncovered_ranges:
                    start = uncovered_range[0]
                    end = uncovered_range[1]
                    if end - start < minimum_uncovered_polypeptide_length: continue
                    record = SeqRecord(seq = seq[start:end],
                                        name = "{}_{}-{}".format(name, start, end),
                                        description = "uncovered_polypeptide_{}".format(description))
                    record.annotations["organism"] = organism
                    result_gb_records.append(record)

    return result_gb_records

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

        # Make sure none of them start with a dash. Otherwise, mmseqs2 will
        # interpret it as a switch.
        if description.startswith("-"):
            description = description[1:]
        if name.startswith("-"):
            name = name[1:]
        if organism.startswith("-"):
            organism = organism[1:]

        # Make sure each description, name, and organism only has one _ in a row
        description = description.replace("__", "_").replace("__", "_")
        name = name.replace("__", "_").replace("__", "_")
        organism = organism.replace("__", "_").replace("__", "_")
        
        # Save into the gb objects
        gb_record = gb_record
        gb_record.description = description
        gb_record.annotations["organism"] = organism
        gb_record.name = name
    
    return cleaned_gb_records

def remove_duplicates(gb_records):
    """
    If there are multiple gb_records with the same name, will discard
    one of them. There will be multiple in the situation where a 
    mat_peptide from a polyprotein is also present as a separate entry.
    """
    seen = set()
    output = []
    for gb_record in gb_records:
        name = gb_record.name


        if name in seen:
            continue

        # Otherwise, save this to the new output
        seen.add(name)
        output.append(gb_record)

    return output

def generate_header(gb_record):
    description = gb_record.description
    name = gb_record.name
    seq = gb_record.seq
    organism = gb_record.annotations["organism"]
    taxonID = gb_record.taxonID
    
    # Define and validate header
    header = "{}__{}__{}__{}".format(description, name, organism, taxonID)
    if header.count("__") != 3:
        msg = "The description, name, organism, or taxonID in the header "
        msg += "Contains a double underscore (__)! Need to remove it because "
        msg += "__ is currently used as a delimiter."
        msg += " The problematic header is {}".format(header)
        raise ValueError(msg)
        
    return header

def write_single_output(gb_records, path):
    """
    Writes fastas to a single output file.
    """
    out_dir = os.path.dirname(path)
    pathlib.Path(out_dir).mkdir(parents=True, exist_ok=True)
    
    with open(path, "w") as outfile:
        for gb_record in gb_records:
            header = generate_header(gb_record)
            seq = gb_record.seq
            outfile.write(">{}\n{}\n".format(header, seq))
        
def write_multi_output(gb_records, base_path):
    """
    Writes a separate file for each entry
    """
    if not base_path.endswith("/"):
        base_path += "/"
        
    # Make output dir if needed
    pathlib.Path(base_path).mkdir(parents=True, exist_ok=True)
    
    for gb_record in gb_records:
        header = generate_header(gb_record)
        seq = gb_record.seq
        with open(base_path + header + ".fasta", "w") as outfile:
            outfile.write(">{}\n{}\n".format(header, seq))
   
def write_family_output(gb_records, base_path):
    """
    Writes a single output file per family.
    """
    if not base_path.endswith("/"):
        base_path += "/"
   
    # Make output dir if needed
    pathlib.Path(base_path).mkdir(parents=True, exist_ok=True)
    
    file_objects = dict()
    
    for gb_record in gb_records:
        header = generate_header(gb_record)
        seq = gb_record.seq
        family = gb_record.family
        
        output_file_path = base_path + family + ".fasta"
        if not family in file_objects:
            file_objects[family] = open(output_file_path, "w")
            
        outfile = file_objects[family]
        outfile.write(">{}\n{}\n".format(header, seq))
        
    # Close the file objects
    for family, file_object in file_objects.items():
        file_object.close()


# Main
def main():
    args = get_args()
    
    print("Parsing input file.")
    gb_records = read_gb_file(args.input_genpept_file)

    # split polyproteins into separate records
    print("Splitting polyproteins")
    gb_records = split_polyproteins(gb_records, minimum_uncovered_polypeptide_length)

    # Add family information
    print("Adding family information")
    gb_records = add_family(gb_records)

    # Make sure that the descriptions and name of each gb entry doesn't have banned characters
    print("Removing banned characters")
    gb_records = clean_up_gb_records(gb_records)

    # Remove duplicates
    print("Removing duplicates.")
    gb_records = remove_duplicates(gb_records)

    # Write output
    print("Writing output.")
    if args.single_output_file_path != "":
        write_single_output(gb_records, args.single_output_file_path)
    if args.multiple_file_output_dir_base != "":
        print(args.multiple_file_output_dir_base)
        write_multi_output(gb_records, args.multiple_file_output_dir_base)
    if args.multiple_files_by_family_output_dir_base != "":
        write_family_output(gb_records, args.multiple_files_by_family_output_dir_base)


if __name__ == "__main__":
    main()