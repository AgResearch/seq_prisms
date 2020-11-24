#!/bin/bash

declare -a files_array

function get_opts() {

   DRY_RUN=no
   DEBUG=no
   HPC_TYPE=slurm
   FILES=""
   OUT_DIR=""
   SAMPLE_RATE=""
   MAX_TASKS=1
   MINIMUM_SAMPLE_SIZE=0
   MINIMUM_TAG_COUNT=0
   MAXIMUM_TAG_COUNT=0
   SAMPLER=fastq
   FORCE=no


   help_text="
\n
./sample_prism.sh  [-h] [-n] [-d] [-s SAMPLE_RATE] [-M minimum sample size] [-t minium_tag_count] [ -T maximum_tag_count] -a sampler -O outdir [-C local|slurm ] input_file_names\n
\n
\n
example:\n
sample_prism.sh -n  -O /dataset/Tash_FL1_Ryegrass/ztmp/seq_qc/test/fastqc  /dataset/Tash_FL1_Ryegrass/ztmp/For_Alan/*.fastq.gz\n
sample_prism.sh -n  -O /dataset/Tash_FL1_Ryegrass/ztmp/seq_qc/test/fastqc  /dataset/Tash_FL1_Ryegrass/ztmp/For_Alan/*.fastq.gz\n
sample_prism.sh -n  -s .00001 -M 10000 -a tag_count -O /dataset/hiseq/scratch/postprocessing/gbs/weevils_tassel3/fasta  /dataset/hiseq/scratch/postprocessing/151016_D00390_0236_AC6JURANXX.gbs/SQ0124.processed_sample/uneak/tagCounts/G88687_C6JURANXX_1_124_X4.cnt\n
sample_prism.sh -n  -t 2  -a tag_count_unique -O /dataset/hiseq/scratch/postprocessing/gbs/weevils_tassel3/fasta  /dataset/hiseq/scratch/postprocessing/151016_D00390_0236_AC6JURANXX.gbs/SQ0124.processed_sample/uneak/tagCounts/G88687_C6JURANXX_1_124_X4.cnt\n
\n
"

   # defaults:
   while getopts ":nhfO:C:D:s:m:M:a:m:t:T:" opt; do
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
         SAMPLER=$OPTARG
         ;;
       m)
         MAX_TASKS=$OPTARG
         ;;
       t)
         MINIMUM_TAG_COUNT=$OPTARG
         ;;
       T)
         MAXIMUM_TAG_COUNT=$OPTARG
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

   if [[ $SAMPLER != "fasta" && $SAMPLER != "fastq" && $SAMPLER != "paired_fastq"  && $SAMPLER != "tag_count" && $SAMPLER != "tag_count_unique" ]]; then
      echo "SAMPLER must be fasta or fastq"
      exit 1
   fi

   if [[ $SAMPLER != "tag_count"  &&  $SAMPLER != "tag_count_unique" && ( $MINIMUM_TAG_COUNT != "0" || $MAXIMUM_TAG_COUNT != "0" ) ]]; then 
      echo "minimum/maximum tag count is only applicable to tag file sampling"
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
  echo MINIMUM_TAG_COUNT=$MINIMUM_TAG_COUNT
  echo MAXIMUM_TAG_COUNT=$MAXIMUM_TAG_COUNT
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
   echo "
conda activate tassel3
" > $OUT_DIR/tassel3_env.src
   cd $OUT_DIR
}


function check_env() {
   if [ -z "$SEQ_PRISMS_BIN" ]; then
      echo "SEQ_PRISMS_BIN not set - exiting"
      exit 1
   fi
}

function link_inputs() {
   # ensure unique monikers for inputs by accessing them via unique links
   for ((j=0;$j<$NUM_FILES;j=$j+1)) do
      file=`realpath ${files_array[$j]}`
      base=`basename $file`
      link_base=$base
      if [ -h  $OUT_DIR/$link_base ]; then
         count=2
         while [ -h $OUT_DIR/${count}_${link_base} ]; do
            let count=$count+1
         done
         ln -s $file $OUT_DIR/${count}_${link_base}
         files_array[$j]=$OUT_DIR/${count}_${link_base}
      else
         ln -s $file $OUT_DIR/${link_base}
         files_array[$j]=$OUT_DIR/${link_base}
      fi
   done
}


function get_targets() {
   # make a target moniker for each input file and write associated 
   # sampler wrapper, which will be called by make 

   rm -f $OUT_DIR/sampling_targets.txt

   sample_phrase=""
   if [ ! -z $SAMPLE_RATE ]; then
      sample_phrase="-s $SAMPLE_RATE"
      if [[ ( $MINIMUM_SAMPLE_SIZE != "0" ) && ( $SAMPLER == "tag_count" ) ]]; then
         sample_phrase="-s $SAMPLE_RATE -M $MINIMUM_SAMPLE_SIZE"
      fi
   fi 

   if [ $MINIMUM_TAG_COUNT != "0" ]; then
      sample_phrase="$sample_phrase -m $MINIMUM_TAG_COUNT "
   fi

   if [ $MAXIMUM_TAG_COUNT != "0" ]; then
      sample_phrase="$sample_phrase -T $MAXIMUM_TAG_COUNT "
   fi
  
   file1=""
   file2=""
   for ((j=0;$j<$NUM_FILES;j=$j+1)) do
      file=${files_array[$j]}
      file_base=`basename "$file"`
      parameters_moniker=`echo $sample_phrase | sed 's/ //g' | sed 's/\//\./g' | sed 's/-//g'`
      if [ $MINIMUM_TAG_COUNT != "0" ]; then
         parameters_moniker="${parameters_moniker}_taggt$MINIMUM_TAG_COUNT"
      fi
      sampler_moniker="${file_base}.${SAMPLER}.${parameters_moniker}"
      sampler_moniker=`echo $sampler_moniker | sed 's/ /space/g' | sed 's/\//\./g' | sed 's/\\\/\./g' | sed 's/\.$//g' `


      if [ $SAMPLER != paired_fastq ]; then
         echo $OUT_DIR/${sampler_moniker}.sample_prism >> $OUT_DIR/sampling_targets.txt
      fi

      # generate wrapper
      sampler_filename=$OUT_DIR/${sampler_moniker}.sample_prism.sh

      if [ -f sampler_filename ]; then
         if [ ! $FORCE == yes ]; then
            echo "found existing sampler $sampler_filename - will re-use (use -f to force rebuild of samplers) "
            continue
         fi
      fi

      if [ $SAMPLER == fasta ]; then
         echo "#!/bin/bash
tardis --hpctype $HPC_TYPE -d  $OUT_DIR  $sample_phrase cat _condition_fastq2fasta_input_$file  \> _condition_text_output_$OUT_DIR/${sampler_moniker}.fasta
        " > $sampler_filename
      elif [ $SAMPLER == fastq ]; then
         echo "#!/bin/bash
tardis --hpctype $HPC_TYPE -d  $OUT_DIR  $sample_phrase cat _condition_fastq_input_$file  \> _condition_text_output_$OUT_DIR/${sampler_moniker}.fastq
         " > $sampler_filename
      elif [ $SAMPLER == paired_fastq ]; then
        if [ -z $file2 ]; then 
           file2=$file
           continue
        elif [ -z $file1 ]; then
           file1=$file2
           file2=$file
           echo $OUT_DIR/${sampler_moniker}.sample_prism >> $OUT_DIR/sampling_targets.txt
        echo "#!/bin/bash
tardis --hpctype $HPC_TYPE -d  $OUT_DIR  $sample_phrase cat _condition_paired_fastq_input_$file1  \> _condition_text_output_$OUT_DIR/${sampler_moniker}_1.fastq \; cat _condition_paired_fastq_input_$file2  \> _condition_text_output_$OUT_DIR/${sampler_moniker}_2.fastq 
         " > $sampler_filename
           file1=""
           file2=""
        fi
      elif [ $SAMPLER == tag_count ]; then
        # tardis can't easily sample tag count files - so no tardis conditioning done here
        echo "#!/bin/bash
tardis --hpctype $HPC_TYPE -d  $OUT_DIR --shell-include-file $OUT_DIR/tassel3_env.src  $SEQ_PRISMS_BIN/cat_tag_count.sh -O fasta $sample_phrase \"$file\"  \> $OUT_DIR/${sampler_moniker}.fasta
" > $sampler_filename
      elif [ $SAMPLER == tag_count_unique ]; then
        # tardis can't easily sample tag count files - so no tardis conditioning done here
        echo "#!/bin/bash
tardis --hpctype $HPC_TYPE -d  $OUT_DIR --shell-include-file $OUT_DIR/tassel3_env.src  $SEQ_PRISMS_BIN/cat_tag_count.sh -u -O fasta $sample_phrase \"$file\"  \> $OUT_DIR/${sampler_moniker}.fasta
" > $sampler_filename
      else 
         echo "unsupported sampler $SAMPLER "
         exit 1
      fi
      chmod +x $sampler_filename
   done 
}


function fake_prism() {
   echo "dry run ! 
   make -n -f sample_prism.mk -d -k  --no-builtin-rules -j 8 `cat $OUT_DIR/sampling_targets.txt` > $OUT_DIR/sample_prism.log 2>&1
   "
   exit 0
}

function run_prism() {
   make -f sample_prism.mk -d -k  --no-builtin-rules -j 8 `cat $OUT_DIR/sampling_targets.txt` > $OUT_DIR/sample_prism.log 2>&1
}

function html_prism() {
   echo "tba" > $OUT_DIR/sample_prism.html 2>&1
}

function clean_prism() {
   # clean up the target shortcuts, ensuring we only delete in OUT_DIR 
   for ((j=0;$j<$NUM_FILES;j=$j+1)) do
      file=${files_array[$j]}
      
      base=`basename $file`
  
      rm -f $OUT_DIR/$base
   done
}


function main() {
   get_opts "$@"
   check_opts
   echo_opts
   check_env
   configure_env
   link_inputs
   get_targets
   if [ $DRY_RUN != "no" ]; then
      fake_prism
   else
      run_prism
      if [ $? == 0 ] ; then
         html_prism
         clean_prism
      else
         echo "error state from sample run - skipping html page generation and clean (suggest deleting target file links in $OUT_DIR before retrying)"
         exit 1
      fi
   fi
}


set -x
main "$@"
set +x
