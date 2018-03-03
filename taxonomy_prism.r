# 
library(Heatplus)
library(RColorBrewer)
library("gplots")
library("matrixStats")

get_command_args <- function() {
   args=(commandArgs(TRUE))
   argresult=list()
   if(length(args)!=3 ){
      #quit with error message if wrong number of args supplied
      print('Usage example : Rscript --vanilla  taxonomy_prism.r analysis_name=160623_D00390_0257_AC9B0MANXX')
      print('args received were : ')
      for (e in args) {
         print(e)
      }
      q()
   }else{
      print("Using...")
      # seperate and parse command-line args
      for (e in args) {
         print(e)
         ta <- strsplit(e,"=",fixed=TRUE)
         switch(ta[[1]][1],
            "analysis_name" = argresult$analysis_name <- ta[[1]][2],
            "summary_table_file" = argresult$summary_table_file <- ta[[1]][2],
            "output_base" = argresult$output_base <- ta[[1]][2]
         )
      }
   }


   argresult$workdir = dirname(argresult$summary_table_file)
   return(argresult)
}

draw_heatmap <- function(args, taxa_count) {
   datamatrix<-read.table(args$summary_table_file, header=TRUE, row.names=1, sep="\t")
   setwd(args$workdir)

   # want to plot only the "taxa_count" most discriminatory taxa - i.e. 
   # 100 highest ranking standard deviations.
   # order the data by the stdev of each row (append the row stdevs 
   # as a column and sort on that)
   sdatamatrix <- cbind(datamatrix, rowSds(as.matrix(datamatrix)))
   #junk <- rowSds(as.matrix(datamatrix))
   sdatamatrix <- sdatamatrix[order(-sdatamatrix[,ncol(sdatamatrix)]),]
   sdatamatrix <- head(sdatamatrix, taxa_count)                    # take the first taxa_count
   sdatamatrix <- sdatamatrix[, sequence(ncol(sdatamatrix)-1)]   # drop the totals column


   # draw the heatmap in the usual way
   #cm<-brewer.pal(11,"Spectral") # a diverging palette
   cm<-brewer.pal(9,"OrRd") # a sequential palette 
   cm <- rev(cm)


   # set up a vector which will index the column labels that are to be blanked out so that 
   # only every nth col is labelled, 
   # the rest empty strings, n=col_label_interval.
   number_of_column_labels=ncol(sdatamatrix)
   col_label_interval=max(1, floor(ncol(sdatamatrix)/number_of_column_labels))  # 1=label every location 2=label every 2nd location  etc 
   colLabels <- colnames(sdatamatrix)
   colBlankSelector <- sequence(length(colLabels))
   colBlankSelector <- subset(colBlankSelector, colBlankSelector %% col_label_interval != 0) 
                       # e.g. will get (2,3, 5,6, 8,9, ..)
                       # so we will only label rows 1,4,7,10,13 etc)


   # set up a vector which will index the row labels that are to be blanked out so that 
   # only every nth col is labelled, 
   # the rest empty strings, n=col_label_interval.
   number_of_row_labels=taxa_count
   row_label_interval=max(1, floor(nrow(sdatamatrix)/number_of_row_labels))  # 1=label every location 2=label every 2nd location  etc 
   rowLabels <- rownames(sdatamatrix)
   rowBlankSelector <- sequence(length(rowLabels))
   rowBlankSelector <- subset(rowBlankSelector, rowBlankSelector %% row_label_interval != 0) 
                       # e.g. will get (2,3, 5,6, 8,9, ..)
                       # so we will only label rows 1,4,7,10,13 etc)


   # initial plot to get the column re-ordering
   jpeg(filename = paste("_", args$output_base,".jpg",sep="") , width=830, height=1200) # with dendrograms

   hm<-heatmap.2(as.matrix(sdatamatrix),  scale = "none", 
       dendrogram = "col",  
       trace="none",
       #trace = "none", breaks =  -2 + 4/9*seq(0,11), 
       col = cm , key=FALSE, density.info="none", 
       #keysize=1.0, margin=c(17,25), cexRow=1.5, cexCol=1.6, 
       keysize=1.0, margin=c(17,28), cexRow=1.5, cexCol=1.8, 
       lmat=rbind(  c(4,3,0 ), c(2, 1, 0) ), lwid=c(.2, .6, 0 ), lhei=c(.5, 3))

   dev.off()


   # edit the re-ordered vectors of labels, obtained from the heatmap object, so that only 
   # every nth label on the final plot has a non-empty string
   # this is for the internal distance matrix
   indexSelector <- hm$colInd[length(hm$colInd):1]    
   indexSelector <- indexSelector[colBlankSelector]
   colLabels[indexSelector] = rep('',length(indexSelector))

   indexSelector <- hm$rowInd[length(hm$rowInd):1]    
   indexSelector <- indexSelector[rowBlankSelector]
   rowLabels[indexSelector] = rep('',length(indexSelector))

   jpeg(filename = paste(args$output_base,".jpg",sep=""), width=1800, height=2400) # with dendrograms
   hm<-heatmap.2(as.matrix(sdatamatrix),  scale = "none", 
       dendrogram = "col",  
       trace="none",
       #trace = "none", breaks =  -2 + 4/9*seq(0,11), 
       col = cm , key=FALSE, density.info="none", 
       #keysize=1.0, margin=c(17,25), cexRow=1.5, cexCol=1.6, 
       keysize=1.0, margin=c(27,48), cexRow=2.0, cexCol=3.0, 
       lmat=rbind(  c(4,3,0 ), c(2, 1, 0) ), lwid=c(.1, .6, 0 ), lhei=c(.25, 3),labCol=colLabels, labRow=rowLabels)
   title(args$analysis_name, cex.main=3)

   clust = as.hclust(hm$colDendrogram) 
   write.table(cutree(clust, 1:dim(sdatamatrix)[2]),file=paste(args$output_base, ".heatmap_clusters.txt",sep=""),row.names=TRUE,sep="\t")  # ref https://stackoverflow.com/questions/18354501/how-to-get-member-of-clusters-from-rs-hclust-heatmap-2
   


   dev.off()
}

args <-get_command_args()

draw_heatmap(args , 100) 




