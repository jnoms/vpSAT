#!/usr/bin/env bash

#------------------------------------------------------------------------------#
# Defining usage and setting inputs
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
            created. Many temporary files and database files will be written to
            the same directory unless -c switch is specified.
        -n --NAME {string}
            Sample name. Used for naming output databases to avoid name
            conflicts.

        Optional params:
        -t --THREADS [5]
            Number of threads.
        -d --IS_DATABASE
            Boolean switch.
            If specified, will assume SUBJECT file is an mmseqs2 database.
        -c --CLEAN_UP
            Boolean switch.
            If specified, will delete all intermediate/unncessary files from
            the result directory, leaving just the a3m.
        "
}

#If less than 3 options are input, show usage and exit script.
if [ $# -le 4 ] ; then
        usage
        exit 1
fi

# Boolean flag defaults
IS_DATABASE=false
CLEAN_UP=false

#Setting input
while getopts q:s:o:n:t:dc option ; do
        case "${option}"
        in
                q) QUERY=${OPTARG};;
                s) SUBJECT=${OPTARG};;
                o) OUTFILE=${OPTARG};;
                n) NAME=${OPTARG};;
                t) THREADS=${OPTARG};;
                d) IS_DATABASE=true;;
                c) CLEAN_UP=true;;
        esac
done

#------------------------------------------------------------------------------#
# Set defaults and constants
#------------------------------------------------------------------------------#
# Constants
SEARCH_PARAM="--num-iterations 3 --db-load-mode 2 -a -s 8 -e 0.1 --max-seqs 10000"

# Defaults
THREADS=${THREADS:-5}

#------------------------------------------------------------------------------#
# Validate inputs and program availablity
#------------------------------------------------------------------------------#
# Make sure query has only one sequence
if (( $(grep -c "^>" $QUERY) > 1 )) ; then
    echo "Query file must contain only one sequence."
    echo "$(grep -c "^>" $QUERY) sequences are detected."
    exit 1
fi

# Make sure all input files exist
# if [ ! -f $QUERY ] ; then
#     echo "QUERY file, $QUERY, not detected."
#     exit 1
# elif [ ! -f $SUBJECT ] ; then
#     echo "SUBJECT file, $SUBJECT, not detected."
#     exit 1
# fi

# Make sure required programs are available
if ! command -v mmseqs ; then
    echo "mmseqs not detected!"
    exit 1
fi

#------------------------------------------------------------------------------#
# Main
#------------------------------------------------------------------------------#
echo "
$0 inputs:

QUERY: $QUERY
SUBJECT: $SUBJECT
OUTFILE: $OUTFILE
NAME: $NAME
THREADS: $THREADS
IS_DATABASE: $IS_DATABASE
CLEAN_UP: $CLEAN_UP
"

echo "$0: Started at $(date)"

# Derive output directory
OUT_DIR=$(dirname $OUTFILE)

# Make output directory if needed
mkdir -p $OUT_DIR

# Convert query and subject (if required) into mmseqs2 databases
echo "$0: Creating query database."
mmseqs createdb ${QUERY} "$OUT_DIR/${NAME}_query_database"

if $IS_DATABASE ; then
    echo "$0: SUBJECT specified as a database."
    SUBJECT_DB=${SUBJECT}
else
    echo "$0: Creating subject database."
    mmseqs createdb ${SUBJECT} "${OUT_DIR}/${NAME}_subject_database"
    SUBJECT_DB="${OUT_DIR}/${NAME}_subject_database"
fi

# Do search
echo "$0: Doing search."
mmseqs search \
    ${OUT_DIR}/${NAME}_query_database \
    $SUBJECT_DB \
    ${OUT_DIR}/${NAME}_result_database \
    ${OUT_DIR}/tmp \
    $SEARCH_PARAM \
    --threads $THREADS

# Convert to a3m
echo "$0: Converting to a3m."
mmseqs result2msa \
    ${OUT_DIR}/${NAME}_query_database \
    $SUBJECT_DB \
    ${OUT_DIR}/${NAME}_result_database \
    $OUTFILE \
    --msa-format-mode 5 \
    --threads $THREADS

# Cleanup if indicated
if $CLEAN_UP ; then
    echo "$0: Cleaning up."
    rm ${OUTFILE}.*
    rm  ${OUT_DIR}/${NAME}_query_database*
    rm ${OUT_DIR}/${NAME}_result_database*
    rm -r ${OUT_DIR}/tmp

    # If input was database, don't want to delete it. But if input was fasta,
    # delete it
    if $IS_DATABASE ; then
        :
    else
        rm ${SUBJECT_DB}*
    fi

fi

echo "$0: Finished at $(date)"
