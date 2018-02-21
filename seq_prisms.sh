#!/bin/bash


function get_opts() {

   PWD0=$PWD
   DRY_RUN=no
   DEBUG=no

   help_text="
\n
./seq_prisms.sh  [-n] -D datadir -O outdir [-C local|slurm ] [ -T taxonomy|kmer|bwa|fastqc ] -S [file name suffix e.g. trimmed or fastq.gz etc]\n
\n
"

   # defaults:
   TARGET="all"
   HPCTYPE="slurm"
   FASTQ_FILE_SUFFIX=.fastq.gz
   while getopts ":ndhR:D:E:b:t:m:M:T:C:F:S:s:" opt; do
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
         HPCTYPE=$OPTARG
         ;;
       T)
         TARGET=$OPTARG
         ;;
       S)
         FASTQ_FILE_SUFFIX=$OPTARG
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
}



function check_opts() {
   if [ ! -d OUT_DIR ]; then
      echo "OUT_DIR $OUT_DIR not found ( you might need to supply the full path $PWD0/$OUT_DIR ? ) "
      exit 1
   fi
   if [ ! -d DATA_DIR ]; then
      echo "DATA_DIR $DATA_DIR not found ( you might need to supply the full path $PWD0/$DATA_DIR ? ) "
      exit 1
   fi
   if [[ $TARGET != "all" && $TARGET != "fastqc" && $TARGET != "bwa" && $TARGET != "taxonomy" && $TARGET != "kmer" ]]; then
      echo "target must be one of all, fastqc, bwa, taxonomy, kmer"
      exit 1
   fi
   if [[ $HPCTYPE != "local" && $HPCTYPE != "slurm" ]]; then
      echo "HPCTYPE must be one of local, slurm"
      exit 1
   fi
}

function echo_opts() {
  echo DATA_DIR=$DATA_DIR
  echo OUT_DIR=$OUT_DIR
  echo DRY_RUN=$DRY_RUN
  echo DEBUG=$DEBUG
  echo HPCTYPE=$HPCTYPE
}

#
# edit this method to set required environment (or set up
# before running this script)
#
function configure_env() {
   cd $SEQ_PRISMS_BIN
   cp seq_prisms.sh $OUT_DIR
   cp seq_prisms.mk $OUT_DIR
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
   make -n -f seq_prisms.mk -d  --no-builtin-rules -j 16 fastq_file_suffix=$FASTQ_FILE_SUFFIX data_dir=$DATA_DIR out_dir=$OUT_DIR $OUT_DIR/seq_prisms.log > $OUT_DIR/fake_prisms.log 2>&1
   exit 0
   # make a precis of the log file
   # cat build${METHOD}.logprecis 
}

function run_prisms() {
   # make a precis of the log file
   # cat build${METHOD}.logprecis 
}


function main() {
   get_opts $@
   check_opts
   echo_opts
   check_env
   configure_env
   if [ $DRY_RUN != "n" ]; then
      fake_prisms
   else
      run_prisms
   fi
}
