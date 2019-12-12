# ref https://cran.r-project.org/web/packages/taxonomizr/readme/README.html

library(taxonomizr)

get_command_args <- function() {
   args=(commandArgs(TRUE))
   if(length(args)!=5 ){
      print('Usage examples : Rscript --vanilla get_taxonomy.r in_file=test.dat acc_col=2 use_base=TRUE result_format=taxid db_dir=/dataset/gseq_processing/ztmp/melseq')
      print('                 Rscript --vanilla get_taxonomy.r in_file=test.dat acc_col=2 use_base=TRUE result_format=taxa db_dir=/dataset/gseq_processing/ztmp/melseq')
      print('                 Rscript --vanilla get_taxonomy.r in_file=test.dat acc_col=2 use_base=FALSE result_format=taxa db_dir=/dataset/gseq_processing/ztmp/melseq')
      print('args received were : ')
      for (e in args) {
         print(e)
      }
      q()
   }else{
      #print("Using...")
      # seperate and parse command-line args
      for (e in args) {
         #print(e)
         ta <- strsplit(e,"=",fixed=TRUE)
         switch(ta[[1]][1],
            "in_file" = in_file <<- ta[[1]][2],
            "db_dir" = db_dir <<- ta[[1]][2],
            "acc_col" = acc_col <<- ta[[1]][2],
            "use_base" = use_base <<- ta[[1]][2],
            "result_format" = result_format <<- ta[[1]][2],
         )
      }
   }
}


get_data <- function(moniker) {
   # count accession
   # e.g. 
   #6394 CP036491.1
   #6476 FP929045.1
   #6480 LR215980.1
   #6584 AP019724.1
   #6681 AP018532.1

   data<-read.table(in_file, header=FALSE, sep="")
   return(data)
}

get_taxonomy <- function(dataset, acc_col, result_format, use_base) {
   setwd(db_dir)
   if ( ! use_base ) {
      taxid<-accessionToTaxa(as.vector(dataset[,acc_col]),"accessionTaxa.sql")
   } 
   else {
      # split the accession on ".", and look up e.g. CP036491 rather than CP036491.1
      acc_bases <- strsplit(as.vector(t(dataset[,acc_col])), split=".", fixed=TRUE)
      get_base <- function(split_result) unlist(split_result)[1]
      acc_bases <- sapply(acc_bases, get_base) 
      taxid<-accessionToTaxa(acc_bases,"accessionTaxa.sql",version="base")
   }

   if ( result_format == "taxid" ) {
      write.table(cbind(dataset, taxid),row.names=FALSE,col.names=FALSE,sep="\t")
   }
   else {
      taxa<-getTaxonomy(taxid,'accessionTaxa.sql')
      #print(cbind(dataset, taxa))
      write.table(cbind(dataset, taxa),row.names=FALSE,col.names=FALSE,sep="\t")
   }
}


main <- function() {
   get_command_args()
   data <- get_data(in_file)
   get_taxonomy(data, as.integer(acc_col), result_format, as.logical(use_base))
}

main()
