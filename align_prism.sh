#!/bin/bash


declare -a references_array
declare -a parameters_array

function get_opts() {

   PWD0=$PWD
   DRY_RUN=no
   DEBUG=no
   HPC_TYPE=slurm
   FILES=""
   OUT_DIR=""
   SAMPLE_RATE=""
   MAX_TASKS=50
   ALIGNER=blastn
   FORCE=no
   PARAMETERS=""
   REFERENCES=none
   NUM_REFERENCES=1


   help_text="
\n
./align_prism.sh  [-h] [-n] [-d] [-f] [-s SAMPLE_RATE] -a aligner -r [ref name | file of ref names ] -p [ parameters or file of parameters ] -O outdir [-C local|slurm ] input_file_names\n
\n
\n
example:\n
bwa_prism.sh -n -D /dataset/Tash_FL1_Ryegrass/ztmp/For_Alan -O /dataset/Tash_FL1_Ryegrass/ztmp/seq_qc/test/fastqc  /dataset/Tash_FL1_Ryegrass/ztmp/For_Alan/*.fastq.gz\n
\n
"

   # defaults:
   while getopts ":nhO:C:s:m:a:r:p:" opt; do
   case $opt in
       n)
         DRY_RUN=yes
         ;;
       d)
         DEBUG=yes
         ;;
       f)
         FORCE=yes
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
         ALIGNER=$OPTARG
         ;;
       p)
         PARAMETERS=$OPTARG
         ;;
       r)
         REFERENCES=$OPTARG
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
   if [[ $HPC_TYPE != "local" && $HPC_TYPE != "slurm" ]]; then
      echo "HPC_TYPE must be one of local, slurm"
      exit 1
   fi
   if [[ $ALIGNER != "blastn" && $ALIGNER != "qblastn" && $ALIGNER != "bwa" ]]; then
      echo "ALIGNER must be one of blastn, qblastn, bwa"
      exit 1
   fi
   if [ $REFERENCES == none ]; then
      echo "must specify one or more references to align against (-r [ref name | file of ref names ] )"
      exit 1
   fi


   ##### note this needs re-working so can specify e.g. ref on command line, but a file of parameters ,
   # and we apply multiple parameters sets
   if [ ! -f $REFERENCES ]; then
      # assume just one reference, specified on command line
      references_array[1]=$REFERENCES


      if [ -z "$PARAMETERS"  ]; then
         echo "warning , no alignment parameters supplied, $ALIGNER defaults will apply"
      else
         parameters_array[1]=$PARAMETERS      
      fi
      NUM_REFERENCES=1
      NUM_PARAMETERS=1

   else  # we have more than one reference to set up (or one ref, but different parameter sets)
      if [ ! -f $PARAMETERS ]; then
         if [ -z $PARAMETERS ]; then
            echo "warning , no alignment parameters supplied, $ALIGNER defaults will apply"
         fi
      fi
      index=1
      IFS=$'\n'
      for record in `awk '/\S+/{print}' $REFERENCES`; do
         references_array[$index]=$record
         let index=$index+1
      done
      NUM_REFERENCES=${#references_array[*]}
      index=1
      if [ -f $PARAMETERS ]; then
         for record in `awk '/\S+/{print}' $PARAMETERS`; do
            parameters_array[$index]=$record
            let index=$index+1
         done
      else
         for ((i=1;$i<=$NUM_REFERENCES;i=$i+1)) do
            parameters_array[$i]=$PARAMETERS      
         done
      fi

      unset IFS 

      NUM_PARAMETERS=${#parameters_array[*]}

      if [ $NUM_REFERENCES != $NUM_PARAMETERS ]; then
         echo "error,  have $NUM_REFERENCES references but $NUM_PARAMETERS parameters"
         exit 1
      fi
   fi
}

function echo_opts() {
  echo OUT_DIR=$OUT_DIR
  echo DRY_RUN=$DRY_RUN
  echo DEBUG=$DEBUG
  echo HPC_TYPE=$HPC_TYPE
  echo FILES=$FILES
  echo SAMPLE_RATE=$SAMPLE_RATE
  echo ALIGNER=$ALIGNER
  echo REFEREENCES
  for ((i=1;$i<=$NUM_REFERENCES;i=$i+1)) do
     echo ${references_array[$i]}
  done
  echo PARAMETERS
  for ((i=1;$i<=$NUM_PARAMETERS;i=$i+1)) do
     echo ${parameters_array[$i]}
  done
}

#
# edit this method to set required environment (or set up
# before running this script)
#
function configure_env() {
   cd $SEQ_PRISMS_BIN
   cp ./align_prism.sh $OUT_DIR
   cp ./align_prism.mk $OUT_DIR
   cp ./collate_mapping_stats.py $OUT_DIR
   cp ./mapping_stats_plots.r $OUT_DIR
   echo "
[tardish]
[tardis_engine]
max_tasks=$MAX_TASKS
" > $OUT_DIR/.tardishrc
   cd $OUT_DIR
   echo "
source activate /dataset/bioinformatics_dev/active/conda-env/biopython
PATH=\"$OUT_DIR:$PATH\"
PYTHONPATH=\"$OUT_DIR:$PYTHONPATH\"
" > $OUT_DIR/configure_env.sh
}


function check_env() {
   if [ -z "$SEQ_PRISMS_BIN" ]; then
      echo "SEQ_PRISMS_BIN not set - exiting"
      exit 1
   fi
}



function get_targets() {
   # make a target moniker for each combination of input file and reference, and write associated 
   # alignment wrapper, which will be called by make 
   
   for ((i=1;$i<=$NUM_REFERENCES;i=$i+1)) do
      for file in $FILES; do
         file_base=`basename $file`
	 ref_base=`basename ${references_array[$i]}`
         parameters_moniker=`echo ${parameters_array[$i]} | sed 's/ //g' | sed 's/\//\./g'`
         alignment_moniker=${file_base}.${ALIGNER}.${ref_base}.${parameters_moniker}
         TARGETS="$TARGETS $OUT_DIR/${alignment_moniker}.align_prism"

         # generate wrapper
         sample_phrase=""
         if [ ! -z $SAMPLE_RATE ]; then
            sample_phrase="-s $SAMPLE_RATE"
         fi 

         reference=${references_array[$i]}
         parameters=${parameters_array[$i]}

         aligner_filename=$OUT_DIR/${alignment_moniker}.sh

         if [ -f aligner_filename ]; then
            if [ ! $FORCE == yes ]; then
               echo "found existing aligner $aligner_filename - will re-use (use -f to force rebuild of aligners) "
               continue
            fi
         fi

         if [ $ALIGNER == bwa ]; then
            echo "#!/bin/bash
source /dataset/bioinformatics_dev/scratch/tardis/bin/activate
tardis -hpctype $HPC_TYPE -d  $OUT_DIR  $sample_phrase bwa aln $parameters _condition_fastq_input_$file \> _condition_throughput_$OUT_DIR/${alignment_moniker}.sai \; bwa samse $reference _condition_throughput_$OUT_DIR/${alignment_moniker}.sai _condition_fastq_input_$file  \> _condition_sam_output_$OUT_DIR/${alignment_moniker}.bam  
tardis -hpctype $HPC_TYPE -q -d $OUT_DIR samtools $OUT_DIR/${alignment_moniker}.bam   > $OUT_DIR/${alignment_moniker}.stats 
            " > $aligner_filename
         elif [ $ALIGNER == blastn ]; then
            echo "#!/bin/bash
source /dataset/bioinformatics_dev/scratch/tardis/bin/activate
tardis -hpctype $HPC_TYPE -d  $OUT_DIR  $sample_phrase blastn -db $reference -query  _condition_fasta_input_$file $parameters \> _condition_text_output_$OUT_DIR/${alignment_moniker}.results   
            " > $aligner_filename
         elif [ $ALIGNER == qblastn ]; then
            echo "#!/bin/bash
source /dataset/bioinformatics_dev/scratch/tardis/bin/activate
tardis -hpctype $HPC_TYPE -d  $OUT_DIR  $sample_phrase blastn -db $reference -query  _condition_fastq2fasta_input_$file $parameters \> _condition_text_output_$OUT_DIR/${alignment_moniker}.results   
            " > $aligner_filename
         else 
            echo "unsupported aligner $ALIGNER "
            exit 1
         fi
         chmod +x $aligner_filename
      done
   done 
}


function fake_prism() {
   echo "dry run ! "
   make -n -f align_prism.mk -d -k  --no-builtin-rules -j 16 $TARGETS > $OUT_DIR/align_prism.log 2>&1
   echo "dry run : summary commands are 
   TBA - probably another make
   "
   exit 0
}

function run_prism() {
   make -f align_prism.mk -d -k  --no-builtin-rules -j 16 $TARGETS > $OUT_DIR/align_prism.log 2>&1
   # will call another make to do summaries
}

function html_prism() {
   echo "tba" > $OUT_DIR/align_prism.html 2>&1
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
