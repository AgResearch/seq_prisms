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
   IN_ROOT=""
   FORCE=no
   ANALYSIS=all
   MINIMUM_SAMPLE_SIZE="0"
   SAMPLE_RATE=""
   BCLCONVERTOPTS=""
   DEDUPEOPTS="dedupe optical dupedist=15000 subs=0"
   THREADS=8
   MYTEMP=/tmp

   help_text="
usage :
./sequencing_qc_prism.sh  [-h] [-n] [-d] [-f] [-C hpctype] [-a dedupe|bclconvert|seq_stats|fasta_sample|fastq_sample|fastqc|mapping_analysis|kmer_analysis|blast_analysis|annotation|all] [-s sample rate] -O outdir [file [.. file]] 
examples:
sequencing_qc_prism.sh -n -a fastqc -O /dataset/gseq_processing/scratch/illumina/hiseq/180824_D00390_0394_BCCPYFANXX /dataset/hiseq/scratch/postprocessing/180824_D00390_0394_BCCPYFANXX.processed/bclconvert/*.fastq.gz 
sequencing_qc_prism.sh -n -a bclconvert -O /dataset/gseq_processing/scratch/illumina/hiseq/180824_D00390_0394_BCCPYFANXX /dataset/hiseq/active/180824_D00390_0394_BCCPYFANXX/SampleSheet.csv
sequencing_qc_prism.sh -n -a bclconvert -B "--no-lane-splitting true"  -O /dataset/gseq_processing/scratch/illumina/hiseq/180824_D00390_0394_BCCPYFANXX /dataset/hiseq/active/180824_D00390_0394_BCCPYFANXX/SampleSheet.csv
sequencing_qc_prism.sh -a bclconvert -I /dataset/hiseq/scratch/220407_A01439_0064_BHY3WWDRXY -B "" -O /dataset/hiseq/scratch/postprocessing/illumina/novaseq/220407_A01439_0064_BHY3WWDRXY/SampleSheet /dataset/hiseq/scratch/postprocessing/illumina/novaseq/220407_A01439_0064_BHY3WWDRXY/SampleSheet.csv  > /dataset/hiseq/scratch/postprocessing/illumina/novaseq/220407_A01439_0064_BHY3WWDRXY/bclconvert.log 2>&1
sequencing_qc_prism.sh -n -a fastq_sample -s .0002 -M 10000 -O /dataset/gseq_processing/scratch/illumina/hiseq/180908_D00390_0397_BCCRAJANXX /dataset/gseq_processing/scratch/illumina/hiseq/180908_D00390_0397_BCCRAJANXX/bclconvert/*.fastq.gz
"
   while getopts ":nhfO:I:C:r:a:s:j:M:B:D:T:" opt; do
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
       j)
         THREADS=$OPTARG
         ;;
       s)
         SAMPLE_RATE=$OPTARG
         ;;
       B)
         BCLCONVERTOPTS=$OPTARG
         ;;
       D)
         DEDUPEOPTS=$OPTARG
         ;;
       T)
         MYTEMP=$OPTARG
         ;;
       M)
         MINIMUM_SAMPLE_SIZE=$OPTARG
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
       I)
         IN_ROOT=$OPTARG
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

   if [ ! -d $IN_ROOT ]; then
      echo "out_dir $IN_ROOT not found"
      exit 1
   fi

   if [ ! -d $MYTEMP ]; then
      echo "custom temp folder $MYTEMP not found"
      exit 1
   fi

   if [[ $HPC_TYPE != "local" && $HPC_TYPE != "slurm" ]]; then
      echo "HPC_TYPE must be one of local, slurm"
      exit 1
   fi

   if [[ ( $ANALYSIS != "all" )  && ( $ANALYSIS != "dedupe" ) && ( $ANALYSIS != "bclconvert" ) && ( $ANALYSIS != "fasta_sample" ) && ( $ANALYSIS != "fastq_sample" ) && ( $ANALYSIS != "seq_stats" ) && ( $ANALYSIS != "fastqc" ) && ( $ANALYSIS != "mapping_analysis" ) && ( $ANALYSIS != "blast_analysis" && ( $ANALYSIS != "annotation" ) && ( $ANALYSIS != "kmer_analysis" ) ) ]] ; then
      echo "analysis must be one of bclconvert,dedupe,fasta_sample,fastq_sample,seq_stats,fastqc,mapping_analysis,kmer_analysis,blast_analysis,annotation,all ) "
      exit 1
   fi

   if [ $ANALYSIS == "bclconvert" ]; then
      if [ $NUM_FILES != 1 ]; then
         echo "for bclconvert analysis , supply the path to the sample sheet as argument"
         exit 1
      fi
   fi

}

function echo_opts() {
  echo IN_ROOT=$IN_ROOT
  echo OUT_ROOT=$OUT_ROOT
  echo DRY_RUN=$DRY_RUN
  echo DEBUG=$DEBUG
  echo HPC_TYPE=$HPC_TYPE
  echo FILES=${files_array[*]}
  echo ENGINE=$ENGINE
  echo ANALYSIS=$ANALYSIS
  echo SAMPLE_RATE=$SAMPLE_RATE
  echo MINIMUM_SAMPLE_SIZE=$MINIMUM_SAMPLE_SIZE
  echo BCLCONVERTOPTS=$BCLCONVERTOPTS
  echo DEDUPEOPTS=$DEDUPEOPTS
  echo MYTEMP=$MYTEMP
}


#
# edit this method to set required environment (or set up
# before running this script)
#
function configure_env() {
   cd $SEQ_PRISMS_BIN
   cp sequencing_qc_prism.sh $OUT_ROOT
   cp sequencing_qc_prism.mk $OUT_ROOT
   cp annotation_prism.sh $OUT_ROOT
   cp annotation_prism.mk $OUT_ROOT
   cp sample_prism.sh $OUT_ROOT
   cp sample_prism.mk $OUT_ROOT
   cp align_prism.sh $OUT_ROOT
   cp align_prism.mk $OUT_ROOT
   cp kmer_prism.sh $OUT_ROOT
   cp kmer_prism.mk $OUT_ROOT
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
   # for each file (or the run , if bclconvert) make a target moniker  and write associated
   # wrapper, which will be called by make

   rm -f $OUT_ROOT/*_targets.txt
   rm -f $OUT_ROOT/file_list.txt


   sample_phrase=""
   if [ ! -z $SAMPLE_RATE ]; then
      sample_phrase="-s $SAMPLE_RATE"
      if [ $MINIMUM_SAMPLE_SIZE != "0" ]; then
         sample_phrase="-s $SAMPLE_RATE -M $MINIMUM_SAMPLE_SIZE"
      fi
   fi

   
   ################## file-set targets (for these we call another prism, passing it the list of files)
   for ((j=0;$j<$NUM_FILES;j=$j+1)) do
      file=`realpath ${files_array[$j]}`
      echo $file >> $OUT_ROOT/file_list.txt
   done

   ###### "all"
   echo $OUT_ROOT/qc.all  >> $OUT_ROOT/all_targets.txt
   echo "#!/bin/bash
# maybe do some checks here
   exit 0
      " > $OUT_ROOT/qc.all.sh
   chmod +x $OUT_ROOT/qc.all.sh

   ###### fastq sample 
   echo $OUT_ROOT/qc.fastq_sample  >> $OUT_ROOT/fastq_sample_targets.txt
   echo "#!/bin/bash
export SEQ_PRISMS_BIN=$SEQ_PRISMS_BIN
cd $OUT_ROOT
mkdir -p fastq_sample
# run fastq_sample
$OUT_ROOT/sample_prism.sh $sample_phrase -a fastq -O $OUT_ROOT/fastq_sample \`cat $OUT_ROOT/file_list.txt\`  > $OUT_ROOT/fastq_sample/fastq_sample.log 2>&1
if [ \$? != 0 ]; then
   echo \"fastq sample returned an error code\"
   exit 1
fi
      " > $OUT_ROOT/qc.fastq_sample.sh
   chmod +x $OUT_ROOT/qc.fastq_sample.sh


   ###### seq stats  - simple file of counts of reads in all the files (works for either fasta or fastq)
   echo $OUT_ROOT/qc.seq_stats  >> $OUT_ROOT/seq_stats_targets.txt
   # prepare command-file
   rm $OUT_ROOT/seq_stats.src
   for filename in  `cat  $OUT_ROOT/file_list.txt `; do
      echo count=\`$SEQ_PRISMS_BIN/kseq_count $filename \`\; echo $filename \" \" \$count >> $OUT_ROOT/seq_stats.src
   done

   echo "#!/bin/bash
export SEQ_PRISMS_BIN=$SEQ_PRISMS_BIN
cd $OUT_ROOT
mkdir -p seq_stats
# launch commands
tardis -q source _condition_text_input_$OUT_ROOT/seq_stats.src > $OUT_ROOT/seq_stats/seq_stats.txt 2>>$OUT_ROOT/seq_stats/seq_stats.stderr
if [ \$? != 0 ]; then
   echo \"seq stats returned an error code\"
   exit 1
fi
      " > $OUT_ROOT/qc.seq_stats.sh
   chmod +x $OUT_ROOT/qc.seq_stats.sh

   ###### fasta sample
   echo $OUT_ROOT/qc.fasta_sample  >> $OUT_ROOT/fasta_sample_targets.txt
   echo "#!/bin/bash
export SEQ_PRISMS_BIN=$SEQ_PRISMS_BIN
cd $OUT_ROOT
mkdir -p fasta_sample
# run fasta_sample
$OUT_ROOT/sample_prism.sh $sample_phrase -a fasta -O $OUT_ROOT/fasta_sample \`cat $OUT_ROOT/file_list.txt\`  > $OUT_ROOT/fasta_sample/fasta_sample.log 2>&1
if [ \$? != 0 ]; then
   echo \"fasta sample returned an error code\"
   exit 1
fi
      " > $OUT_ROOT/qc.fasta_sample.sh
   chmod +x $OUT_ROOT/qc.fasta_sample.sh

   ###### blast_analysis
   echo $OUT_ROOT/qc.blast_analysis  >> $OUT_ROOT/blast_analysis_targets.txt
   echo "#!/bin/bash
export SEQ_PRISMS_BIN=$SEQ_PRISMS_BIN
cd $OUT_ROOT
mkdir -p blast_analysis
# run blast
$OUT_ROOT/align_prism.sh -C $HPC_TYPE -m 60 -a blastn -r nt -p \"-evalue 1.0e-10  -dust \\'20 64 1\\' -max_target_seqs 1 -outfmt \\'7 qseqid sseqid pident evalue staxids sscinames scomnames sskingdoms stitle\\'\" -O $OUT_ROOT/blast_analysis  $OUT_ROOT/fasta_sample/*.fasta.gz
if [ \$? != 0 ]; then
   echo \"warning , blast of $OUT_ROOT/fasta_sample/*.fasta returned an error code\"
   exit 1
fi
     " >  $OUT_ROOT/qc.blast_analysis.sh
   chmod +x $OUT_ROOT/qc.blast_analysis.sh


   ################ annotation 
   echo $OUT_ROOT/qc.annotation  >> $OUT_ROOT/annotation_targets.txt
   echo "#!/bin/bash
export SEQ_PRISMS_BIN=$SEQ_PRISMS_BIN
cd $OUT_ROOT
mkdir -p annotation
# summarise species from blast results
$OUT_ROOT/annotation_prism.sh -C $HPC_TYPE -a taxonomy -O $OUT_ROOT/blast_analysis $OUT_ROOT/blast_analysis/*.results.gz
return_code1=\$?
# summarise descriptions from blast results
rm -f $OUT_ROOT/*.annotation
$OUT_ROOT/annotation_prism.sh -C $HPC_TYPE -a description -O $OUT_ROOT/blast_analysis $OUT_ROOT/blast_analysis/*.results.gz
return_code2=\$?
if [[ ( \$return_code1 != 0 ) || ( \$return_code2 != 0 ) ]]; then
   echo \"warning, summary of $OUT_ROOT/blast_analysis returned an error code\"
   exit 1
fi
     " >  $OUT_ROOT/qc.annotation.sh
   chmod +x $OUT_ROOT/qc.annotation.sh


   ################  kmer analysis 
   echo $OUT_ROOT/qc.kmer_analysis >> $OUT_ROOT/kmer_analysis_targets.txt
   echo "#!/bin/bash
export SEQ_PRISMS_BIN=$SEQ_PRISMS_BIN
cd $OUT_ROOT
mkdir -p kmer_analysis
# run kmer analysis
$OUT_ROOT/kmer_prism.sh -a fastq -p \"-k 6 -A\" -O $OUT_ROOT/kmer_analysis $OUT_ROOT/fastq_sample/*.fastq.gz  >  $OUT_ROOT/kmer_analysis/kmer_analysis.log 2>&1
# summarise common sequence 
rm -f $OUT_ROOT/kmer_analysis/common_sequence_summary.txt
for file in $OUT_ROOT/kmer_analysis/*.fastq.k6A.log; do  
   echo \"\$file :\" >> $OUT_ROOT/kmer_analysis/common_sequence_summary.txt
   grep -A 20 \"count of distinct kmers\" \$file  >> $OUT_ROOT/kmer_analysis/common_sequence_summary.txt
   echo \" \" >> $OUT_ROOT/kmer_analysis/common_sequence_summary.txt
done 
if [ \$? != 0 ]; then
   echo \"warning, kmer analysis returned an error code\"
   exit 1
fi
   " >  $OUT_ROOT/qc.kmer_analysis.sh
   chmod +x $OUT_ROOT/qc.kmer_analysis.sh

   ################## individual file targets (for these we call anotherapplication)
   for ((j=0;$j<$NUM_FILES;j=$j+1)) do
      file=`realpath ${files_array[$j]}`
      base=`basename $file`
      file_moniker=$base


      #for analysis_type in bclconvert all fastqc fastq_sample kmer_analysis blast_analysis fasta_sample annotation fastqc mapping_analysis ; do
      for analysis_type in bclconvert fastqc dedupe; do
         echo $OUT_ROOT/$file_moniker.$analysis_type  >> $OUT_ROOT/${analysis_type}_targets.txt
         script=$OUT_ROOT/${file_moniker}.${analysis_type}.sh
         if [ -f $script ]; then
            if [ ! $FORCE == yes ]; then
               echo "found existing processing script $script  - will re-use (use -f to force rebuild of scripts) "
               continue
            fi
         fi

         # bclconvert is special , we only generate a single target
         if [ $ANALYSIS == "bclconvert" ]; then
            break
         fi
      done

      ############### bclconvert script
      if [ $ANALYSIS == "bclconvert" ]; then 
# example : 
#bcl-convert --output-directory $OUT_ROOT/bclconvert --bcl-input-directory /dataset/hiseq/scratch/$RUN --sample-sheet /dataset/hiseq/scratch/$RUN/SampleSheet.csv
# where 
# OUT_ROOT=/dataset/hiseq/scratch/postprocessing/illumina/novaseq/$RUN/SampleSheet

         # for bclconvert, file is the sample sheet
         echo "#!/bin/bash
export SEQ_PRISMS_BIN=$SEQ_PRISMS_BIN
cd $OUT_ROOT
# run bcl-convert
# report version 
echo \"bcl-convert version in use:\"
bcl-convert -V 
#
bcl-convert $BCLCONVERTOPTS --output-directory $OUT_ROOT/bclconvert --bcl-input-directory $IN_ROOT  --sample-sheet $file > $OUT_ROOT/bcl-convert.log 2>&1
if [ \$? != 0 ]; then
   echo \"bclconvert  of $file returned an error code\"
   exit 1
fi
         " > $OUT_ROOT/${file_moniker}.bclconvert.sh
         chmod +x $OUT_ROOT/${file_moniker}.bclconvert.sh

         # bclconvert is special , we only generate a single target
         return
      fi


      ############### fastqc script
      echo "#!/bin/bash
export SEQ_PRISMS_BIN=$SEQ_PRISMS_BIN
cd $OUT_ROOT
mkdir -p fastqc
# run fastqc
tardis --hpctype $HPC_TYPE fastqc -t 8 -o $OUT_ROOT/fastqc $file 1>$OUT_ROOT/fastqc/fastqc.log 2>&1
if [ \$? != 0 ]; then
   echo \"fastqc  of $file returned an error code\"
   exit 1
fi
      " > $OUT_ROOT/${file_moniker}.fastqc.sh
      chmod +x $OUT_ROOT/${file_moniker}.fastqc.sh

      ############### dedupe script
      echo "#!/bin/bash
export SEQ_PRISMS_BIN=$SEQ_PRISMS_BIN
cd $OUT_ROOT
mkdir -p dedupe
echo "conda activate $SEQ_PRISMS_BIN/conda/bbmap" > $OUT_ROOT/dedupe/env_include.src
cp $SEQ_PRISMS_BIN/etc/dedup_slurm_array_job $OUT_ROOT/dedupe
cat >$OUT_ROOT/dedupe/tardis.toml <<EOF
max_tasks=50
jobtemplatefile = \"$OUT_ROOT/dedupe/dedup_slurm_array_job\"
EOF

# run dedupe
cd dedupe
base=`basename $file`
mytmpdir=\`mktemp -d --tmpdir=$MYTEMP  clumpifyXXXXX\`
tardis  --hpctype $HPC_TYPE --shell-include-file $OUT_ROOT/dedupe/env_include.src clumpify.sh $DEDUPEOPTS tmpdir=\$mytmpdir in=$file out=$OUT_ROOT/dedupe/$base  2>${OUT_ROOT}/dedupe/${base}.stderr 1>${OUT_ROOT}/dedupe/${base}.stdout  
if [ \$? != 0 ]; then
   echo \"dedupe of $file returned an error code\"
   exit 1
fi
      " > $OUT_ROOT/${file_moniker}.dedupe.sh
      chmod +x $OUT_ROOT/${file_moniker}.dedupe.sh


   done
}


function fake_prism() {
   echo "dry run ! 

   "
   exit 0
}

function run_prism() {
   cd $OUT_ROOT

   make -f sequencing_qc_prism.mk -d -k  --no-builtin-rules -j $THREADS `cat $OUT_ROOT/${ANALYSIS}_targets.txt` > $OUT_ROOT/${ANALYSIS}.log 2>&1

   # run summaries
}

function html_prism() {
   echo "tba" > $OUT_ROOT/sequencing_qc_prism.html 2>&1
}

function clean() {
   nohup rm -rf $OUT_ROOT/tardis_* > $OUT_ROOT/sequencing_clean.log 2>&1 &
   rm $OUT_ROOT/*.fastq
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
