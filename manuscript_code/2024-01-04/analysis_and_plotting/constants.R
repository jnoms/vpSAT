level_order <- c("species", "genus", "family", "order", "class", "phylum", "superkingdom")


level_colors <- c(
  "species" = "#0000ff",
  "genus" = "#9d02d7",
  "family" = "#cd34b5",
  "order" = "#ea5f94",
  "class" = "#fa8775",
  "phylum" = "#ffb14e",
  "superkingdom" = "#ffd700"
)

genome_type_order <- c("dsDNA (large)", "dsDNA (medium)", "dsDNA (small)", "ssDNA", "ssRNA(-)", "ssRNA(+)", "RNA (Other)")

molecule_type_colors <- c("DNA" = "#B8D1E0", "RNA"= "#F4A4AB")

#molecule_type_colors <- c("dsDNA" = "#0000ff", "ssDNA" = "#9d02d7", "dsRNA" = "#fa8775", "ssRNA(+)" = "#ffb14e", "ssRNA(-)" = "#ffd700")

genome_type_colors <- c(
  "dsDNA (large)" = "black", 
  #"dsDNA (large)" = "#0000FF", 
  "dsDNA (medium)" = "#4F01EB",
  "dsDNA (small)" = "#9D02D7",
  "ssDNA" = "#CC45A6",
  "ssRNA(-)" = "#FA8775",
  "ssRNA(+)" = "#FFB14E",
  "RNA (Other)" = "#FFD700"
  )

genome_type_shapes <- c(
  "dsDNA (large)" = 16, 
  "dsDNA (medium)" = 15,
  "dsDNA (small)" = 17,
  "ssDNA" = 18,
  "ssRNA(-)" = 0,
  "ssRNA(+)" = 1,
  "RNA (Other)" = 2
)


# Special cases
genome_type_order_newlines <- c("dsDNA\n(large)", "dsDNA\n(medium)", "dsDNA\n(small)", "ssDNA", "ssRNA(-)", "ssRNA(+)", "RNA\n(Other)")
genome_type_colors_newlines <- c(
  "dsDNA\n(large)" = "#0000FF", 
  "dsDNA\n(medium)" = "#4F01EB",
  "dsDNA\n(small)" = "#9D02D7",
  "ssDNA" = "#CC45A6",
  "ssRNA(-)" = "#FA8775",
  "ssRNA(+)" = "#FFB14E",
  "RNA\n(Other)" = "#FFD700"
)
