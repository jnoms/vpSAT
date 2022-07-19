# ---------------------------------------------------------------------------- #
# Packages and function import
# ---------------------------------------------------------------------------- #
import pathlib
import os
import argparse
import gzip
import sys
from turtle import setundobuffer
from Bio import SeqIO

# ---------------------------------------------------------------------------- #
# Arguments
# ---------------------------------------------------------------------------- #
def get_args():
    parser = argparse.ArgumentParser(description="""
            The purpose of this script is to take in a fasta
            and split each entry that is longer than a maximum sequence length.
            The too-long sequences will either be split into chunks of size
            max_len, or will be written to chunks that overlap by half of their
            length.

            For example, if a sequence is 2300AA long but you desire sequences
            of 1000 max, this script can either generate the following:
            1) 1-1000, 1001-2000, 2001-2300. (if -v is NOT specified)
            2) 1-1000, 501-1500, 1001-2000, 1501-2300, 2001-2300 (if -v is specified)

            The output fasta will be labeled with a prefix
            PARTN_, where N is the chunk number.
            """)

    # Required arguments
    parser.add_argument(
        '-i',
        '--in_fasta',
        type=str,
        required=True,
        help='''
        Path to the input fasta. 
        '''
    )
    parser.add_argument(
        '-o',
        '--out_fasta',
        type=str,
        required=True,
        help='''
        Path to the output fasta.
        '''
    )
    parser.add_argument(
        '-m',
        '--max_seq_length',
        type=int,
        required=True,
        help='''
        The maximum sequence length.
        '''
    )

    # Optional arguments
    def str2bool(v):
        if isinstance(v, bool):
            return v
        if v.lower() in ('yes', 'true', 't', 'y', '1'):
            return True
        elif v.lower() in ('no', 'false', 'f', 'n', '0'):
            return False
        else:
            raise argparse.ArgumentTypeError('Boolean value expected.')

    parser.add_argument(
        '-v',
        '--overlapping_chunks',
        type=str2bool,
        required=False,
        default=False,
        nargs="?",
        const=True,
        help='''
        If specified, each chunk will overlap by max_seq_length/2. If not
        specified, chunks will be just
        1:max_seq_length, max_seq_length+1:max_seq_length*2, etc
        '''
    )

    args = parser.parse_args()

    # if overlapping_chunks is specified, max_seq_length must be even
    if args.overlapping_chunks:
        if args.max_seq_length % 2 != 0:
            msg = "Because you want overlapping chunks, max_seq_length must "
            msg += "be even."
            raise ValueError(msg)

    return args


# ---------------------------------------------------------------------------- #
# General functions
# ---------------------------------------------------------------------------- #
def read_fasta_to_memory(input_fasta):
    """
    Reads fasta into a memory as a dictionary with header:sequence.
    This function can handle .gzip files, but input_fasta needs to
    end with .gz
    """
    fasta_dict = dict()

    if not input_fasta.endswith(".gz"):
        for seq_record in SeqIO.parse(input_fasta, "fasta"):
            fasta_dict[seq_record.id] = str(seq_record.seq)

    elif input_fasta.endswith(".gz"):
        with gzip.open(input_fasta, "rt") as handle:
            for seq_record in SeqIO.parse(handle, "fasta"):
                fasta_dict[seq_record.id] = str(seq_record.seq)

    return fasta_dict


# ---------------------------------------------------------------------------- #
# Main
# ---------------------------------------------------------------------------- #
def main():
    args = get_args()
    fasta_dict = read_fasta_to_memory(args.in_fasta)
    out_fasta_dict = dict()

    for header, seq in fasta_dict.items():

        if len(seq) <= args.max_seq_length:
            out_fasta_dict[header] = seq
            continue

        if not args.overlapping_chunks:
            chunks = [seq[i:i+args.max_seq_length] for i in range(0, len(seq), args.max_seq_length)]
        else:
            overlap = int(args.max_seq_length/2)
            chunks = [seq[i:i+args.max_seq_length] for i in range(0, len(seq), args.max_seq_length-overlap)]

        for i, chunk in enumerate(chunks):
            new_header = "PART{}_{}".format(str(i), header)
            out_fasta_dict[new_header] = chunk

    # Write output
    out_dir = os.path.dirname(args.out_fasta)
    pathlib.Path(out_dir).mkdir(parents=True, exist_ok=True)
    with open(args.out_fasta, "w") as outfile:
        for header, seq in out_fasta_dict.items():
            out = ">{}\n{}\n".format(header, seq)
            outfile.write(out)


if __name__ == "__main__":
    main()
