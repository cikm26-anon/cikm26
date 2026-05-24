# /// script
# requires-r = "==4.5.1"
# dependencies = [
#   "tidyverse==2.0.0",
#   "lme4==1.1.35.1",
#   "emmeans==1.10.0",
#   "multcomp==1.4.25"
# ]
# ///
library(tidyverse)
library(lme4)
library(emmeans)
library(multcomp)

COL.type <- c("Fallow"="black", "Single"= "tomato", "Mix"="darkmagenta")
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

df.20 <- read.csv("https://service.tib.eu/ldmservice/dataset/60540bb4-11f2-4dc9-893f-cc2523b9c4f9/resource/8d4b0f77-7608-44fe-82c0-b3961db5f8c3/download/mkhogda1.csv", check.names=FALSE)

df.20$cc_variant <- recode(df.20$cc_variant, "1" ="Fallow", "2"="Mustard", "3"="Clover", 
                           "4" = "Oat", "5" = "Phacelia","6" ="Mix4", "7"="Mix12")
df.20$cc_type <- ifelse(df.20$cc_variant %in% c("Mix4", "Mix12"), "Mix", "Single")
df.20$cc_type <- as.factor(ifelse(df.20$cc_variant == "Fallow", "Fallow", df.20$cc_type))
df.20$Fraction <- factor(df.20$Fraction, levels=c("<1","2-1","4-2","8-4","16-8", "bulk"))
df.MWD <- subset(df.20, Fraction=="bulk")

lm.mwd <- lmer(MWD_cor ~ cc_type + (1|depth), df.MWD)
df.pw.MWD.tot <- cld(emmeans(lm.mwd, list(pairwise ~ cc_type)), Letters=letters, sort=FALSE)
df.MWD$depth2 <- gsub(" cm", "", df.MWD$depth)

ggplot(df.MWD, aes(x=as.numeric(Soil_depth), y = MWD_cor, color=cc_type))+
    geom_smooth(method = "auto", se=T, alpha = 0.2)+
    scale_x_reverse(breaks=as.numeric(df.MWD$Soil_depth), labels = df.MWD$depth2)+
    geom_text(data = df.pw.MWD.tot, aes(y=emmean+SE, x=3, label=.group), size=4, color="black", nudge_x = -0.05)+
    coord_flip() +
    scale_color_manual(values = COL.type)+
    labs(x="Soil depth (cm)", y= expression("MWD (mm)"), color="")+
    theme_myBW +
    theme(legend.position = "bottom")