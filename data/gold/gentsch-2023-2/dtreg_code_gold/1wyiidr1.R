# written with R version 4.1.3 (2022-03-10) -- "One Push-Up"
# by Norman Gentsch - gentsch@ifbk.uni-hannover.de
# Institute of Soil Science
# Leibniz University Hannover

library(dplyr)
library(lme4)
library(lmerTest) # p values from t statistic

df.20 <- read.csv("CATCHY_aggregate_stability_2020_block2.csv", check.names=FALSE)

for(i in c(3:9, 11:18)) {
  df.20[,i] <- as.factor(df.20[,i])
}

df.20$cc_variant <- recode(df.20$cc_variant, "1" ="Fallow", "2"="Mustard", "3"="Clover", 
                             "4" = "Oat", "5" = "Phacelia","6" ="Mix4", "7"="Mix12")

df.20$cc_type <- ifelse(df.20$cc_variant %in% c("Mix4", "Mix12"), "Mix", "Single")
df.20$cc_type <- as.factor(ifelse(df.20$cc_variant == "Fallow", "Fallow", df.20$cc_type))

# Input data
df.MWD <- subset(df.20, Fraction=="bulk")
write.csv(df.MWD, "df-MWD.csv")

# Two Linear Mixed Model (LMM) computations
lm.mwd.1 <- lmer(MWD_cor ~ cc_variant + (1|depth), data = df.MWD)
lm.mwd.2 <- lmer(MWD_cor ~ cc_type + (1|depth), data = df.MWD)

# Output data for the two LMM
df1 <- data.frame(summary(lm.mwd.1)$coefficients, check.names=FALSE)
df2 <- data.frame(summary(lm.mwd.2)$coefficients, check.names=FALSE)

library(dtreg)
source("utils/functions.r")

dt1 <- dtreg::load_datatype("https://doi.org/21.T11969/feeb33ad3e4440682a4d") # Data analysis
dt2 <- dtreg::load_datatype("https://doi.org/21.T11969/c6b413ba96ba477b5dca") # Multilevel analysis

#check_name_mapping("table-2-snippet-1.R", file_type="R")

instance <- dt1$data_analysis(
  is_implemented_by=get_resource_url("table-1-snippet-1.R"),
  has_part=dt2$multilevel_analysis(
    label="Linear mixed model (LMM) fitting with mean weight diameter (MWD) as response, cover crop (CC) variant as predictor variable, and soil depth as random variable.",
    executes=dt2$software_method(
      label="lmer",
      has_support_url="https://search.r-project.org/CRAN/refmans/lmerTest/html/lmer.html",
      is_implemented_by="lmer(MWD_cor ~ cc_variant + (1|depth), data = df.MWD)",
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
      label="Soil data (OC, TN, bulk density, texture) as well as data from soil aggregate fractionation and evaluation of their aggregate stability.",
      source_url=get_resource_url("df-mwd.csv"),
      has_characteristic=dt2$matrix_size(
        number_of_rows=nrow(df.MWD),
        number_of_columns=ncol(df.MWD)
      )
    ),
    has_output=dt2$data_item(
      source_table=df1,
      has_part=c(
        dt2$component(label="Estimate"),
        dt2$component(label="Std. Error"),
        dt2$component(label="df"),
        dt2$component(label="t value"),
        dt2$component(label="Pr(>|t|)")
      ),
      has_characteristic=dt2$matrix_size(
        number_of_rows=nrow(df1),
        number_of_columns=ncol(df1)
      )
    )
  )
)

json <- dtreg::to_jsonld(instance)
write(json, get_mapped_name("table-1.json"))

instance <- dt1$data_analysis(
  is_implemented_by=get_resource_url("table-2-snippet-1.R"),
  has_part=dt2$multilevel_analysis(
    label="Linear mixed model (LMM) fitting with mean weight diameter (MWD) as response, cover crop (CC) type as predictor variable, and soil depth as random variable.",
    executes=dt2$software_method(
      label="lmer",
      has_support_url="https://search.r-project.org/CRAN/refmans/lmerTest/html/lmer.html",
      is_implemented_by="lmer(MWD_cor ~ cc_type + (1|depth), data = df.MWD)",
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
      label="Soil data (OC, TN, bulk density, texture) as well as data from soil aggregate fractionation and evaluation of their aggregate stability.",
      source_url=get_resource_url("df-mwd.csv"),
      has_characteristic=dt2$matrix_size(
        number_of_rows=nrow(df.MWD),
        number_of_columns=ncol(df.MWD)
      )
    ),
    has_output=dt2$data_item(
      source_table=df2,
      has_part=c(
        dt2$component(label="Estimate"),
        dt2$component(label="Std. Error"),
        dt2$component(label="df"),
        dt2$component(label="t value"),
        dt2$component(label="Pr(>|t|)")
      ),
      has_characteristic=dt2$matrix_size(
        number_of_rows=nrow(df2),
        number_of_columns=ncol(df2)
      )
    )
  )
)

json <- dtreg::to_jsonld(instance)
write(json, get_mapped_name("table-2.json"))