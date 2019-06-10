#!/bin/bash


declare -a references_array
declare -a parameters_array
declare -a files_array

function get_opts() {

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
   MEM_PER_CPU=8G


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
   while getopts ":nhfO:C:s:m:a:r:p:B:" opt; do
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
       B)
         MEM_PER_CPU=$OPTARG
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


function test_if_fofn() {
   # test whether the arg is a fofn, by checking if each record in it is the 
   # name of a file 
   is_fofn=1
   if [ -z "$1" ]; then
      is_fofn=0
   elif [[ ( ! -f $1 ) && ( ! -h $1 ) ]]; then
      is_fofn=0
   else
      IFS=$'\n'
      # if the first and last 50 records are filenames, assume fofn
      for record in `awk '/\S+/{print}' $1 | head -50`; do  
         if [[ ( ! -f $record ) && ( ! -h $record ) ]]; then 
            is_fofn=0
            break
         fi
      done
      for record in `awk '/\S+/{print}' $1 | tail -50`; do  
         if [[ ( ! -f $record ) && ( ! -h $record ) ]]; then 
            is_fofn=0
            break
         fi
      done

      unset IFN
   fi
}

function test_if_f() {
   # test whether the arg is a link or file  
   is_f=1
   if [ -z "$1" ]; then
      is_f=0
   elif [[ ( ! -f $1 ) && ( ! -h $1 ) ]]; then
      is_f=0
   fi
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


   test_if_fofn $REFERENCES

   if [ $is_fofn != 1  ]; then
      # assume just one reference, specified on command line
      references_array[0]=$REFERENCES
      NUM_REFERENCES=1

      test_if_f $PARAMETERS

      if [ -z "$PARAMETERS"  ]; then
         echo "warning , no alignment parameters supplied, $ALIGNER defaults will apply"
         parameters_array[0]=$PARAMETERS
         NUM_PARAMETERS=1
      elif [ $is_f != 1  ]; then
         parameters_array[0]=$PARAMETERS      
         NUM_PARAMETERS=1
      else   # we have a filename listing a number n of alt parameters ( - so will duplicate reference n times )
         index=0
         for record in `awk '/\S+/{print}' $PARAMETERS`; do
            parameters_array[$index]=$record
            let index=$index+1
         done
         NUM_PARAMETERS=${#parameters_array[*]}

         echo "cloning $NUM_PARAMETERS references"
         for ((i=0;$i<$NUM_PARAMETERS;i=$i+1)) do
            references_array[$i]=$REFERENCES      
         done
      fi
   else  # we have more than one reference to set up 
      index=0
      IFS=$'\n'
      for record in `awk '/\S+/{print}' $REFERENCES`; do
         references_array[$index]=$record
         let index=$index+1
      done
      NUM_REFERENCES=${#references_array[*]}

      test_if_f $PARAMETERS

      if [ -z "$PARAMETERS"  ]; then
         echo "warning , no alignment parameters supplied, $ALIGNER defaults will apply"
         NUM_PARAMETERS=1
      fi

      if [ $is_f != 1  ]; then
         echo "cloning $NUM_REFERENCES parameter sets"
         for ((i=0;$i<$NUM_REFERENCES;i=$i+1)) do
            parameters_array[$i]=$PARAMETERS      
         done
         NUM_PARAMETERS=1
      else
         index=0
         for record in `awk '/\S+/{print}' $PARAMETERS`; do
            parameters_array[$index]=$record
            let index=$index+1
         done
         NUM_PARAMETERS=${#parameters_array[*]}
      fi
      unset IFS 

      if [ ${#parameters_array[*]} != ${#references_array[*]} ]; then
         echo "error - have  ${#references_array[*]} references but ${#parameters_array[*]} parameter sets - must have same number of each !"
         exit 1
      fi
   fi
}

function echo_opts() {
  echo OUT_DIR=$OUT_DIR
  echo DRY_RUN=$DRY_RUN
  echo DEBUG=$DEBUG
  echo HPC_TYPE=$HPC_TYPE
  echo FILES=${files_array[*]}
  echo SAMPLE_RATE=$SAMPLE_RATE
  echo ALIGNER=$ALIGNER
  echo REFEREENCES
  for ((i=0;$i<$NUM_REFERENCES;i=$i+1)) do
     echo ${references_array[$i]}
  done
  echo PARAMETERS
  for ((i=0;$i<$NUM_PARAMETERS;i=$i+1)) do
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
   cp ./mapping_stats_plots.r $OUT_DIR
   # if there is not already a tardis config file in the workign folder,
   # write one to set max tasks and (indirectly) mem per cpu (via also 
   # configuring a slurm job file , and pointing tardis at that )
   if [ ! -f $OUT_DIR/tardis.toml ]; then 
      cat $SEQ_PRISMS_BIN/etc/default_slurm_array_job | sed "s/_mem-per-cpu_/${MEM_PER_CPU}/g" - > $OUT_DIR/slurm_array_job
      cat >$OUT_DIR/tardis.toml <<EOF
max_tasks = $MAX_TASKS
jobtemplatefile = "$OUT_DIR/slurm_array_job"
EOF
   fi
   cd $OUT_DIR
#   echo "
#source activate /dataset/bioinformatics_dev/active/conda-env/biopython
#PATH=\"$OUT_DIR:$PATH\"
#PYTHONPATH=\"$OUT_DIR:$PYTHONPATH\"
#" > $OUT_DIR/configure_env.sh
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

   rm -f $OUT_DIR/alignment_targets.txt
   
   for ((i=0;$i<${#references_array[*]};i=$i+1)) do
      for ((j=0;$j<$NUM_FILES;j=$j+1)) do
         file=${files_array[$j]}
         file_base=`basename $file`
	 ref_base=`basename ${references_array[$i]}`
         parameters_moniker=`echo ${parameters_array[$i]} | sed 's/ //g' | sed 's/\//\./g' | sed 's/-//g' | sed "s/'//g"  | sed 's/\\\//g' | sed 's/"//g' `
         alignment_moniker=${file_base}.${ALIGNER}.${ref_base}.${parameters_moniker}
         alignment_moniker=`echo $alignment_moniker | awk '{printf("%s\n", substr($1,1,230));}' -`
         echo $OUT_DIR/${alignment_moniker}.align_prism >> $OUT_DIR/alignment_targets.txt

         # generate wrapper
         sample_phrase=""
         if [ ! -z $SAMPLE_RATE ]; then
            sample_phrase="-s $SAMPLE_RATE"
         fi 

         reference=${references_array[$i]}
         parameters=`echo ${parameters_array[$i]} | sed 's/"//g'`

         aligner_filename=$OUT_DIR/${alignment_moniker}.align_prism.sh

         if [ -f aligner_filename ]; then
            if [ ! $FORCE == yes ]; then
               echo "found existing aligner $aligner_filename - will re-use (use -f to force rebuild of aligners) "
               continue
            fi
         fi

         if [ $ALIGNER == bwa ]; then
            echo "#!/bin/bash
tardis --hpctype $HPC_TYPE -d  $OUT_DIR  $sample_phrase bwa aln $parameters $reference _condition_fastq_input_$file \> _condition_throughput_$OUT_DIR/${alignment_moniker}.sai \; bwa samse $reference _condition_throughput_$OUT_DIR/${alignment_moniker}.sai _condition_fastq_input_$file  \> _condition_sam_output_$OUT_DIR/${alignment_moniker}.bam  
tardis --hpctype $HPC_TYPE -q -d $OUT_DIR samtools flagstat $OUT_DIR/${alignment_moniker}.bam   > $OUT_DIR/${alignment_moniker}.stats 
            " > $aligner_filename
         elif [ $ALIGNER == blastn ]; then
            echo "#!/bin/bash
tardis --hpctype $HPC_TYPE -d  $OUT_DIR  $sample_phrase blastn -db $reference -query  _condition_fasta_input_$file $parameters \> _condition_text_output_$OUT_DIR/${alignment_moniker}.results   
            " > $aligner_filename
         elif [ $ALIGNER == qblastn ]; then
            echo "#!/bin/bash
tardis --hpctype $HPC_TYPE -d  $OUT_DIR  $sample_phrase blastn -db $reference -query  _condition_fastq2fasta_input_$file $parameters \> _condition_text_output_$OUT_DIR/${alignment_moniker}.results   
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
   make -n -f align_prism.mk -d -k  --no-builtin-rules -j 16 `cat $OUT_DIR/alignment_targets.txt` > $OUT_DIR/align_prism.log 2>&1
   echo "dry run : summary commands are 
   TBA - probably another make
   "
   exit 0
}

function run_prism() {
   make -f align_prism.mk -d -k  --no-builtin-rules -j 16 `cat $OUT_DIR/alignment_targets.txt` > $OUT_DIR/align_prism.log 2>&1
   # will call another make to do summaries
}

function html_prism() {
   echo "tba" > $OUT_DIR/align_prism.html 2>&1
}

function clean() {
   nohup rm -rf $OUT_DIR/tardis_*  > $OUT_DIR/align_clean.log 2>&1  &
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
         clean
      else
         echo "error state from run - skipping clean and html page generation"
         exit 1
      fi
   fi
}


set -x
main "$@"
set +x
