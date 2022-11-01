#!/bin/env python
from __future__ import print_function
#########################################################################
# generates fastq filenames to expect,from Illumina sample sheet 
#########################################################################
import argparse
import sys
import os
import re


def get_options():
    description = """
    """
    long_description = """

examples :

# list expected filenames 
python samplesheet_to_fastqname.py /dataset/hiseq/scratch/221007_A01439_0124_BHW2C2DSX3/HW2C2DSX3.csv

# list expected filenames, and compare with actual files that were generated. If any differences, list to stderr and exit with process code 1  
python samplesheet_to_fastqname.py -x -d /bifo/scratch/hiseq/postprocessing/illumina/novaseq/221007_A01439_0124_BHW2C2DSX3/SampleSheet/bclconvert /dataset/hiseq/scratch/221007_A01439_0124_BHW2C2DSX3/HW2C2DSX3.csv

# sample sheet does not specify lane, impute listed lanes (e.g. GBS). Also only generate single-end lanes
python samplesheet_to_fastqname.py -I 1,2 -t single_end -d /bifo/scratch/hiseq/postprocessing/illumina/novaseq/221012_A01439_0125_AHLJGVDRX2/SampleSheet/bclconvert /bifo/scratch/hiseq/221012_A01439_0125_AHLJGVDRX2/HLJGVDRX2.csv  2>junk

"""

    parser = argparse.ArgumentParser(description=description, epilog=long_description, formatter_class = argparse.RawDescriptionHelpFormatter)
    parser.add_argument('samplesheet', type=str, nargs=1,help='name of sample sheet')
    parser.add_argument('-d', '--fastq_folder' , dest='fastq_folder', required=False, default=None , type=str, help="optional folder containing files to compare with expected")
    parser.add_argument('-x','--exit_with_error', dest='exit_with_error', action='store_const', default = False, const=True, help='if set, exit with an error code if any differences between expected and actual files')
    parser.add_argument('-t', '--sequencing_type' , dest='sequencing_type', required=False, default="paired_end" , type=str, choices=["paired_end", "single_end"], help="generate paired / single end names")
    parser.add_argument('-I', '--impute_lanes' , dest='impute_lanes', required=False, default=None , type=str,help="a comma-separated list of lanes to impute")    

    
    
    args = vars(parser.parse_args())

    
    return args


                   
def get_fastq_filenames(options):
    """
    parse the Sample sheet and construct expected fastq filenames
    """

    with open(options["samplesheet"][0],"r") as input_file:
        header=None
        sample_dict = {}
        predicted_files = set()
        for record in input_file:
            #[Data],,,,,,,,,,,
            #Lane,Sample_ID,Sample_Name,Sample_Plate,Sample_Well,Index_Plate_Well,I7_Index_ID,index,I5_Index_ID,index2,Sample_Project,Description
            #1,P628_2,P628_2,NS0035,A1,A5,S769,TCCTCATG,S519,AGGTGTAC,Pestivirus_MethySeq,Pestivirus_MethySeq
            #1,P726_3,P726_3,NS0035,B1,B5,S752,AGGATAGC,S544,AACCTTGG,Pestivirus_MethySeq,Pestivirus_MethySeq
            #
            # generates P628_2_S1_L001_R1_001.fastq.gz etc.
            fields=re.split(",",record.strip())
            if fields[0] == "[Data]":
                header=input_file.next()
                header_fields = [item.lower() for item in re.split(",",header.strip()) ]
                record = input_file.next()
                fields=re.split(",",record.strip())
                s_number = 1

            if header is not None:
                if len(fields[0].strip()) ==0:
                    break
                if fields[0][0] == "[":
                    break
                if "lane" in header_fields:
                    (ilane,isample) = (header_fields.index("lane"), header_fields.index("sample_id"))
                    (lane,sample) = (int(fields[ilane]), fields[isample])
                else:
                    isample = header_fields.index("sample_id")
                    (lane,sample) = (1, fields[isample])   # default lane to 1
                    
                if sample not in sample_dict:
                    sample_dict[sample] = s_number
                    s_number += 1

                if options["impute_lanes"] is None: 
                    R1_filename="%s_S%d_L%03d_R1_001.fastq.gz"%(sample,sample_dict[sample],lane)
                    R2_filename="%s_S%d_L%03d_R2_001.fastq.gz"%(sample,sample_dict[sample],lane)

                    predicted_files.add(R1_filename)

                    if options["sequencing_type"] == "paired_end":
                        predicted_files.add(R2_filename)
                    
                else:
                    for lane in re.split(",", options["impute_lanes"]):
                        R1_filename="%s_S%d_L%03d_R1_001.fastq.gz"%(sample,sample_dict[sample],int(lane))
                        R2_filename="%s_S%d_L%03d_R2_001.fastq.gz"%(sample,sample_dict[sample],int(lane))

                        predicted_files.add(R1_filename)

                        if options["sequencing_type"] == "paired_end":
                            predicted_files.add(R2_filename)                        




        return predicted_files
        
         
def main():    
    options = get_options()

    predicted_files = get_fastq_filenames(options)

    for name in predicted_files:
        print(name)

    if options["fastq_folder"] is not None:
        found_files = [ filename for filename in os.listdir( options["fastq_folder"] ) if re.search("\.fastq\.gz$", filename) is not None and re.search("undetermined", filename, re.IGNORECASE) is None ]
        found_files = set(found_files)

        if len(predicted_files - found_files) != 0:
            print( "the following files expected from the sample sheet were not found in %s"%options["fastq_folder"], file=sys.stderr)
            for name in predicted_files - found_files:
                print(name, file=sys.stderr)
                
        if len(found_files - predicted_files) != 0:
            print( "the following unexpected files were found in %s"%options["fastq_folder"], file=sys.stderr)
            for name in found_files - predicted_files:
                print(name, file=sys.stderr)

        if found_files != predicted_files and options["exit_with_error"]:
            sys.exit(1)
        
   
if __name__=='__main__':
    sys.exit(main())    

    

        

