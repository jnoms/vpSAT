#!/usr/bin/env bash

#------------------------------------------------------------------------------#
# Defining usage and setting inputs
#------------------------------------------------------------------------------#
usage() {
        echo "
        This is a helper script to generate a SGE-compatible job array. The situation 
        is that SGE job arrays are great for running processes in parallel, but the
        queueing of the jobs is prohibitively slow. Thus, this script works to 
        prepare a job array submission of N files at one time. 

        The resultant array template is sent to stdout. Either redirct this to a 
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

# Split into desired nuber of lines
split --lines=${N} ${JOB_NAME}_lists/file_list.txt ${JOB_NAME}_lists/sublists/

# Generate sublists, each of whome contain a part of the original list.
ls ${JOB_NAME}_lists/sublists/* > ${JOB_NAME}_lists/sublist_list.txt

# Count of sublists for use generating the array.
FILE_COUNT=$(wc -l ${JOB_NAME}_lists/sublist_list.txt | awk '{print $1}')

# Prepare this output... redict the stdout to the array file
cat << EOF
#!/bin/bash
#$ -S /bin/bash
#$ -o ./
#$ -e ./
#$ -cwd
#$ -r y
#$ -j y
#$ -l mem_free=10G
#$ -l scratch=10G
#$ -l h_rt=0:15:00
#$ -t 1-${FILE_COUNT}

conda activate SAT

LIST=\$(sed "\${SGE_TASK_ID}q;d" ${JOB_NAME}_lists/sublist_list.txt)


cat $LIST | while read LINE ; do

FILE=\$($DIR\$LINE)
# FILE now is the relative path to an individual file! Do stuff.

done

EOF