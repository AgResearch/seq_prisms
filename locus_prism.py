#!/usr/bin/env python2.7

import itertools,os,re,argparse,string,sys
#sys.path.append('/usr/local/agr-scripts')
#from prbdf import Distribution , build, from_tab_delimited_file, bin_discrete_value
from data_prism import prism, build, from_tab_delimited_file, bin_discrete_value


def my_hit_provider(filename, *xargs):
    """
    transform the tab-delimited stream, to only yield the records that relates either to a hit
    or "no hit" . Note that sometimes this format reports multiple hits to the same target
    - we only want the top hit - this is provided by the next method
# BLASTN 2.6.0+
# Query: seq_20382 count=638
# Database: /bifo/scratch/datacache/ncbi/indexes/blast/capra_hircus_ncbi_PRJNA290100.fasta
# 0 hits found
# BLAST processed 1 queries
# BLASTN 2.6.0+
# Query: seq_21074 count=204
# Database: /bifo/scratch/datacache/ncbi/indexes/blast/capra_hircus_ncbi_PRJNA290100.fasta
# Fields: query acc.ver, subject acc.ver, % identity, alignment length, mismatches, gap opens, q. start, q. end, s. start, s. end, evalue, bit score
# 17 hits found
seq_21074       CM004590.1      100.000 64      0       0       1       64      4028254 4028191 1.14e-25        119
seq_21074       CM004590.1      100.000 64      0       0       1       64      39689322        39689385        1.14e-25        119
seq_21074       CM004590.1      98.438  64      1       0       1       64      402829  402892  5.31e-24        113
seq_21074       CM004590.1      98.438  64      1       0       1       64      3455400 3455337 5.31e-24        113

    """
    weighting_method = xargs[0]
    raw_tuple_stream = from_tab_delimited_file(filename,*xargs[1:])   # query, hitacc, hstart,hend
    database=[None]
    tuple_stream = ((item[0], database[0], item[1], item[2],item[3]) for item in raw_tuple_stream)

    atuple = tuple_stream.next()
    query = ""
    while True:
        #print "DEBUG", atuple
        database_match=re.search("^#\s+Database:\s+(\S+)$",atuple[0].strip())
        if database_match is not None:
            database[0] = os.path.splitext( os.path.basename(database_match.groups()[0]) )[0]
        weight = 1
        query_match = re.search("^#\s+Query:\s+(.*)$",atuple[0].strip())
        if query_match is not None:
            query = query_match.groups()[0]
        if re.search(" 0 hits",atuple[0],re.IGNORECASE) is not None:
            if weighting_method == "tag_count":
                weighting_match = re.search("count=(\d*\.*\d*)\s*$", query)
                weight = float(weighting_match.groups()[0])
            yield ((query,database[0],'No hits'),weight)
        elif atuple[3:] != (None, None):
            if weighting_method == "tag_count":
                weighting_match = re.search("count=(\d*\.*\d*)\s*$", query)
                weight = float(weighting_match.groups()[0])
            yield ((query,database[0],atuple[2]), weight)
        else:
            pass 
        
        atuple = tuple_stream.next()

def my_top_hit_provider(filename, *xargs):
    """
    for each file stream  which may contain multiple hits, and yields just the top hit in each group
    """
    groups = itertools.groupby(my_hit_provider(filename, *xargs), lambda x:x[0][0]) 
    top_hits  = (group.next() for (key, group) in groups) 
    return top_hits


def my_spectrum_value_provider(interval_weight, *xargs):
    """
    this takes the items from top hit provider - e.g.
    (('seq_25449', 'filename', 'chrn'), 52)
    and transforms to e.g.
    ((52, 'filename', 'chrn'),)
  
    """
    #print interval_weight
    return ((interval_weight[1],interval_weight[0][1],interval_weight[0][2]),)       

def build_locus_distribution(datafiles, weighting_method = None):
    distob = prism(datafiles, 1)
    distob.file_to_stream_func = my_top_hit_provider
    #distob.DEBUG = True
    distob.file_to_stream_func_xargs = [weighting_method,0,1,8,9] # i.e. pick out first field (query) then hit accession and subject start and end
    distob.interval_locator_funcs = [bin_discrete_value, bin_discrete_value]
    distob.spectrum_value_provider_func = my_spectrum_value_provider
    distdata = build(distob,"singlethread")

    print "saving distribution to %s.pickle"%os.path.commonprefix(datafiles)
    distob.save("%s.pickle"%os.path.commonprefix(datafiles))
    print """
    seq count %d
    locus count %d
    
    """%(distob.total_spectrum_value, len(distob.spectrum.keys()))
    distob.list()
    
    return distdata

def locus_cmp(x,y):
    ord=cmp(x[0],y[0])
    if ord == 0:
        ord = cmp(x[1], y[1])
    return ord

def get_sample_locus_distribution(sample_locus_summaries, measure,rownames):
    sample_locus_lists = [ prism.load(sample_locus_summary).get_spectrum().keys() for sample_locus_summary in sample_locus_summaries ] 
    all_locusa = set( reduce(lambda x,y:x+y, sample_locus_lists))
    all_locusa_list = list(all_locusa)
    all_locusa_list.sort(locus_cmp)

    #print all_locusa_list

    if measure == "frequency":
        if not rownames:
            sample_locus_distributions = [[re.sub("'|#","","%s\t%s"%item) for item in all_locusa_list]] + [ prism.load(sample_locus_summary).get_raw_projection(all_locusa_list) for sample_locus_summary in sample_locus_summaries]
        else:
            sample_locus_distributions = [[re.sub("'|#","","%s_%s"%item) for item in all_locusa_list]] + [ prism.load(sample_locus_summary).get_raw_projection(all_locusa_list) for sample_locus_summary in sample_locus_summaries]

    else:
        if not rownames:
            sample_locus_distributions = [[re.sub("'|#","","%s\t%s"%item) for item in all_locusa_list]] + [ prism.load(sample_locus_summary).get_unsigned_information_projection(all_locusa_list) for sample_locus_summary in sample_locus_summaries]
        else:
            sample_locus_distributions = [[re.sub("'|#","","%s_%s"%item) for item in all_locusa_list]] + [ prism.load(sample_locus_summary).get_unsigned_information_projection(all_locusa_list) for sample_locus_summary in sample_locus_summaries]



    fd_iter = itertools.izip(*sample_locus_distributions)
    if not rownames:
        heading = itertools.izip(*[["genome\tlocus"]]+[[re.split("\.",os.path.basename(path.strip()))[0]] for path in sample_locus_summaries])
    else:
        heading = itertools.izip(*[["genome_locus"]]+[[re.split("\.",os.path.basename(path.strip()))[0]] for path in sample_locus_summaries])

    #print heading

    fd_iter = itertools.chain(heading, fd_iter)

    for record in fd_iter:
        print string.join([str(item) for item in record],"\t")

def debug(options):
    #test_iter = my_hit_provider(options["filenames"][0], *[None,0,7,6])
    test_iter = my_top_hit_provider(options["filenames"][0], *["tag_count",0,7,6])

    for item in test_iter:
        print item
        #print my_spectrum_value_provider(item, *[])

class outer_list(list):        
    def __getitem__(self, key):
        if key >= self.__len__():
            return None
        else:
            return super(outer_list,self).__getitem__(key)

def get_options():
    description = """
    """
    long_description = """

example :

 for file in /dataset/gseq_processing/scratch/gbs/180419_D00390_0357_ACCHG7ANXX/SQ0673.all.PstI-MspI.PstI-MspI/genome_alignment_blast/*.gz;
   do ./locus_prism.py --weighting_method tag_count $file >> /dataset/gseq_processing/scratch/gbs/180419_D00390_0357_ACCHG7ANXX/SQ0673.all.PstI-MspI.PstI-MspI/annotation/otsh_align.summary.txt;
 done
 ./locus_prism.py --summary_type summary_table --measure frequency --rownames /dataset/gseq_processing/scratch/gbs/180419_D00390_0357_ACCHG7ANXX/SQ0673.all.PstI-MspI.PstI-MspI/genome_alignment_blast/*.pickle  
 ./locus_prism.py --summary_type summary_table --measure information --rownames /dataset/gseq_processing/scratch/gbs/180419_D00390_0357_ACCHG7ANXX/SQ0673.all.PstI-MspI.PstI-MspI/genome_alignment_blast/*.pickle  


optionally, the query line can specify a weighting to be used as a count instead of 1 - e.g.
# Query: seq_26674 count=16

(this is used when blasting queries such as unique tags)
"""

    parser = argparse.ArgumentParser(description=description, epilog=long_description, formatter_class = argparse.RawDescriptionHelpFormatter)
    parser.add_argument('filenames', type=str, nargs="*",help='input files of blast hits for a given subject (optionally compressed with gzip)')    
    parser.add_argument('--summary_type', dest='summary_type', default="sample_summaries", \
                   choices=["sample_summaries", "summary_table"],help="summary type (default: sample_summaries")
    parser.add_argument('--measure', dest='measure', default="frequency", \
                   choices=["frequency", "information"],help="measure (default: frequency")
    parser.add_argument('--rownames' , dest='rownames', default=False,action='store_true', help="combine genome and locus fields to make a rowname")
    parser.add_argument('--weighting_method' , dest='weighting_method', default=None,choices=["tag_count"],help="weighting method")


    args = vars(parser.parse_args())
    return args

        
    
def main():
    args=get_options()

    #test = my_top_hit_provider(filename, 0,7,6)
    #test = my_hit_provider(filename, 0,7,6)
    #for record in test:
    #    print record

    #return
    #debug(args)

    if args["summary_type"] == "sample_summaries" :
        locus_dist = build_locus_distribution(args['filenames'], weighting_method = args["weighting_method"])
        #write_summaries(filename,locus_dist)
    elif args["summary_type"] == "summary_table" :
        #print "summarising %s"%str(args["filename"])
        get_sample_locus_distribution(args["filenames"], args["measure"], args["rownames"])

    

    return

                                
if __name__ == "__main__":
   main()



        

