hash_lookup <- function(in_hash, in_vector){
  # This function allows replacement of the hash object with similar behavior from the 
  # hashmap object (which doesn't seem to work in R4.0). in_hash should be generated as such:
  #     in_hash <- hash(vector_of_keys, vector_of_values)
  # In this function, in_vector is a vector of the keys that you desire to be looked up.
  # The output is a vector of same length as the in_vector, but containing the values.
  # If an input is not found in the hash, NA will be returned as value.
  
  result <- c()
  for (key in in_vector) {
    value = in_hash[[key]]
    
    # If item can't be found, value is NA
    if (is.null(value)) {
      value = NA
    }
    
    result = c(result, value)
  }
  result
}

save_pheatmap_pdf <- function(x, filename, width=7, height=7) {
  stopifnot(!missing(x))
  stopifnot(!missing(filename))
  pdf(filename, width=width, height=height)
  grid::grid.newpage()
  grid::grid.draw(x$gtable)
  dev.off()
}

round_sci <- function(num, digits = 2) {
  # Extract the exponent of the number
  exponent <- floor(log10(abs(num)))
  
  # Adjust the number by the exponent
  shifted_number <- num * 10^(-exponent)
  
  # Round the shifted number
  rounded_shifted_number <- round(shifted_number, digits)
  
  # Shift the decimal places back to the original position
  rounded_number <- rounded_shifted_number * 10^exponent
  
  return(rounded_number)
}

round_to_k <- function(num) {
  if(num < 100) {
    return(as.character(num))
  }
  rounded <- round(num / 100) / 10
  if (rounded == floor(rounded)) {
    # If rounded value is a whole number, format without decimal
    return(paste0(rounded, "K"))
  }
  return(paste0(rounded, "K"))
}
