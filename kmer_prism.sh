#!/bin/bash

declare -a files_array

function get_opts() {

   DRY_RUN=no
   DEBUG=no
   HPC_TYPE=slurm
   FILES=
   OUT_DIR=
   SAMPLE_RATE=
   KMER_PARAMETERS="-k 6"
   MAX_TASKS=1
   MIMIMUM_SAMPLE_SIZE=0
   KMERER=fasta
   FORCE=np


   help_text="
\n
./kmer_prism.sh  [-h] [-n] [-d] [-s SAMPLE_RATE] [-p kmeroptions ] [ -a fasta|fastq] -D datadir -O outdir [-C local|slurm ] input_file_names\n
\n
\n
example:\n
kmer_prism.sh -n -D /dataset/Tash_FL1_Ryegrass/ztmp/For_Alan -O /dataset/Tash_FL1_Ryegrass/ztmp/seq_qc/test/fastqc  /dataset/Tash_FL1_Ryegrass/ztmp/For_Alan/*.fastq.gz\n
\n
"

   # defaults:
   while getopts ":nhfO:C:s:M:p:a:" opt; do
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
       f)
         FORCE=yes
         ;;
       O)
         OUT_DIR=$OPTARG
         ;;
       C)
         HPC_TYPE=$OPTARG
         ;;
       s)
         SAMPLE_RATE=$OPTARG
         ;;
       M)
         MINIMUM_SAMPLE_SIZE=$OPTARG
         ;;
       p)
         KMER_PARAMETERS=$OPTARG
         ;;
       a)
         KMERER=$OPTARG
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
  echo KMER_SIZE=$KMER_SIZE
  echo KMERER=$KMERER
  echo MINIMUM_SAMPLE_SIZE=$MINIMUM_SAMPLE_SIZE
  echo KMER_PARAMETERS=$KMER_PARAMETERS 

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
min_sample_size=$MINIMUM_SAMPLE_SIZE
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

   rm -f $OUT_DIR/kmer_targets.txt


   TARGETS1=""
   TARGETS2=""
   for file in $FILES; do
      base=`basename $file`
      TARGETS1="$TARGETS1 $OUT_DIR/${base}.kmer_prism"
      TARGETS2="$TARGETS2 $OUT_DIR/${base}"
   done 

   sample_phrase=""
   if [ ! -z $SAMPLE_RATE ]; then
      sample_phrase="-s $SAMPLE_RATE"
   fi 

   
   for ((j=0;$j<$NUM_FILES;j=$j+1)) do
      file=${files_array[$j]}
      file_base=`basename $file`
      parameters_moniker=$KMER_SIZE
      kmerer_moniker=${file_base}.${KMERER}.${parameters_moniker}
      echo $TARGETS $OUT_DIR/${kmerer_moniker}.kmer_prism >> $OUT_DIR/kmer_targets.txt

      # generate wrapper
      kmerer_filename=$OUT_DIR/${kmerer_moniker}.sh

      if [ -f kmerer_filename ]; then
         if [ ! $FORCE == yes ]; then
            echo "found existing kmerer $kmerer_filename - will re-use (use -f to force rebuild of kmerers) "
            continue
         fi
      fi

      if [ $KMERER == fasta ]; then
         echo "#!/bin/bash
	tardis -hpctype $HPC_TYPE -d  $OUT_DIR  $sample_phrase -shell-include-file configure_env.sh cat _condition_fasta_input_$file  \> _condition_text_output_$OUT_DIR/${sampler_moniker}.fasta
        " > $kmerer_filename 
      elif [ $KMERER == fastq ]; then
         echo "#!/bin/bash
source /dataset/bioinformatics_dev/scratch/tardis/bin/activate
	tardis -hpctype $HPC_TYPE -d  $OUT_DIR  $sample_phrase -shell-include-file configure_env.sh kmer_prism.py $KMER_PARAMETERS  _condition_fastq2fasta_input_$file  \> _condition_text_output_$OUT_DIR/${kmerer_moniker}.log
         " > $kmerer_filename
      else 
         echo "unsupported kmerer  $KMERER "
         exit 1
      fi
      chmod +x $sampler_filename
   done 
}


function fake_prism() {
   echo "dry run ! "
   make -n -f kmer_prism.mk -d -k  --no-builtin-rules -j 16 `cat $OUT_DIR/kmer_targets.txt` > $OUT_DIR/kmer_prism.log 2>&1
   echo "dry run : summary commands are 
   "
   exit 0
}

function run_prism() {
   # this distributes the kmer distribtion builds for each file across the cluster
   make -f kmer_prism.mk -d -k  --no-builtin-rules -j 16 `cat $OUT_DIR/kmer_targets.txt` > $OUT_DIR/kmer_prism.log 2>&1
   # this uses the pickled distributions to make the final spectra
   tardis.py -hpctype $HPC_TYPE -d $OUT_DIR -shell-include-file configure_env.sh kmer_prism.py -k 6 -t zipfian -o $OUT_DIR/kmer_summary_plus.txt -b $OUT_DIR $TARGETS2
   tardis.py -hpctype $HPC_TYPE -d $OUT_DIR -shell-include-file configure_env.sh kmer_prism.py -k 6 -t frequency -o $OUT_DIR/kmer_frequency_plus.txt -b $OUT_DIR $TARGETS2
   tardis.py -hpctype $HPC_TYPE -d $OUT_DIR -shell-include-file configure_env.sh kmer_prism.py -k 6 -a CGAT -t zipfian -o $OUT_DIR/kmer_summary.txt -b $OUT_DIR $TARGETS2
   tardis.py -hpctype $HPC_TYPE -d $OUT_DIR -shell-include-file configure_env.sh kmer_prism.py -k 6 -a CGAT -t frequency -o $OUT_DIR/kmer_frequency.txt -b $OUT_DIR $TARGETS2
   # do plots. This will fail until we sort out R env - need to run manually 
   #/dataset/bioinformatics_dev/active/R3.3/R-3.3.0/bin/Rscript --vanilla  $(GBS_BIN)/kmer_plots_gbs.r datafolder=$(dir $@)
   tardis.py -hpctype $HPC_TYPE -d $OUT_DIR Rscript --vanilla $OUT_DIR/kmer_plots_gbs.r datafolder=$OUT_DIR
}

function html_prism() {
   echo "tba" > $OUT_DIR/kmer_prism.html 2>&1
}


function main() {
   get_opts "$@"
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
main "$@"
set +x

