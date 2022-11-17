#!/usr/bin/env bash

#------------------------------------------------------------------------------#
# Defining usage and setting inputs
#------------------------------------------------------------------------------#
usage() {
        echo "
        This script takes in a query fasta (containing a single sequence) and
        searches against an hhblits database. This script will output a typical
        hh-suite .hhr file output, as well as a blast-tabulated file that has the 
        column fields: 'query,target,fident,alnlen,mismatch,gapopen,qstart,qend,tstart,
        tend,evalue,bits'

        Required params:
        -q --QUERY {fasta}
            Query fasta, containing a single sequence.
        -d --DATABASE 
            Target hh-suite database.
        -1 --BLAST_OUT {m8}
            Path to the output blast-tabulated file. This file has the column fields:
            'query,target,fident,alnlen,mismatch,gapopen,qstart,qend,tstart,tend,evalue,
            bits'.
        -2 --HRR_OUT {.hrr}
            Path to the verbose hh-suite hhr output file.

        Optional params:
        -t --THREADS [5]
            Number of threads.
        -i --ITERATIONS [2]
            Number of search iterations. Increasing this value will increase sensitivity
            but could draw in false-positives (reduce percision).
        -e --EVALUE [0.001]
            An alignment must have an evalue smaller than this value in order to be 
            output.
        "
}

#If less than 4 options are input, show usage and exit script.
if [ $# -le 5 ] ; then
        usage
        exit 1
fi

#Setting input
while getopts q:d:1:2:t:i:e option ; do
        case "${option}"
        in
                q) QUERY=${OPTARG};;
                d) DATABASE=${OPTARG};;
                1) BLAST_OUT=${OPTARG};;
                2) HRR_OUT=${OPTARG};;
                t) THREADS=${OPTARG};;
                i) ITERATIONS=${OPTARG};;
                e) EVALUE=${OPTARG};;
        esac
done

#------------------------------------------------------------------------------#
# Set defaults and constants
#------------------------------------------------------------------------------#
# Defaults
THREADS=${THREADS:-5}
ITERATIONS=${ITERATIONS:-2}
EVALUE=${EVALUE:-0.001}

#------------------------------------------------------------------------------#
# Validate inputs and program availablity
#------------------------------------------------------------------------------#
# Make sure all input files exist
if [ ! -f $QUERY ] ; then
    echo "QUERY file, $QUERY, not detected."
    exit 1
fi

# Make sure query has only one sequence
if (( $(grep -c "^>" $QUERY) > 1 )) ; then
    echo "Query file must contain only one sequence."
    echo "$(grep -c "^>" $QUERY) sequences are detected."
    exit 1
fi

# Make sure required programs are available
if ! command -v hhblits ; then
    echo "hhblits not detected!"
    exit 1
fi

#------------------------------------------------------------------------------#
# Main
#------------------------------------------------------------------------------#
echo "
$0 inputs:

QUERY: $QUERY
DATABASE: $DATABASE
BLAST_OUT: $BLAST_OUT
HRR_OUT: $HRR_OUT
THREADS: $THREADS
ITERATIONS: $ITERATIONS
EVALUE: $EVALUE
"

echo "$0: Started at $(date)"

# Make output directories if needed
mkdir -p $(dirname $BLAST_OUT)
mkdir -p $(dirname $HRR_OUT)

# Do search
echo "$0: Running hhblits"
hhblits \
    -i $QUERY \
    -d $DATABASE \
    -n $ITERNATIONS \
    -e $EVALUE \
    -o $HRR_OUT \
    -blasttab ${BLAST_OUT}.tmp \
    -cpu $THREADS

echo "$0: Filtering the blasttab output by evalue"
# The second awk removes empty lines
awk -v EVALUE=$EVALUE '$11 < EVALUE' ${BLAST_OUT}.tmp |\
    awk 'NF > 0' > ${BLAST_OUT} && rm ${BLAST_OUT}.tmp

echo "$0: Finished at $(date)"
