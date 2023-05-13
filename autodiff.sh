#!/bin/sh
#
# autodiff.sh - Extract submissions and diff their output with a reference.
#
# Usage: autodiff.sh <path to unzipped Collab submissions> <computing ID of student>
#

# Error on unset variables.
set -u
# Uncomment to see commands as they execute.
# set -x

CLEAN_SCRATCH='y'
while getopts "r" o
do
    case "$o" in
        r)
            CLEAN_SCRATCH='n'
            ;;
        *)
            ;;
    esac
done

# Path to unzipped Collab zip.
SUBMISSIONS_PATH="${@:$OPTIND:1}"
# Computing ID of the submission to run.
COMPUTING_ID="${@:$OPTIND+1:1}"
CID=$COMPUTING_ID
# Path the script will use to build/run submissions.
# Cleaned before each run.
SCRATCH_PATH="/tmp/$(whoami)-cs4414grading"

printf "Submission path: %s\n" "$SUBMISSIONS_PATH"
printf "Computing ID:    %s\n" "$CID"

# Make sure these exist at these paths!
TRIVIAL_IMAGE_PATH="$HOME/trivial.img"
TRIVIAL_IMAGE_REF_OUTPUT="$HOME/trivial.out"
OTHER_IMAGE_PATH="$HOME/other.img"
OTHER_IMAGE_REF_OUTPUT="$HOME/other.out"

# Check to see if the program created a CSV file instead of printing to stdout.
# Rename the file accordingly.
CSV_RENAME_TARGET=''
function check_for_csv() {
    csv="$(find . -mindepth 1 -maxdepth 1 -type f -name \*.csv)"
    if [ -n "$csv" ]
    then
        printf "Submission created CSV file '%s'.\n" "$csv"
        sort "$csv" >"$(pwd)"/"$CSV_RENAME_TARGET"
        rm "$csv"
    fi
}

module load gcc python3

cd "$SUBMISSIONS_PATH"/*\($COMPUTING_ID\)*/"Submission attachment(s)"/
a="$(find . -type f -name \*.tar.gz -or -name \*.tgz -or -name \*.tar)"
if [ -z "$a" ]
then
    printf "Could not find archive for %s.\n" "$CID"
    exit 1
else
    printf "Archive is at %s.\n" "$a"
fi

# Clear the scratch path.
if [ "$CLEAN_SCRATCH" = "y" ]
then
    rm -rf "$SCRATCH_PATH"
    mkdir "$SCRATCH_PATH"
    tar -xf "$a" -C "$SCRATCH_PATH"
else
    printf "Rerunning what's in scratch path.\n"
fi

cd "$SCRATCH_PATH"

# Copy image files into the scratch directory.
cp "$TRIVIAL_IMAGE_PATH" .
cp "$OTHER_IMAGE_PATH" .

# First look for a Python script.
py="$(find . -type f -name \*.py)"
if [ -n "$py" ]
then
    printf "Submitted Python script.\n"
    if [ ! -e './fsdump.py' ]
    then
        mv "$py" "./fsdump.py"
    fi

    # Make sure the program works.
    python3 ./fsdump.py "$TRIVIAL_IMAGE_PATH" >/dev/null 2>&1
    if [ "$?" != "0" ]
    then
        printf "Program is not running; try running it manually.\n"
        exit 1
    fi

    python3 ./fsdump.py ./trivial.img 2>/dev/null | sort >student-trivial.out
    if [ "$?" != "0" ]
    then
        printf "Program failed to run successfully against trivial disk image.\n"
        exit 1
    fi
    CSV_RENAME_TARGET='student-trivial.out'
    check_for_csv

    python3 ./fsdump.py ./other.img 2>/dev/null | sort >student-other.out
    if [ "$?" != "0" ]
    then
        printf "Program failed to run successfully against other disk image.\n"
        exit 1
    fi
    CSV_RENAME_TARGET='student-other.out'
    check_for_csv
else
    printf "Python script not found; assuming using Makefile.\n"
    # Find the makefile.
    makefile_path="$(find . -type f -name Makefile -or -name makefile -or -name GNUMakefile)"
    if [ -z "$makefile_path" ]
    then
        printf "No makefile found!\n"
        exit 1
    fi

    printf "Found makefile at %s\n" "$makefile_path"
    makefile_dir_path="$(dirname "$makefile_path")"

    printf "Building...\n"
    make -C "$makefile_dir_path"
    if [ "$?" != "0" ]
    then
        printf "Build failed.\n"
        exit 1
    fi

    # Move fsdump to this directory.
    if [ ! -e './fsdump' ]
    then
        find . -type f -name 'fsdump' -exec mv {} . \;
    fi

    printf "Running submission...\n"
    ./fsdump ./trivial.img 2>/dev/null | sort >student-trivial.out
    if [ "$?" != "0" ]
    then
        printf "Program failed to run successfully against trivial disk image.\n"
        exit 1
    fi
    CSV_RENAME_TARGET='student-trivial.out'
    check_for_csv

    ./fsdump ./other.img 2>/dev/null | sort >student-other.out
    if [ "$?" != "0" ]
    then
        printf "Program failed to run successfully against other disk image.\n"
        exit 1
    fi
    CSV_RENAME_TARGET='student-other.out'
    check_for_csv
fi

# Create diffs.
printf "Creating diffs...\n"
diff "$TRIVIAL_IMAGE_REF_OUTPUT" student-trivial.out >trivial.diff
diff "$OTHER_IMAGE_REF_OUTPUT" student-other.out >other.diff

# See if the diffs have content.
printf "Checking diffs...\n"

if [ -s trivial.diff ]
then
    printf "Trivial diff is not empty. Needs review (left: reference, right: submission)... press enter and view.\n"
    read
    less trivial.diff
fi

if [ -s other.diff ]
then
    printf "Other diff is not empty. Needs review (left: reference, right: submission)... press enter and view.\n"
    read
    less other.diff
fi

exit 0
