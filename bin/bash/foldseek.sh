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
        -T --TEMPDIR {path} [INFILE_TEMP/]
            Path to the temp file directory.
        -H --HTML_FILE {html} [Default: '']
            If specified, will also output a html file to this path.
        -c --CLEAN_UP 
            Boolean flag.
            If specified, will delete the TEMPDIR.
        "
}

#If less than 3 options are input, show usage and exit script.
if [ $# -le 4 ] ; then
        usage
        exit 1
fi

# Boolean flag defaults
CLEAN_UP=false


#Setting input
while getopts i:o:d:f:t:e:T:H:c option ; do
        case "${option}"
        in
                i) INFILE=${OPTARG};;
                o) OUT_FILE=${OPTARG};;
                d) DATABASE=${OPTARG};;
                f) FIELDS=${OPTARG};;
                t) THREADS=${OPTARG};;
                e) EVALUE=${OPTARG};;
                T) TEMPDIR=${OPTARG};;
                H) HTML_FILE=${OPTARG};;
                c) CLEAN_UP=true;;
        esac
done

#------------------------------------------------------------------------------#
# Set defaults and constants
#------------------------------------------------------------------------------#
# Defaults
FIELDS=${FIELDS:-"query,target,fident,alnlen,mismatch,gapopen,qstart,qend,tstart,tend,evalue,bits"}
THREADS=${THREADS:-1}
EVALUE=${EVALUE:-0.001}
TEMPDIR=${TEMPDIR:-"${INFILE}_TEMP"}
HTML_FILE=${HTML_FILE:-""}

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
TEMPDIR: $TEMPDIR
HTML_FILE: $HTML_FILE
CLEAN_UP: $CLEAN_UP
"

echo "$0: Started at $(date)"

# Make directories if necessary
mkdir -p $(dirname $OUT_FILE)
mkdir -p $TEMPDIR

# Generate query database
echo "$0: Making query database"
foldseek createdb \
    $QUERY \
    ${TEMPDIR}/queryDB \
    --threads $THREADS

# Do the search
echo "$0: Doing search."
foldseek search \
    ${TEMPDIR}/queryDB \
    $DATABASE \
    ${TEMPDIR}/alignment_DB \
    ${TEMPDIR} \
    -a \
    --threads $THREADS \
    -e $EVALUE

# Convert to tabular output
echo "$0: Writing tabular output"
foldseek convertalis \
    ${TEMPDIR}/queryDB \
    $DATABASE \
    ${TEMPDIR}/alignment_DB \
    $OUT_FILE \
    --format-mode 0 \
    --format-output "$FIELDS" \
    --threads $THREADS

# If specified, also write html file
if [[ $HTML_FILE != "" ]] ; then
    echo "$0: Writing HTML output."
    foldseek convertalis \
    ${TEMPDIR}/queryDB \
    $DATABASE \
    ${TEMPDIR}/alignment_DB \
    $HTML_FILE \
    --format-mode 3 \
    --threads $THREADS
fi

# Clean up if specified
if $CLEAN_UP ; then
    echo "$0: Cleaning up."
    rm -r ${TEMPDIR}
fi

echo "$0: Finished at $(date)"