# ag_gbs_qc_prism.mk prism main makefile
#***************************************************************************************
# references:
#***************************************************************************************
# make: 
#     http://www.gnu.org/software/make/manual/make.html
#

# (fastq is not included as part of all , because fastqc has file moniker as prefix, whereas 
# the others have a fixed prefix, and a file-of-file names is used by the script to find the
# files. This is not idea - all should use the file-of-filenames approach).
# 
%.all:  %.annotation %.kmer_analysis
	date > $@

%.annotation:   %.blast_analysis
	$@.sh > $@.mk.log 2>&1
	date > $@

%.blast_analysis:   %.fasta_sample
	$@.sh > $@.mk.log 2>&1
	date > $@

%.kmer_analysis:   %.fastq_sample
	$@.sh > $@.mk.log 2>&1
	date > $@

%.fastq_sample:  
	$@.sh > $@.mk.log 2>&1
	date > $@

%.fasta_sample:  
	$@.sh > $@.mk.log 2>&1
	date > $@

%.seq_stats:
	$@.sh > $@.mk.log 2>&1
	date > $@

%.dedupe:
	$@.sh > $@.mk.log 2>&1
	date > $@

%.bclconvert:  
	$@.sh > $@.mk.log 2>&1
	date > $@

%.fastqc:
	$@.sh > $@.mk.log 2>&1
	date > $@





##############################################
# specify the intermediate files to keep 
##############################################
.PRECIOUS: %.mk.log %.all %.taxonomy_analysis %.blast_analysis %.kmer_analysis %.fasta_sample %.fastq_sample %.fastqc %.bcl2fastq

##############################################
# cleaning - not yet doing this using make  
##############################################
clean:
	echo "no clean for now" 

