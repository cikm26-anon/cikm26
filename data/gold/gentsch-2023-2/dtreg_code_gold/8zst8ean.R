# written with R version 4.1.3 (2022-03-10) -- "One Push-Up"
# by Norman Gentsch - gentsch@ifbk.uni-hannover.de
# Institute of Soil Science
# Leibniz University Hannover

library(tidyverse)

se <- function(x) sqrt(var(x,na.rm=TRUE)/length(na.omit(x)))

COL1 <- c("Fallow" = "black", "Mustard" = "red3" , "Clover" = "OliveDrab", "Oat" = "Gold", 
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

df.20 <- read.csv("CATCHY_aggregate_stability_2020_block2.csv")

for(i in c(3:9, 11:18)) {
  df.20[,i] <- as.factor(df.20[,i])
}

df.20$cc_variant <- dplyr::recode(df.20$cc_variant, "1" ="Fallow", "2"="Mustard", "3"="Clover", 
                             "4" = "Oat", "5" = "Phacelia","6" ="Mix4", "7"="Mix12")
df.20$depth <- dplyr::recode(df.20$depth, "0-10" = "0-10 cm", "20-30"="20-30 cm", "30-40"="30-40 cm")
df.20$cc_type <- ifelse(df.20$cc_variant %in% c("Mix4", "Mix12"), "Mix", "Single")
df.20$cc_type <- as.factor(ifelse(df.20$cc_variant == "Fallow", "Fallow", df.20$cc_type))
df.20$Fraction <- factor(df.20$Fraction, levels=c("<1","2-1","4-2","8-4","16-8", "bulk"))
          
coord_radar <- function (theta = "x", start = 0, direction = 1, clip = "off") {
  theta <- match.arg(theta, c("x", "y"))
  r <- if (theta == "x") "y" else "x"
  ggproto("CordRadar", CoordPolar, theta = theta, r = r, start = start, 
          direction = sign(direction),clip = clip,
          is_linear = function(coord) TRUE)
}

df.radar <- subset(df.20[,c("cc_variant", "depth", "Fraction","Plot", "OC_Frac", "OC_Frac_pc")], Fraction!="bulk")
          
df.fallow <- df.radar %>% 
  filter(cc_variant =="Fallow" & OC_Frac > 0)%>%
  group_by(cc_variant, depth, Fraction) %>%
  summarise(OC_Frac = mean(OC_Frac),
            OC_Frac_pc = mean(OC_Frac_pc))
          
df.radar <- merge(df.radar, df.fallow, by =c( "depth", "Fraction"),suffixes = c("",".fal"))

df.radar$OC_ratio.pc <- (df.radar$OC_Frac/df.radar$OC_Frac.fal*100)
df.radar$OC_ratio.fal <-  100+df.radar$OC_Frac_pc-df.radar$OC_Frac_pc.fal
          
df.radar.m <- df.radar %>% 
  filter(cc_variant !="Fallow") %>%
  group_by(cc_variant, depth, Fraction)%>%
  summarise(OC_ratio.m = mean(OC_ratio.pc),
            OC_ratio.se = se(OC_ratio.pc),
            OC_Frac_pc = mean(OC_Frac_pc),
            OC_Frac_pc.fal = mean(OC_Frac_pc.fal),
            OC_ratio.fal = mean(OC_ratio.fal))
          
df.radar.F <- df.radar %>% 
  filter(cc_variant !="Fallow") %>%
  group_by(cc_variant, depth, Fraction)%>%
  summarise(OC_ratio.m = 100)

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

#ggsave("figure-1.png", width=160, height = 110,dpi = 500, units = "mm")
#write.csv(df.radar, "df-radar.csv", row.names=FALSE)

library(dtreg)
source("utils/functions.r")

dt1 <- dtreg::load_datatype("https://doi.org/21.T11969/feeb33ad3e4440682a4d") # Data analysis
dt2 <- dtreg::load_datatype("https://doi.org/21.T11969/5b66cb584b974b186f37") # Descriptive statistics

#names()
#dtreg::show_fields()
#check_name_mapping("figure-1.png", file_type="png")

instance <- dt1$data_analysis(
  is_implemented_by=get_resource_url("figure-1-snippet.r"),
  has_part=dt2$descriptive_statistics(
    label="Descriptive statistics for relative proportion of organic carbon in different soil fractions in percentage of fallow level.",
    has_input=dt2$data_item(
      source_url=get_resource_url("df-radar.csv"),
      has_part=c(
        dt2$component(label="depth"),
        dt2$component(label="Fraction"),
        dt2$component(label="cc_variant"),
        dt2$component(label="Plot"),
        dt2$component(label="OC_Frac"),
        dt2$component(label="OC_Frac_pc"),
        dt2$component(label="cc_variant.fal"),
        dt2$component(label="OC_Frac.fal"),
        dt2$component(label="OC_Frac_pc.fal"),
        dt2$component(label="OC_ratio.pc"),
        dt2$component(label="OC_ratio.fal")
      ),
      has_characteristic=dt2$matrix_size(
        number_of_rows=nrow(df.radar),
        number_of_columns=ncol(df.radar)
      )
    ),
    has_output=dt2$data_item(
      label="Relative proportion of organic carbon in different soil fractions in percentage of fallow level.",
      source_table=df.radar.m,
      has_part=c(
        dt2$component(label="cc_variant"),
        dt2$component(label="depth"),
        dt2$component(label="Fraction"),
        dt2$component(label="OC_ratio.m"),
        dt2$component(label="OC_ratio.se"),
        dt2$component(label="OC_Frac_pc"),
        dt2$component(label="OC_Frac_pc.fal"),
        dt2$component(label="OC_ratio.fal")
      ),
      has_characteristic=dt2$matrix_size(
        number_of_rows=nrow(df.radar.m),
        number_of_columns=ncol(df.radar.m)
      ),
      has_expression=dt2$figure(
        source_url=get_resource_url("figure-1.png")
      )
    ),
    executes=dt2$software_method(
      label="summarise",
      is_implemented_by="summarise(OC_ratio.m = mean(OC_ratio.pc), 
  OC_ratio.se = se(OC_ratio.pc), 
  OC_Frac_pc = mean(OC_Frac_pc), 
  OC_Frac_pc.fal = mean(OC_Frac_pc.fal), 
  OC_ratio.fal = mean(OC_ratio.fal))",
      has_support_url="https://search.r-project.org/CRAN/refmans/dplyr/html/summarise.html",
      part_of=dt2$software_library(
        label="dplyr",
        version_info="1.1.4",
        has_support_url="https://doi.org/10.32614/CRAN.package.dplyr",
        part_of=dt2$software(
          label="R",
          version_info="4.3.2",
          has_support_url="https://www.r-project.org"
        )
      )
    )
  )
)

json <- dtreg::to_jsonld(instance)
write(json, get_mapped_name("figure-1.json"))