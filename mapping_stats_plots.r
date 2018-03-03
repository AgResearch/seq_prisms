# 
#-------------------------------------------------------------------------
# plot the % reads mappng 
#-------------------------------------------------------------------------


get_command_args <- function() {
   args=(commandArgs(TRUE))
   if(length(args)!=1 ){
      #quit with error message if wrong number of args supplied
      print('Usage example : Rscript --vanilla  mapping_stats_plots.r datafolder=/dataset/hiseq/scratch/postprocessing/170207_D00390_0282_ACA7WHANXX.processed/mapping_preview')
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
            "datafolder" = datafolder <- ta[[1]][2]
         )
      }
   }
   return(datafolder)
}



data_folder<-get_command_args() 

setwd(data_folder) 
mapping_stats = read.table("stats_summary.txt", header=TRUE, sep="\t")
mapping_stats <- mapping_stats[order(mapping_stats$map_pct),] 


jpeg("mapping_stats.jpg", height=nrow(mapping_stats) *  80, width=800)


# ref 
# refs for this way of doing error bars 
# http://environmentalcomputing.net/single-continuous-vs-categorical-variables/ 
# https://stackoverflow.com/questions/13032777/scatter-plot-with-error-bars

op <- par(mar = c(4,20,4,2) + 0.1) # bottom, left, top, and right
mapping.plot <- barplot(mapping_stats$map_pct, names.arg = mapping_stats$sample, horiz=TRUE,
                      xlab="Mapping %", ylab = "File",xlim=c(0,100), cex.names = 0.8, las=2)
par(op)

lower <- mapping_stats$map_pct - mapping_stats$map_std
upper <- mapping_stats$map_pct + mapping_stats$map_std

#arrows(mapping.plot, lower, mapping.plot, upper, angle=90, code=3)
arrows(lower, mapping.plot, upper, mapping.plot, angle=90, code=3, length=.1)
dev.off()
