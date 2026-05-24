#' ---
#' title: "Aggregate stability cover crops 2023"
#' author: "Norman Gentsch"
#' date: "Thu Nov  2 16:43:12 2023"
#' ---
# written with R version 4.1.3 (2022-03-10) -- "One Push-Up"
# by Norman Gentsch - gentsch@ifbk.uni-hannover.de
# Institute of Soil Science
# Leibniz University Hannover

#################### packages and functions ####################
# surpress warning messages
options(warn=-1)

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
library(PerformanceAnalytics)# cor matrix
library(xlsx)




# function to extract the pairwise letters from the list
pairwiseLetters <- function (x) {
  df <- data.frame(x$byout)$p.value
  names(df) <- row.names(data.frame(x$byout))
  comp <- multcompLetters(df, compare = "<",threshold = 0.05,Letters = c(letters, LETTERS, "."),reversed = F)
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
# REWRITE_DATAURL_v1  basename=CATCHY_soil_data_2015_block2.csv  status=missing
# ORIG: df.15 <- read.csv("CATCHY_soil_data_2015_block2.csv")
df.15 <- NULL  # TODO_REWRITE_DATAURL missing CATCHY_soil_data_2015_block2.csv :: no URL found in snippets_gold for variable(s): 15
# BD = Bulk density in g cm-1
# Clay, silt sand in %
# OC, TN in %

#str(df.15)
# change attributes
for(i in c(1:12)) {
  df.15[,i] <- as.factor(df.15[,i])
}

#data from sampling for aggregate fractionation 2020 block 2 
# REWRITE_DATAURL_v1  basename=CATCHY_aggregate_stability_2020_block2.csv  status=verified
# ORIG: df.20 <- read.csv("CATCHY_aggregate_stability_2020_block2.csv")
df.20 <- read.csv("https://service.tib.eu/ldmservice/dataset/60540bb4-11f2-4dc9-893f-cc2523b9c4f9/resource/8d4b0f77-7608-44fe-82c0-b3961db5f8c3/download/mkhogda1.csv")

#str(df.20)
names(df.20)

for(i in c(3:9, 11:18)) {
  df.20[,i] <- as.factor(df.20[,i])
}

# recode cover crop (cc) levels
df.20$cc_variant <- dplyr::recode(df.20$cc_variant, "1" ="Fallow", "2"="Mustard", "3"="Clover", 
                             "4" = "Oat", "5" = "Phacelia","6" ="Mix4", "7"="Mix12")
levels(df.20$cc_variant)

df.20$depth <- dplyr::recode(df.20$depth, "0-10" = "0-10 cm", "20-30"="20-30 cm", "30-40"="30-40 cm")

df.20$cc_fac <- ifelse(df.20$cc_variant =="Fallow", "Fallow", "Cover crop")

# produce a new label
df.20$cc_type <- ifelse(df.20$cc_variant %in% c("Mix4", "Mix12"), "Mix", "Single")
df.20$cc_type <- as.factor(ifelse(df.20$cc_variant == "Fallow", "Fallow", df.20$cc_type))
levels(df.20$cc_type)

# order Fractions
df.20$Fraction <- factor(df.20$Fraction, levels=c("<1","2-1","4-2","8-4","16-8", "bulk"))
levels(df.20$Fraction)


###################### calculate OC stocks ######################
# OC stock (kg m-2) = BD (g cm-3) * OC (%) * depth (m) *10
# OC stock (t ha-1) = BD (g cm-3) * OC (%) * depth (m) *100
#################################################################
# calculate stocks 2015 for 0-10, 20-30, 30-60 cm in t ha-1

as.numeric(levels(df.15$Soil_depth))/10


df.15 <- df.15 %>%
  mutate(OC_st = OC*BD*as.numeric(Soil_depth)*10,
         TN_st = TN*BD*as.numeric(Soil_depth)*10)



# calculate OC stocks 2020 for 0-10, 20-30, 30-50 and interpolate the 10-20 cm increment
df.20.bulk <- subset(df.20, Fraction=="bulk")


df.20.bulk$Soil_depth.int <- revalue(df.20.bulk$Soil_depth, c("2" = "3", "3" = "4"))

depth2 <- data.frame(Soil_depth.int = as.factor(c(1:4)))

df.20.bulk <- ddply(df.20.bulk, .(Site, Name, Plot, year_ID),.fun = function (x){
  merge(depth2, x, by="Soil_depth.int", all.x = T)
})

# fill missing values
names(df.20.bulk)
df.20.bulk[, c(31:38)] <- NULL

df.20.bulk <- fill(df.20.bulk, c(2:14, 17:21, 31))
# fill missing increment
df.20.bulk$Soil_depth <- df.20.bulk$Soil_depth.int
df.20.bulk$depth <- as.factor(ifelse(df.20.bulk$Soil_depth=="2", "10-20 cm", as.character(df.20.bulk$depth)))

# interpolate OC and TN 
head(df.20.bulk)


df.20.bulk <- df.20.bulk %>%
  mutate(BD = na.approx(BD),
         OC = na.approx(OC),
         TN = na.approx(TN),
         d13C = na.approx(d13C),
         d15N = na.approx(d15N))

# calculate stocks
df.20.bulk <- df.20.bulk %>%
  mutate(OC_st = OC*BD*10,
         TN_st = TN*BD*10)

# summarize Stocks to 30 cm
df.20.bulk.st30 <- subset(df.20.bulk, Soil_depth.int %in% c("1","2","3"))

df.20.bulk.st30 <- df.20.bulk.st30 %>%
  group_by(Name, Plot, Block, Row, year_ID, Year, cc_variant)%>%
  summarise(OC_st = sum(OC_st),
            TN_st = sum (TN_st))



# merge data frames
names(df.15)
names(df.20.bulk)

df.all <- rbind(df.20.bulk[, names(df.15)], df.15)
#str(df.all)

############ Plot OC concentration change 2015-2020  #################
# produce supplement figures

df.all$plot_fac <- factor(paste(df.all$Plot, df.all$Soil_depth, sep="_"))
levels(df.all$Year)

df.all$Year <- factor(df.all$Year, levels = c("2015","2020"))
# plot only measured values, not interpolated. New Soil_depth index only for selection
df.all$Soil_depth2 <- ifelse(df.all$Year =="2020" & df.all$Soil_depth=="3", "2", df.all$Soil_depth)
df.all$Soil_depth2 <- ifelse(df.all$Year =="2020" & df.all$Soil_depth=="2", "0", df.all$Soil_depth2)
df.all$plot_fac <- factor(paste(df.all$Plot, df.all$Soil_depth2, sep="_"))

ggplot(subset(df.all, Soil_depth2 %in% c("1", "2")), aes(x = Year, y= OC, fill = Soil_depth2))+
  geom_point(size=3, shape=21)+
  geom_line(aes(group = plot_fac))+
  facet_grid(.~cc_variant)+
  labs(y="OC concentration (%)", fill="Soil depth")+
  scale_fill_manual(values=c("slategrey", "tomato2"), labels = c("0-10 cm", "20-30 cm"))+
  theme_myBW
  

#ggsave("Fig.S3.png", width = 160, height = 100,units = "mm", dpi = 300)



# evaluate increase of OC concentrations by LMM
ggplot(subset(df.all, Soil_depth2 %in% c("1", "2")), aes(OC)) +                                # ggplot2 histogram & density
  geom_histogram(aes(y = stat(density)), fill="gray80", color="black") +
  geom_density(col = "red")
# data are close to normal distribution

# check difference between years
lmer.OC.change <- lmer(OC ~ Year+(1|Plot:Soil_depth2), data = subset(df.all, Soil_depth2 %in% c("1", "2")))

summary(lmer.OC.change)
cld(emmeans(lmer.OC.change, list(pairwise ~ Year)), Letters=letters, sort=FALSE)
anova(lmer.OC.change)
# the increase of OC concentrations from 2015 to 2020 is significantly different


# differences in 2015 between 0-10 and 10-30
lmer.OC.depth.15 <- lmer(OC ~ depth + (1|Plot), data = subset(df.all, Year !="2020"& depth !="30-60"))
summary(lmer.OC.depth.15)
cld(emmeans(lmer.OC.depth.15, list(pairwise ~ depth)), Letters=letters, sort=FALSE)
anova(lmer.OC.depth.15)
# no difference in the upper 30 cm

########### (1)	Change of soil cultivation practices ###############
# comparizon of the two layers 2015 and 2018

df.all %>%
  filter(Soil_depth2 %in% c("1", "2")) %>%
  group_by(Year, Soil_depth2)%>%
  summarise(OC.coc = mean(OC, na.rm=T),
            OC.se = se(OC))
  
ggplot(subset(df.all, Soil_depth2 %in% c("1", "2")), aes(y=OC, x=as.factor(Soil_depth2):Year, fill=Year))+
  geom_boxplot(width=0.5, outlier.colour = NA)+
  geom_jitter(size=2, shape=21, width = 0.3, alpha=0.7)+
  labs(x= "Soil depth (cm)", y="OC (%)")+
  scale_fill_manual(values=c("slategrey", "tomato2"))+
  scale_x_discrete(labels=c("1:2015" = "0-10", "1:2020" = "0-10",
                              "2:2015" = "20-30", "2:2020" = "20-30"))+
  annotate("text", x =1:4, y = 1.3, label = c("a", "b", "a","a"))+
  theme_myBW

#ggsave("Fig.S4.png", width = 100, height = 90,units = "mm", dpi = 500)

# statistic evaluation on Figure S4
lmer.OC.depth <- lmer(OC ~ Soil_depth2*Year + (1|Year:Plot), data = subset(df.all, Soil_depth2 %in% c("1", "2")))
summary(lmer.OC.depth)
cld(emmeans(lmer.OC.depth, list(pairwise ~ Soil_depth2*Year)), Letters=letters, sort=FALSE)
anova(lmer.OC.depth)




########### OC stock evaluation 2020 ###############
# evaluate OC stocks to 40 cm soil depth
# OC stock (kg m-2) = BD (g cm-3) * OC (%) * depth (m) *10
# I used the concentration of 0-10 for 0-20, because there is usually not much change to the 10-20cm layer

# summarize Stocks to 40 cm
df.20.bulk.st40 <- df.20.bulk %>%
  group_by(Name, Plot, Block, Row, year_ID, Year, cc_variant)%>%
  summarise(OC_st = sum(OC_st),
            TN_st = sum (TN_st))


# plot stock
# pairwise comparison of CC_variants only of the measured increments
pw.OCstCC <- function(x) {
  pairwiseTest(OC_st ~ cc_variant, data = x)
}

pw.list.OCstCC <- dlply(subset(df.20.bulk, depth != "10-20 cm"), .(depth), pw.OCstCC)

# apply function on list and produce data frame for plotting
(df.pw.OCstCC <-  ldply(pw.list.OCstCC, .fun=pairwiseLetters))

(pOC1 <- ggplot(subset(df.20.bulk, depth != "10-20 cm"), aes(x=cc_variant, y=OC_st, fill=cc_variant))+
    stat_summary(fun.data = "mean_se",  geom = "bar",color="black", position = position_dodge(preserve = 'single'))+
    stat_summary(fun.data = "mean_se", geom = "errorbar",width = 0.1, color="black", position=position_dodge(preserve = 'single', width=0.9))+
    geom_jitter(size=3, alpha=0.5, shape=21, width = 0.2)+
    geom_text(data = df.pw.OCstCC, aes(x=cc_variant, y=2, label=.group), size=4, vjust = 0.2 )+
    scale_fill_manual(values=COL, guide="none")+
    labs(x="", y=expression("OC stocks ("~t~ha^-1*")"))+
    facet_wrap(.~depth, ncol = 1)+
    theme_myBW+
    theme(axis.text.x = element_text(angle = 35, hjust = 1))
)

# total stocks to 40 cm
df.st <- df.20.bulk %>%
  group_by(cc_variant, Plot)%>%
  summarise(OC_st = sum(OC_st))

(df.pw.OCst <- pairwiseLetters(pairwiseTest(OC_st ~ cc_variant, data = df.st)))

(pOC2 <- ggplot(df.st , aes(x=cc_variant, y=OC_st, fill=cc_variant))+
    stat_summary(fun.data = "mean_se",  geom = "bar",color="black", position = position_dodge(preserve = 'single'))+
    stat_summary(fun.data = "mean_se", geom = "errorbar",width = 0.1, color="black", position=position_dodge(preserve = 'single', width=0.9))+
    geom_jitter(size=3, alpha=0.5, shape=21, width = 0.2)+
    geom_text(data = df.pw.OCst, aes(x=cc_variant, y=2, label=.group), size=4, vjust = 0.2 )+
    scale_fill_manual(values=COL, guide="none")+
    labs(x="", y=expression("OC stocks 0-40 cm ("~t~ha^-1*")"))+
    theme_myBW+
    theme(axis.text.x = element_text(angle = 35, hjust = 1))
)


(p.OCst <- ggarrange(pOC1, pOC2, widths = c(2,2), labels = c('a)', 'b)')))

#ggsave("Fig.S5.png",plot = p.OCst, width = 160, height = 100, units = "mm")

# min and max of OC stocks
min(df.st$OC_st)
max(df.st$OC_st)

##correlation of OC stocks with soil parameters
#str(df.20.bulk)

ggplot(df.20.bulk, aes(x=Clay, y=OC))+
  geom_point(size=3)+
  geom_smooth(method = "lm", se=F)+
  stat_cor(aes(label =  paste(..rr.label.., ..p.label.., sep = "~`,`~")))+
  labs(x="Clay (%)", y = "OC (%)")+
  theme_myBW

ggplot(df.20.bulk, aes(x=Silt, y=OC))+
  geom_point(size=3)+
  geom_smooth(method = "lm", se=F)+
  stat_cor(aes(label =  paste(..rr.label.., ..p.label.., sep = "~`,`~")))+
  labs(x="Silt (%)", y = "OC (%)")+
  theme_myBW

ggplot(df.20.bulk, aes(x=BD, y=OC))+
  geom_point(size=3, aes(color=depth))+
  geom_smooth(method = "lm", se=T)+
  stat_cor(aes(label =  paste(..rr.label.., ..p.label.., sep = "~`,`~")))+
  labs(x=expression("BD ("*g~cm^-1*")"), y = "OC (%)")+
  theme_myBW

# No correlation of OC and texture, but strong correlation with BD

##################### evaluate Aggregate Fractions ############################
###############################################################################
#str(df.20)
df.frac <- subset(df.20, Fraction!="bulk")
levels(df.frac$depth)
levels(df.frac$Fraction)
#str(df.frac)
# evaluate mass distribution and percentage

# ordered pairwise comparison of CC_variants
pw.DS <- function(x) {
  t <- pairwiseTest(log10(DS_pc+1) ~ cc_variant, data = x)
  df <- data.frame(t$byout)$p.value
  names(df) <- row.names(data.frame(t$byout))
  comp <- multcompLetters2(DS_pc ~ cc_variant, df, data =x, reversed = T)
  data.frame(.group = comp$Letters,
             cc_variant = names(comp$Letters))
}

(df.pw.DS <- ddply(df.frac, .(depth, Fraction), pw.DS))

# calculate max values for plotting
df.pw.DS <- merge(df.pw.DS, ddply(df.frac, .(Fraction), summarize, Max=max(DS_pc)), 
                  by=c("Fraction"))
df.pw.DS

# Mass distribution
ggplot(df.frac, aes(x=cc_variant, y=DS_pc, fill = cc_variant))+
  geom_jitter(shape=21, size=3.5, width = 0.2, alpha=0.3)+
  stat_summary(fun.data = "mean_se", geom = "errorbar",width = 0.1, color="black")+
  stat_summary(fun.data = "mean_se",  geom = "point", size=4, shape=21)+
  geom_text(data = df.pw.DS, aes(x=cc_variant, y=Max+(8*Max/100), label=.group), size=4)+
  facet_grid(Fraction~depth, scales = "free")+
  scale_fill_manual(values = COL, guide="none")+
  labs(x="Cover crop", y="Proportion aggregate fraction (% DM)")+
  theme_myBW+
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("Fig.S6.png", width=170, height = 150, units = "mm")

# on CC type with soil depth
ggplot(df.frac, aes(x=as.numeric(Soil_depth), y = DS_pc, color=cc_type))+
  geom_smooth(method = "auto", se=F, alpha = 0.2)+
  scale_x_reverse(breaks=as.numeric(df.frac$depth), labels = df.frac$depth)+
  coord_flip() +
  facet_grid(.~Fraction, scales="free")+
  scale_color_manual(values = COL.type)+
  scale_y_continuous()+
  labs(x="Soil depth (cm)", y= "Aggregate proportion DS (%)", color="")+
  theme_myBW +
  theme(legend.position = "bottom",
        axis.text.x = element_text(angle = 35, hjust = 1))

# average values
df.frac %>%
  group_by(depth, Fraction)%>%
  summarise(DS.mean = mean(DS_pc, na.rm=T),
            DS.se = se(DS_pc),
            DS.min = min(DS_pc, na.rm=T),
            DS.max = max(DS_pc, na.rm=T))


############## evaluate the OC in fraction g per kg ######################
names(df.frac)

# check data distribution
ggplot(df.frac, aes(x=OC_Frac)) +                                # ggplot2 histogram & density
  geom_histogram(aes(y = stat(density)), fill="gray80", color="black") +
  stat_function(fun = dnorm,
                args = list(mean = mean(df.frac$OC_Frac),
                            sd = sd(df.frac$OC_Frac)),
                col = "red")

ggplot(df.frac, aes(x=log10(OC_Frac+1))) +                                # ggplot2 histogram & density
  geom_histogram(aes(y = stat(density)), fill="gray80", color="black") +
  stat_function(fun = dnorm,
                args = list(mean = log10(mean(df.frac$OC_Frac)),
                            sd = log10(sd(df.frac$OC_Frac))),
                col = "red")

# pairwise comparison
pw.OC_Frac <- function(x) {
  t <- pairwiseTest(log10(OC_Frac+1) ~ cc_variant, data = x)
  df <- data.frame(t$byout)$p.value
  names(df) <- row.names(data.frame(t$byout))
  comp <- multcompLetters2(OC_Frac ~ cc_variant, df, data =x, reversed = T)
  data.frame(.group = comp$Letters,
             cc_variant = names(comp$Letters))
}

(df.pw.OC_Frac <- ddply(df.frac, .(depth, Fraction), pw.OC_Frac))

# calculate min values for plotting
df.pw.OC_Frac <- merge(df.pw.OC_Frac, ddply(df.frac, .(Fraction), summarize, Max=max(OC_Frac)), 
                       by=c("Fraction"))


# OC distribution
ggplot(df.frac, aes(x=cc_variant, y=OC_Frac, fill = cc_variant))+
  geom_jitter(shape=21, size=3.5, width = 0.2, alpha=0.3)+
  stat_summary(fun.data = "mean_se", geom = "errorbar",width = 0.1, color="black")+
  stat_summary(fun.data = "mean_se",  geom = "point", size=4, shape=21)+
  geom_text(data = df.pw.OC_Frac, aes(x=cc_variant, y=Max+(8*Max/100), label=.group), size=4)+
  facet_grid(Fraction~depth, scales = "free")+
  scale_fill_manual(values = COL, guide="none")+
  labs(x="Cover crop", y=expression("OC ("*g~kg^-1*")"))+
  theme_myBW+
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

#ggsave("Fig.Sx.png", width=170, height = 150, units = "mm")

ggplot(df.frac, aes(x=as.numeric(Soil_depth), y = OC_Frac, color=cc_type))+
  geom_smooth(method = "auto", se=F, alpha = 0.2)+
  scale_x_reverse(breaks=as.numeric(df.all$depth), labels = df.all$depth)+
  coord_flip() +
  facet_grid(.~Fraction, scales="free")+
  scale_color_manual(values = COL.type)+
  scale_y_continuous()+
  labs(x="Soil depth (cm)", y= expression("OC ("*g~kg^-1*")"), color="")+
  theme_myBW +
  theme(legend.position = "bottom")




############## evaluate the percentage of OC in % soil OC ######################
#
names(df.frac)
hist(df.frac$OC_Frac_pc)
hist(log10(df.frac$OC_Frac_pc))

# pairwise comparison

pw.OC_Frac_pc <- function(x) {
  t <- pairwiseTest(log10(OC_Frac_pc+1) ~ cc_variant, data = x)
  df <- data.frame(t$byout)$p.value
  names(df) <- row.names(data.frame(t$byout))
  comp <- multcompLetters2(OC_Frac_pc ~ cc_variant, df, data =x, reversed = T)
  data.frame(.group = comp$Letters,
             cc_variant = names(comp$Letters))
}

(df.pw.OC_Frac_pc <- ddply(df.frac, .(depth, Fraction), pw.OC_Frac_pc))

# calculate min values for plotting
df.pw.OC_Frac_pc <- merge(df.pw.OC_Frac_pc, ddply(df.frac, .(Fraction), summarize, Max=max(OC_Frac_pc)), 
                          by=c("Fraction"))


# OC distribution
ggplot(df.frac, aes(x=cc_variant, y=OC_Frac_pc, fill = cc_variant))+
  geom_jitter(shape=21, size=3.5, width = 0.2, alpha=0.3)+
  stat_summary(fun.data = "mean_se", geom = "errorbar",width = 0.1, color="black")+
  stat_summary(fun.data = "mean_se",  geom = "point", size=4, shape=21)+
  geom_text(data = df.pw.OC_Frac_pc, aes(x=cc_variant, y=Max+(8*Max/100), label=.group), size=4)+
  facet_grid(Fraction~depth, scales = "free")+
  scale_fill_manual(values = COL, guide="none")+
  labs(x="Cover crop", y="OC (% total)")+
  theme_myBW+
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("Fig.S7.png", width=170, height = 150, units = "mm")


ggplot(df.frac, aes(x=as.numeric(Soil_depth), y = OC_Frac_pc, color=cc_type))+
  geom_smooth(method = "auto", se=F, alpha = 0.2)+
  scale_x_reverse(breaks=as.numeric(df.all$depth), labels = df.all$depth)+
  coord_flip() +
  facet_grid(.~Fraction, scales="free")+
  scale_color_manual(values = COL.type)+
  scale_y_continuous()+
  labs(x="Soil depth (cm)", y= "OC (% total)", color="")+
  theme_myBW +
  theme(legend.position = "bottom")


# average values
df.frac %>%
  group_by(Fraction)%>%
  summarise(OC.mean = mean(OC_Frac_pc, na.rm=T),
            OC.se = se(OC_Frac_pc),
            OC.min = min(OC_Frac_pc, na.rm=T),
            OC.max = max(OC_Frac_pc, na.rm=T))



##################### radar plots on OC distribution ###############################
# function for radar plots 
coord_radar <- function (theta = "x", start = 0, direction = 1, clip = "off") {
  theta <- match.arg(theta, c("x", "y"))
  r <- if (theta == "x") "y" else "x"
  ggproto("CordRadar", CoordPolar, theta = theta, r = r, start = start, 
          direction = sign(direction),clip = clip,
          is_linear = function(coord) TRUE)
}


df.radar <- subset(df.20[,c("cc_variant", "depth", "Fraction","Plot", "OC_Frac", "OC_Frac_pc")], Fraction!="bulk")

# subset of fallow, set fallow as 100%
#OC_Frac in mg/g
df.fallow <- df.radar %>% 
  filter(cc_variant =="Fallow" & OC_Frac > 0)%>%
  group_by(cc_variant, depth, Fraction) %>%
  summarise(OC_Frac = mean(OC_Frac),
            OC_Frac_pc = mean(OC_Frac_pc))


df.radar <- merge(df.radar, df.fallow, by =c( "depth", "Fraction"),suffixes = c("",".fal"))

df.radar$OC_ratio.pc <- (df.radar$OC_Frac/df.radar$OC_Frac.fal*100)
# Fallow as 100 %
df.radar$OC_ratio.fal <-  100+df.radar$OC_Frac_pc-df.radar$OC_Frac_pc.fal


#  summarize CC values per treatment
df.radar.m <- df.radar %>% 
  filter(cc_variant !="Fallow") %>%
  group_by(cc_variant, depth, Fraction)%>%
  summarise(OC_ratio.m = mean(OC_ratio.pc),
            OC_ratio.se = se(OC_ratio.pc),
            OC_Frac_pc = mean(OC_Frac_pc),
            OC_Frac_pc.fal = mean(OC_Frac_pc.fal),
            OC_ratio.fal = mean(OC_ratio.fal))

# df only for fallow as polygon in the plot
df.radar.F <- df.radar %>% 
  filter(cc_variant !="Fallow") %>%
  group_by(cc_variant, depth, Fraction)%>%
  summarise(OC_ratio.m = 100)


# set levels into correct order
df.radar.m$Fraction <- factor(df.radar.m$Fraction, levels=c("<1","2-1","4-2","8-4","16-8"))
levels(df.radar.m$Fraction)

ggplot(df.radar.m, aes(x = Fraction, y = OC_ratio.fal, group = cc_variant, color= cc_variant, fill= cc_variant)) +
  geom_polygon(data = df.radar.F, aes(x = Fraction, y = OC_ratio.m), color="black" , fill = NA, size = 0.8, alpha=0.8) +
  geom_polygon(size = 0.8, alpha= 0.5) +
  coord_radar(clip="off") +
  #scale_y_log10()+
  scale_color_manual(values = COL1)+
  scale_fill_manual(values = COL1)+
  labs(y = "OC (% of Fallow)", color="", fill="")+
  facet_grid(depth~cc_variant)+
  theme_myBW+
  theme(legend.position = "bottom",
        panel.grid.major = element_line(color = "gray", size = 0.5,linetype = 2),
        axis.text.x = element_text(color = "gray12", size = 6),
        axis.title.x = element_blank(),
        axis.text.y = element_text(size = 8),
        panel.border = element_blank()
  )

#ggsave("Fig.1.png", width=160, height = 110,dpi = 500, units = "mm")
#ggsave("Fig.1.pdf", width=160, height = 110, units = "mm")



#------------------------------
# statistic evaluation of Fig.1
hist(df.radar$OC_ratio.fal)
# normal distributed
# pairwise comparison

pw.OC_Frac_fal <- function(x) {
  t <- pairwiseTest(OC_ratio.fal ~ cc_variant, data = x)
  df <- data.frame(t$byout)$p.value
  names(df) <- row.names(data.frame(t$byout))
  comp <- multcompLetters2(OC_ratio.fal ~ cc_variant, df, data =x, reversed = T)
  data.frame(.group = comp$Letters,
             cc_variant = names(comp$Letters))
}

(df.pw.OC_Frac_fal <- ddply(df.radar, .(depth, Fraction), pw.OC_Frac_fal))

# calculate min values for plotting
df.pw.OC_Frac_fal <- merge(df.pw.OC_Frac_fal, ddply(df.radar, .(Fraction), summarize, Max=max(OC_ratio.fal)), 
                          by=c("Fraction"))

ggplot(df.radar, aes(x=cc_variant, y=OC_ratio.fal, fill = cc_variant))+
  geom_jitter(shape=21, size=3.5, width = 0.2, alpha=0.3)+
  stat_summary(fun.data = "mean_se", geom = "errorbar",width = 0.1, color="black")+
  stat_summary(fun.data = "mean_se",  geom = "point", size=4, shape=21)+
  geom_text(data = df.pw.OC_Frac_fal, aes(x=cc_variant, y=Max+(3*Max/100), label=.group), size=4)+
  facet_grid(Fraction~depth, scales = "free")+
  scale_fill_manual(values = COL, guide="none")+
  labs(x="Cover crop", y="OC (% of Fallow)")+
  theme_myBW+
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("Fig.S8.png", width=170, height = 150, units = "mm")

# p values for review
names(df.radar)
pairwiseTest(OC_ratio.fal ~ cc_variant, data = subset(df.radar, depth=="0-10 cm" & Fraction =="<1"))

#########################################################################################
########################### mean weight diameter (MWD) in mm ############################
# The higher the MWD as more large scale aggregates are present after water treatment

#str(df.20)

df.MWD <- subset(df.20, Fraction=="bulk")
#str(df.MWD)
df.MWD$cc_type
levels(df.MWD$cc_type)
levels(df.MWD$cc_variant)


# the data represent approximately normally distribution
ggplot(df.MWD, aes(x=MWD_cor))+
  geom_histogram(aes(y =..density..))+
  geom_density(col=2)


# ordered pairwise comparison of CC_variants
pw.MWD <- function(x) {
  t <- pairwiseTest(MWD_cor ~ cc_variant, data = x)
  df <- data.frame(t$byout)$p.value
  names(df) <- row.names(data.frame(t$byout))
  comp <- multcompLetters2(MWD_cor ~ cc_variant, df, data =x, reversed = T)
  data.frame(.group = comp$Letters,
             cc_variant = names(comp$Letters))
}

(df.pw.MWD <- ddply(df.MWD, .(depth), pw.MWD))


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

# comparison of plot B with a mixed model
lm.mwd <- lmer(MWD_cor ~ cc_type + (1|depth), df.MWD)

df.pw.MWD.tot <- cld(emmeans(lm.mwd, list(pairwise ~ cc_type)), Letters=letters, sort=FALSE)
df.pw.MWD.tot

# plot results
df.MWD$depth2 <- gsub(" cm", "", df.MWD$depth)


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


(p.mwd <- ggarrange(p1,p2, widths = c(2,1.45), labels = c('a)', 'b)'))
)

ggsave("Fig.2.png",plot = p.mwd, width = 160, height = 100, units = "mm")
ggsave("Fig.2.pdf",plot = p.mwd, width = 160, height = 100, units = "mm")

#-------------------------------------
# For review in SOIL ##------ Tue Oct 24 15:18:28 2023 ------##
# alternative approach by ANOVA for reviewer#1
ggplot(subset(df.MWD, Soil_depth=="1"), aes(x=cc_variant, y=MWD_cor, fill=cc_variant))+
  geom_jitter(shape=21, size=3.5, width = 0.2, alpha=0.3)+
  geom_text(data = subset(df.pw.MWD, depth=="0-10 cm"), aes(x=cc_variant, y=2, label=.group), size=4, vjust = 0.4 )+
  stat_summary(fun.data = "mean_se", geom = "errorbar",width = 0.1, color="black")+
  stat_summary(fun.data = "mean_se",  geom = "point", size=4, shape=21)+
  facet_grid (depth~.,scales = "free")+
  scale_fill_manual(values = COL, guide="none")+
  labs(x="", y="MWD (mm)")+
  theme_myBW+
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("Review_1.1.png", width = 120, height = 80, units = "mm")


library(car)
leveneTest(MWD_cor ~ cc_variant, data = subset(df.MWD, Soil_depth=="1"))
# The homogenity of the varice is violated  because Pr(>F) größer 0.05, and F value is below 1

# run ANOVA
an1 <- aov(MWD_cor ~ cc_variant, data = subset(df.MWD, Soil_depth=="1"))
tuc1 <- stats::TukeyHSD(an1)
multcompLetters(tuc1$cc_variant[,4])

multcompLetters2(MWD_cor ~ cc_variant, tuc1$cc_variant[,"p adj"], data = subset(df.MWD, Soil_depth=="1"))

# Welch test
#0-10 cm
pairwiseTest(MWD_cor ~ cc_variant, data = subset(df.MWD, Soil_depth=="1"))
#20-30 cm
pairwiseTest(MWD_cor ~ cc_variant, data = subset(df.MWD, Soil_depth=="2"))
#30-40 cm
pairwiseTest(MWD_cor ~ cc_variant, data = subset(df.MWD, Soil_depth=="3"))

# Estimation plots
library(dabestr)

EstPl <- 
  df.MWD %>%
  filter(Soil_depth =="1") %>%
  dabest(cc_variant, MWD_cor, 
         idx = list(c("Fallow",   "Mustard",  "Clover" ,  "Oat" ,     "Phacelia", "Mix4" ,    "Mix12")),
         paired = F)

meandiff_EstPl <- mean_diff(EstPl)

meandiff_EstPl %>% 
  plot(color.column = cc_variant,
       palette = c("red3" ,"black", "orchid3", "orange4",  "SteelBlue","OliveDrab","Gold"),
       show.legend=F,
       rawplot.type="sinaplot",
       rawplot.markersize = 2.5,
       rawplot.ylabel="MWD")

ggsave("Review_1.2_estim.png", width = 120, height = 120, units = "mm")
#---------------------------------------

# correlation of MWD with soil parameters

#png("CorMatr.png", width = 140, height = 140, units = "mm", res = 500)
chart.Correlation(df.MWD[,c("MWD_cor", "BD", "OC", "CN_ratio", "Clay", "Sand", "Silt")], histogram=TRUE, pch=19)
#dev.off()


# no correlation with OC at different depth increments
ggplot(df.MWD, aes(x=MWD_cor, y =OC, color=depth))+
  geom_point(size = 3)+
  geom_smooth(method = "lm", se=T)+
  stat_cor(aes(label =  paste(..rr.label.., ..p.label.., sep = "~`,`~")))

# no correlation with BD at different depth increments 
ggplot(df.MWD, aes(x=MWD_cor, y =BD, color=depth))+
  geom_point(size = 3)+
  geom_smooth(method = "lm", se=T)+
  stat_cor(aes(label =  paste(..rr.label.., ..p.label.., sep = "~`,`~")))

# no correlation with Texture (Clay, Silt, Sand) at different depth increments 
ggplot(df.MWD, aes(x=MWD_cor, y =Clay, color=depth))+
  geom_point(size = 3)+
  geom_smooth(method = "lm", se=T)+
  stat_cor(aes(label =  paste(..rr.label.., ..p.label.., sep = "~`,`~")))


# correlation with CC variant order according to the mean C:N ratios of root+shoot litter
# published in Gentsch et al. (2022): DOI 10.1007/s00374-020-01475-8 
levels(df.MWD$cc_variant)
#str(df.MWD)

(df.CN.CC <- data.frame(cc_variant = levels(df.MWD$cc_variant)[2:7],
  C_N_ratio = c(23.57, 18.93, 25.09,22.80, 24.72 ,21.10))
)
# merge data frames
df.MWD.cor <- merge(df.MWD, df.CN.CC, by = "cc_variant")

# plot correlation with depth
ggplot(df.MWD.cor, aes(x=C_N_ratio, y =MWD_cor))+
  geom_point(size = 3, aes(fill=cc_variant), shape=21)+
  facet_wrap(.~depth)+
  geom_smooth(method = "lm", se=T)+
  stat_cor(aes(label =  paste(..rr.label.., ..p.label.., sep = "~`,`~")))+
  scale_fill_manual(values = COL)+
  labs(x="C:N ratio", y= expression("MWD (mm)"), fill="")+
  theme_myBW
  
ggsave("Fig.S9.png",width = 160, height = 100, units = "mm")

# correlation of MWD with OC in aggregate fractions
# add OC distribution in fraction
df.MWD.cor <- merge(df.MWD.cor, spread(df.frac[, c("Plot","cc_variant","cc_type", "depth","Fraction", "OC_Frac_pc")], Fraction , OC_Frac_pc), 
by=c("Plot","cc_variant","cc_type", "depth"))

# correlation matrix with Pearsons's R
#str(df.MWD.cor)
#png("Fig.S10.png", width = 140, height = 140, units = "mm", res = 500)
chart.Correlation(df.MWD.cor[,c("MWD_cor", "<1", "2-1", "4-2", "8-4", "16-8")], histogram=TRUE, pch=19)
#dev.off()

# strong positive correlation with 8-4
ggplot(df.MWD.cor, aes(y=MWD_cor, x =df.MWD.cor[,44]))+
  geom_point(size = 3)+
  geom_smooth(method = "lm", se=T)+
  stat_cor(aes(label =  paste(..rr.label.., ..p.label.., sep = "~`,`~")))+
  labs(x = "OC in 4-8 mm fraction (% total)", y="MWD (mm)")

# negative correlation with <1
ggplot(df.MWD.cor, aes(y=MWD_cor, x =df.MWD.cor[,41]))+
  geom_point(size = 3)+
  geom_smooth(method = "lm", se=T)+
  stat_cor(aes(label =  paste(..rr.label.., ..p.label.., sep = "~`,`~")))+
  labs(x = "OC in < 1 mm fraction (% total)", y="MWD (mm)")

# very wheek positive correlation with 8-16mm
ggplot(df.MWD.cor, aes(y=MWD_cor, x =df.MWD.cor[,45]))+
  geom_point(size = 3, aes(color=depth))+
  geom_smooth(method = "lm", se=T)+
  stat_cor(aes(label =  paste(..rr.label.., ..p.label.., sep = "~`,`~")))+
  labs(x = "OC in 8-16 mm fraction (% total)", y="MWD (mm)")



# impact of CC on MWD
# Fallow is the refferece group
lm.mwd.1 <- lmer(MWD_cor ~ cc_variant + (1|depth), data = df.MWD)
summary(lm.mwd.1)
# mean fallow is the reverence intercept 
mean(subset(df.MWD, cc_variant =="Fallow")[,31 ])
# write coefficients to data frame and excel file
#write.xlsx(data.frame(summary(lm.mwd.1)$coefficients), "Lmer_output_MRT.xlsx", sheetName="CC_variant",
#           append = T, row.names =T)


lm.mwd.2 <- lmer(MWD_cor ~ cc_type + (1|depth), data = df.MWD)
summary(lm.mwd.2)
# write coefficients to data frame
#write.xlsx(data.frame(summary(lm.mwd.2)$coefficients), "Lmer_output_MRT.xlsx", sheetName="CC_type",
#           append = T, row.names =T)

########################### mean weight diameter (GMD) in mm ############################
# is an estimate of the size of the most frequent aggregate size classes
# as higher as larger the mean aggregate size 

# the data represent approximately normally distribution
ggplot(df.MWD, aes(x=GMD_cor))+
  geom_histogram(aes(y =..density..))+
  geom_density(col=2)


# ordered pairwise comparison of CC_variants
pw.GMD <- function(x) {
  t <- pairwiseTest(GMD_cor ~ cc_variant, data = x)
  df <- data.frame(t$byout)$p.value
  names(df) <- row.names(data.frame(t$byout))
  comp <- multcompLetters2(GMD_cor ~ cc_variant, df, data =x, reversed = T)
  data.frame(.group = comp$Letters,
             cc_variant = names(comp$Letters))
}

(df.pw.GMD <- ddply(df.MWD, .(depth), pw.GMD))


# comparison of plot B with a mixed model
lm.GMD <- lmer(GMD_cor ~ cc_type + (1|depth), df.MWD)

df.pw.GMD.tot <- cld(emmeans(lm.GMD, list(pairwise ~ cc_type)), Letters=letters, sort=FALSE)
df.pw.GMD.tot




(p3 <- ggplot(df.MWD, aes(x=cc_variant, y=GMD_cor, fill=cc_variant))+
    geom_jitter(shape=21, size=3.5, width = 0.2, alpha=0.3)+
    geom_text(data = df.pw.GMD, aes(x=cc_variant, y=1, label=.group), vjust = 0.1)+
    stat_summary(fun.data = "mean_se", geom = "errorbar",width = 0.1, color="black")+
    stat_summary(fun.data = "mean_se",  geom = "point", size=4, shape=21)+
    facet_grid (depth~.,scales = "free")+
    scale_fill_manual(values = COL, guide="none")+
    labs(x="", y="GMD (mm)")+
    theme_myBW+
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
)



(p4 <- ggplot(df.MWD, aes(x=as.numeric(Soil_depth), y = GMD_cor, color=cc_type))+
    geom_smooth(method = "auto", se=T, alpha = 0.2)+
    scale_x_reverse(breaks=as.numeric(df.MWD$Soil_depth), labels = df.MWD$depth2)+
    geom_text(data = df.pw.GMD.tot, aes(y=c(1.5,1.75,1.95), x=3, label=.group), size=4, color="black", nudge_x = -0.05)+
    coord_flip() +
    scale_color_manual(values = COL.type)+
    labs(x="Soil depth (cm)", y= expression("GMD (mm)"), color="")+
    theme_myBW +
    theme(legend.position = "bottom")
)

(p.GMD <- ggarrange(p3,p4, widths = c(2,1.45), labels = c('a)', 'b)'))
)

ggsave("Fig.S11.png",plot = p.GMD, width = 160, height = 100, units = "mm")



ggplot(df.MWD.cor, aes(x=C_N_ratio, y =GMD_cor))+
  geom_point(size = 3, aes(fill=cc_variant), shape=21)+
  facet_wrap(.~depth)+
  geom_smooth(method = "lm", se=T)+
  stat_cor(aes(label =  paste(..rr.label.., ..p.label.., sep = "~`,`~")))+
  scale_fill_manual(values = COL)+
  labs(x="C:N ratio", y= expression("GMD (mm)"), fill="")+
  theme_myBW


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
df.sem <- df.MWD.cor
names(df.sem)

# rename special characters in names
df.sem <- rename(df.sem, c("OC1"="<1", "OC2_1" ="2-1", "OC4_2"="4-2", "OC8_4"="8-4","OC16_8"="16-8"))

# categorical variables need to be coded as numeric values 0,1,2,...
# transform CC-variant to numeric values 
levels(df.sem$cc_variant)
df.sem$cc_variant.n <- as.numeric(df.sem$cc_variant)

levels(df.sem$cc_type)
df.sem$cc_type.n <- as.numeric(df.sem$cc_type)

# throw out outliers for Clay
ggplot(df.sem, aes(x=cc_type.n, y= Clay))+
  geom_boxplot()

df.sem <- subset(df.sem, Clay<10)

# throw out outliers for OC4_2
ggplot(df.sem, aes(x=cc_type.n, y= OC4_2))+
  geom_boxplot()

df.sem <- subset(df.sem, OC4_2<15)

# check correlation between parameters for SEM construction
chart.Correlation(df.sem[,c("BD","Clay","MWD_cor","OC", "OC1", "OC2_1", "OC4_2", "OC8_4", "OC16_8")], histogram=TRUE, pch=19)

# check PCA to create latent variables from contrasting measures
#str(df.sem)
pred <- c("BD","Clay","OC", "MWD_cor", "OC1", "OC2_1", "OC4_2", "OC8_4", "OC16_8")
pca.all <- princomp(df.sem[,pred],cor=TRUE)
# Eigenvalues
pca.all$sd^2
# print factor loadings on eigenvectors
tabloadvar.princomp(pca.all)
# write table to file with Eigenvalues >0.9
# write.xlsx(round(tabloadvar.princomp(pca.all)[,c(1,2,3)], digits=2), file="PCA_predictors.xlsx")

# plot with ggplot
ggbiplot(pca.all, choices = 1:2, scale = 0.2, ellipse = T, circle = F)+
  theme_myBW

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
#            * P-value of the Chi-square test is =0.1   (should be not significant > 0.05)
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
OC8_4~~OC4_2
"

# fit the optimized  model
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

graph_sem(model=sem.opt, layout = leyout.sem)


p <- prepare_graph(model=sem.opt, layout = leyout.sem)
p
#p$edges
#str(p$nodes)
# changing nod names for plotting
p$nodes$name <- dplyr::recode(p$nodes$name, Distribution ="Aggreg. \n distrib.", 
                    Soil_prop = "Soil\n propert.", 
                    MWD_cor="MWD", 
                    cc_type ="Cover crop\n type", 
                    OC1="< 1 mm", 
                    OC8_4="8-4 mm", 
                    OC4_2 = "4-2 mm",
                    OC16_8 = "16-8 mm")

p$nodes$name

# Plot SEM and produce Fig.3 
# edges = arrows 
# nodes = boxes/elipses
#png("Fig.3.png", width = 140, height = 140, units = "mm", res = 500)
#pdf("Fig.3.pdf")

prepare_graph(sem.opt, layout = leyout.sem) %>%
  edit_graph({ label = paste(est_sig_std) }, element = "edges") %>%
  edit_graph({ label = paste(p$nodes$name) }, element = "nodes") %>%
  label_color_latent("blue") %>%
  label_size_load(label_size = 3)%>%
  color_load(color = "gray60") %>%
  label_size_obs(label_size = 3)%>% # names
  label_size_latent(label_size = 3)%>%
  label_size_cov(label_size = 3)%>%
  label_size_reg(label_size = 3)%>%
  label_alpha_obs(label_alpha = 0 )%>%
  label_alpha_latent(label_alpha = 0)%>%
  label_alpha_load(label_alpha = 0.3)%>%
  hide_var()%>% # hide variances of factors
  plot()

#dev.off()


# here I check the factor order of my CC levels how they interact with Aggregate distribution
# plot some interactions with predicted values for interpretation
df.sem.pred <- cbind(df.sem, data.frame(lavPredict(sem.opt)))

# plot impact of OC on distribution
ggplot(df.sem.pred, aes(x= OC, y=Distribution))+
  geom_point()+
  geom_smooth(method = "lm")+
  stat_cor(aes(label =  paste(..rr.label.., ..p.label.., sep = "~`,`~")))

ggplot(df.sem.pred, aes(x= OC1, y=Distribution))+
  geom_point()+
  geom_smooth(method = "lm")+
  stat_cor(aes(label =  paste(..rr.label.., ..p.label.., sep = "~`,`~")))

# mixed effects model on CC type
# order factor levels  by mean value of distribution
df.sem.pred$cc_type.ord <- as.factor(reorder(df.sem.pred$cc_type, df.sem.pred$Distribution, FUN = mean))

lmer.sem <- lmer(Distribution ~ cc_type.ord + (1|depth), data = df.sem.pred)
summary(lmer.sem)
anova(lmer.sem)

#plot the model for interpretation
ggplot(df.sem.pred, aes(x= as.numeric(cc_type.ord), y=Distribution, color=depth))+
  geom_point()+
  geom_smooth(method = "lm")+
  stat_cor(aes(label =  paste(..rr.label.., ..p.label.., sep = "~`,`~")))+
  scale_x_continuous(breaks=c(1,2, 3), labels=c("Mix", "Fallow", "Single"))


##################### end script #########################################
