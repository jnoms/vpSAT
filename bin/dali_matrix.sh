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
            Path to the directory containing the queries. These will be subjected to an
            all-by-all alignment.
        -o --OUT_PREFIX {string}
            Prefix of the output files. The output files will be written to the
            appropriate directory. If you want the output in a specific directory, you
            should incorporate that into this OUT_PREFIX string. Output files:
                - {OUT_PREFIX}.newick: File containing the newick string.
                - {OUT_PREFIX}.newick_unrooted: File containing the unrooted newick string.
                - {OUT_PREFIX}.sim.txt 
                - {OUT_PREFIX}.{QUERYID}.aln.txt: Where QUERYID is the ID. These are the
                    alignment files - each query has a separate DALI alignment file.

        Optional params:
        -f --OUTPUT_FORMAT {comma-delimited list} [summary,equivalences,transrot]
            This is a comma-delimited list of the DALI output alignments to include. 
            Summary is the most important information about the alignments. transrot is 
            highly useful for rotating target structures after alignment. The additional
            field is alignments.
        -s --SYMMETRY {oneway,twoway} ['oneway'] 
            Options are oneway or twoway. If oneway is specified, will use the --oneway
            switch. This is a substaintial speedup.
        -n --THREADS {int} [1]
            The number of threads to use. CRITICAL: If set to more than 1, will be using
            MPI to handle the multithreading. On SGE, need to add #$ -pe mpi N (where N
            is the number of THREADS/the value of this commandline option) and may also
            need to module load mpi.
        -d --DALI_EXE {path} [dali.pl]
            Path to the dali.pl executable. Default assumes it is in your path.
        -M --MPIRUN_EXE {path} [mpirun]
            This sets the dali.pl --MPIRUN_EXE flag. Default assumes mpirun is in the 
            path. Otherwise, set accordingly. The DALI default is
            /usr/lib64/openmpi/bin/mpirun

        Some additional details:
        - Because DALI hates when paths are above 60 or 80 characters, the query_dir and 
        target_dir will be referred to via a symlink. The symlinks will be deleted 
        after the script completes.
        "
}

#If less than 2 options are input, show usage and exit script.
if [ $# -le 3 ] ; then
        usage
        exit 1
fi

#Setting input
while getopts q:o:f:s:n:d:M option ; do
        case "${option}"
        in
                q) QUERY_DIR=${OPTARG};;
                o) OUT_PREFIX=${OPTARG};;
                f) OUTPUT_FORMAT=${OPTARG};;
                s) SYMMETRY=${OPTARG};;
                n) THREADS=${OPTARG};;
                d) DALI_EXE=${OPTARG};;
                M) MPIRUN_EXE=${OPTARG};;
        esac
done

#------------------------------------------------------------------------------#
# Set defaults and constants
#------------------------------------------------------------------------------#
# Defaults
OUTPUT_FORMAT=${OUTPUT_FORMAT:-"summary,equivalences,transrot"}
SYMMETRY=${SYMMETRY:-oneway}
THREADS=${THREADS:-1}
DALI_EXE=${DALI_EXE:-dali.pl}
MPIRUN_EXE=${MPIRUN_EXE:-mpirun}

#------------------------------------------------------------------------------#
# Validate inputs and program availablity
#------------------------------------------------------------------------------#
if ! command -v $DALI_EXE ; then
    echo "dali.pl not detected!"
    exit 1
fi

if [[ $THREADS != 1 ]] ; then
    if ! command -v $MPIRUN_EXE ; then
        echo "You are attempting to multithread, but "
        echo "mpirun not detected at the specified MPIRUN_EXE, $MPIRUN_EXE"
        exit 1
    fi
fi

if [[ $QUERY_DIR == "" ]] ; then
    echo "QUERY_DIR must be specified!"
    exit 1
fi

if [[ $OUT_PREFIX == "" ]] ; then
    echo "OUT_PREFIX must be specified!"
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
OUT_PREFIX: $OUT_PREFIX
SYMMETRY_LINE: $SYMMETRY_LINE
THREADS: $THREADS
"

echo "$0: Started at $(date)"

# Make a temp directory
TEMP=$RANDOM
mkdir $TEMP

# Make the output directory
OUT_DIR=$(dirname $OUT_PREFIX)
mkdir -p $OUT_DIR

# Generate symlinks for the query dir
ln -s $(realpath $QUERY_DIR) $TEMP/query_dir_symlink

# Prepare file lists for dali
mkdir -p $TEMP/lists
ls $TEMP/query_dir_symlink | awk -F . '{print $1}'  > $TEMP/lists/query_list.txt

# Run DALI. Will also capture exicution time. I move into the TEMP directory to run it
# to avoid LOCK files blocking things, and to organize the output .txt files.
cd $TEMP
time $DALI_EXE \
--dat1 query_dir_symlink \
--query lists/query_list.txt \
--np $THREADS \
--clean \
$SYMMETRY_LINE \
--outfmt $OUTPUT_FORMAT \
--MPIRUN_EXE $MPIRUN_EXE \
--matrix
cd ..

# Copy over the output data and clean up the temp directory
for FILE in $TEMP/*txt ; do
    BASE=$(basename ${FILE%.txt})
    cp $FILE ${OUT_PREFIX}.${BASE}.aln.txt
done

cp ${TEMP}/newick ${OUT_PREFIX}.newick
cp ${TEMP}/newick_unrooted ${OUT_PREFIX}.newick_unrooted
cp ${TEMP}/ordered ${OUT_PREFIX}.sim.txt
rm -r $TEMP

echo "$0: Finished at $(date)"