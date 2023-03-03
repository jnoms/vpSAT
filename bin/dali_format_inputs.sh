#!/usr/bin/env bash

#------------------------------------------------------------------------------#
# Defining usage and setting inputs
#------------------------------------------------------------------------------#
usage() {
        echo "
        This script takes in a single directory full of pdb files, renames them 
        to be of structure [A-Z][A-Z][A-Z][A-Z].pdb and generates a key that can be 
        used to convert them back.

        The key is double-comma delimited and of structure
        [pdb_file_name],,[4digit identifier]

        Required params:
        -d --INPUT_DIR {path}
            Path to an input directory containing pdb files.
        -o --OUTPUT_DIR {path}
            Path to an output directory containing .dat files (with a 4 digit ID)
            that are generated from dali import.pl.
        -s --STRUCTURE_KEY {path}
            Path to the output key file to convert the .dat file identifiers back to the 
            original file name.

        Optional params:
        -b --STRUCTURE_KEY_BLACKLIST {file} ['']
            Path to a different structure_key file. This make ssure that the identifiers
            genereated for in input_dir in this script do not overlap with existing
            identifiers. 
        -L --STRUCTURE_SYMLINK_STORAGE_DIR {path} ['structure_symlinks']
            Path to a directory holding the symlinks, which are the pdb files renamed 
            as 4 digit letters [A-Z][A-Z][A-Z][A-Z].pdb. This is helpful for when you're
            formatting a target dir and you want to rotate some of the pdb files later. 
        "
}

#If less than 3 options are input, show usage and exit script.
if [ $# -le 4 ] ; then
        usage
        exit 1
fi


#Setting input
while getopts d:o:s:b:L: option ; do
        case "${option}"
        in
                d) INPUT_DIR=${OPTARG};;
                o) OUTPUT_DIR=${OPTARG};;
                s) STRUCTURE_KEY=${OPTARG};;
                b) STRUCTURE_KEY_BLACKLIST=${OPTARG};;
                L) STRUCTURE_SYMLINK_STORAGE_DIR=${OPTARG};;
        esac
done

#------------------------------------------------------------------------------#
# Set defaults and constants
#------------------------------------------------------------------------------#
# Defaults
STRUCTURE_KEY_BLACKLIST=${STRUCTURE_KEY_BLACKLIST:-""}
STRUCTURE_SYMLINK_STORAGE_DIR=${STRUCTURE_SYMLINK_STORAGE_DIR:-"structure_symlinks"}

#------------------------------------------------------------------------------#
# Validate inputs and program availablity
#------------------------------------------------------------------------------#
# Make sure required programs are available
if ! command -v import.pl ; then
    echo "DALI import.pl  not detected!"
    exit 1
fi

#------------------------------------------------------------------------------#
# Main
#------------------------------------------------------------------------------#
echo "
$0 inputs:

INPUT_DIR: $INPUT_DIR
OUTPUT_DIR: $OUTPUT_DIR
STRUCTURE_KEY: $STRUCTURE_KEY
STRUCTURE_KEY_BLACKLIST: $STRUCTURE_KEY_BLACKLIST
"

echo "$0: Started at $(date)"

if [[ -f $STRUCTURE_KEY ]] ; then 
    echo "There is currently a STRUCTURE_KEY file, $STRUCTURE_KEY!"
    echo "It will be appended to."
fi

# Make a temp directory
TEMP=$RANDOM
mkdir $TEMP

# Prepare other directories
mkdir -p ${STRUCTURE_SYMLINK_STORAGE_DIR}
mkdir -p $OUTPUT_DIR

# This is a counter to keep track of when we can stop iterating
TOTAL_INPUTS=$(ls $INPUT_DIR | wc -l)
COUNT=1

# Generate an list of IDs. Each time, need to check if it's valid (e.g. hasn't been used
# before and isn't in the blacklist).
alphabet="abcdefghijklmnopqrstuvwxyz"
while [[ $COUNT -le $TOTAL_INPUTS ]] ; do 
    c1="${alphabet:$(( RANDOM % ${#alphabet} )):1}"
    c2="${alphabet:$(( RANDOM % ${#alphabet} )):1}"
    c3="${alphabet:$(( RANDOM % ${#alphabet} )):1}"
    c4="${alphabet:$(( RANDOM % ${#alphabet} )):1}"
    ID="${c1}${c2}${c3}${c4}"
    
    if [[ -f $STRUCTURE_KEY_BLACKLIST ]] ; then
        if grep $ID $STRUCTURE_KEY_BLACKLIST ; then
            continue
        fi
    fi

    # Write the ID to a file
    echo $ID >> $TEMP/IDs.txt
    COUNT=$(($COUNT+1))
done

# Iterate over all inputs
COUNT=1
for CURRENT_STRUCTURE in $INPUT_DIR/*pdb ; do 
    CURRENT_STRUCTURE=$(realpath ${CURRENT_STRUCTURE})
    CURRENT_STRUCTURE_BASE=$(basename $CURRENT_STRUCTURE)
    
    # Find ID
    ID=$(sed "${COUNT}q;d" $TEMP/IDs.txt)

    # Write to key
    echo "${CURRENT_STRUCTURE_BASE},,${ID}" >> $STRUCTURE_KEY

    # make a symlink
    ln -s $CURRENT_STRUCTURE ${STRUCTURE_SYMLINK_STORAGE_DIR}/${ID}.pdb

    # import to dali
    import.pl \
    --pdbfile ${STRUCTURE_SYMLINK_STORAGE_DIR}/${ID}.pdb \
    --dat $OUTPUT_DIR \
    -pdbid $ID \
    --clean

    # Update counter
    COUNT=$(($COUNT+1))

done

# Delete the temp folder
rm -r $TEMP