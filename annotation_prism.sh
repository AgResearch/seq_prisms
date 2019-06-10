#!/bin/bash

declare -a files_array

function get_opts() {

   DRY_RUN=no
   DEBUG=no
   HPC_TYPE=slurm
   OUT_DIR=
   SAMPLE_RATE=
   MAX_TASKS=1
   FORCE=no
   ANNOTATION_PARAMETERS=none
   ANALYSIS_NAME=taxonomy
   WEIGHTING_METHOD=none


   help_text="
\n
./annotation_prism.sh  [-h] [-n] [-d] [-p options ] [-w weighting_method] [-a analysis_name] -O outdir [-C local|slurm ] input_file_names\n
\n
\n
example:\n
\n
"

   # defaults:
   while getopts ":nhfO:C:s:M:p:a:w:" opt; do
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
       p)
         ANNOTATION_PARAMETERS=$OPTARG  # not actually used at the moment 
         ;;
       w)
         WEIGHTING_METHOD=$OPTARG
         ;;
       a)
         ANALYSIS_NAME=$OPTARG
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
   if [[ $HPC_TYPE != "local" && $HPC_TYPE != "slurm" ]]; then
      echo "HPC_TYPE must be one of local, slurm"
      exit 1
   fi

   if [[ $WEIGHTING_METHOD != "none" && $WEIGHTING_METHOD != "tag_count" ]]; then
      echo "weighting method must be either tag_count or omitted"
      exit 1
   fi

   if [[ $ANALYSIS_NAME != "taxonomy" && $ANALYSIS_NAME != "description" ]]; then
      echo "analysis name must be either taxonomy or description"
      exit 1
   fi

}

function echo_opts() {
  echo OUT_DIR=$OUT_DIR
  echo DRY_RUN=$DRY_RUN
  echo DEBUG=$DEBUG
  echo HPC_TYPE=$HPC_TYPE
  echo ANNOTATION_PARAMETERS=$ANNOTATION_PARAMETERS 
  echo ANALYSIS_NAME=$ANALYSIS_NAME  
  echo WEIGHTING_METHOD=$WEIGHTING_METHOD  
}

#
# edit this method to set required environment (or set up
# before running this script)
#
function configure_env() {
   cd $SEQ_PRISMS_BIN
   cp ./annotation_prism.sh $OUT_DIR
   cp ./annotation_prism.mk $OUT_DIR
   cp ./taxonomy_prism.py $OUT_DIR
   cp ./locus_prism.py $OUT_DIR
   cp ./data_prism.py $OUT_DIR
   cp ./taxonomy_prism.r $OUT_DIR
   cp ./locus_summary_heatmap.r $OUT_DIR
   cat >$OUT_DIR/tardis.toml <<EOF
max_tasks = $MAX_TASKS
EOF
   cd $OUT_DIR
   echo "
conda activate /dataset/bioinformatics_dev/active/conda-env/bioconductor
PATH="$OUT_DIR:\$PATH"
PYTHONPATH="$OUT_DIR:$PYTHONPATH"
" > $OUT_DIR/configure_bioconductor_env.src
   cd $OUT_DIR

}


function check_env() {
   if [ -z "$SEQ_PRISMS_BIN" ]; then
      echo "SEQ_PRISMS_BIN not set - exiting"
      exit 1
   fi
}

function get_targets() {

   rm -f $OUT_DIR/annotation_targets.txt

   sample_phrase=""
   if [ ! -z $SAMPLE_RATE ]; then
      sample_phrase="-s $SAMPLE_RATE"
   fi 

   
   for ((j=0;$j<$NUM_FILES;j=$j+1)) do
      file=${files_array[$j]}
      file_base=`basename $file`
      parameters_moniker=`echo $ANNOTATION_PARAMETERS | sed 's/ //g' | sed 's/\//\./g' | sed 's/-//g'`
      parameters_moniker="a${ANALYSIS_NAME}p${parameters_moniker}w${WEIGHTING_METHOD}"
      annotation_moniker=${file_base}.${parameters_moniker}
      annotation_moniker=`echo $annotation_moniker | awk '{printf("%s\n", substr($1,1,230));}' -`
      echo $TARGETS $OUT_DIR/${annotation_moniker}.annotation_prism >> $OUT_DIR/annotation_targets.txt

      # generate wrapper
      annotation_filename=$OUT_DIR/${annotation_moniker}.annotation_prism.sh

      if [ -f $annotation_filename ]; then
         if [ ! $FORCE == yes ]; then
            echo "found existing annotation script $annotation_filename - will re-use (use -f to force rebuild of annotation) "
            continue
         fi
      fi

      args_phrase=""
      if [ $WEIGHTING_METHOD == "tag_count" ]; then
         args_phrase="--weighting_method tag_count"
      fi

      echo "#!/bin/bash
if [ $ANALYSIS_NAME == "taxonomy" ]; then
   tardis.py --hpctype $HPC_TYPE -d $OUT_DIR $OUT_DIR/taxonomy_prism.py $args_phrase $file
elif [ $ANALYSIS_NAME == "description" ]; then 
   tardis.py --hpctype $HPC_TYPE -d $OUT_DIR $OUT_DIR/locus_prism.py $args_phrase --locus_type description $file
else
   echo unsupported analysis $ANALYSIS_NAME
fi
" > $annotation_filename 
      chmod +x $annotation_filename 
   done 
}


function fake_prism() {
   echo "dry run ! "
   make -n -f annotation_prism.mk -d -k  --no-builtin-rules -j 16 `cat $OUT_DIR/annotation_targets.txt` > $OUT_DIR/annotation_prism.log 2>&1
   echo "dry run : summary commands are 
   "
   exit 0
}

function run_prism() {
   # this distributes the annotation distribtion builds for each file across the cluster
   make -f annotation_prism.mk -d $OUT_DIR -k  --no-builtin-rules -j 16 `cat $OUT_DIR/annotation_targets.txt` > $OUT_DIR/annotation_prism.log 2>&1


   if [ $ANALYSIS_NAME == "taxonomy" ]; then
      tardis.py -q --hpctype $HPC_TYPE -d $OUT_DIR  $OUT_DIR/taxonomy_prism.py --summary_type summary_table --rownames --measure "information" $OUT_DIR/*.results.gz.tax.pickle  > $OUT_DIR/information_table.txt
      tardis.py -q --hpctype $HPC_TYPE -d $OUT_DIR  $OUT_DIR/taxonomy_prism.py --summary_type summary_table --rownames --measure "frequency" $OUT_DIR/*.results.gz.tax.pickle  > $OUT_DIR/frequency_table.txt
      tardis.py --hpctype $HPC_TYPE -d $OUT_DIR  --shell-include-file configure_bioconductor_env.src Rscript --vanilla  $OUT_DIR/taxonomy_prism.r analysis_name=\'$ANALYSIS_NAME\' summary_table_file=$OUT_DIR/information_table.txt output_base=\"taxonomy_summary\" 1\>${OUT_DIR}/plots.stdout 2\>${OUT_DIR}/plots.stderr
   elif [ $ANALYSIS_NAME == "description" ]; then
      tardis.py -q --hpctype $HPC_TYPE -d $OUT_DIR $OUT_DIR/locus_prism.py --summary_type summary_table --measure frequency --rownames $OUT_DIR/*.results.gz.locus.pickle  > /$OUT_DIR/locus_freq.txt
      tardis.py --hpctype $HPC_TYPE -d $OUT_DIR  --shell-include-file configure_bioconductor_env.src Rscript --vanilla  $OUT_DIR/locus_summary_heatmap.r num_profiles=50 moniker="locus_freq" datafolder=$OUT_DIR 1\>${OUT_DIR}/plots.stdout 2\>${OUT_DIR}/plots.stderr
   else
      echo unsupported analysis $ANALYSIS_NAME
   fi
}

function clean() {
   nohup rm -rf $OUT_DIR/tardis_* > $OUT_DIR/annotation_clean.log 2>&1 &
}


function html_prism() {
   echo "tba" > $OUT_DIR/annotation_prism.html 2>&1
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
         clean
         html_prism
      else
         echo "error state from annotation run - skipping clean and html page generation"
         exit 1
      fi
   fi
}


set -x
main "$@"
set +x

