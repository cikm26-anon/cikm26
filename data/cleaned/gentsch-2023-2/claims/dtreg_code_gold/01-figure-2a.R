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

pairwiseLetters <- function (x) {
  df <- data.frame(x$byout)$p.value
  names(df) <- row.names(data.frame(x$byout))
  comp <- multcompLetters(df,compare = "<",threshold = 0.05,Letters = c(letters, LETTERS, "."),reversed = FALSE)
  data.frame(.group = comp$Letters,
             cc_variant = names(comp$Letters))
}

COL <- c("Fallow" = "slategray", "Mustard" = "red3" , "Clover" = "OliveDrab", "Oat" = "Gold", 
         "Phacelia" ="SteelBlue", "Mix4" = "orchid3", "Mix12"= "orange4")

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

df.20 <- read.csv("CATCHY_aggregate_stability_2020_block2.csv", check.names=FALSE)

for(i in c(3:9, 11:18)) {
  df.20[,i] <- as.factor(df.20[,i])
}

df.20$cc_variant <- recode(df.20$cc_variant, "1" ="Fallow", "2"="Mustard", "3"="Clover", 
                             "4" = "Oat", "5" = "Phacelia","6" ="Mix4", "7"="Mix12")

df.20$depth <- recode(df.20$depth, "0-10" = "0-10 cm", "20-30"="20-30 cm", "30-40"="30-40 cm")

df.20$cc_type <- ifelse(df.20$cc_variant %in% c("Mix4", "Mix12"), "Mix", "Single")
df.20$cc_type <- as.factor(ifelse(df.20$cc_variant == "Fallow", "Fallow", df.20$cc_type))

df.MWD <- subset(df.20, Fraction=="bulk")

# pairwise comparison of CC_variants
pw.MWD <- function(x) {
  # Computes t-tests
  pairwiseTest(MWD_cor ~ cc_variant, data = x)
}

# has_specified_input
df.MWD <- df.MWD[,c("depth","cc_variant","MWD_cor")] 

pw.list.MWD <- dlply(df.MWD, .(depth), pw.MWD)

# apply function on list and produce data frame for plotting
# Small letters denoting significant difference between CC treatments by pairwise comparison 
(df.pw.MWD <- ldply(pw.list.MWD, .fun=pairwiseLetters))

# has_specified_output
(df.pw.MWD.pvalues <- ldply(pw.list.MWD, .fun=function (x) {
  data.frame(p.value = x$byout[[1]]["p.value"],
             compnames = x$byout[[1]]["compnames"])
}))

(p1 <- ggplot(df.MWD, aes(x=cc_variant, y=MWD_cor, fill=cc_variant))+
    geom_jitter(shape=21, size=3.5, width = 0.2, alpha=0.3)+
    geom_text(data = df.pw.MWD, aes(x=cc_variant, y=2, label=.group), size=4, vjust = 0.2 )+
    stat_summary(fun.data = "mean_se", geom = "errorbar",width = 0.1, color="black")+
    stat_summary(fun.data = "mean_se",  geom = "point", size=4, shape=21)+
    facet_grid (depth~.,scales = "free")+
    scale_fill_manual(values = COL, guide="none")+
    labs(x="", y="MWD (mm)")+
    theme_myBW+
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
)

#ggsave("figure-2a.png", plot = p1, width = 160, height = 100, units = "mm")

library(dtreg)
source("utils/functions.r")

dt1 <- dtreg::load_datatype("https://doi.org/21.T11969/feeb33ad3e4440682a4d") # Data analysis
dt2 <- dtreg::load_datatype("https://doi.org/21.T11969/b9335ce2c99ed87735a6") # Group comparison

#check_name_mapping("figure-2a.json", file_type="json")

instance <- dt1$data_analysis(
  is_implemented_by=get_resource_url("figure-2a-snippet.R"),
  has_part=dt2$group_comparison(
    label="Pairwise t-test with mean weight diameter (MWD) response and cover crop (CC) variant predictor.",
    executes=dt2$software_method(
      label="pairwiseTest",
      has_support_url="https://search.r-project.org/CRAN/refmans/pairwiseCI/html/pairwiseTest.html",
      is_implemented_by="pairwiseTest(MWD_cor ~ cc_variant, data = x)",
      part_of=dt2$software_library(
        label="pairwiseCI",
        has_support_url="https://doi.org/10.32614/CRAN.package.pairwiseCI",
        version_info="0.1.27",
        part_of=dt2$software(
          label="R",
          version_info="4.3.2",
          has_support_url="https://www.r-project.org"
        ) 
      )
    ),
    targets=dt2$component(label="MWD_cor"),
    has_input=dt2$data_item(
      label="Difference of mean weight diameter (MWD) between the dry and wet sieving method.",
      source_table=df.MWD,
      has_part=c(
        dt2$component(label="depth"),
        dt2$component(label="cc_variant"),
        dt2$component(label="MWD_cor")
      ),
      has_characteristic=dt2$matrix_size(
        number_of_rows=nrow(df.MWD),
        number_of_columns=ncol(df.MWD)
      )
    ),
    has_output=dt2$data_item(
      label="Pairwise t-test p-values for cover crop (CC) variants at three soil depths.",
      source_table=df.pw.MWD.pvalues,
      has_part=c(
        dt2$component(label="depth"),
        dt2$component(label="p.value"),
        dt2$component(label="compnames")
      ),
      has_characteristic=dt2$matrix_size(
        number_of_rows=nrow(df.pw.MWD.pvalues),
        number_of_columns=ncol(df.pw.MWD.pvalues)
      ),
      has_expression=dt2$figure(
        source_url=get_resource_url("figure-2a.png")
      )
    )
  )
)

json <- dtreg::to_jsonld(instance)
write(json, get_mapped_name("figure-2a.json"))