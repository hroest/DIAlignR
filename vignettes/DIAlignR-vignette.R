## ----setup, include = FALSE----------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ----installDIAlignR, eval=FALSE-----------------------------------------
#  require(devtools)
#  install_github("Roestlab/DIAlignR")

## ----loadDIAlignR--------------------------------------------------------
library(DIAlignR)

## ----loadChroms, eval=FALSE----------------------------------------------
#  library(mzR)
#  library(signal)
#  TargetPeptides <- read.table("500Peptide4Alignment.csv", sep = ",", header = T)
#  temp <- list.files(pattern="*.mzML", recursive = TRUE)
#  for(filename in temp){
#    # This makes sure that order of extracted MS2 chromatograms is same for each run.
#    mz <- openMSfile(filename, backend = "pwiz")
#    chromHead <- chromatogramHeader(mz)
#    filename <- gsub("(.*)(/hroest_)(.*)(_SW.chrom.mzML)", replacement = "\\3", filename)
#    chromatogramIndices <- chromHead$chromatogramIndex[match(TargetPeptides$transition_name, chromHead$chromatogramId)]
#    TargetPeptides[filename] <- chromatogramIndices
#    transition_group_ids <- unique(TargetPeptides$transition_group_id)
#    ChromsExtractedPerRun <- sapply(transition_group_ids, function(id){
#      chromIndices <- chromatogramIndices[TargetPeptides$transition_group_id == id]
#      # ChromsExtracted <- lapply(1:length(chromIndices), function(i) chromatograms(mz, chromIndices[i]))
#      ChromsExtracted <- lapply(1:length(chromIndices), function(i) {
#        rawChrom <- chromatograms(mz, chromIndices[i])
#        rawChrom[,2] <- sgolayfilt(rawChrom[,2], p = 4, n = 9) # To smooth chromatograms, use Savitzky-Golay filter
#        return(rawChrom)
#      } )
#      return(ChromsExtracted)
#    })
#    names(ChromsExtractedPerRun) <- transition_group_ids
#    rm(mz)
#    saveRDS(ChromsExtractedPerRun, paste0(filename, "_ChromSelected.rds"))
#  }
#  write.table(TargetPeptides, file = "TargetPeptidesWchromIndex.csv", sep = ",")
#  
#  # Load chromatograms of all runs
#  temp <- list.files(pattern = "*_ChromSelected.rds")
#  StrepChroms1 <- list()
#  for(i in 1:length(temp)){
#    StrepChroms1[[i]] <- readRDS(temp[i])
#  }
#  temp <- sapply(temp, strsplit, split = "_ChromSelected.rds", USE.NAMES = FALSE)
#  names(StrepChroms1) <- temp

## ----globalFit-----------------------------------------------------------
run_pair <- c("run1", "run2")
loess.fit <- getLOESSfit(run_pair, peptides, oswOutStrep, 0.15)
StrepAnnot <- as.data.frame(StrepAnnot)
predict.run2 <- predict(loess.fit, data.frame(RUN1 = StrepAnnot[, run_pair[1]]))
Err <- predict.run2 - StrepAnnot[,run_pair[2]]

## ----plotGlobal, fig.width=6, fig.align='center', fig.height=6-----------
plotErrorCurve <- function(x, clr = "black", SameGraph = FALSE, xmax = 120, ...){
    x <- x[!is.na(x)]
    breaks = seq(0, xmax, by=0.5)
    duration.cut = cut(x, breaks, right = FALSE) 
    duration.freq = table(duration.cut)
    cumfreq0 = c(0, cumsum(duration.freq))
    if(SameGraph == TRUE){lines(breaks, cumfreq0/length(x), col = clr, ...)}
    else{plot(breaks, cumfreq0/length(x), col = clr, type = "l", ...)}
}
plotErrorCurve(abs(Err), "blue", xlab = "Retention time difference (in sec)", ylab = "Cumulative fraction of peptides")

## ----localFit, eval=TRUE-------------------------------------------------
gapQuantile <- 0.5; goFactor <- 1/8; geFactor <- 40
simMeasure <- "dotProductMasked"
run_pair <- c("run1", "run2")
Err <- matrix(NA, nrow = length(peptides), ncol = 1)
rownames(Err) <- peptides
for(peptide in peptides){
  s <- getSimilarityMatrix(StrepChroms, peptide, run_pair[1], run_pair[2], type = simMeasure)
  gapPenalty <- getGapPenalty(s, gapQuantile, type = simMeasure)
  Alignobj <- getAffineAlignObj(s, go = gapPenalty*goFactor, ge = gapPenalty*geFactor)
  AlignedIndices <- getAlignment(Alignobj)
  tA <- StrepChroms[[run_pair[1]]][[peptide]][[1]][["time"]]
  tB <- StrepChroms[[run_pair[2]]][[peptide]][[1]][["time"]]
  tA.aligned <- mapIdxToTime(tA, AlignedIndices[[1]][,"indexA_aligned"])
  tB.aligned <- mapIdxToTime(tB, AlignedIndices[[1]][,"indexB_aligned"])
  predictTime <- tB.aligned[which.min(abs(tA.aligned - StrepAnnot[peptide, run_pair[1]]))]
  deltaT <- predictTime - StrepAnnot[peptide, run_pair[2]]
  Err[peptide, 1] <- deltaT
}

## ----plotLocal, fig.width=6, fig.align='center', fig.height=6, fig.show='hold'----
plotErrorCurve(abs(Err), "darkgreen", SameGraph = FALSE, xlab = "Retention time difference (in sec)", ylab = "Cumulative fraction of peptides")

## ----hybridAlignParam----------------------------------------------------
samplingTime <-3.4 # In example dataset, all points are acquired at 3.4 second interval.
samples4gradient <- 100; RSEdistFactor <- 3.5; hardConstrain <- FALSE
pair_names <- vector(); runs <- names(StrepChroms)
for (i in 1:(length(runs)-1)){
    for (j in (i+1): length(runs)){
        pair_names <- c(paste(runs[i], runs[j], sep = "_"), pair_names)
    }}
globalStrep <- matrix(NA, nrow = 1, ncol = length(pair_names))
colnames(globalStrep) <- pair_names
rownames(globalStrep) <- c("RSE")

for(pair in pair_names){
  run_pair <- strsplit(pair, split = "_")[[1]]
  Loess.fit <- getLOESSfit(run_pair, peptides, oswOutStrep, 0.1)
  globalStrep["RSE", pair] <- Loess.fit$s
}
meanRSE <- mean(globalStrep["RSE",])

## ----hybridAlign, eval=TRUE----------------------------------------------
gapQuantile <- 0.5; goFactor <- 1/8; geFactor <- 40
simMeasure <- "dotProductMasked"
run_pair <- c("run1", "run2"); pair <- "run1_run2"
Err <- matrix(NA, nrow = length(peptides), ncol = 1)
rownames(Err) <- peptides
Loess.fit <- getLOESSfit(run_pair, peptides, oswOutStrep, 0.1)
for(peptide in peptides){
  s <- getSimilarityMatrix(StrepChroms, peptide, run_pair[1], run_pair[2], type = simMeasure)
  gapPenalty <- getGapPenalty(s, gapQuantile, type = simMeasure)
  tRunAVec <- StrepChroms[[run_pair[1]]][[peptide]][[1]][["time"]]
  tRunBVec <- StrepChroms[[run_pair[2]]][[peptide]][[1]][["time"]]
  noBeef <- ceiling(RSEdistFactor*min(globalStrep["RSE", pair], meanRSE)/samplingTime)
  if(hardConstrain) {
    MASK <- calcNoBeefMaskGlobal(tRunAVec, tRunBVec, Fit = Loess.fit, noBeef)
    s <- constrainSimilarity(s, MASK, -2*max(s))
    } else {
      MASK <- calcNoBeefMaskGlobalWSlope(tRunAVec, tRunBVec, Fit = Loess.fit, noBeef)
      s <- constrainSimilarity(s, MASK, -2*max(s)/samples4gradient) # it will take 100 time points to reach -2max
    }
  Alignobj <- getAffineAlignObj(s, go = gapPenalty*goFactor, ge = gapPenalty*geFactor)
  AlignedIndices <- getAlignment(Alignobj)
  tA <- StrepChroms[[run_pair[1]]][[peptide]][[1]][["time"]]
  tB <- StrepChroms[[run_pair[2]]][[peptide]][[1]][["time"]]
  tA.aligned <- mapIdxToTime(tA, AlignedIndices[[1]][,"indexA_aligned"])
  tB.aligned <- mapIdxToTime(tB, AlignedIndices[[1]][,"indexB_aligned"])
  predictTime <- tB.aligned[which.min(abs(tA.aligned - StrepAnnot[peptide, run_pair[1]]))]
  deltaT <- predictTime - StrepAnnot[peptide, run_pair[2]]
  Err[peptide, 1] <- deltaT
}

## ----plotHybrid, fig.width=6, fig.align='center', fig.height=6-----------
plotErrorCurve(abs(Err), "red", SameGraph = FALSE, xlab = "Retention time difference (in sec)", ylab = "Cumulative fraction of peptides")

## ----VisualizeAlignment, fig.width=6, fig.align='center', fig.height=6, eval=TRUE----
library(lattice)
library(ggplot2)
library(reshape2)

plotChromatogram <- function(data, run, peptide, StrepAnnot, printTitle =TRUE){
  df <- do.call("cbind", data[[run]][[peptide]])
  df <- df[,!duplicated(colnames(df))]
  df <- melt(df, id.vars="time", value.name = "Intensity")
  g <- ggplot(df, aes(time, Intensity, col=variable)) + geom_line(show.legend = FALSE) + theme_bw()
  if(printTitle) g <- g + ggtitle(paste0(run, ", ",peptide)) + theme(plot.title = element_text(hjust = 0.5))
  g <- g + geom_vline(xintercept=StrepAnnot[peptide, run], lty="dotted", size = 0.4)
  return(g)
}

levelplot(s, axes = TRUE, xlab = "run1 index", ylab = "run2 index")
Path <- getAlignmentPath(AlignedIndices[[1]], s)
levelplot(s, axes = TRUE, xlab = "run1 index", ylab = "run2 index", main = paste0("Alignment path through the ", simMeasure, " similarity matrix\n for ", peptide)) + latticeExtra::as.layer(levelplot(Path, col.regions = c("transparent", "green"), alpha = 1, axes = FALSE))

## ----sessionInfo, eval=TRUE----------------------------------------------
devtools::session_info()

