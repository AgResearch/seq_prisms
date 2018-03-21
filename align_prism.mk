# align_prism main makefile
#***************************************************************************************
# references:
#***************************************************************************************
# make: 
#     http://www.gnu.org/software/make/manual/make.html
#
##############################################
# how to make bwa prism results
# The commands below 
##############################################
%.align_prism:
	source $*.src
	date > $@
	

##############################################
# specify the intermediate files to keep 
##############################################
.PRECIOUS: %.log %.align_prism

##############################################
# cleaning - not yet doing this using make  
##############################################
clean:
	echo "no clean for now" 

