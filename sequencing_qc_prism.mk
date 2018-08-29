# ag_gbs_qc_prism.mk prism main makefile
#***************************************************************************************
# references:
#***************************************************************************************
# make: 
#     http://www.gnu.org/software/make/manual/make.html
#


%.all:  %.taxonomy_analysis
	date > $@

%.taxonomy_analysis:   %.blast_analysis
	$@.sh
	date > $@

%.blast_analysis:   %.fasta_sample
	$@.sh
	date > $@

%.kmer_analysis:   %.fasta_sample
	$@.sh
	date > $@

%.fasta_sample:  
	$@.sh
	date > $@

%.fastqc:  
	$@.sh
	date > $@




##############################################
# specify the intermediate files to keep 
##############################################
.PRECIOUS: %.log %.all %.taxonomy_analysis %.blast_analysis %.kmer_analysis %.fasta_analysis %.fasta %.all 

##############################################
# cleaning - not yet doing this using make  
##############################################
clean:
	echo "no clean for now" 

