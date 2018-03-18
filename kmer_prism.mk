# kmer_prism main makefile
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
kmer_parameters=-t frequency -k 6 -p 4

##############################################
# how to make kmer summary. Note that this will pickle the kmer distribution
# in $(out_dir), so that a subsequent call to kmer_entropy can build the 
# complete spectra.
##############################################
%.kmer_prism:
	tardis.py -hpctype $(hpc_type) -d $(out_dir) -shell-include-file configure_env.sh kmer_prism.py $(sample_args) $(kmer_parameters) -o $(out_dir)/$(notdir $*).frequency.txt -b $(out_dir) $(data_dir)/$(notdir $*)
	date > $@
	
##############################################
# specify the intermediate files to keep 
##############################################
.PRECIOUS: %.log %.kmer_prism

##############################################
# cleaning - not yet doing this using make  
##############################################
clean:
	echo "no clean for now" 

