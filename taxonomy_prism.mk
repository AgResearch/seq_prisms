# taxonomy_prism main makefile
#***************************************************************************************
# references:
#***************************************************************************************
# make: 
#     http://www.gnu.org/software/make/manual/make.html
#
data_dir=
out_dir=
hpc_type=
sample_rate=

ifeq ($(strip $(sample_rate)),)
sample_args=
else
sample_args=-s $(sample_rate)
endif


# this is for testing - these will be pulled out from a look-up file
blast_parameters=-num_threads 2 -db nt -evalue 1.0e-10 -dust \'20 64 1\' -max_target_seqs 1 -outfmt \'7 qseqid sseqid pident evalue staxids sscinames scomnames sskingdoms stitle\'

##############################################
# how to make blast
##############################################
%.taxonomy_prism:
	tardis.py -hpctype $(hpc_type) -d $(out_dir) $(sample_args) blastn -query _condition_fastq2fasta_input_$(data_dir)/$(notdir $*) -task blastn $(blast_parameters) -out _condition_text_output_$(out_dir)/$(notdir $*).blastresults 1\>_condition_text_output_$(out_dir)/$(notdir $*).stdout 2\>_condition_text_output_$(out_dir)/$(notdir $*).stderr
	tardis.py -hpctype $(hpc_type) -d $(out_dir) $(out_dir)/taxonomy_prism.py $(out_dir)/$(notdir $*).blastresults.gz
	date > $@
	


##############################################
# specify the intermediate files to keep 
##############################################
.PRECIOUS: %.log %.taxonomy_prism

##############################################
# cleaning - not yet doing this using make  
##############################################
clean:
	echo "no clean for now" 

