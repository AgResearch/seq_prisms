#!/bin/bash


#./kmer_prism.py -t assembly --kmer_listfile kmer_test_list.txt T867.fastq.gz 

#./kmer_prism.py -t assembly --kmer_listfile kmer_test_list1.txt  T903.fasta

rm B76006.frequency.txt 
rm B76006.*.pickle
../kmer_prism.py -f fasta -k 6 -o B76006.frequency.txt  -A B76006.fa  
#for seq in `grep "^assembled" test_assemble.out | awk '{print $2}' -`; do grep  $seq adapters.txt; done



