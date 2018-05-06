#!/bin/bash

function get_opts() {

   PWD0=$PWD
   DRY_RUN=no
   DEBUG=no
   HPC_TYPE=slurm
   FILES=""
   OUT_DIR=""
   DATA_DIR=""
   SAMPLE_RATE=".0002"
   MAX_TASKS=50


   help_text="
\n
./bwa_prism.sh  [-h] [-n] [-d] [-s SAMPLE_RATE] -D datadir -O outdir [-C local|slurm ] input_file_names\n
\n
\n
example:\n
bwa_prism.sh -n -D /dataset/Tash_FL1_Ryegrass/ztmp/For_Alan -O /dataset/Tash_FL1_Ryegrass/ztmp/seq_qc/test/fastqc  /dataset/Tash_FL1_Ryegrass/ztmp/For_Alan/*.fastq.gz\n
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
   cp ./bwa_prism.sh $OUT_DIR
   cp ./bwa_prism.mk $OUT_DIR
   cp ./collate_mapping_stats.py $OUT_DIR
   cp ./mapping_stats_plots.r $OUT_DIR
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
      TARGETS="$TARGETS $OUT_DIR/${base}.bwa_prism"
   done 
}


function fake_prism() {
   echo "dry run ! "
   make -n -f bwa_prism.mk -d -k  --no-builtin-rules -j 16 hpc_type=$HPC_TYPE sample_rate=$SAMPLE_RATE data_dir=$DATA_DIR out_dir=$OUT_DIR  $TARGETS > $OUT_DIR/bwa_prism.log 2>&1
   echo "dry run : summary commands are 
   tardis.py -q --hpctype $HPC_TYPE -d $OUT_DIR $OUT_DIR/collate_mapping_stats.py $OUT_DIR/*.stats > $OUT_DIR/stats_summary.txt
   tardis.py --hpctype $HPC_TYPE -d $OUT_DIR Rscript --vanilla  $OUT_DIR/mapping_stats_plots.r datafolder=$OUT_DIR
   "
   exit 0
}

function run_prism() {
   make -f bwa_prism.mk -d -k  --no-builtin-rules -j 16 hpc_type=$HPC_TYPE sample_rate=$SAMPLE_RATE data_dir=$DATA_DIR out_dir=$OUT_DIR $TARGETS > $OUT_DIR/bwa_prism.log 2>&1
   tardis.py -q --hpctype $HPC_TYPE -d $OUT_DIR $OUT_DIR/collate_mapping_stats.py $OUT_DIR/*.stats > $OUT_DIR/stats_summary.txt
   tardis.py --hpctype $HPC_TYPE -d $OUT_DIR Rscript --vanilla  $OUT_DIR/mapping_stats_plots.r datafolder=$OUT_DIR
}

function html_prism() {
   echo "tba" > $OUT_DIR/bwa_prism.html 2>&1
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
         echo "error state from bwa run - skipping html page generation"
         exit 1
      fi
   fi
}


set -x
main $@
set +x

