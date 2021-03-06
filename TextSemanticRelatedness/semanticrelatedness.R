# set global options
options(digits=3)

# Add required libraries
library(igraph)
library(lattice)
library(Matrix)
library(Hmisc)
library(MASS)
library(ggplot2)
library(gridExtra)
library(lsa)
library(proxy)
library(tm)

# load required sources
source("utils.R")

# create BOW (term-doc matrix)
txt <- system.file("texts", "lee", package = "tm")
(corpus <- Corpus(DirSource(txt, encoding = "UTF-8"), readerControl = list(language = "en")))
corpus <- tm_map(corpus, tolower)
corpus <- tm_map(corpus, removeWords, stopwords("english"))
corpus <- tm_map(corpus, stemDocument)
corpus <- tm_map(corpus, stripWhitespace)
dtm <- DocumentTermMatrix(corpus, control=list(weighting=weightTfIdf))


# load the local feature similarity graph
graph <- read.graph("G.net", format="pajek")

# load doc-concept data frame
doc_concept <- read.csv(file="doc_concept.csv", sep="$", check.names=F)

# IDF normalization of doc_concept
k <- length(row.names(doc_concept))
for(colname in names(doc_concept)){
  idf <- 1 + length(which(doc_concept[,colname] > 0))
  doc_concept[,colname] <- doc_concept[,colname] * log10(k/idf)
}

# extract all cliques
l <- maximal.cliques(graph=graph, min=2, max=NULL)

# create an empty Clique Kernel <Concept,Clique> (Kernel Matrix)
KM <- data.frame(matrix(0, nrow = ncol(doc_concept), ncol = length(l)),
                 row.names=colnames(doc_concept))
C <- character()
for(c in l){
  C <- append(C, paste(V(graph)[c]$id, collapse=":"))
}
names(KM) <- C

# fill Kernel Matrix (take a long time)
vocab <- row.names(KM)
for(c in l){
  clique <- V(graph)[c]$id
  colname <- paste(V(graph)[c]$id, collapse=":")
  for(t in clique){
    if(t %in% vocab)
      KM[t,colname] <- KM[t,colname] + 1
  }
}

# calculate different kernel matrixes
km <- KM

# skip empty cliques: 13k -> 2.6k: 0.63
notempty <- c()
for(colname in names(km)){
  if(length(which(km[,colname] > 0)) > 1)
    notempty <- append(notempty, colname)
}
km <- km[,notempty]

# IDF normalization of the kernel matrix: 0.67
k <- length(names(km))
for(rowname in row.names(km)){
  idf <- 1 + length(which(km[rowname,] > 0))
  km[rowname,] <- km[rowname,] * log10(k/idf)
  if(idf == 1)
    print(rowname)
}


# building the feature matrix using the kernel matrix
FM <- as.matrix(doc_concept) %*% as.matrix(km)

# IDF normalization of the feature matrix: 0.69
D <- nrow(FM)
for(colname in colnames(FM)){
  idf <- 1 + length(which(FM[,colname] > 0))
  FM[,colname] <- FM[,colname] * log10(D/idf)
}


# create a local similarity frame <gold,alg,bcos,label>
sim <- getlocalsimframe(doc_concept, km)

# compute correlation
correlation(dsim=sim, rtype="pearson")

