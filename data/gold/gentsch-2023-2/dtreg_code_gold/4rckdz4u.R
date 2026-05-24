# written with R version 4.1.3 (2022-03-10) -- "One Push-Up"
# by Norman Gentsch - gentsch@ifbk.uni-hannover.de
# Institute of Soil Science
# Leibniz University Hannover

library(tidyverse)
library(lme4)
library(emmeans)
library(lmerTest)
library(plyr)
library(pairwiseCI)
library(multcomp)
library(multcompView)
library(ggpubr)

# function to extract the pairwise letters from the list
pairwiseLetters <- function (x) {
  df <- data.frame(x$byout)$p.value
  names(df) <- row.names(data.frame(x$byout))
  comp <- multcompLetters(df,compare = "<",threshold = 0.05,Letters = c(letters, LETTERS, "."),reversed = FALSE)
  data.frame(.group = comp$Letters,
             cc_variant = names(comp$Letters))
}

# standard error calculation
se <- function(x) sqrt(var(x,na.rm=TRUE)/length(na.omit(x)))

# set vector with colors and label
COL <- c("Fallow" = "slategray", "Mustard" = "red3" , "Clover" = "OliveDrab", "Oat" = "Gold", 
         "Phacelia" ="SteelBlue", "Mix4" = "orchid3", "Mix12"= "orange4")

COL1 <- c("Fallow" = "black", "Mustard" = "red3" , "Clover" = "OliveDrab", "Oat" = "Gold", 
          "Phacelia" ="SteelBlue", "Mix4" = "orchid3", "Mix12"= "orange4")

COL.type <- c("Fallow"="black", "Single"= "tomato", "Mix"="darkmagenta")

# customized ggplot theme 
theme_set(theme_bw())
theme_myBW <- theme(axis.title.x = element_text(size = 10, color = "black"), 
                    axis.title.y = element_text(angle = 90, vjust = 1.5, size = 10, color = "black"),
                    axis.text.x = element_text(size = 10, color = "black"), 
                    axis.text.y = element_text(size = 10, color = "black"), 
                    axis.ticks =element_line(colour="black"),
                    strip.text.x = element_text(size = 10, color = "black"),
                    strip.background = element_blank(),
                    panel.border =element_rect(colour="black", fill=NA), 
                    panel.grid.major = element_blank(),
                    panel.grid.minor = element_blank(),
                    plot.title = element_text(size = 12, hjust=0.5),
                    legend.text = element_text(size = 10),
                    legend.text.align=0,
                    legend.title =  element_text(size = 10), 
                    legend.key = element_rect(colour="white", fill = "white"),
                    legend.key.size = unit(5, "mm"),
                    legend.background = element_blank(),
                    legend.position = "bottom")



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

# the data represent approximately normally distribution
#ggplot(df.MWD, aes(x=MWD_cor))+
#  geom_histogram(aes(y =..density..))+
#  geom_density(col=2)


# pairwise comparison of CC_variants
pw.MWD <- function(x) {
  pairwiseTest(MWD_cor ~ cc_variant, data = x)
}

pw.list.MWD <- dlply(df.MWD, .(depth), pw.MWD)

# apply function on list and produce data frame for plotting
(df.pw.MWD <-  ldply(pw.list.MWD, .fun=pairwiseLetters))


# comparison of plot B with a mixed model
lm.mwd <- lmer(MWD_cor ~ cc_type + (1|depth), df.MWD)
lm.mwd

df.pw.MWD.tot <- cld(emmeans(lm.mwd, list(pairwise ~ cc_type)), Letters=letters, sort=FALSE)
df.pw.MWD.tot

# plot results
df.MWD$depth2 <- gsub(" cm", "", df.MWD$depth)

df.MWD[c('depth2', 'MWD_cor')]

(p2 <- ggplot(df.MWD, aes(x=as.numeric(Soil_depth), y = MWD_cor, color=cc_type))+
    geom_smooth(method = "auto", se=T, alpha = 0.2)+
    scale_x_reverse(breaks=as.numeric(df.MWD$Soil_depth), labels = df.MWD$depth2)+
    geom_text(data = df.pw.MWD.tot, aes(y=emmean+SE, x=3, label=.group), size=4, color="black", nudge_x = -0.05)+
    coord_flip() +
    scale_color_manual(values = COL.type)+
    labs(x="Soil depth (cm)", y= expression("MWD (mm)"), color="")+
    theme_myBW +
    theme(legend.position = "bottom")
)

#ggsave("figure-2b.png", plot = p2, scale=0.5)
p2

# overall effects of CC from a LMM (linear mixed effect model)
# Input: df.MWD
# Formula: MWD_cor ~ cc_type + (1|depth)
# Output Figure: Fig.2b.png
# Output Dataset: df.pw.MWD.tot

# Generate Output Dataset
class(df.pw.MWD.tot) <- "data.frame"

library(dtreg)
source("utils/functions.r")

dt1 <- dtreg::load_datatype("https://doi.org/21.T11969/feeb33ad3e4440682a4d") # Data analysis
dt2 <- dtreg::load_datatype("https://doi.org/21.T11969/c6b413ba96ba477b5dca") # Multilevel analysis

#check_name_mapping("CATCHY_aggregate_stability_2020_block2.csv", file_type="csv")

instance <- dt1$data_analysis(
  is_implemented_by=get_resource_url("figure-2b-snippet.R"),
  has_part=dt2$multilevel_analysis(
    label="Overall effects of cover crops (CC) from a linear mixed model (LMM).",
    executes=dt2$software_method(
      label="lmer",
      has_support_url="https://search.r-project.org/CRAN/refmans/lmerTest/html/lmer.html",
      is_implemented_by="cld(emmeans(lmer(MWD_cor ~ cc_type + (1|depth), df.MWD), list(pairwise ~ cc_type)), Letters=letters, sort=FALSE)",
      part_of=dt2$software_library(
        label="lmerTest",
        has_support_url="https://doi.org/10.32614/CRAN.package.lmerTest",
        version_info="3.1.3",
        part_of=dt2$software(
          label="R",
          version_info="4.3.2",
          has_support_url="https://www.r-project.org"
        ) 
      )
    ),
    targets=dt2$component(label="MWD_cor"),
    level=dt2$component(label="depth"),
    has_input=dt2$data_item(
      source_url=get_resource_url("catchy_aggregate_stability_2020_block2.csv"),
      has_characteristic=dt2$matrix_size(
        number_of_rows=nrow(df.20),
        number_of_columns=ncol(df.20)
      )
    ),
    has_output=dt2$data_item(
      label="Estimated marginal means for cover crop (CC) type.",
      source_table=df.pw.MWD.tot,
      has_part=c(
        dt2$component(label="cc_type"),
        dt2$component(label="emmean"),
        dt2$component(label="SE"),
        dt2$component(label="df"),
        dt2$component(label="lower.CL"),
        dt2$component(label="upper.CL"),
        dt2$component(label=".group")
      ),
      has_characteristic=dt2$matrix_size(
        number_of_rows=nrow(df.pw.MWD.tot),
        number_of_columns=ncol(df.pw.MWD.tot)
      ),
      has_expression=dt2$figure(
        source_url=get_resource_url("figure-2b.png")
      )
    )
  )
)

json <- dtreg::to_jsonld(instance)
write(json, get_mapped_name("figure-2b.json"))