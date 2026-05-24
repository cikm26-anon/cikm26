# /// script
# requires-r = "==4.5.1"
# dependencies = [
#   "plyr==1.8.9",
#   "pairwiseCI==0.1.27",
#   "tidyverse==2.0.0",
#   "multcompView==0.1.9"
# ]
# ///
library(tidyverse)
library(plyr)
library(pairwiseCI)
library(multcompView)

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

pairwiseLetters <- function (x) {
  df <- data.frame(x$byout)$p.value
  names(df) <- row.names(data.frame(x$byout))
  comp <- multcompLetters(df,compare = "<",threshold = 0.05,Letters = c(letters, LETTERS, "."),reversed = FALSE)
  data.frame(.group = comp$Letters,
             cc_variant = names(comp$Letters))
}

pw.MWD <- function(x) {
  pairwiseTest(MWD_cor ~ cc_variant, data = x)
}

df.20 <- read.csv("https://service.tib.eu/ldmservice/dataset/60540bb4-11f2-4dc9-893f-cc2523b9c4f9/resource/8d4b0f77-7608-44fe-82c0-b3961db5f8c3/download/mkhogda1.csv", check.names=FALSE)

for(i in c(3:9, 11:18)) {
  df.20[,i] <- as.factor(df.20[,i])
}

df.20$cc_variant <- recode(df.20$cc_variant, "1" ="Fallow", "2"="Mustard", "3"="Clover", 
                             "4" = "Oat", "5" = "Phacelia","6" ="Mix4", "7"="Mix12")
df.20$depth <- recode(df.20$depth, "0-10" = "0-10 cm", "20-30"="20-30 cm", "30-40"="30-40 cm")
df.20$cc_type <- ifelse(df.20$cc_variant %in% c("Mix4", "Mix12"), "Mix", "Single")
df.20$cc_type <- as.factor(ifelse(df.20$cc_variant == "Fallow", "Fallow", df.20$cc_type))
df.MWD <- subset(df.20, Fraction=="bulk")
df.MWD <- df.MWD[,c("depth","cc_variant","MWD_cor")] 
pw.list.MWD <- dlply(df.MWD, .(depth), pw.MWD)
(df.pw.MWD <- ldply(pw.list.MWD, .fun=pairwiseLetters))
(df.pw.MWD.pvalues <- ldply(pw.list.MWD, .fun=function (x) {
  data.frame(p.value = x$byout[[1]]["p.value"],
             compnames = x$byout[[1]]["compnames"])
}))

ggplot(df.MWD, aes(x=cc_variant, y=MWD_cor, fill=cc_variant))+
    geom_jitter(shape=21, size=3.5, width = 0.2, alpha=0.3)+
    geom_text(data = df.pw.MWD, aes(x=cc_variant, y=2, label=.group), size=4, vjust = 0.2 )+
    stat_summary(fun.data = "mean_se", geom = "errorbar",width = 0.1, color="black")+
    stat_summary(fun.data = "mean_se",  geom = "point", size=4, shape=21)+
    facet_grid (depth~.,scales = "free")+
    scale_fill_manual(values = COL, guide="none")+
    labs(x="", y="MWD (mm)")+
    theme_myBW+
    theme(axis.text.x = element_text(angle = 45, hjust = 1))