# written with R version 4.1.3 (2022-03-10) -- "One Push-Up"
# by Norman Gentsch - gentsch@ifbk.uni-hannover.de
# Institute of Soil Science
# Leibniz University Hannover

library(plyr)
library(reshape2)
library(tidyverse)
library(pairwiseCI)
library(lme4)
library(emmeans)
library(lmerTest) # p values from t statistic
library(multcomp)
library(multcompView)
library(ggpubr)
library(zoo) # na.approx
library(PerformanceAnalytics) # cor matrix

# function to extract the pairwise letters from the list
pairwiseLetters <- function (x) {
  df <- data.frame(x$byout)$p.value
  names(df) <- row.names(data.frame(x$byout))
  comp <- multcompLetters(df,compare = "<",threshold = 0.05,Letters = c(letters, LETTERS, "."),reversed = FALSE)
  data.frame(.group = comp$Letters,
             cc_variant = names(comp$Letters))
}

###################### read in data ######################
# data from initial soil inventory 2015 block 2
df.15 <- read.csv("CATCHY_soil_data_2015_block2.csv")
# BD = Bulk density in g cm-1
# Clay, silt sand in %
# OC, TN in %

str(df.15)
# change attributes
for(i in c(1:12)) {
  df.15[,i] <- as.factor(df.15[,i])
}

#data from sampling for aggregate fractionation 2020 block 2 
df.20 <- read.csv("CATCHY_aggregate_stability_2020_block2.csv")

str(df.20)
names(df.20)

for(i in c(3:9, 11:18)) {
  df.20[,i] <- as.factor(df.20[,i])
}

# recode cover crop (cc) levels
df.20$cc_variant <- recode(df.20$cc_variant, "1" ="Fallow", "2"="Mustard", "3"="Clover", 
                           "4" = "Oat", "5" = "Phacelia","6" ="Mix4", "7"="Mix12")
levels(df.20$cc_variant)

df.20$depth <- recode(df.20$depth, "0-10" = "0-10 cm", "20-30"="20-30 cm", "30-40"="30-40 cm")

df.20$cc_fac <- ifelse(df.20$cc_variant =="Fallow", "Fallow", "Cover crop")

# produce a new label
df.20$cc_type <- ifelse(df.20$cc_variant %in% c("Mix4", "Mix12"), "Mix", "Single")
df.20$cc_type <- as.factor(ifelse(df.20$cc_variant == "Fallow", "Fallow", df.20$cc_type))
levels(df.20$cc_type)

# order Fractions
df.20$Fraction <- factor(df.20$Fraction, levels=c("<1","2-1","4-2","8-4","16-8", "bulk"))
levels(df.20$Fraction)



########################### mean weight diameter (MWD) in mm ############################
# The higher the MWD as more large scale aggregates are present after water treatment

str(df.20)

df.MWD <- subset(df.20, Fraction=="bulk")
str(df.MWD)
df.MWD$cc_type
levels(df.MWD$cc_type)

# pairwise comparison of CC_variants
pw.MWD <- function(x) {
  pairwiseTest(MWD_cor ~ cc_variant, data = x)
}

# correlation of MWD with OC in aggregate fractions
# add OC distribution in fraction
df.frac <- subset(df.20, Fraction!="bulk")
df.MWD <- merge(df.MWD, spread(df.frac[, c("Plot","cc_variant","cc_type", "depth","Fraction", "OC_Frac_pc")], Fraction , OC_Frac_pc), 
                by=c("Plot","cc_variant","cc_type", "depth"))


####################################################################################################
#---------------------------------------------------------------------------------------------------
# structure equation model - evaluating factors that controls OC distribution in aggregate fractions
#---------------------------------------------------------------------------------------------------
library(lavaan)
library(tidySEM)
library(ggbiplot)

# table of loading for PCA
tabloadvar.princomp <- function(pca){
  spca<-summary(pca)
  lpca<-pca$loadings
  propvarexpl <- (spca$sdev^2)/sum(spca$sdev^2)
  cumvarexpl <- cumsum(propvarexpl)
  eigenvalue <-spca$sdev^2
  tabpca <- rbind(lpca, "prop.var.expl"=propvarexpl,"cum.var.expl"=cumvarexpl, "eigenvalue"=eigenvalue )
  return(tabpca)
}

#---------
# data preparation for model structure
df.sem <- df.MWD
names(df.sem)

# categorical variables need to be coded as numeric values 0,1,2,...
# transform CC-variant to numeric values 
levels(df.sem$cc_type)
df.sem$cc_variant.n <- as.numeric(df.sem$cc_variant)
df.sem$cc_type.n <- as.numeric(df.sem$cc_type)

# throw out outliers for Clay
df.sem <- subset(df.sem, Clay<10)

# rename special characters in names
df.sem <- rename(df.sem, c("OC1"="<1", "OC2_1"="2-1", "OC4_2"="4-2", "OC8_4"="8-4", "OC16_8"="16-8"))

# throw out outliers for OC4_2
df.sem <- subset(df.sem, OC4_2<15)

# check correlation between parameters for SEM construction
#chart.Correlation(df.sem[,c("BD","Clay","OC", "OC1", "OC2_1", "OC4_2", "OC8_4", "OC16_8")], histogram=TRUE, pch=19)

# check PCA to create latent variables from contrasting measures
str(df.sem)
pred <- c("BD","Clay","OC", "OC1", "OC2_1", "OC4_2", "OC8_4", "OC16_8")
pca.all <- princomp(df.sem[,pred],cor=TRUE)
# Eigenvalues
pca.all$sd^2
# print factor loadings on eigenvectors
tabloadvar.princomp(pca.all)
# write table to file with Eigenvalues >0.9
# write.xlsx(round(tabloadvar.princomp(pca.all)[,c(1,2,3)], digits=2), file="PCA_predictors.xlsx")

# OC2_1 and OC4_2 have the similar loading on Comp. 1 and 2
# therefore OC2_1 does not fit the data structure of the base model below
# due to the redundancy of OC2_1 and OC4_2 we exclude OC2_1 from the latent variable construction

# SEM model syntax base model
# =~ is measured by
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

# Step 1:
# fit the base model
sem.base <- sem(model.syn.base, data = df.sem)
summary(sem.base,  fit.measures= T, standardized=T)
fitMeasures(sem.base, c('chisq', 'df', 'pvalue', 'cfi', 'rmsea', 'srmr', 'AIC'))
# Model evaluation according to https://m-clark.github.io/sem/sem.html:
# the fitting ended normally
# global fit = general fitting of the model to the data
#            * P-value of the Chi-square test is =0.1   (should be not significant > 0.5)
#            * CFI = 0.979 (should be >0.95)
#            * RMSEA =  0.101 (should be < 0.6, and p-value not significant)
#            * SRMR = 0.053 (should be lower than 0.08)
# the global fit indexes suggested that the model fits the data well

# local fit = if the model fits in all parts or some parts do not fit to the data
# therefore we use the modification indexes
# the index showed at which paths the model could be improved (according to Chisq-test) if we would allow additional paths
mi.base <- modindices(sem.base)
# explore modification larger 10 
mi.base[mi.base$mi>10,]
# zero suggestions >10 
# further, the variances of variables are not negative
# the standardized loading of indicator variables have a relatively high loading on factors



# Step 2:
# optimize the model and include the structure equation
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
OC8_4 ~~ OC4_2
"

# fit the base model
sem.opt <- sem(model.syn.opt, data = df.sem)
summary(sem.opt,  fit.measures= T, standardized=T, rsquare=T)
fitMeasures(sem.opt, c('chisq', 'df', 'pvalue', 'cfi', 'rmsea', 'srmr', 'AIC'))

lavTestLRT(sem.opt, sem.base)
# all fit parameters indicate the model is fitting the data as the base model
# according to AIC (lower AIC in sem.opt) the model improved as compared to the base model 
# all regression paths are significant 
# explore suggestions for improvements
mi <- modindices(sem.opt)
# explore mod indexes larger 10
mi[mi$mi>10,]

# plot SEM with tidySEM
# Caspar J. van Lissa (2022). tidySEM: Tidy Structural Equation Modeling. R package
#version 0.2.3. https://CRAN.R-project.org/package=tidySEM

leyout.sem <- get_layout("OC1", "OC4_2","", "OC8_4", "OC16_8",
                         "cc_type.n", "", "Distribution", "","MWD_cor",
                         "", "", "Soil_prop", "","",
                         "", "OC", "BD", "Clay","",
                         rows =4)

#graph_sem(model=sem.opt, layout = leyout.sem)

p <- prepare_graph(model=sem.opt, layout = leyout.sem)

#p$edges
str(p$nodes)
# changing nod names for plotting
p$nodes$name <- recode(p$nodes$name, Distribution ="Aggreg. \n distrib.", 
                       Soil_prop = "Soil\n propert.", 
                       MWD_cor="MWD", 
                       cc_type.n ="Cover crop\n type", 
                       OC1="< 1 mm", 
                       OC8_4="8-4 mm", 
                       OC4_2 = "4-2 mm",
                       OC16_8 = "16-8 mm")

p$nodes$name

# Plot SEM and produce Fig.3 


# Create SEM Graph
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
# Save PNG
#ggsave("figure-3.png", pM)

##################### end script #########################################

##################### ORKG Output ########################################


# Generate output dataset with new labels
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

library(dtreg)
source("utils/functions.r")

dt1 <- dtreg::load_datatype("https://doi.org/21.T11969/feeb33ad3e4440682a4d") # Data analysis
dt2 <- dtreg::load_datatype("https://doi.org/21.T11969/437807f8d1a81b5138a3") # Factor analysis

#check_name_mapping("figure-3-snippet.R", file_type="R")

instance <- dt1$data_analysis(
  is_implemented_by=get_resource_url("figure-3-snippet.R"),
  has_part=dt2$factor_analysis(
    label="Structural equation model (SEM) investigating the impact of parameters on aggregate organic carbon (OC) distribution.",
    executes=dt2$software_method(
      label="sem",
      is_implemented_by='sem("# latent variable
Distribution =~ OC1 + OC4_2 + OC8_4 + OC16_8
Soil_prop =~ BD + Clay + OC
# regression
Distribution ~ cc_type.n + Soil_prop + MWD_cor
# variances and covariances
OC1 ~~ OC8_4
OC1 ~~ OC16_8
OC1 ~~ OC4_2
OC8_4 ~~ OC4_2", data = df.sem)',
      part_of=dt2$software_library(
        label="lavaan",
        has_support_url="https://doi.org/10.32614/CRAN.package.lavaan",
        version_info="0.6.19",
        part_of=dt2$software(
          label="R",
          version_info="4.3.2",
          has_support_url="https://www.r-project.org"
        ) 
      )
    ),
    has_input=dt2$data_item(
      source_url=get_resource_url("catchy_aggregate_stability_2020_block2.csv"),
      has_characteristic=dt2$matrix_size(
        number_of_rows=nrow(df.20),
        number_of_columns=ncol(df.20)
      )
    ),
    has_output=dt2$data_item(
      label="Structural equation model (SEM) investigating the impact of parameters on aggregate organic carbon (OC) distribution.",
      source_table=tab,
      has_part=c(
        dt2$component(label="from"),
        dt2$component(label="to"),
        dt2$component(label="est_sig_std")
      ),
      has_characteristic=dt2$matrix_size(
        number_of_rows=nrow(tab),
        number_of_columns=ncol(tab)
      ),
      has_expression=dt2$figure(
        source_url=get_resource_url("figure-3.png")
      )
    )
  )
)

json <- dtreg::to_jsonld(instance)
write(json, get_mapped_name("figure-3.json"))