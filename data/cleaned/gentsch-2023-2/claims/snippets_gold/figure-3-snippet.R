# /// script
# requires-r = "==4.5.1"
# dependencies = [
#   "plyr==1.8.9",
#   "reshape2==1.4.4",
#   "tidyverse==2.0.0"
# ]
# ///
library(plyr)
library(reshape2)
library(tidyverse)

df.20 <- read.csv("https://service.tib.eu/ldmservice/dataset/60540bb4-11f2-4dc9-893f-cc2523b9c4f9/resource/8d4b0f77-7608-44fe-82c0-b3961db5f8c3/download/mkhogda1.csv")

for(i in c(3:9, 11:18)) {
  df.20[,i] <- as.factor(df.20[,i])
}

df.20$cc_variant <- recode(df.20$cc_variant, "1" ="Fallow", "2"="Mustard", "3"="Clover", 
                           "4" = "Oat", "5" = "Phacelia","6" ="Mix4", "7"="Mix12")
df.20$depth <- recode(df.20$depth, "0-10" = "0-10 cm", "20-30"="20-30 cm", "30-40"="30-40 cm")
df.20$cc_fac <- ifelse(df.20$cc_variant =="Fallow", "Fallow", "Cover crop")

df.20$cc_type <- ifelse(df.20$cc_variant %in% c("Mix4", "Mix12"), "Mix", "Single")
df.20$cc_type <- as.factor(ifelse(df.20$cc_variant == "Fallow", "Fallow", df.20$cc_type))

df.20$Fraction <- factor(df.20$Fraction, levels=c("<1","2-1","4-2","8-4","16-8", "bulk"))

df.MWD <- subset(df.20, Fraction=="bulk")

df.frac <- subset(df.20, Fraction!="bulk")
df.MWD <- merge(df.MWD, spread(df.frac[, c("Plot","cc_variant","cc_type", "depth","Fraction", "OC_Frac_pc")], Fraction , OC_Frac_pc), 
                by=c("Plot","cc_variant","cc_type", "depth"))

library(lavaan)
library(tidySEM)
#library(ggbiplot)

df.sem <- df.MWD
df.sem <- rename(df.sem, c("OC1"="<1", "OC2_1"="2-1", "OC4_2"="4-2", "OC8_4"="8-4", "OC16_8"="16-8"))
df.sem$cc_variant.n <- as.numeric(df.sem$cc_variant)
df.sem$cc_type.n <- as.numeric(df.sem$cc_type)
df.sem <- subset(df.sem, Clay<10)
df.sem <- subset(df.sem, OC4_2<15)
model.syn.base <- "
# latent variable
Distribution =~ OC1 + OC4_2 + OC8_4 + OC16_8
Soil_prop =~ BD + Clay + OC
# variances and covariances
OC1 ~~ OC8_4
OC1 ~~ OC16_8
OC1 ~~ OC4_2
OC8_4~~OC4_2
"
model.syn.opt <- "
# latent variable
Distribution =~ OC1 + OC4_2 + OC8_4 + OC16_8
Soil_prop =~ BD + Clay + OC
# regression
Distribution ~ cc_type.n + Soil_prop + MWD_cor
# variances and covariances
OC1 ~~ OC8_4
OC1 ~~ OC16_8
OC1 ~~ OC4_2
OC8_4~~OC4_2
"
sem.opt <- sem(model.syn.opt, data = df.sem)
leyout.sem <- get_layout("OC1", "OC4_2","", "OC8_4", "OC16_8",
                         "cc_type.n", "", "Distribution", "","MWD_cor",
                         "", "", "Soil_prop", "","",
                         "", "OC", "BD", "Clay","",
                         rows =4)
p <- prepare_graph(model=sem.opt, layout = leyout.sem)
# changing nod names for plotting
p$nodes$name <- recode(p$nodes$name, Distribution ="Aggreg. \n distrib.", 
                       Soil_prop = "Soil\n propert.", 
                       MWD_cor="MWD", 
                       cc_type.n ="Cover crop\n type", 
                       OC1="< 1 mm", 
                       OC8_4="8-4 mm", 
                       OC4_2 = "4-2 mm",
                       OC16_8 = "16-8 mm")
pM <- prepare_graph(sem.opt, layout = leyout.sem)
pM <-   edit_graph(pM, { label = paste(est_sig_std) }, element = "edges")
pM <-   edit_graph(pM, { label = paste(p$nodes$name) }, element = "nodes")
pM <-   label_color_latent(pM, "blue")
pM <-   label_size_load(pM, label_size = 3)
pM <-   color_load(pM, color = "gray60")
pM <-   label_size_obs(pM, label_size = 3) # names
pM <-   label_size_latent(pM, label_size = 3)
pM <-   label_size_cov(pM, label_size = 3)
pM <-   label_size_reg(pM, label_size = 3)
pM <-   label_alpha_obs(pM, label_alpha = 0 )
pM <-   label_alpha_latent(pM, label_alpha = 0)
pM <-   label_alpha_load(pM, label_alpha = 0.3)
pM <-   hide_var(pM) # hide variances of factors
pM <- plot(pM)
pM

pM2 <- prepare_graph(sem.opt, layout = leyout.sem)
pM2 <-  edit_graph(pM2,{ label = paste(est_sig_std) }, element = "edges")
pM2 <-  edit_graph(pM2, { label = paste(p$nodes$name) }, element = "nodes")
tab <- edges(pM2)[ , c("from", "to", "est_sig_std")]
tab[tab=='Distribution'] <-  "Aggreg. distrib."
tab[tab=='MWD_cor'] <-  "MWD"
tab[tab=='OC1'] <-  "< 1 mm"
tab[tab=='OC8_4'] <-  "< 8-4 mm"
tab[tab=='OC4_2'] <-  "< 4-2 mm"
tab[tab=='OC16_8'] <-  "< 16-8 mm"
tab[tab=='cc_type.n'] <-  "Cover crop type"
class(tab) <- "data.frame"
tab