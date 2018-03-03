# fastqc_prism main makefile
#***************************************************************************************
# references:
#***************************************************************************************
# make: 
#     http://www.gnu.org/software/make/manual/make.html
#
data_dir=
out_dir=
hpc_type=slurm


##############################################
# how to make fastqc 
##############################################
%.fastqc_prism:
	#fastqc $(data_dir)/$(notdir $*) -o $(out_dir) 1>$@ 2>$@
	tardis.py -hpctype $(hpc_type) fastqc $(data_dir)/$(notdir $*) -o $(out_dir) \1>$@ \2>$@
	


##############################################
# specify the intermediate files to keep 
##############################################
.PRECIOUS: %.log %.fastqc

##############################################
# cleaning - not yet doing this using make  
##############################################
clean:
	echo "no clean for now" 

