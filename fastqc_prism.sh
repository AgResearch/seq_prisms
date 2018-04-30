#!/bin/bash

function get_opts() {

   PWD0=$PWD
   DRY_RUN=no
   DEBUG=no
   HPC_TYPE=slurm
   FILES=""
   OUT_DIR=""
   DATA_DIR=""
   MAX_TASKS=50

   help_text="
\n
./seq_prisms.sh  [-h] [-n] [-d] -D datadir -O outdir [-C local|slurm ] input_file_names\n
\n
\n
example:\n
fastqc_prism.sh -n -D /dataset/Tash_FL1_Ryegrass/ztmp/For_Alan -O /dataset/Tash_FL1_Ryegrass/ztmp/seq_qc/test/fastqc  /dataset/Tash_FL1_Ryegrass/ztmp/For_Alan/*.fastq.gz\n
\n
"

   # defaults:
   while getopts ":nhO:C:D:m:" opt; do
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
   mkdir -p $OUT_DIR
   if [ ! -d $OUT_DIR ]; then
      echo "OUT_DIR $OUT_DIR not found/could not create"
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
}

#
# edit this method to set required environment (or set up
# before running this script)
#
function configure_env() {
   cd $SEQ_PRISMS_BIN
   cp ./fastqc_prism.sh $OUT_DIR
   cp ./fastqc_prism.mk $OUT_DIR
   cat >$OUT_DIR/tardis.toml <<EOF
max_tasks = $MAX_TASKS
EOF
   cd $OUT_DIR
}


function check_env() {
   if [ -z "$SEQ_PRISMS_BIN" ]; then
      echo "SEQ_PRISMS_BIN not set - exiting"
      exit 1
   fi
}

function get_targets() {
   TARGETS=""
   for file in $FILES; do
      base=`basename $file`
      TARGETS="$TARGETS $OUT_DIR/${base}.fastqc_prism"
   done 
}


function fake_prism() {
   echo "dry run ! "
   make -n -f fastqc_prism.mk -d -k  --no-builtin-rules -j 16 hpc_type=$HPC_TYPE data_dir=$DATA_DIR out_dir=$OUT_DIR  $TARGETS > $OUT_DIR/fastqc_prism.log 2>&1
   exit 0
}

function run_prism() {
   make -f fastqc_prism.mk -d -k  --no-builtin-rules -j 16 hpc_type=$HPC_TYPE data_dir=$DATA_DIR out_dir=$OUT_DIR $TARGETS > $OUT_DIR/fastqc_prism.log 2>&1
}

function html_prism() {
   echo "tba" > $OUT_DIR/fastqc_prism.html 2>&1
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
         echo "error state from fastqc run - skipping html page generation"
         exit 1
      fi
   fi
}


set -x
main $@
set +x

