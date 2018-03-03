#!/bin/env python 
import sys
import re
import os

sam_flagstats_files=sys.argv[1:]
stats_dict={}

for filename in sam_flagstats_files:
   # e.g.
   #44 + 0 in total (QC-passed reads + QC-failed reads)
   #0 + 0 secondary
   #0 + 0 supplementary
   #0 + 0 duplicates
   #13 + 0 mapped (29.55% : N/A)
   #0 + 0 paired in sequencing
   #0 + 0 read1
   #0 + 0 read2
   #0 + 0 properly paired (N/A : N/A)
   #0 + 0 with itself and mate mapped
   #0 + 0 singletons (N/A : N/A)
   #0 + 0 with mate mapped to a different chr
   #0 + 0 with mate mapped to a different chr (mapQ>=5)
   with open(filename,"r") as f:
      stats_dict[filename] = [0,0]   # p, n 
      for record in f:
         match = re.search("^\d+\s+\+\s+\d+\s+mapped\s+\((\S+)\%", record.strip())  # look for p , i.e. .2955 , in "13 + 0 mapped (29.55% : N/A)"
         if match is not None:
            stats_dict[filename][0] = float(match.groups()[0])/100.0
            continue
         match = re.search("^(\d+)\s+\+\s+\d+\s+in\s+total\s+\(QC-passed", record.strip())  # look for n , i.e. 44 , in "44 + 0 in total (QC-passed reads + QC-failed reads)"
         if match is not None:
            stats_dict[filename][1] = float(match.groups()[0])
            continue
         
print "\t".join(("sample", "map_pct", "map_std"))
for filename  in stats_dict:
   out_rec = [os.path.splitext(os.path.basename(filename))[0],"0","0"]

   # mapped stats
   (p,n) = stats_dict[filename]
   if p > 0:
      n = n/p

   q = 1-p
   stddev = 0
   if n>0:
      stddev = (p * q / n ) ** .5
   out_rec[1] = str(p*100.0)
   out_rec[2] = str(stddev*100.0)
   print "\t".join(out_rec)
                               
                               

   

               
                    
            
                    
                    
         
        
                    
