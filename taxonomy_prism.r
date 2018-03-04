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

draw_most_variable_heatmap <- function(args, taxa_count) {
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
   number_of_column_labels=min(100,ncol(sdatamatrix))
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

   jpeg(filename = paste(args$output_base,"_variable.jpg",sep=""), width=2800, height=2400) # with dendrograms
   hm<-heatmap.2(as.matrix(sdatamatrix),  scale = "none", 
       dendrogram = "col",  
       trace="none",
       #trace = "none", breaks =  -2 + 4/9*seq(0,11), 
       col = cm , key=FALSE, density.info="none", 
       #keysize=1.0, margin=c(17,25), cexRow=1.5, cexCol=1.6, 
       keysize=1.0, margin=c(37,48), cexRow=2.0, cexCol=2.5, 
       lmat=rbind(  c(4,3,0 ), c(2, 1, 0) ), lwid=c(.1, .6, 0 ), lhei=c(.25, 3),labCol=colLabels, labRow=rowLabels)
   title(args$analysis_name, cex.main=3)

   clust = as.hclust(hm$colDendrogram) 
   write.table(cutree(clust, 1:dim(sdatamatrix)[2]),file=paste(args$output_base, "_variable.heatmap_clusters.txt",sep=""),row.names=TRUE,sep="\t")  # ref https://stackoverflow.com/questions/18354501/how-to-get-member-of-clusters-from-rs-hclust-heatmap-2
   


   dev.off()
}


draw_profiles_heatmap <- function(args, num_clust) {
   datamatrix<-read.table(args$summary_table_file, header=TRUE, row.names=1, sep="\t")
   setwd(args$workdir)

   # want to plot num_clust  broad taxonomy profiles - so cluster the profiles (if necessary)
   if(nrow(datamatrix) > 1.5 * num_clust) {
      clustering <<- kmeans(datamatrix, num_clust, iter.max=500)


      # label each profile with the name of the species whose profile
      # is closest to the center of each cluster - so find these

      closest_dists = rep(NA,nrow(clustering$centers))
      closest_rownums = rep(NA,nrow(clustering$centers))

      for (center_num in sequence(nrow(clustering$centers))) {
         v_center = as.numeric(clustering$centers[center_num,])
         for (row_num in sequence(nrow(datamatrix))) {
            # only consider this row as potentially supplying a name for the cluster if it is in the cluster
            # (sometimes a point not in the cluster can be closer to the center than a point that is in the cluster)
            if ( clustering$cluster[row_num] == center_num ) {
               v_data = as.numeric(datamatrix[row_num,])

               # calculate the distance from the center and update the closest_dists data structure
               d = (v_center - v_data) %*% (v_center - v_data)
               if(is.na(closest_dists[center_num])) {
                  closest_dists[center_num] = d
                  closest_rownums[center_num] = row_num
               }
               else if( d < closest_dists[center_num] ) {
                  closest_dists[center_num] = d
                  closest_rownums[center_num] = row_num
               }
            } 
         }
      }

      # assign the labels to the clustered data
      rownames=rownames(datamatrix)[closest_rownums]
      clustered_data = clustering$centers
      rownames(clustered_data) = rownames
   }
   else {
      clustered_data = datamatrix
      clustering <<- NA
   }

   # ref for configuring plot
   #http://stackoverflow.com/questions/15351575/moving-color-key-in-r-heatmap-2-function-of-gplots-package
   #1 Heatmap,
   #2 Row dendrogram,
   #3 Column dendrogram,
   #4 Key


   # draw the heatmap in the usual way
   #cm<-brewer.pal(11,"Spectral") # a diverging palette
   cm<-brewer.pal(9,"OrRd") # a sequential palette 
   cm <- rev(cm)


   # set up a vector which will index the labels that are to be blanked out so that 
   # only every nth col is labelled, 
   # the rest empty strings, n=col_label_interval.
   number_of_column_labels=min(100,ncol(datamatrix))
   col_label_interval=max(1, floor(ncol(clustered_data)/number_of_column_labels))  # 1=label every location 2=label every 2nd location  etc 
   colLabels <- colnames(as.matrix(clustered_data))
   colBlankSelector <- sequence(length(colLabels))
   colBlankSelector <- subset(colBlankSelector, colBlankSelector %% col_label_interval != 0) 
                       # e.g. will get (2,3, 5,6, 8,9, ..)
                       # so we will only label rows 1,4,7,10,13 etc)


   # initial plot to get the column re-ordering
   jpeg(filename = paste("_", args$output_base, "_temp.jpg",sep="") , width=830, height=1200) # with dendrograms

   hm<-heatmap.2(as.matrix(clustered_data),  scale = "none", 
   #hm<-heatmap.2(as.matrix(datamatrix),  scale = "none", 
       dendrogram = "col",  
       trace="none",
       #trace = "none", breaks =  -2 + 4/9*seq(0,11), 
       col = cm , key=FALSE, density.info="none", 
       #keysize=1.0, margin=c(17,25), cexRow=1.5, cexCol=1.6, 
       keysize=1.0, margin=c(17,28), cexRow=1.5, cexCol=1.6, 
       lmat=rbind(  c(4,3,0 ), c(2, 1, 0) ), lwid=c(.2, .6, 0 ), lhei=c(.5, 3))

  dev.off()


   # edit the re-ordered vector of col labels, obtained from the heatmap object, so that only 
   # every nth label on the final plot has a non-empty string
   # this is for the internal distance matrix
   indexSelector <- hm$colInd[length(hm$colInd):1]    
   indexSelector <- indexSelector[colBlankSelector]
   colLabels[indexSelector] = rep('',length(indexSelector))

   #jpeg(filename = paste(moniker, ".jpg",sep=""), width=1400, height=1000) # with dendrograms
   jpeg(filename = paste(args$output_base,"_profile.jpg",sep=""), width=2800, height=2400) # with dendrograms

   hm<-heatmap.2(as.matrix(clustered_data),  scale = "none", 
       dendrogram = "col",  
       trace="none",
       #trace = "none", breaks =  -2 + 4/9*seq(0,11), 
       col = cm , key=FALSE, density.info="none", 
       #keysize=1.0, margin=c(17,25), cexRow=1.5, cexCol=1.6, 
       #keysize=1.0, margin=c(27,28), cexRow=1.2, cexCol=1.2, 
       #keysize=1.0, margin=c(27,48), cexRow=1.2, cexCol=1.2, 
       keysize=1.0, margin=c(27,78), cexRow=1.3, cexCol=1.3, 
       #lmat=rbind(  c(4,3,0 ), c(2, 1, 0) ), lwid=c(.2, .6, 0 ), lhei=c(.25, 3),labCol=colLabels)
       lmat=rbind(  c(4,3,0), c(2,1,0)), lwid=c(.1, 1.2, 0), lhei=c(.25, 3 ),labCol=colLabels)

   # the column labels on the plots are usually too crowded so supply a file with the 
   # column names ordered as per the plot
   write.table(colnames(as.matrix(clustered_data))[hm$colInd[1:length(hm$colInd)]] , file=paste(args$output_base, "_samplenames_ordered.dat",sep=""),row.names=TRUE,sep="\t")
   # the row labels on the plots may be truncated  so supply a file with the 
   # row  names ordered as per the plot
   write.table(rownames(as.matrix(clustered_data))[hm$rowInd[length(hm$rowInd):1]] , file=paste(args$output_base, "_taxnames_ordered.dat",sep=""),row.names=TRUE,sep="\t")

   if ( ! is.na( clustering ) ) {
      # supply the tax clusters
      write.table(clustering$cluster, file=paste(args$output_base, "_tax_clusters.dat",sep=""),row.names=TRUE,sep="\t")
      # supply the names given to the tax clusters
      write.table(rownames, file=paste(args$output_base, "_tax_cluster_names.dat",sep=""),row.names=TRUE,sep="\t")
   }


   # 
   clust = as.hclust(hm$colDendrogram)
   sink(paste(args$output_base, "_heatmap_clustering_support.txt",sep=""))
   print("clust$merge:")
   print(clust$merge)
   print("clust$height:")
   print(clust$height)
   print("clust$order")
   print(clust$order)
   print("clust$labels")
   print(clust$labels)
   sink()
   write.table(cutree(clust, 1:dim(clustered_data)[2]),file=paste(args$output_base, "_profiles_clusters.txt",sep=""),row.names=TRUE,sep="\t")  # ref https://stackoverflow.com/questions/18354501/how-to-get-member-of-clusters-from-rs-hclust-heatmap-2


   dev.off()
}


args <-get_command_args()

draw_most_variable_heatmap(args , 100) 
draw_profiles_heatmap(args,100)




