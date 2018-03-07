# bwa_prism main makefile
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

# this is for testing - these will be pulled out from a look-up file
alignment_parameters=-B 10
ref_genome=/dataset/MBIE_genomics4production/active/rachael_ryegrass_GBS/LP_GBS_reference_2_rename_v2.fasta

##############################################
# how to make bwa prism results
# The commands below 
##############################################
%.bwa_prism:
	tardis.py -hpctype $(hpc_type) -d $(out_dir) -s $(sample_rate) bwa aln $(alignment_parameters) $(ref_genome) _condition_fastq_input_$(data_dir)/$(notdir $*) \> _condition_throughput_$(out_dir)/$(notdir $*)_vs_$(notdir $(ref_genome)).sai \; bwa samse $(ref_genome) _condition_throughput_$(out_dir)/$(notdir $*)_vs_$(notdir $(ref_genome)).sai _condition_fastq_input_$(data_dir)/$(notdir $*)  \> _condition_sam_output_$(out_dir)/$(notdir $*)_vs_$(notdir $(ref_genome)).bam  
	tardis.py -q -hpctype $(hpc_type) -d $(out_dir) samtools flagstat $(out_dir)/$(notdir $*)_vs_$(notdir $(ref_genome)).bam > $(out_dir)/$(notdir $*)_vs_$(notdir $(ref_genome)).stats
	date > $@
	

##############################################
# specify the intermediate files to keep 
##############################################
.PRECIOUS: %.log %.bwa_prism

##############################################
# cleaning - not yet doing this using make  
##############################################
clean:
	echo "no clean for now" 

