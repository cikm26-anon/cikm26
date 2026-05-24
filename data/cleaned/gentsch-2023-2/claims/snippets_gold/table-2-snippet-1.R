# /// script
# requires-r = "==4.5.1"
# dependencies = [
#   "lme4==1.1.35.1",
#   "lmerTest==3.1.3"
# ]
# ///
library(lme4)
library(lmerTest)

df.MWD  <- read.csv("https://service.tib.eu/ldmservice/dataset/60540bb4-11f2-4dc9-893f-cc2523b9c4f9/resource/8d0309d9-baee-4f24-8937-4811aa9d6a92/download/n23taj4i.csv")
lm.mwd <- lmer(MWD_cor ~ cc_type + (1|depth), data = df.MWD)
df <- data.frame(summary(lm.mwd)$coefficients, check.names=FALSE)
df