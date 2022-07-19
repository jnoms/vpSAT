#!/usr/bin/env bash

#------------------------------------------------------------------------------#
# Defining usage and setting inputs
#------------------------------------------------------------------------------#
usage() {
        echo "
        This script runs FoldSeek to align an input structure against a database
        consisting of many other structures. 

        Required params:
        -i --INFILE {pdb}
            Structure that serves as the query.
        -o --OUT_FILE {path}
            Path to the output file. This will be a tabular file (.m8 is a
            recommended file suffix for the tabular file), unless the -H switch
            is specified, in which case it will be an HTML file. 
        -d --DATABASE {database}
            Path to a database generated with foldseek createdb.

        Optional params:
        -f --FIELDS {comma-delimited string}
            [Default: 'query,target,fident,alnlen,mismatch,gapopen,qstart,qend,tstart,tend,evalue,bits']
            The output fields present in the tabular output file. taxid is not
            present at default and is useful - just make sure that the database
            searched against has taxonomy information. 
        -t --THREADS {int} [Default: 1]
            Number of threads to use for structural alignment.
        -e --EVALUE {int} [Default: 0.001]
            List matches below this e-value. An e-value of 0.001 indicates that 
            the match has a 0.1% chance of occuring by chance alone.
        -H --HTML 
            Boolean switch.
            If specified, the output file will be an html file. Note that
            ideally this script would be able to output both an html file and
            a tabular file... however, due to a foldseek bug, it currently
            cannot generate an html file from a result database. Thus, must
            use easy-search.
        "
}

#If less than 2 options are input, show usage and exit script.
if [ $# -le 3 ] ; then
        usage
        exit 1
fi

# Boolean flag defaults
HTML=false

#Setting input
while getopts i:o:d:f:t:e:H option ; do
        case "${option}"
        in
                i) INFILE=${OPTARG};;
                o) OUT_FILE=${OPTARG};;
                d) DATABASE=${OPTARG};;
                f) FIELDS=${OPTARG};;
                t) THREADS=${OPTARG};;
                e) EVALUE=${OPTARG};;
                H) HTML=true;;
        esac
done

#------------------------------------------------------------------------------#
# Set defaults and constants
#------------------------------------------------------------------------------#
# Defaults
FIELDS=${FIELDS:-"query,target,fident,alnlen,mismatch,gapopen,qstart,qend,tstart,tend,evalue,bits"}
THREADS=${THREADS:-1}
EVALUE=${EVALUE:-0.001}

# Handle output format
if $HTML ; then
    OUTFORMAT=3
else
    OUTFORMAT=0
fi

#------------------------------------------------------------------------------#
# Validate inputs and program availablity
#------------------------------------------------------------------------------#
# Make sure all input files exist
if [ ! -f $INFILE ] ; then
    echo "Input file, $INFILE, not detected."
    exit 1
fi

if [ ! -f $DATABASE ] ; then
    echo "Database, $DATABASE, not detected."
    exit 1
fi

# Make sure required programs are available
if ! command -v foldseek  ; then
    echo "foldseek not detected!"
    exit 1
fi


#------------------------------------------------------------------------------#
# Main
#------------------------------------------------------------------------------#
echo "
$0 inputs:

INFILE: $INFILE
OUT_FILE: $OUT_FILE
DATABASE: $DATABASE
FIELDS: $FIELDS
THREADS: $THREADS
EVALUE: $EVALUE
HTML: $HTML
"

echo "$0: Started at $(date)"

# Make output directory if necessary
mkdir -p $(dirname $OUT_FILE)

# Run foldseek
foldseek easy-search \
    $INFILE \
    $DATABASE \
    $OUT_FILE \
    foldseek-tmp \
    --format-mode $OUTFORMAT \
    --format-output "$FIELDS" \
    -e $EVALUE