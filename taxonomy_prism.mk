# taxonomy_prism main makefile
#***************************************************************************************
# references:
#***************************************************************************************
# make: 
#     http://www.gnu.org/software/make/manual/make.html
#


##############################################
# how to make taxonomy spectra
##############################################
%.taxonomy_prism:
	$*.sh
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

