# sample_prism main makefile
#***************************************************************************************
# references:
#***************************************************************************************
# make: 
#     http://www.gnu.org/software/make/manual/make.html
#
data_dir=
out_dir=
hpc_type=
sample_rate=.0002


##############################################
# how to make blast
##############################################
%.sample_prism:
	tardis.py -hpctype $(hpc_type) -d $(out_dir) -s $(sample_rate) cat _condition_fastq2fasta_input_$(data_dir)/$(notdir $*)  \> _condition_text_output_$(out_dir)/$(notdir $*).fasta
	date > $@
	


##############################################
# specify the intermediate files to keep 
##############################################
.PRECIOUS: %.log %.sample_prism

##############################################
# cleaning - not yet doing this using make  
##############################################
clean:
	echo "no clean for now" 

