#!/bin/env python
#
# read tag info from stdin and write out as
# tags, optionally sampling , and optionally either unique or redundant 
#
#    The tag count file contains records like
#TGCAGAAGTCTTGAATTTAATTCAGGATACTCGTCTACCACGTTGTCCATGTCTCCGCAAGGGA        64      1
#TGCAGAAGTCTTGAATTTAGTTCAGGATACTCGTCTACCACGTTGTCCATGTCTCCGCAAAGGA        64      1
#TGCAGAAGTCTTGGCCTGAGGAGCTGAGTTGTGCATCACCCTGCAAAAAAAAAAAAAAAAAAAA        45      3
#TGCAGAAGTCTTGGTGATGTTGTAAAGGTGTGTTGATGTCTCTGTGGTTGAGGACACATCATCA        64      3
#
# example : 
#./cat_tag_count.sh /dataset/hiseq/scratch/postprocessing/151016_D00390_0236_AC6JURANXX.gbs/SQ0124.processed_sample/uneak/tagCounts/G88687_C6JURANXX_1_124_X4.cnt | ./tags_to_tags.py
# 


import sys
import re
import itertools
import argparse
import random


def getSampleBool(samplerate):
    # sample from bernoulli p=1/samplerate  if we are sampling, or if not return 1
    if samplerate is None:
      return 1
    elif samplerate <= 0:
      return 1
    elif samplerate >= 1.0:
      return 1
    else:
      uniform = random.random()
      if uniform <= samplerate:
         return 1
      else:
         return 0

def tags_to_tags(options):    
    tag_iter = (record for record in sys.stdin)
    for tag in tag_iter:
        if options["samplerate"] is None:
            print tag.strip()
        else:
            if getSampleBool(options["samplerate"]) == 1:
                print tag.strip()
                    
                    
def get_options():
    description = """
    This script outputs tags from stdin , optionally
    sampling 
    """
    
    long_description = """
    Example :

./cat_tag_count.sh /dataset/hiseq/scratch/postprocessing/151016_D00390_0236_AC6JURANXX.gbs/SQ0124.processed_sample/uneak/tagCounts/G88687_C6JURANXX_1_124_X4.cnt | ./tags_to_tags.py -s .001

    """
    parser = argparse.ArgumentParser(description=description, epilog=long_description, formatter_class = argparse.RawDescriptionHelpFormatter)
    parser.add_argument('-s', '--samplerate', dest='samplerate', type=float, metavar='sample rate', default = None, help="specify a random sampling rate - e.g. .1 means randomly sample around 10%% etc.")

    args = vars(parser.parse_args())

    random.seed()

    return args


def main():
    tags_to_tags(get_options())
    return 

    
if __name__ == "__main__":
   main()
        




