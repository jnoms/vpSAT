# Read data
#------------------------------------------------#
counts <- read_tsv("inputs/merged_clusters.counts.tsv") %>%
  filter(cluster_ID != "cluster_ID")

clusters <- read_tsv("inputs/merged_clusters.tax.tsv") %>%
  filter(cluster_ID != "cluster_ID") %>%
  rename(structure_rep = cluster_rep, seq_rep = subcluster_rep)


foldseek_aln <- read_tsv("inputs/foldseek_clusters_mode0cov0.7_TMscore0.4.filt.m8")

cmap <- read_tsv("inputs/connection_map.tsv")


dali_eve <- read_tsv("inputs/dali_euk_vs_euk.filt.m8")

dali_evp <- read_tsv("inputs/dali_euk_vs_phage.filt.m8")


# Prepare hashes
#------------------------------------------------#

# Downloaded from table here https://www.ncbi.nlm.nih.gov/labs/virus/vssi/#/virus?SeqType_s=Nucleotide&SourceDB_s=RefSeq 
# added family information
fam_genome_sizes <- read_csv("inputs/ncbi_viruses_genome_lengths.csv") %>%
  filter(!is.na(Family)) %>%
  select(Family, Length, genome_type=Molecule_type) %>%
  mutate(genome_type = ifelse(Family == "Phenuiviridae", "ssRNA(-)", genome_type)) %>%
  mutate(genome_type = ifelse(Family == "Polymycoviridae", "dsRNA", genome_type)) %>%
  mutate(genome_type = ifelse(Family == "Parvoviridae", "ssDNA", genome_type)) %>%
  mutate(genome_type = ifelse(Family == "Yadokariviridae", "ssRNA(+)", genome_type)) %>%
  mutate(genome_type = ifelse(Family == "Curvulaviridae", "dsRNA", genome_type)) %>%
  mutate(genome_type = ifelse(Family == "Fusariviridae", "ssRNA(+)", genome_type)) %>%
  mutate(genome_type = ifelse(Family == "Tospoviridae", "ssRNA(-)", genome_type)) %>%
  
  # These are phage and are of Molecule type "RNA"
  filter(!Family %in% c("Steitzviridae", "Duinviridae")) %>%
  
  # These are virods
  filter(! Family %in% c("Avsunviroidae", "Pospiviroidae"))


fam_genome_size_means <- fam_genome_sizes %>%
  group_by(Family) %>%
  summarize(mean_length = mean(Length))

genome_types <- fam_genome_sizes %>%
  select(Family, genome_type) %>%
  distinct() %>%
  filter(!is.na(genome_type))

fam_genome_size_means_hash <- hash(fam_genome_size_means$Family, fam_genome_size_means$mean_length)
genome_types_hash <- hash(genome_types$Family, genome_types$genome_type)


# Modify the genome types hash
fam_genome_sizes <- genome_types %>%
  mutate(avg_genome_size = hash_lookup(fam_genome_size_means_hash, Family)) %>%
  mutate(genome_type = ifelse(grepl("ssDNA", genome_type), "ssDNA", genome_type)) %>%
  mutate(genome_type = ifelse(grepl("dsDNA", genome_type), "dsDNA", genome_type)) %>%
  mutate(genome_type = ifelse(genome_type %in% c("dsRNA","ssRNA-RT", "ssRNA(+/-)"), "RNA (Other)", genome_type)) %>%
  mutate(genome_type = ifelse(genome_type == "dsDNA" & avg_genome_size < 20000, "dsDNA (small)", genome_type)) %>%
  mutate(genome_type = ifelse(genome_type == "dsDNA" & avg_genome_size < 35000, "dsDNA (medium)", genome_type)) %>%
  mutate(genome_type = ifelse(genome_type == "dsDNA" & avg_genome_size >= 35000, "dsDNA (large)", genome_type)) %>%
  filter(!is.na(avg_genome_size), !is.na(genome_type))
genome_types_hash <- hash(fam_genome_sizes$Family, fam_genome_sizes$genome_type)




# Make hash to convert family to # species
family_species_counts <- clusters %>%
  select(family, species) %>%
  distinct() %>%
  group_by(family) %>%
  summarize(n = n()) %>%
  filter(family != "")

family_species_counts_hash <- hash(family_species_counts$family, family_species_counts$n)

# Make hash to convert species to it's family

species_to_family <- clusters %>%
  select(family, species) %>%
  distinct() %>%
  filter(family != "", species != "")

species_to_family_hash <- hash(species_to_family$species, species_to_family$family)