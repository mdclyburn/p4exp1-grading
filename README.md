p4exp1 grading
=====

A script for diffing p4exp1 submissions.
The script runs submissions from a given directory against two disk images,
`trivial.img` and `other.img`.
It creates files containing the stdout output of submission programs
and diffs them against the reference output,
`trivial.out` and `other.out`.
It displays non-zero diffs from the CLI

Setup
-----

The script expects the disk images and the reference output files to be in the `$HOME` directory.
This is easily changeable by updating the variables in the script.
Run the script with:
`./autodiff.sh [ -r ] <path-to-submissions> <computing ID>`.

The `-r` option will skip cleaning the scratch directory and unarchiving the submission.
This is useful if manual intervention is necessary and you want to re-run the diffing process
after the manual intervention.
