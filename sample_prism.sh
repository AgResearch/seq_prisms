#!/bin/bash

declare -a files_array

function get_opts() {

   PWD0=$PWD
   DRY_RUN=no
   DEBUG=no
   HPC_TYPE=slurm
   FILES=""
   OUT_DIR=""
   SAMPLE_RATE=""
   MAX_TASKS=1
   MINIMUM_SAMPLE_SIZE=0
   SAMPLER=fastq


   help_text="
\n
./sample_prism.sh  [-h] [-n] [-d] [-s SAMPLE_RATE] [-M minimum sample size] -a sampler -O outdir [-C local|slurm ] input_file_names\n
\n
\n
example:\n
sample_prism.sh -n -D /dataset/Tash_FL1_Ryegrass/ztmp/For_Alan -O /dataset/Tash_FL1_Ryegrass/ztmp/seq_qc/test/fastqc  /dataset/Tash_FL1_Ryegrass/ztmp/For_Alan/*.fastq.gz\n
\n
"

   # defaults:
   while getopts ":nhO:C:D:s:m:M:a:" opt; do
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
       C)
         HPC_TYPE=$OPTARG
         ;;
       s)
         SAMPLE_RATE=$OPTARG
         ;;
       a)
         SAMPLER=$OPTARG
         ;;
       m)
         MAX_TASKS=$OPTARG
         ;;
       M)
         MINIMUM_SAMPLE_SIZE=$OPTARG
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
   if [ ! -d $OUT_DIR ]; then
      echo "OUT_DIR $OUT_DIR not found"
      exit 1
   fi

   if [[ $HPC_TYPE != "local" && $HPC_TYPE != "slurm" ]]; then
      echo "HPC_TYPE must be one of local, slurm"
      exit 1
   fi

   if [[ $SAMPLER != "fasta" && $SAMPLER != "fastq" && $SAMPLER != "paired_fastq" ]]; then
      echo "SAMPLER must be fasta or fastq"
      exit 1
   fi

}

function echo_opts() {
  echo OUT_DIR=$OUT_DIR
  echo DRY_RUN=$DRY_RUN
  echo DEBUG=$DEBUG
  echo HPC_TYPE=$HPC_TYPE
  echo FILES=${files_array[*]}
  echo SAMPLE_RATE=$SAMPLE_RATE
  echo SAMPLER=$SAMPLER
  echo MINIMUM_SAMPLE_SIZE=$MINIMUM_SAMPLE_SIZE

}


#
# edit this method to set required environment (or set up
# before running this script)
#
function configure_env() {
   cd $SEQ_PRISMS_BIN
   cp ./sample_prism.sh $OUT_DIR
   cp ./sample_prism.mk $OUT_DIR
   cat >$OUT_DIR/tardis.toml <<EOF
max_tasks = $MAX_TASKS
min_sample_size = $MINIMUM_SAMPLE_SIZE
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
   # make a target moniker for each input file and write associated 
   # sampler wrapper, which will be called by make 

   rm -f $OUT_DIR/sampling_targets.txt

   sample_phrase=""
   if [ ! -z $SAMPLE_RATE ]; then
      sample_phrase="-s $SAMPLE_RATE"
   fi 

  
   file1=""
   file2=""
   for ((j=0;$j<$NUM_FILES;j=$j+1)) do
      file=${files_array[$j]}
      file_base=`basename $file`
      parameters_moniker=`echo $sample_phrase | sed 's/ //g' | sed 's/\//\./g' | sed 's/-//g'`
      sampler_moniker=${file_base}.${SAMPLER}.${parameters_moniker}
      echo $OUT_DIR/${sampler_moniker}.sample_prism >> $OUT_DIR/sampling_targets.txt

      # generate wrapper
      sampler_filename=$OUT_DIR/${sampler_moniker}.sh

      if [ -f sampler_filename ]; then
         if [ ! $FORCE == yes ]; then
            echo "found existing sampler $sampler_filename - will re-use (use -f to force rebuild of samplers) "
            continue
         fi
      fi

      if [ $SAMPLER == fasta ]; then
         echo "#!/bin/bash
source /dataset/bioinformatics_dev/scratch/tardis/bin/activate
	tardis --hpctype $HPC_TYPE -d  $OUT_DIR  $sample_phrase cat _condition_fastq2fasta_input_$file  \> _condition_text_output_$OUT_DIR/${sampler_moniker}.fasta
        " > $sampler_filename
      elif [ $SAMPLER == fastq ]; then
         echo "#!/bin/bash
source /dataset/bioinformatics_dev/scratch/tardis/bin/activate
	tardis --hpctype $HPC_TYPE -d  $OUT_DIR  $sample_phrase cat _condition_fastq_input_$file  \> _condition_text_output_$OUT_DIR/${sampler_moniker}.fastq
         " > $sampler_filename
      elif [ $SAMPLER == paired_fastq ]; then
        if [ -z $file2 ]; then 
           file2=$file
           continue
        elif [ -z $file1 ]; then
           file1=$file2
           file2=$file
         echo "#!/bin/bash
source /dataset/bioinformatics_dev/scratch/tardis/bin/activate
	tardis --hpctype $HPC_TYPE -d  $OUT_DIR  $sample_phrase cat _condition_pairedfastq_input_$file1  \> _condition_text_output_$OUT_DIR/${sampler_moniker}_1.fasta \; cat _condition_pairedfastq_input_$file2  \> _condition_text_output_$OUT_DIR/${sampler_moniker}_2.fasta 
         " > $sampler_filename
           file1=""
           file2=""
        fi
      else 
         echo "unsupported sampler $SAMPLER "
         exit 1
      fi
      chmod +x $sampler_filename
   done 
}


function fake_prism() {
   echo "dry run ! 
   make -n -f sample_prism.mk -d -k  --no-builtin-rules -j 16 `cat $OUT_DIR/sampling_targets.txt` > $OUT_DIR/sample_prism.log 2>&1
   "
   exit 0
}

function run_prism() {
   make -f sample_prism.mk -d -k  --no-builtin-rules -j 16 `cat $OUT_DIR/sampling_targets.txt` > $OUT_DIR/sample_prism.log 2>&1
}

function html_prism() {
   echo "tba" > $OUT_DIR/sample_prism.html 2>&1
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
         echo "error state from sample run - skipping html page generation"
         exit 1
      fi
   fi
}


set -x
main "$@"
set +x
