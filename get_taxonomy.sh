#!/bin/bash

export SEQ_PRISMS_BIN=/dataset/gseq_processing/active/bin/melseq_prism/seq_prisms

declare -a files_array

function get_opts() {

   DRY_RUN=no
   DEBUG=no
   HPC_TYPE=local   # testing has found problems connecting to the SQLlite database, if jobs are launched on cluster nodes
   OUT_DIR=
   ACC_COL=1
   USE_BASE=TRUE
   RESULT_FORMAT=taxa
   DB_DIR=/dataset/gseq_processing/scratch/taxonomizr
   help_text="
\n
get_taxonomy.sh  [-h] [-c (accession column, default 1)] [-b (use base, TRUE|FALSE default TRUE)] [-f (result format, taxa|taxid, default taxa)] [-d (db dir default /dataset/gseq_processing/scratch/taxonomizr) ]  -O outdir input_file_names\n
\n
\n
example:\n
get_taxonomy.sh -c 2 -b TRUE -f taxid  -O ~ test.dat \n
get_taxonomy.sh -c 2 -b TRUE -f taxa  -O ~ test1.dat test2.dat test3.dat\n
\n
example input:\n
\n
879     CP017297.1\n
879     CP017707.1\n
879     CP028287.1\n
880     CP032707.1\n
\n
"

   # defaults:
   while getopts ":hO:b:f:d:c:" opt; do
   case $opt in
       h)
         echo -e $help_text
         exit 0
         ;;
       O)
         OUT_DIR=$OPTARG
         ;;
       c)
         ACC_COL=$OPTARG
         ;;
       b)
         USE_BASE=$OPTARG   
         ;;
       f)
         RESULT_FORMAT=$OPTARG
         ;;
       d)
         DB_DIR=$OPTARG
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

   FILE_STRING=$@

   # this is needed because of the way we process args a "$@" - which 
   # is needed in order to parse parameter sets to be passed to the 
   # aligner (which are space-separated)
   declare -a files="(${FILE_STRING})";
   NUM_FILES=${#files[*]}
   for ((i=0;$i<$NUM_FILES;i=$i+1)) do
      files_array[$i]=${files[$i]}     
   done
}


function check_opts() {
   if [  -z "$OUT_DIR" ]; then
      echo "must specify OUT_DIR ( -O )"
      exit 1
   fi
   if [ ! -d $OUT_DIR ]; then
      echo "OUT_DIR $OUT_DIR not found"
      exit 1
   fi

   python -c "print int('$ACC_COL')" >/dev/null 2>&1
   if [ $? != 0 ]; then
      echo "looks like the accession column number ( $ACC_COL ) is not a number"
      exit 1
   fi

   if [[ $USE_BASE != "TRUE" && $USE_BASE != "FALSE" ]]; then
      echo "USE_BASE must be either TRUE or FALSE"
      exit 1
   fi

   if [[ $RESULT_FORMAT != "taxid" && $RESULT_FORMAT != "taxa" ]]; then
      echo "result format ( $RESULT_FORMAT ) must be either taxid or taxa"
      exit 1
   fi

   if [ ! -f $DB_DIR/accessionTaxa.sql ]; then
      echo "could not find database file accessionTaxa.sql in the database folder specified ( $DB_DIR )"
      exit 1
   fi

}

function echo_opts() {
  echo OUT_DIR=$OUT_DIR
  echo ACC_COL=$ACC_COL
  echo USE_BASE=$USE_BASE
  echo RESULT_FORMAT=$RESULT_FORMAT
  echo DB_DIR=$DB_DIR
}

#
# edit this method to set required environment (or set up
# before running this script)
#
function configure_env() {
   cd $OUT_DIR
}


function check_env() {
   if [ -z "$SEQ_PRISMS_BIN" ]; then
      echo "SEQ_PRISMS_BIN not set - exiting"
      exit 1
   fi
}

function run() {
   for ((j=0;$j<$NUM_FILES;j=$j+1)) do
      infile=${files_array[$j]}
      outbase=`basename $infile`
      set -x
      tardis -c 5000 --hpctype local --shell-include-file $SEQ_PRISMS_BIN/etc/r-taxonomizr_env.inc  Rscript --vanilla $SEQ_PRISMS_BIN/get_taxonomy.r in_file=_condition_text_input_$infile acc_col=$ACC_COL use_base=$USE_BASE result_format=$RESULT_FORMAT db_dir=$DB_DIR \>_condition_uncompressedtext_output_$OUT_DIR/${outbase}.taxonomy 2\>_condition_uncompressedtext_output_$OUT_DIR/${outbase}.stderr
      set +x
   done
}


function clean() {
   echo ""
}


function main() {
   get_opts "$@"
   check_opts
   echo_opts
   check_env
   run
   if [ $? == 0 ] ; then
      clean
   else
      echo "error state from run - skipping clean"
      exit 1
   fi
}


main "$@"
