# /// script
# requires-r = "==4.5.1"
# dependencies = [
#   "tidyverse==2.0.0"
# ]
# ///
library(tidyverse)

COL1 <- c("Fallow" = "black", "Mustard" = "red3", "Clover" = "OliveDrab", "Oat" = "Gold", 
          "Phacelia" = "SteelBlue", "Mix4" = "orchid3", "Mix12" = "orange4")
theme_myBW <- theme(axis.title.x = element_text(size = 10, color = "black"), 
                    axis.title.y = element_text(angle = 90, vjust = 1.5, size = 10, color = "black"),
                    axis.text.x = element_text(size = 10, color = "black"), 
                    axis.text.y = element_text(size = 10, color = "black"), 
                    axis.ticks = element_line(colour = "black"),
                    strip.text.x = element_text(size = 10, color = "black"),
                    strip.background = element_blank(),
                    panel.border = element_rect(colour = "black", fill = NA), 
                    panel.grid.major = element_blank(),
                    panel.grid.minor = element_blank(),
                    plot.title = element_text(size = 12, hjust = 0.5),
                    legend.text = element_text(size = 10),
                    legend.text.align = 0,
                    legend.title = element_text(size = 10), 
                    legend.key = element_rect(colour = "white", fill = "white"),
                    legend.key.size = unit(5, "mm"),
                    legend.background = element_blank(),
                    legend.position = "bottom")
se <- function(x) sqrt(var(x, na.rm = TRUE) / length(na.omit(x)))
coord_radar <- function (theta = "x", start = 0, direction = 1, clip = "off") {
  theta <- match.arg(theta, c("x", "y"))
  r <- if (theta == "x") "y" else "x"
  ggproto("CordRadar", CoordPolar, theta = theta, r = r, start = start, 
          direction = sign(direction), clip = clip,
          is_linear = function(coord) TRUE)
}
df.radar <- read.csv("https://service.tib.eu/ldmservice/dataset/60540bb4-11f2-4dc9-893f-cc2523b9c4f9/resource/0c44d6eb-bdcc-4791-8235-3f45bd818f2f/download/1nuwo314.csv")
df.radar$Fraction <- factor(df.radar$Fraction, levels = c("<1", "2-1", "4-2", "8-4", "16-8", "bulk"))
df.radar.m <- df.radar %>% 
  filter(cc_variant != "Fallow") %>%
  group_by(cc_variant, depth, Fraction) %>%
  summarise(OC_ratio.m = mean(OC_ratio.pc),
            OC_ratio.se = se(OC_ratio.pc),
            OC_Frac_pc = mean(OC_Frac_pc),
            OC_Frac_pc.fal = mean(OC_Frac_pc.fal),
            OC_ratio.fal = mean(OC_ratio.fal))
df.radar.F <- df.radar %>% 
  filter(cc_variant != "Fallow") %>%
  group_by(cc_variant, depth, Fraction) %>%
  summarise(OC_ratio.m = 100)
ggplot(df.radar.m, aes(x = Fraction, y = OC_ratio.fal, group = cc_variant, color = cc_variant, fill = cc_variant)) +
  geom_polygon(data = df.radar.F, aes(x = Fraction, y = OC_ratio.m), color="black", fill = NA, size = 0.8, alpha = 0.8) +
  geom_polygon(size = 0.8, alpha= 0.5) +
  coord_radar(clip = "off") +
  scale_color_manual(values = COL1) +
  scale_fill_manual(values = COL1) +
  labs(y = "OC (% of Fallow)", color="", fill="") +
  facet_grid(depth~cc_variant) +
  theme_myBW +
  theme(legend.position = "bottom",
        panel.grid.major = element_line(color = "gray", size = 0.5, linetype = 2),
        axis.text.x = element_text(color = "gray12", size = 6),
        axis.title.x = element_blank(),
        axis.text.y = element_text(size = 8),
        panel.border = element_blank())