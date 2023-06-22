#!/usr/bin/env Rscript

# Load required libraries
library(argparse)
library(tidyverse)

# Define the argument parser
parser <- ArgumentParser(description = "This script reads in an input file and a fit RDS object,
                                      runs a prediction based on a glm fit model, and adds a new
                                      column to the input file called 'interaction'. The 
                                      'interaction' column is 1 if the prediction is true, and 
                                      0 otherwise.")
# Add arguments
parser$add_argument("--infile", required=TRUE, help="Path to the input file.")
parser$add_argument("--fit", required=TRUE, help="Path to the fit RDS object.")
parser$add_argument("--outfile", required=TRUE, help="Path to the output file.")
parser$add_argument("--infile_columns", 
                    default="m1,m2,pae,n_contacts,n_interface_residues,cross_chain_cluster,n1,n2",
                    help="Comma-delimited string that indicates the column names for input file.
                    Default: m1,m2,pae,n_contacts,n_interface_residues,cross_chain_cluster,n1,n2")

# Parse arguments
args <- parser$parse_args()

# Split the comma-delimited column names into a vector
columns <- str_split(args$infile_columns, pattern = ",", simplify = TRUE) %>% 
    trimws()  # trim leading and trailing whitespaces if any

# Load data and fit object
data <- read_tsv(args$infile, col_names = columns)

fit <- readRDS(args$fit)

# Run prediction
predictions <- predict(fit, newdata = data, type = "response")

# Add predictions to data
data <- data %>%
    mutate(interaction = if_else(predictions > 0.5, 1, 0))

# Write output file
write_tsv(data, args$outfile)
