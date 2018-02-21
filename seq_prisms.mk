# seq_prisms main makefile
#***************************************************************************************
# references:
#***************************************************************************************
# make: 
#     http://www.gnu.org/software/make/manual/make.html
#
fastq_file_suffix=trimmed
data_dir=
out_dir=


seq_files := $(wildcard $(data_dir)/*.$(fastq_file_suffix))



%.logprecis: %.log


.PHONY : versions.log
versions.log:

##############################################
# how to make everything
##############################################
$(out_dir)/seq_prisms.html:  $(out_dir)/fastqc/fastqc_prism.html
	echo "tba" > $(out_dir)/seq_prisms.html





##############################################
# how to make fastqc 
##############################################
$(out_dir)/fastqc/fastqc_prism.html:
	mkdir -p $(out_dir)/fastqc
	fastqc_prism.sh -o $(out_dir)/fastqc $(seq_files)


##############################################
# specify the intermediate files to keep 
##############################################
.PRECIOUS: %.log

##############################################
# cleaning - not yet doing this using make  
##############################################
clean:
	echo "no clean for now" 

