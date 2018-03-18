#!/bin/bash

function get_opts() {

   PWD0=$PWD
   DRY_RUN=no
   DEBUG=no
   HPC_TYPE=slurm
   FILES=
   OUT_DIR=
   DATA_DIR=
   SAMPLE_RATE=
   MAX_TASKS=50


   help_text="
\n
./kmer_prism.sh  [-h] [-n] [-d] [-s SAMPLE_RATE] -D datadir -O outdir [-C local|slurm ] input_file_names\n
\n
\n
example:\n
kmer_prism.sh -n -D /dataset/Tash_FL1_Ryegrass/ztmp/For_Alan -O /dataset/Tash_FL1_Ryegrass/ztmp/seq_qc/test/fastqc  /dataset/Tash_FL1_Ryegrass/ztmp/For_Alan/*.fastq.gz\n
\n
"

   # defaults:
   while getopts ":nhO:C:D:s:m:" opt; do
   case $opt in
       n)
         DRY_RUN=yes
         ;;
       d)
         DEBUG=yes
         ;;
       h)
         echo -e $help_text
         exit 0
         ;;
       O)
         OUT_DIR=$OPTARG
         ;;
       D)
         DATA_DIR=$OPTARG
         ;;
       C)
         HPC_TYPE=$OPTARG
         ;;
       s)
         SAMPLE_RATE=$OPTARG
         ;;
       m)
         MAX_TASKS=$OPTARG
         ;;
       \?)
         echo "Invalid option: -$OPTARG" >&2
         exit 1
         ;;
       :)
         echo "Option -$OPTARG requires an argument." >&2
         exit 1
         ;;
     esac
   done

   shift $((OPTIND-1))

   FILES=$@
}


function check_opts() {
   if [ ! -d $OUT_DIR ]; then
      echo "OUT_DIR $OUT_DIR not found"
      exit 1
   fi
   if [ ! -d $DATA_DIR ]; then
      echo "DATA_DIR $DATA_DIR not found"
      exit 1
   fi

   if [[ $HPC_TYPE != "local" && $HPC_TYPE != "slurm" ]]; then
      echo "HPC_TYPE must be one of local, slurm"
      exit 1
   fi
}

function echo_opts() {
  echo DATA_DIR=$DATA_DIR
  echo OUT_DIR=$OUT_DIR
  echo DRY_RUN=$DRY_RUN
  echo DEBUG=$DEBUG
  echo HPC_TYPE=$HPC_TYPE
  echo FILES=$FILES
  echo SAMPLE_RATE=$SAMPLE_RATE
}

#
# edit this method to set required environment (or set up
# before running this script)
#
function configure_env() {
   cd $SEQ_PRISMS_BIN
   cp ./kmer_prism.sh $OUT_DIR
   cp ./kmer_prism.mk $OUT_DIR
   cp ./kmer_prism.py $OUT_DIR
   cp ./data_prism.py $OUT_DIR
   cp ./kmer_plots.r $OUT_DIR
   echo "
[tardish]
[tardis_engine]
max_tasks=$MAX_TASKS
" > $OUT_DIR/.tardishrc
   echo "
source activate /dataset/bioinformatics_dev/active/conda-env/biopython
PATH="$OUT_DIR:$PATH"
PYTHONPATH="$OUT_DIR:$PYTHONPATH"
" > $OUT_DIR/configure_env.sh
   cd $OUT_DIR
}


function check_env() {
   if [ -z "$SEQ_PRISMS_BIN" ]; then
      echo "SEQ_PRISMS_BIN not set - exiting"
      exit 1
   fi
}

function get_targets() {
   TARGETS1=""
   TARGETS2=""
   for file in $FILES; do
      base=`basename $file`
      TARGETS1="$TARGETS1 $OUT_DIR/${base}.kmer_prism"
      TARGETS2="$TARGETS2 $OUT_DIR/${base}"
   done 
}


function fake_prism() {
   echo "dry run ! "
   make -n -f kmer_prism.mk -d -k  --no-builtin-rules -j 16 hpc_type=$HPC_TYPE sample_rate=$SAMPLE_RATE data_dir=$DATA_DIR out_dir=$OUT_DIR  $TARGETS > $OUT_DIR/kmer_prism.log 2>&1
   echo "dry run : summary commands are 
   tardis.py -q -hpctype $HPC_TYPE -d $OUT_DIR $OUT_DIR/kmer_prism.py -s .00015 -t zipfian -k 8 -p 30 -o zipfian8.txt -b /dataset/Tash_FL1_Ryegrass/ztmp/seq_qc/kmer_analysis /dataset/Tash_FL1_Ryegrass/ztmp/For_Alan/*.fastq.gz

   tardis.py -hpctype $HPC_TYPE -d $OUT_DIR Rscript --vanilla  $OUT_DIR/mapping_stats_plots.r datafolder=$OUT_DIR
   "
   exit 0
}

function run_prism() {
   # this distributes the kmer distribtion builds for each file across the cluster
   make -f kmer_prism.mk -d -k  --no-builtin-rules -j 16 hpc_type=$HPC_TYPE sample_rate=$SAMPLE_RATE data_dir=$DATA_DIR out_dir=$OUT_DIR $TARGETS1 > $OUT_DIR/kmer_prism.log 2>&1
   # this uses the pickled distributions to make the final spectra
   tardis.py -hpctype $HPC_TYPE -d $OUT_DIR -shell-include-file configure_env.sh kmer_prism.py -k 6 -t zipfian -o $OUT_DIR/kmer_summay.txt -b $OUT_DIR $TARGETS2
   tardis.py -hpctype $HPC_TYPE -d $OUT_DIR -shell-include-file configure_env.sh kmer_prism.py -k 6 -t frequency -o $OUT_DIR/kmer_frequency.txt -b $OUT_DIR $TARGETS2
   # do plots. This will fail until we sort out R env - need to run manually 
   #/dataset/bioinformatics_dev/active/R3.3/R-3.3.0/bin/Rscript --vanilla  $(GBS_BIN)/kmer_plots_gbs.r datafolder=$(dir $@)
   tardis.py -hpctype $HPC_TYPE -d $OUT_DIR Rscript --vanilla $OUT_DIR/kmer_plots_gbs.r datafolder=$OUT_DIR
}

function html_prism() {
   echo "tba" > $OUT_DIR/kmer_prism.html 2>&1
}


function main() {
   get_opts $@
   check_opts
   echo_opts
   check_env
   get_targets
   configure_env
   if [ $DRY_RUN != "no" ]; then
      fake_prism
   else
      run_prism
      if [ $? == 0 ] ; then
         html_prism
      else
         echo "error state from kmer run - skipping html page generation"
         exit 1
      fi
   fi
}


set -x
main $@
set +x

