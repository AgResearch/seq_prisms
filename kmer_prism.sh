#!/bin/bash

declare -a files_array

function get_opts() {

   DRY_RUN=no
   DEBUG=no
   HPC_TYPE=slurm
   OUT_DIR=
   SAMPLE_RATE=
   KMER_PARAMETERS="-k 6"
   MAX_TASKS=1
   MINIMUM_SAMPLE_SIZE=0
   KMERER=fasta
   FORCE=no
   MEM_PER_CPU=8G
   MAX_WALL_TIME=2
   NUM_THREADS=8


   help_text="
\n
./kmer_prism.sh  [-h] [-n] [-d] [-s SAMPLE_RATE] [-p kmeroptions ] [ -a fasta|fastq] -O outdir [-C local|slurm ] input_file_names\n
\n
\n
example:\n
kmer_prism.sh -n -O /dataset/Tash_FL1_Ryegrass/ztmp/seq_qc/test/fastqc  /dataset/Tash_FL1_Ryegrass/ztmp/For_Alan/*.fastq.gz\n
\n
"

   # defaults:
   while getopts ":nhfO:C:s:M:p:a:j:B:W:" opt; do
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
       j)
         NUM_THREADS=$OPTARG
         ;;
       B)
         MEM_PER_CPU=$OPTARG
         ;;
       W)
         MAX_WALL_TIME=$OPTARG
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

   python -c "x=int(\"$MAX_WALL_TIME\")" > /dev/null 2>&1
   if [ $? != 0 ]; then
      echo "error bad value for MAX_WALL_TIME ( $MAX_WALL_TIME )"
      exit 1
   fi

}

function echo_opts() {
  echo DATA_DIR=$DATA_DIR
  echo OUT_DIR=$OUT_DIR
  echo DRY_RUN=$DRY_RUN
  echo DEBUG=$DEBUG
  echo HPC_TYPE=$HPC_TYPE
  echo SAMPLE_RATE=$SAMPLE_RATE
  echo KMERER=$KMERER
  echo MINIMUM_SAMPLE_SIZE=$MINIMUM_SAMPLE_SIZE
  echo KMER_PARAMETERS=$KMER_PARAMETERS 
  echo NUM_THREADS=$NUM_THREADS

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
   if [ ! -f $OUT_DIR/tardis.toml ]; then
      cat $SEQ_PRISMS_BIN/etc/default_slurm_array_job | sed "s/_mem-per-cpu_/${MEM_PER_CPU}/g" - | sed "s/_max-wall-time_/${MAX_WALL_TIME}/g" - > $OUT_DIR/slurm_array_job
      cat >$OUT_DIR/tardis.toml <<EOF
max_tasks = $MAX_TASKS
jobtemplatefile = "$OUT_DIR/slurm_array_job"
min_sample_size = $MINIMUM_SAMPLE_SIZE
EOF
   fi
   echo "
conda activate /dataset/bioinformatics_dev/active/conda-env/biopython
PATH="$OUT_DIR:\$PATH"
PYTHONPATH="$OUT_DIR:$PYTHONPATH"
" > $OUT_DIR/configure_biopython_env.src
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

function link_inputs() {
   # ensure unique monikers for inputs by accessing them via unique links
   for ((j=0;$j<$NUM_FILES;j=$j+1)) do
      file=`realpath ${files_array[$j]}`
      base=`basename $file`
      link_base=$base
      if [ -h  $OUT_DIR/$link_base ]; then
         count=2
         while [ -h $OUT_DIR/${count}${link_base} ]; do
            let count=$count+1
         done
         ln -s $file $OUT_DIR/${count}${link_base} 
         files_array[$j]=$OUT_DIR/${count}${link_base}
      else
         ln -s $file $OUT_DIR/${link_base} 
         files_array[$j]=$OUT_DIR/${link_base}
      fi
   done
}

function get_targets() {

   rm -f $OUT_DIR/kmer_targets.txt

   SUMMARY_TARGETS=""

   sample_phrase=""
   if [ ! -z $SAMPLE_RATE ]; then
      sample_phrase="-s $SAMPLE_RATE"
   fi 

   
   for ((j=0;$j<$NUM_FILES;j=$j+1)) do
      file=${files_array[$j]}
      file_base=`basename $file`
      parameters_moniker=`echo $KMER_PARAMETERS | sed 's/ //g' | sed 's/\//\./g' | sed 's/-//g'`
      SUMMARY_TARGETS="$SUMMARY_TARGETS $OUT_DIR/${file_base}.${parameters_moniker}.1"
      kmerer_moniker=${file_base}.${KMERER}.${parameters_moniker}
      echo $TARGETS $OUT_DIR/${kmerer_moniker}.kmer_prism >> $OUT_DIR/kmer_targets.txt

      # generate wrapper
      kmerer_filename=$OUT_DIR/${kmerer_moniker}.kmer_prism.sh

      if [ -f $kmerer_filename ]; then
         if [ ! $FORCE == yes ]; then
            echo "found existing kmerer $kmerer_filename - will re-use (use -f to force rebuild of kmerers) "
            continue
         fi
      fi

      if [ $KMERER == fasta ]; then
        if [ -z "$sample_phrase" ]; then
           echo "#!/bin/bash
cp -s $file $OUT_DIR/${file_base}.${parameters_moniker}.1
" > $kmerer_filename
        else
           echo "#!/bin/bash
tardis -q --hpctype $HPC_TYPE -d  $OUT_DIR  $sample_phrase --shell-include-file configure_biopython_env.src cat  _condition_fasta_input_$file  \> _condition_uncompressedtext_output_$OUT_DIR/${file_base}.${parameters_moniker}.1
rm $OUT_DIR/${file_base}.frequency.txt
" > $kmerer_filename 
        fi
	echo "tardis --hpctype $HPC_TYPE -d  $OUT_DIR  --shell-include-file configure_biopython_env.src kmer_prism.py -f fasta $KMER_PARAMETERS -o $OUT_DIR/${file_base}.frequency.txt  $OUT_DIR/${file_base}.${parameters_moniker}.1   \> _condition_uncompressedtext_output_$OUT_DIR/${kmerer_moniker}.log
        if [ \$? == 0 ]; then
           rm $OUT_DIR/${file_base}.${parameters_moniker}.1
           rm $OUT_DIR/${file_base}.frequency.txt
        fi
        " >> $kmerer_filename 
      elif [ $KMERER == fastq ]; then
         echo "#!/bin/bash
	tardis -q --hpctype $HPC_TYPE -d  $OUT_DIR  $sample_phrase --shell-include-file configure_biopython_env.src cat  _condition_fastq2fasta_input_$file  \> _condition_uncompressedtext_output_$OUT_DIR/${file_base}.${parameters_moniker}.1
	tardis --hpctype $HPC_TYPE -d  $OUT_DIR  --shell-include-file configure_biopython_env.src kmer_prism.py -f fasta $KMER_PARAMETERS -o $OUT_DIR/${file_base}.frequency.txt  $OUT_DIR/${file_base}.${parameters_moniker}.1   \> _condition_uncompressedtext_output_$OUT_DIR/${kmerer_moniker}.log
        if [ \$? == 0 ]; then
           rm $OUT_DIR/${file_base}.${kmerer_moniker}.1
           rm $OUT_DIR/${file_base}.frequency.txt
        fi
         " > $kmerer_filename
      else 
         echo "unsupported kmerer  $KMERER "
         exit 1
      fi
      chmod +x $kmerer_filename 
   done 
}


function fake_prism() {
   echo "dry run ! "
   make -n -f kmer_prism.mk -d -k  --no-builtin-rules -j $NUM_THREADS `cat $OUT_DIR/kmer_targets.txt` > $OUT_DIR/kmer_prism.log 2>&1
   echo "dry run : summary commands are 
   "
   exit 0
}

function run_prism() {
   # this distributes the kmer distribtion builds for each file across the cluster
   make -f kmer_prism.mk -d -k  --no-builtin-rules -j $NUM_THREADS `cat $OUT_DIR/kmer_targets.txt` > $OUT_DIR/kmer_prism.log 2>&1
   # this uses the pickled distributions to make the final spectra
   # (note that the -k 6 arg here is not actually used , as the distributions have already been done by the make step)
   rm -f $OUT_DIR/kmer_summary_plus.${parameters_moniker}.txt
   tardis.py --hpctype $HPC_TYPE -d $OUT_DIR --shell-include-file configure_biopython_env.src kmer_prism.py -k 6 -t zipfian -o $OUT_DIR/kmer_summary_plus.${parameters_moniker}.txt -b $OUT_DIR $SUMMARY_TARGETS >> $OUT_DIR/kmer_prism.log 2>&1

   rm -f $OUT_DIR/kmer_frequency_plus.${parameters_moniker}.txt
   tardis.py --hpctype $HPC_TYPE -d $OUT_DIR --shell-include-file configure_biopython_env.src kmer_prism.py -k 6 -t frequency -o $OUT_DIR/kmer_frequency_plus.${parameters_moniker}.txt -b $OUT_DIR $SUMMARY_TARGETS >> $OUT_DIR/kmer_prism.log 2>&1
   
   rm -f $OUT_DIR/kmer_summary.${parameters_moniker}.txt
   tardis.py --hpctype $HPC_TYPE -d $OUT_DIR --shell-include-file configure_biopython_env.src kmer_prism.py -k 6 -a CGAT -t zipfian -o $OUT_DIR/kmer_summary.${parameters_moniker}.txt -b $OUT_DIR $SUMMARY_TARGETS >> $OUT_DIR/kmer_prism.log 2>&1

   rm -f  $OUT_DIR/kmer_frequency.${parameters_moniker}.txt
   tardis.py --hpctype $HPC_TYPE -d $OUT_DIR --shell-include-file configure_biopython_env.src kmer_prism.py -k 6 -a CGAT -t frequency -o $OUT_DIR/kmer_frequency.${parameters_moniker}.txt -b $OUT_DIR $SUMMARY_TARGETS >> $OUT_DIR/kmer_prism.log 2>&1

   # first do plots including N's , then rename and do plots excluding N's 
   for version in "" "_plus" ; do
      rm -f $OUT_DIR/kmer_summary.txt
      cp -s $OUT_DIR/kmer_summary${version}.${parameters_moniker}.txt $OUT_DIR/kmer_summary.txt
      tardis.py --hpctype $HPC_TYPE -d $OUT_DIR --shell-include-file configure_bioconductor_env.src Rscript --vanilla $OUT_DIR/kmer_plots.r datafolder=$OUT_DIR >> $OUT_DIR/kmer_prism.log 2>&1
      for output in kmer_entropy kmer_zipfian_comparisons kmer_zipfian zipfian_distances; do
         if [ -f $OUT_DIR/${output}.jpg ]; then
            mv $OUT_DIR/${output}.jpg $OUT_DIR/${output}${version}.${parameters_moniker}.jpg
         fi
      done
      for output in heatmap_sample_clusters  zipfian_distances_fit ; do
         if [ -f $OUT_DIR/${output}.txt ]; then
            mv $OUT_DIR/${output}.txt $OUT_DIR/${output}${version}.${parameters_moniker}.txt
         fi
      done
   done
}

function clean() {
   nohup rm -rf $OUT_DIR/tardis_* > $OUT_DIR/kmer_clean.log 2>&1 &
}

function clean_prism() {
   # clean up the target shortcuts, ensuring we only delete in OUT_DIR
   for ((j=0;$j<$NUM_FILES;j=$j+1)) do
      file=${files_array[$j]}

      base=`basename $file`

      rm -f $OUT_DIR/$base
   done
}



function html_prism() {
   echo "tba" > $OUT_DIR/kmer_prism.html 2>&1
}


function main() {
   get_opts "$@"
   check_opts
   echo_opts
   check_env
   link_inputs
   get_targets
   configure_env
   if [ $DRY_RUN != "no" ]; then
      fake_prism
   else
      run_prism
      if [ $? == 0 ] ; then
         clean
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

