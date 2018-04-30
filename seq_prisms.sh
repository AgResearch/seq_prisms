#!/bin/bash


function get_opts() {

   PWD0=$PWD
   DRY_RUN=no
   DEBUG=no
   HPC_TYPE=slurm
   FILES=""
   OUT_DIR=""
   DATA_DIR=""
   SAMPLE_RATE=.002
   MAX_TASKS=50

   help_text="
\n
./seq_prisms.sh [-h] [-n] [-d] -D datadir -O outdir [-C local|slurm ] files \n
\n
"

   while getopts ":ndhD:O:C:s:m:" opt; do
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
      echo "OUT_DIR $OUT_DIR not found ( you might need to supply the full path $PWD0/$OUT_DIR ? ) "
      exit 1
   fi
   if [ ! -d $DATA_DIR ]; then
      echo "DATA_DIR $DATA_DIR not found ( you might need to supply the full path $PWD0/$DATA_DIR ? ) "
      exit 1
   fi
   if [[ $HPC_TYPE != "local" && $HPC_TYPE != "slurm" ]]; then
      echo "HPC_TYPE must be one of local, slurm"
      exit 1
   fi

   if [ -z $FILES ] ; then
      echo "must specify at least one file to analyse"
      exit 1
   fi

   for file in $FILES; do
      if [ ! -f $file ]; then
         echo "at least one file ( $file ) not found - giving up"
      fi
   done
}

function echo_opts() {
  echo DATA_DIR=$DATA_DIR
  echo OUT_DIR=$OUT_DIR
  echo DRY_RUN=$DRY_RUN
  echo DEBUG=$DEBUG
  echo HPC_TYPE=$HPC_TYPE
  echo SAMPLE_RATE=$SAMPLE_RATE
}

#
# edit this method to set required environment (or set up
# before running this script)
#
function configure_env() {
   cd $SEQ_PRISMS_BIN
   cp seq_prisms.sh $OUT_DIR
   cp seq_prisms.mk $OUT_DIR
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


function fake_prisms() {
   echo "dry run ! "
   make -n -f seq_prisms.mk -d -k  --no-builtin-rules -j 16 dry_run=$DRY_RUN hpc_type=$HPC_TYPE seq_files="$FILES" data_dir=$DATA_DIR out_dir=$OUT_DIR sample_rate=$SAMPLE_RATE $OUT_DIR/seq_prisms.html > $OUT_DIR/fake_prisms.log 2>&1
   exit 0
   # make a precis of the log file
   # cat build${METHOD}.logprecis 
}

function run_prisms() {
   # make a precis of the log file
   make -f seq_prisms.mk -d -k --no-builtin-rules -j 16 dry_run=$DRY_RUN hpc_type=$HPC_TYPE seq_files="$FILES" data_dir=$DATA_DIR out_dir=$OUT_DIR sample_rate=$SAMPLE_RATE $OUT_DIR/seq_prisms.html > $OUT_DIR/seq_prisms.log 2>&1
}


function main() {
   get_opts $@
   check_opts
   echo_opts
   check_env
   configure_env
   if [ $DRY_RUN != "no" ]; then
      fake_prisms
   else
      run_prisms
   fi
}

set -x
main $@
set +x
