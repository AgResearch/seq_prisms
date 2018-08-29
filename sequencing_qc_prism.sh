#!/bin/bash
#
# this prism supports various basic data processing , q/c analysis tasks for sequencing data 
# 
#

declare -a files_array

function get_opts() {

   DRY_RUN=no
   DEBUG=no
   HPC_TYPE=slurm
   FILES=""
   OUT_ROOT=""
   FORCE=no
   ANALYSIS=all

   help_text="
usage :
./sequencing_qc_prism.sh  [-h] [-n] [-d] [-f] [-C hpctype] [-a bcl2fastq|fasta_sample|fastq_sample|fastqc|mapping_analysis|kmer_analysis|blast_analysis|taxonomy_analysis|all] -O outdir [file [.. file]] 
example:
./sequencing_qc_prism.sh -n -a fastqc -O /dataset/gseq_processing/scratch/illumina/hiseq/180824_D00390_0394_BCCPYFANXX /dataset/hiseq/scratch/postprocessing/180824_D00390_0394_BCCPYFANXX.processed/bcl2fastq/*.fastq.gz 
"
   while getopts ":nhfO:C:r:a:" opt; do
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
         echo -e "$help_text"
         exit 0
         ;;
       r)
         RUN=$OPTARG
         ;;
       a)
         ANALYSIS=$OPTARG
         ;;
       C)
         HPC_TYPE=$OPTARG
         ;;
       O)
         OUT_ROOT=$OPTARG
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
   if [ -z "$SEQ_PRISMS_BIN" ]; then
      echo "please set SEQ_PRISMS_BIN environment variable"
      exit 1
   fi

   if [ ! -d $OUT_ROOT ]; then
      echo "out_dir $OUT_ROOT not found"
      exit 1
   fi

   if [[ $HPC_TYPE != "local" && $HPC_TYPE != "slurm" ]]; then
      echo "HPC_TYPE must be one of local, slurm"
      exit 1
   fi

   if [[ ( $ANALYSIS != "all" ) && ( $ANALYSIS != "bcl2fastq" ) && ( $ANALYSIS != "fasta_sample" ) && ( $ANALYSIS != "fastq_sample" ) && ( $ANALYSIS != "fastqc" ) && ( $ANALYSIS != "mapping_analysis" ) && ( $ANALYSIS != "blast_analysis" && ( $ANALYSIS != "taxonomy_analysis" ) ) ]] ; then
      echo "analysis must be one of bcl2fastq,fasta_sample,fastq_sample,fastqc,mapping_analysis,kmer_analysis,blast_analysis,taxonomy_analysis,all ) "
      exit 1
   fi

}

function echo_opts() {
  echo OUT_ROOT=$OUT_ROOT
  echo DRY_RUN=$DRY_RUN
  echo DEBUG=$DEBUG
  echo HPC_TYPE=$HPC_TYPE
  echo FILES=${files_array[*]}
  echo ENGINE=$ENGINE
  echo ANALYSIS=$ANALYSIS

}


#
# edit this method to set required environment (or set up
# before running this script)
#
function configure_env() {
   cd $SEQ_PRISMS_BIN
   cp sequencing_qc_prism.sh $OUT_ROOT
   cp sequencing_qc_prism.mk $OUT_ROOT
   cp taxonomy_prism.sh $OUT_ROOT
   cp taxonomy_prism.mk $OUT_ROOT
   cp sample_prism.sh $OUT_ROOT
   cp sample_prism.mk $OUT_ROOT
   cp alignment_prism.sh $OUT_ROOT
   cp alignment_prism.mk $OUT_ROOT
   cp kmer_prism.sh $OUT_ROOT
   cp kmer_prism.mk $OUT_ROOT
   cp data_prism.sh $OUT_ROOT
   cp data_prism.mk $OUT_ROOT
   echo "
max_tasks=50
" > $OUT_ROOT/tardis.toml
   cd $OUT_ROOT
}


function check_env() {
   if [ -z "$SEQ_PRISMS_BIN" ]; then
      echo "SEQ_PRISMS_BIN not set - exiting"
      exit 1
   fi
}


function get_targets() {
   # for each file (or the run , if bcl2fastq) make a target moniker  and write associated
   # wrapper, which will be called by make

   rm -f $OUT_ROOT/*_targets.txt

   for ((j=0;$j<$NUM_FILES;j=$j+1)) do
      file=${files_array[$j]}
      base=`basename $file`
      file_moniker=$base


      for analysis_type in all bcl2fastqc fastqc fastq_sample kmer_analysis blast_analysis fasta_sample taxonomy_analysis fastqc mapping_analysis ; do
         echo $OUT_ROOT/$file_moniker.$analysis_type  >> $OUT_ROOT/${analysis_type}_targets.txt
         script=$OUT_ROOT/${file_moniker}.${analysis_type}.sh
         if [ -f $script ]; then
            if [ ! $FORCE == yes ]; then
               echo "found existing processing script $script  - will re-use (use -f to force rebuild of scripts) "
               continue
            fi
         fi
      done

      ############### fastqc script
      echo "#!/bin/bash
cd $OUT_ROOT
mkdir -p fastqc
# run fastqc
tardis fastqc -t 8 -o $OUT_ROOT/fastqc $file 1>$OUT_ROOT/fastqc/fastqc.log 2>&1
if [ $? != 0 ]; then
   echo \"fastqc  of $file returned an error code\"
   exit 1
fi
      " > $OUT_ROOT/${file_moniker}.fastqc.sh
   chmod +x $OUT_ROOT/${file_moniker}.fastqc.sh
   done
}


function fake_prism() {
   echo "dry run ! 

   "
   exit 0
}

function run_prism() {
   cd $OUT_ROOT

   make -f sequencing_qc_prism.mk -d -k  --no-builtin-rules -j 16 `cat $OUT_ROOT/${ANALYSIS}_targets.txt` > $OUT_ROOT/${ANALYSIS}.log 2>&1

   # run summaries
}

function html_prism() {
   echo "tba" > $OUT_ROOT/sequencing_qc_prism.html 2>&1
}

function clean() {
   echo "skipping clean for now"
   #rm -rf $OUT_ROOT/tardis_*
   #rm $OUT_ROOT/*.fastq
}


function main() {
   get_opts "$@"
   check_opts
   echo_opts
   check_env
   configure_env
   get_targets
   if [ $DRY_RUN != "no" ]; then
      fake_prism
   else
      run_prism
      if [ $? == 0 ] ; then
         html_prism
         clean
      else
         echo "error state from sample run - skipping html page generation and clean-up"
         exit 1
      fi
   fi
}


set -x
main "$@"
set +x
