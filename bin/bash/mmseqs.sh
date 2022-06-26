#!/usr/bin/env bash

#------------------------------------------------------------------------------#
# Defining usage and setting input
#------------------------------------------------------------------------------#
usage() {
        echo "
        This script takes in a query fasta (containing a single sequence) and
        searches against a subject fasta that acts as the database (and contains
        many sequences) using mmseqs search. The output is in a3m format and is
        compatible with subsequent structure generation using colabfold.

        Notably, this process uses the search parameters suggested by the 
        colabfold authors:
        --num-iterations 3 --db-load-mode 2 -a -s 8 -e 0.1 --max-seqs 10000

        Required params:
        -q --QUERY {fasta}
            Query fasta, containing a single sequence.
        -s --SUBJECT {fasta or mmseqs2 database file}
            Subject fasta, containing multiple fastas. OR, can be a previously-
            made mmseqs2 database (set by -d switch). Fasta can be gzipped.
        -o --OUTFILE {a3m}
            Path to the output a3m file. Necessary output directories will be 
            created.
        -n --NAME {string}
            Sample name. Used for naming output databases to avoid name
            conflicts.

        Optional params:
        -d --IS_DATABASE
            Boolean switch.
            If specified, will assume SUBJECT file is an mmseqs2 database.
        "
}

#If less than 3 options are input, show usage and exit script.
if [ $# -le 4 ] ; then
        usage
        exit 1
fi

# Boolean flag defaults
IS_DATABASE=false

#Setting input
while getopts q:s:o:n:d option ; do
        case "${option}"
        in
                q) QUERY=${OPTARG};;
                s) SUBJECT=${OPTARG};;
                o) OUTFILE=${OPTARG};;
                n) NAME=${OPTARG};;
                d) IS_DATABASE=true;;
        esac
done

#------------------------------------------------------------------------------#
# Set defaults and constants
#------------------------------------------------------------------------------#
# Constants
SEARCH_PARAM="--num-iterations 3 --db-load-mode 2 -a -s 8 -e 0.1 --max-seqs 10000"


#------------------------------------------------------------------------------#
# Validate inputs
#------------------------------------------------------------------------------#
# Make sure query has only one sequence
if (( $(grep -c "^>" $QUERY) > 1 )) ; then 
    echo "Query file must contain only one sequence."
    echo "(grep -c "^>" $QUERY) sequences are detected."
    exit 1 
fi

#------------------------------------------------------------------------------#
# Main
#------------------------------------------------------------------------------#
echo "
Inputs:

QUERY: $QUERY
SUBJECT: $SUBJECT
OUTFILE: $OUTFILE
NAME: $NAME
IS_DATABASE: $IS_DATABASE
"

# Derive output directory
OUT_DIR=$(dirname $OUTFILE)

# Make output directory if needed
mkdir -p $OUT_DIR

# Convert query and subject (if required) into mmseqs2 databases
mmseqs createdb ${QUERY} "$OUT_DIR/${NAME}_query_database"

if $IS_DATABASE ; then
    SUBJECT_DB=${SUBJECT}
else
    mmseqs createdb ${SUBJECT} "${OUT_DIR}/${NAME}_subject_database"
    SUBJECT_DB="${OUT_DIR}/${NAME}_subject_database"
fi

# Do search
mmseqs search \
    ${OUT_DIR}/${NAME}_query_database \
    $SUBJECT_DB \
    ${OUT_DIR}/${NAME}_result_database \
    ${OUT_DIR}/tmp \
    $SEARCH_PARAM

# Convert to a3m
mmseqs result2msa \
    ${OUT_DIR}/${NAME}_query_database \
    $SUBJECT_DB \
    ${OUT_DIR}/${NAME}_result_database \
    $OUTFILE \
    --msa-format-mode 5
