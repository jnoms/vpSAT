#!/usr/bin/env bash

#------------------------------------------------------------------------------#
# Defining usage and setting inputs
#------------------------------------------------------------------------------#
usage() {
        echo "
        This is a helper script to generate a Slurm-compatible job array. The situation 
        is that Slurm job arrays are great for running processes in parallel, but the
        queueing of the jobs is prohibitively slow. Thus, this script works to 
        prepare a job array submission of N files at one time. 

        The resultant array template is sent to stdout. Either redirect this to a 
        file or copy it from stdout.

        Required params:
        -d --DIR {path}
            Path to the directory containing the infiles you want to process in parallel
        -N --N {int}
            Number of files you want to process at once.
        -J --JOB_NAME {str}
            Name of the job - used to generate the directory holding lists and sublists 
            that will be read by the job array.
        "
}

#If less than 3 options are input, show usage and exit script.
if [ $# -le 4 ] ; then
        usage
        exit 1
fi

#Setting input
while getopts d:N:J: option ; do
        case "${option}"
        in
                d) DIR=${OPTARG};;
                N) N=${OPTARG};;
                J) JOB_NAME=${OPTARG};;
        esac
done

#------------------------------------------------------------------------------#
# Main
#------------------------------------------------------------------------------#
echo "
$0 inputs:

DIR: $DIR
N: $N
JOB_NAME: $JOB_NAME
"

mkdir -p ${JOB_NAME}_lists/sublists

# Generating file list - but, absolute paths not present because sometimes too many 
# files can break ls. 
ls $DIR > ${JOB_NAME}_lists/file_list.txt

# Split into desired number of lines
split --lines=${N} ${JOB_NAME}_lists/file_list.txt ${JOB_NAME}_lists/sublists/

# Generate sublists, each of whom contain a part of the original list.
ls ${JOB_NAME}_lists/sublists/* > ${JOB_NAME}_lists/sublist_list.txt

# Count of sublists for use generating the array.
FILE_COUNT=$(wc -l ${JOB_NAME}_lists/sublist_list.txt | awk '{print $1}')

# Prepare this output... redirect the stdout to the array file
cat << EOF
#!/bin/bash
#SBATCH --account=ac_ribosome
#SBATCH --partition=lr6
#SBATCH --qos=lr_normal
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=0:10:00
#SBATCH --array=1-${FILE_COUNT}

LIST=\$(sed "\${SLURM_ARRAY_TASK_ID}q;d" ${JOB_NAME}_lists/sublist_list.txt)

cat \$LIST | while read LINE ; do

FILE=$DIR/\$LINE
# FILE now is the relative path to an individual file! Do stuff.

done

EOF
