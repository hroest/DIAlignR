% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get_global_fit.R
\name{getLinearfit}
\alias{getLinearfit}
\title{calculates linear fit between RT of two runs}
\usage{
getLinearfit(run_pair, peptides, oswOutput)
}
\arguments{
\item{run_pair}{A vector of length 2 with run names}

\item{peptides}{Test peptides' names}

\item{oswOutput}{list of list (OpenSWATH output)}
}
\value{
An object of class "lm"
}
\description{
This function takes in run-pairs, names of test peptides, output of OpenSWATH
which include estimated retention time of peptides.
}
