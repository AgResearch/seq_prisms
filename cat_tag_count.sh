#!/bin/bash

#reference:
# https://bytebucket.org/tasseladmin/tassel-5-source/wiki/docs/TasselPipelineGBS.pdf
# /programs/tassel/run_pipeline.pl -fork1 -BinaryToTextPlugin
# -i tagCounts/rice.cnt -o tagCounts/rice_cnt.txt -t TagCounts
# -endPlugin -runfork1

# convenience wrapper to cat a tag-count file 
sample_rate=none
minimum_sample_size=0
minimum_tag_count=0
maximum_tag_count=0

function get_opts() {

help_text="
 wrapper to tassel function, to cat a tag count file to stdout
 
 (stdout / stderr of the process itself is written to /tmp/*.cat_tag_count_stderr)
 
 examples : \n
 # just list the raw text tag file \n
 cat_tag_count.sh /dataset/hiseq/scratch/postprocessing/151016_D00390_0236_AC6JURANXX.gbs/SQ0124.processed_sample/uneak/tagCounts/G88687_C6JURANXX_1_124_X4.cnt \n
\n
 # produce a redundant fasta listing of tags (i.e. each is listed as a sequence N times, N its tag count) \n
 cat_tag_count.sh -O fasta /dataset/hiseq/scratch/postprocessing/151016_D00390_0236_AC6JURANXX.gbs/SQ0124.processed_sample/uneak/tagCounts/G88687_C6JURANXX_1_124_X4.cnt \n
\n
 # produce a sampled redundant fasta listing of tags (i.e. each is listed as a sequence N times, N its tag count) \n
 cat_tag_count.sh -O -s .001 fasta /dataset/hiseq/scratch/postprocessing/151016_D00390_0236_AC6JURANXX.gbs/SQ0124.processed_sample/uneak/tagCounts/G88687_C6JURANXX_1_124_X4.cnt \n
\n
 # produce a sampled redundant fasta listing of tags (i.e. each is listed as a sequence N times, N its tag count) - but specify a ninimum sample size\n
 cat_tag_count.sh -O -s .001 -M 10000 fasta /dataset/hiseq/scratch/postprocessing/151016_D00390_0236_AC6JURANXX.gbs/SQ0124.processed_sample/uneak/tagCounts/G88687_C6JURANXX_1_124_X4.cnt \n
\n
 # produce a non-redundant fasta listing of tags (i.e. each is listed as a sequence once) \n
 cat_tag_count.sh -u -O fasta /dataset/hiseq/scratch/postprocessing/151016_D00390_0236_AC6JURANXX.gbs/SQ0124.processed_sample/uneak/tagCounts/G88687_C6JURANXX_1_124_X4.cnt \n
 # print out the total count of all tags \n
 cat_tag_count.sh -O count /dataset/hiseq/scratch/postprocessing/151016_D00390_0236_AC6JURANXX.gbs/SQ0124.processed_sample/uneak/tagCounts/G88687_C6JURANXX_1_124_X4.cnt \n
"

FORMAT="text"
unique=no
while getopts ":huO:s:M:m:T:" opt; do
  case $opt in
    h)
      echo -e $help_text
      exit 0
      ;;
    u)
      unique=yes
      ;;
    s)
      sample_rate=$OPTARG
      ;;
    M)
      minimum_sample_size=$OPTARG
      ;;
    m)
      minimum_tag_count=$OPTARG
      ;;
    T)
      maximum_tag_count=$OPTARG
      ;;
    O)
      FORMAT=$OPTARG
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
infile=$1
# we might need to join together bits of file names if they have embedded spaces
shift
while [ ! -z "$1" ]; do
   infile="$infile $1"
   shift
done
}

function check_opts() {
  if [ -z "$SEQ_PRISMS_BIN" ]; then
    echo "SEQ_PRISMS_BIN not set - quitting"
    exit 1
  fi

  if [ -z "$infile" ]; then
    echo "must specify an input file "
    exit 1
  fi
  if [ ! -f "$infile" ]; then
    echo "$infile not found"
    exit 1
  fi
  if [[ $FORMAT != "text" && $FORMAT != "fasta"  && $FORMAT != "count" ]]; then
    echo "FORMAT must be text , fasta or count"
    exit 1
  fi

  # tassel cannot handle files with spaces in them - we will need to make a shortcut
  #newname=""
  remove_temp=0
  echo "$infile" | grep " " > /dev/null 2>&1 
  if [ $? == 0 ]; then
     nametmpdir=`mktemp --tmpdir=/tmp -d XXXXXXXXXXXXXX.cat_tag_count_links`
     temp_name=`mktemp --tmpdir=$nametmpdir`
     rm -f $temp_name
     ln -s "$infile" $temp_name
     infile=$temp_name 
     remove_temp=1
  fi
}

function echo_opts() {
   echo minimum_tag_count=$minimum_tag_count
   echo maximum_tag_count=$maximum_tag_count
   echo sample_phrase=$sample_phrase
}

function get_sample_phrase() {
  sample_phrase=""
  if [ $sample_rate != "none" ]; then 
     sample_phrase="-s $sample_rate"
     if [ $minimum_sample_size != "0" ]; then
        tag_count=`$SEQ_PRISMS_BIN/cat_tag_count.sh -O count $infile`
        new_sample_rate=`python2.7 -c "print '%8.7f'%($minimum_sample_size / (1.0 * $tag_count))"`
        sample_phrase="-s $new_sample_rate"
     fi
  fi
  if [ $minimum_tag_count != "0" ]; then
     sample_phrase="$sample_phrase -m $minimum_tag_count"
  fi
  if [ $maximum_tag_count != "0" ]; then
     sample_phrase="$sample_phrase -M $maximum_tag_count"
  fi
}

# get and check opts
get_opts $@
check_opts
get_sample_phrase
#echo_opts


# set up a file for the stdout / stderr of this run
OUT_PREFIX=`mktemp -u`
OUT_PREFIX=`basename $OUT_PREFIX`
OUT_PREFIX=/tmp/$OUT_PREFIX
errfile=`mktemp --tmpdir=/tmp XXXXXXXXXXXXXX.cat_tag_count_stderr`
if [[ ( $? != 0 ) || ( -z "$errfile" ) || ( ! -f "$errfile" ) ]]; then
   echo "cat_tag_count.sh, error creating log file $errfile"
   exit 1
fi


# set up a fifo to pass to tassel as its outfile. sleeps inserted
# as we seem to get occassional fails and that could be due to 
# race condition
tmpdir=`mktemp --tmpdir=/tmp -d XXXXXXXXXXXXXX.cat_tag_count_fifos`
sleep 1
fifo=`mktemp --tmpdir=$tmpdir`
sleep 1
# sometimes this appears to fail , returning nothing. Try to pick this 
# up and try again 
if [[ ( -z "$fifo" ) || ( ! -f "$fifo" ) ]]; then
   echo "mktemp returned empty string or failed - trying again after short wait" >>$errfile 2>&1
   sleep 1

   if [[ ( -z "$tmpdir" ) || ( ! -d "$tmpdir" ) ]]; then
      tmpdir=`mktemp --tmpdir=/tmp -d XXXXXXXXXXXXXX.cat_tag_count_fifos`
      sleep 1
   fi
   fifo=`mktemp --tmpdir=$tmpdir`
   sleep 1

   if [[ ( -z "$fifo" ) || ( ! -f "$fifo" ) ]]; then
      echo "mktemp failed on second attempt - giving up and bailing out" >>$errfile 2>&1
      exit 1
   fi
fi
rm -f $fifo
mkfifo $fifo
sleep 1
if [ ! -p $fifo ]; then
   echo "cat_tag_count.sh, error creating fifo $fifo" >>$errfile 2>&1
   exit 1
fi


#load tassel3
#module load tassel/3 assume loaded by the calling environment. We should really
#check that we have tassel available

#start tassel process to write text to fifo, running in background
echo "running nohup run_pipeline.pl -fork1 -BinaryToTextPlugin  -i \"$infile\" -o $fifo -t TagCounts -endPlugin -runfork1" >>$errfile 2>&1
nohup run_pipeline.pl -fork1 -BinaryToTextPlugin  -i "$infile" -o $fifo -t TagCounts -endPlugin -runfork1 >>$errfile 2>&1 &

#test if this command worked  (after waiting reasonable time for background to start)
sleep 3
grep -q "failed to run command" $errfile > /dev/null 2>&1
if [ $? == 0 ]; then
   echo "looks like we could not run tassel - please ensure you have a tassel environment (e.g. run_pipeline.pl should be on the PATH)"
   exit 1
fi

#start process to read fifo and list to stdout
 
if [ $FORMAT == "text" ]; then
   if [ -z "$sample_phrase" ]; then
      cat <$fifo
   else
      cat <$fifo | $SEQ_PRISMS_BIN/tags_to_tags.py $sample_phrase
   fi
elif [ $FORMAT == "count" ]; then
   awk '{ if(NF == 3) {sum += $3} } END { print sum }' $fifo
elif [ $FORMAT == "fasta" ]; then
   if [ $unique == "no" ]; then
      cat <$fifo | $SEQ_PRISMS_BIN/tags_to_fasta.py $sample_phrase 
   else
      cat <$fifo | $SEQ_PRISMS_BIN/tags_to_fasta.py -u $sample_phrase
   fi
fi

# clean up
rm -f $fifo
rmdir $tmpdir

if [ $remove_temp == 1 ]; then
   rm -f $temp_name
   rmdir $nametmpdir
fi

