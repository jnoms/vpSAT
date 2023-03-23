#!/usr/bin/env bash

#------------------------------------------------------------------------------#
# Defining usage and setting inputs
#------------------------------------------------------------------------------#
usage() {
        echo "
        This script conducts DALI alignment between one or more queries and one 
        or more targets. NOTE - All queries must be in the same directory, 
        and all targets must be in the same directory (they can technically be the same
        if you're doing all-by-all). The specified inputs are the paths to the
        relevant directories.

        All input files should already be dali databases generated with
        dali_format_inputs.sh.

        Required params:
        -q --QUERY_DIR {path}
            Path to the directory containing the queries. Must have one or more 
            previously-imported .dat files.
        -t --TARGET_DIR {path}
            Path to the directory containing the targets. Must have one or more 
            previously-imported .dat files.
        -o --OUT_DIR {path}
            Path to the directory containing the output alignment files.

        Optional params:
        -f --OUTPUT_FORMAT {comma-delimited list} [summary,equivalences,transrot]
            This is a comma-delimited list of the DALI outpits to incldue. Summary 
            is the most important information about the alignments. transrot is 
            highly useful for rotating target structures after alignment. The additional
            field is alignments.
        -s --SYMMETRY {oneway,twoway} ['oneway'] 
            Options are oneway or twoway. If oneway is specified, will use the --oneway
            switch. This is a substaintial speedup.

        Some additional details:
        - Because DALI hates when paths are above 60 or 80 characters, the query_dir and 
        target_dir will be referred to via a symlink. The symlinks will be deleted 
        after the script completes.
        "
}

#If less than 3 options are input, show usage and exit script.
if [ $# -le 4 ] ; then
        usage
        exit 1
fi

#Setting input
while getopts q:t:o:f:s: option ; do
        case "${option}"
        in
                q) QUERY_DIR=${OPTARG};;
                t) TARGET_DIR=${OPTARG};;
                o) OUT_DIR=${OPTARG};;
                f) OUTPUT_FORMAT=${OPTARG};;
                s) SYMMETRY=${OPTARG};;
        esac
done

#------------------------------------------------------------------------------#
# Set defaults and constants
#------------------------------------------------------------------------------#
# Defaults
OUTPUT_FORMAT=${OUTPUT_FORMAT:-"summary,equivalences,transrot"}
SYMMETRY=${SYMMETRY:-oneway}

#------------------------------------------------------------------------------#
# Validate inputs and program availablity
#------------------------------------------------------------------------------#
if ! command -v dali.pl ; then
    echo "dali.pl not detected!"
    exit 1
fi

if [[ $SYMMETRY == "oneway" ]] ; then
    SYMMETRY_LINE="--oneway"
elif [[ $SYMMETRY == "twoway" ]] ; then
    SYMMETRY_LINE=""
else
    echo "SYMMETRY must be set to 'oneway' or 'twoway!! You entered $SYMMETRY"
    exit 1
fi

#------------------------------------------------------------------------------#
# Main
#------------------------------------------------------------------------------#
echo "
$0 inputs:

QUERY_DIR: $QUERY_DIR
TARGET_DIR: $TARGET_DIR
OUT_DIR: $OUT_DIR
SYMMETRY_LINE: $SYMMETRY_LINE
"

echo "$0: Started at $(date)"

# Make a temp directory
TEMP=$RANDOM
mkdir $TEMP

mkdir -p $OUT_DIR

# Generate symlinks for each of the databases
ln -s $(realpath $QUERY_DIR) $TEMP/query_dir_symlink
ln -s $(realpath $TARGET_DIR) $TEMP/target_dir_symlink

# Prepare file lists for dali
mkdir -p $TEMP/lists
ls $TEMP/query_dir_symlink | awk -F . '{print $1}'  > $TEMP/lists/query_list.txt
ls $TEMP/target_dir_symlink | awk -F . '{print $1}'  > $TEMP/lists/target_list.txt

# Run DALI. Will also capture exicution time. I move into the TEMP directory to run it
# to avoid LOCK files blocking things, and to organize the output .txt files.
cd $TEMP
time dali.pl \
--dat1 query_dir_symlink \
--dat2 target_dir_symlink \
--query lists/query_list.txt \
--db lists/target_list.txt \
--clean \
$SYMMETRY_LINE \
--outfmt $OUTPUT_FORMAT
cd ..

# Copy over the output data and clean up the temp directory
cp $TEMP/*txt $OUT_DIR
rm -r $TEMP

echo "$0: Finished at $(date)"