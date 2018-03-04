# seq_prisms main makefile
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
seq_files=
dry_run=yes


%.logprecis: %.log


.PHONY : versions.log
versions.log:

##############################################
# how to make everything
##############################################
$(out_dir)/seq_prisms.html:  $(out_dir)/fastqc/fastqc_prism.html  $(out_dir)/bwa/bwa_prism.html $(out_dir)/taxonomy/taxonomy_prism.html
	echo "tba" > $(out_dir)/seq_prisms.html


##############################################
# how to make fastqc 
##############################################
$(out_dir)/fastqc/fastqc_prism.html:
	mkdir -p $(out_dir)/fastqc
	$(SEQ_PRISMS_BIN)/fastqc_prism.sh -C $(hpc_type) -O $(out_dir)/fastqc $(seq_files) > $(out_dir)/fastqc_prism.log 2>&1


##############################################
# how to make bwa 
##############################################
$(out_dir)/bwa/bwa_prism.html:
	mkdir -p $(out_dir)/bwa
	$(SEQ_PRISMS_BIN)/bwa_prism.sh -C $(hpc_type)  -O $(out_dir)/bwa -s $(sample_rate) $(seq_files) > $(out_dir)/bwa_prism.log 2>&1

##############################################
# how to make taxonomy 
##############################################
$(out_dir)/taxonomy/taxonomy_prism.html:
	mkdir -p $(out_dir)/taxonomy
	$(SEQ_PRISMS_BIN)/taxonomy_prism.sh -C $(hpc_type)  -O $(out_dir)/taxonomy -s $(sample_rate) $(seq_files) > $(out_dir)/taxonomy_prism.log 2>&1




##############################################
# specify the intermediate files to keep 
##############################################
.PRECIOUS: %.log

##############################################
# cleaning - not yet doing this using make  
##############################################
clean:
	echo "no clean for now" 

