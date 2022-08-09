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

        Either-or params:
        -d --DATABASE {database}
            Path to a database generated with foldseek createdb.
        -C --CLUSTER_FILE {path}
            If specified, will produce a cluster output file using the foldseek 
            cluster command. Here, the INFILE will be used as both the query and target
            databases - thus, the DATABASE flag is not required.

        Optional params:
        -f --FIELDS {comma-delimited string}
            [Default: 'query,target,fident,alnlen,mismatch,gapopen,qstart,qend,tstart,tend,evalue,bits']
            The output fields present in the tabular output file. 'taxid' is not
            present at default but is useful - just make sure that the database
            searched against has taxonomy information. 
        -t --THREADS {int} [Default: 1]
            Number of threads to use for structural alignment.
        -e --EVALUE {int} [Default: 0.001]
            List matches below this e-value. An e-value of 0.001 indicates that 
            the match has a 0.1% chance of occuring by chance alone.
        -T --TEMPDIR {path} [\$(basename \${INFILE})_TEMP/]
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
while getopts i:o:d:C:f:t:e:T:H:c option ; do
        case "${option}"
        in
                i) INFILE=${OPTARG};;
                o) OUT_FILE=${OPTARG};;
                d) DATABASE=${OPTARG};;
                C) CLUSTER_FILE=${OPTARG};;
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
DATABASE=${DATABASE:-""}
CLUSTER_FILE=${CLUSTER_FILE:-""}
FIELDS=${FIELDS:-"query,target,fident,alnlen,mismatch,gapopen,qstart,qend,tstart,tend,evalue,bits"}
THREADS=${THREADS:-1}
EVALUE=${EVALUE:-0.001}
TEMPDIR=${TEMPDIR:-"$(basename ${INFILE})_TEMP"}
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

if [ -z $DATABASE ] && [ -z $CLUSTER_FILE ] ; then
    echo "--DATABASE or --CLUSTER_FILE must be set!"
    exit 1
elif [ ! -z $DATABASE ] && [ ! -z $CLUSTER_FILE ] ; then
    echo "Have detected that both --DATABASE and --CLUSTER_FILE are set."
    echo "Typically should just specify one of those, as if --CLUSTER_FILE is provided "
    echo "the INFILE will be used as both query and target."
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
CLUSTER_FILE: $CLUSTER_FILE
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
    $INFILE \
    ${TEMPDIR}/queryDB \
    --threads $THREADS

# If this is a cluster job, specify DATABASE as the query database.
if [[ $CLUSTER_FILE != "" ]] ; then 
    DATABASE=${TEMPDIR}/queryDB
fi

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

# If this is a cluster job, generate the cluster output file.
if [[ $CLUSTER_FILE != "" ]] ; then 
    mkdir -p $(dirname $CLUSTER_FILE)
    foldseek clust \
        ${TEMPDIR}/queryDB \
        $DATABASE
        ${TEMPDIR}/clusterDB

    foldseek createtsv \
        ${TEMPDIR}/queryDB \
        $DATABASE
        ${TEMPDIR}/clusterDB
        $CLUSTER_FILE
fi

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