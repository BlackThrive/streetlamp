# Generate shareable research figures after scripts 05, 05b and 06 finish.
# Rscript inst/scripts/07-research-figures.R
suppressMessages(library(ggplot2))
dir <- file.path("inst", "validation", "research-upgrade")
sim <- utils::read.csv(file.path(dir, "simulation-summary.csv"))
original <- utils::read.csv(file.path(dir, "elasticity-original-design-summary.csv"))
original$scenario <- ifelse(original$missing == 0, "Original design: complete", "Original design: missing 10%")
original$estimator <- ifelse(grepl("^PPML", original$estimator), "Count mean (PPML)", "Legacy target mismatch")
count <- sim[grepl("^PPML", sim$estimator), ]
count$estimator <- "Count mean (PPML)"
count$scenario <- c(count_mean="Count mean", sparse_counts="Sparse counts",
                    overdispersed="Overdispersion", selective_missing="Selective missingness")[count$scenario]
columns <- c("scenario", "estimator", "coverage", "coverage_mc_low", "coverage_mc_high")
d <- rbind(original[, columns], count[, columns])
set <- c("Original design: complete", "Original design: missing 10%", "Count mean", "Sparse counts", "Overdispersion", "Selective missingness")
d$scenario <- factor(d$scenario, levels=rev(set))
p <- ggplot(d, aes(x=coverage, y=scenario, colour=estimator)) +
  geom_vline(xintercept=0.95, linetype=2, colour="#52514E") +
  geom_errorbar(aes(xmin=coverage_mc_low, xmax=coverage_mc_high), orientation="y", width=0.15,
                position=position_dodge(width=0.35)) +
  geom_point(position=position_dodge(width=0.35), size=2.8) +
  scale_colour_manual(values=c("Count mean (PPML)"="#2A78D6", "Legacy target mismatch"="#D03B3B")) +
  scale_x_continuous(limits=c(0.45,1), breaks=seq(0.5,1,0.1), labels=function(x) paste0(100*x,"%")) +
  labs(x="Interval coverage", y=NULL, colour=NULL, title="Elasticity validation against an explicit target",
       subtitle="200 replications per scenario; whiskers show Wilson Monte Carlo intervals",
       caption="Nominal coverage: 95%. Original design: 400 areas x 60 months; other count scenarios: 100 x 36.\nOLS log-one-plus outcomes and a log-mean target are different estimands.") +
  theme_minimal(base_size=11) + theme(legend.position="bottom", panel.grid.minor=element_blank())
ggsave(file.path(dir,"elasticity-coverage.png"),p,width=9,height=5.5,dpi=180)
ggsave(file.path(dir,"elasticity-coverage.pdf"),p,width=9,height=5.5)
h <- sim[sim$scenario %in% c("homogeneous_additive","heterogeneous_cohorts","dynamic_cohorts","violated_parallel_trends"),]
h$scenario <- c(homogeneous_additive="Homogeneous effects",heterogeneous_cohorts="Different cohort effects",
                 dynamic_cohorts="Dynamic cohort effects",violated_parallel_trends="Violated parallel trends")[h$scenario]
h$scenario <- factor(h$scenario,levels=c("Homogeneous effects","Different cohort effects","Dynamic cohort effects","Violated parallel trends"))
h$estimator <- c(callaway_santanna="Callaway-Sant'Anna",sun_abraham="Sun-Abraham",
                 "linear TWFE comparator"="Linear TWFE")[h$estimator]
q <- ggplot(h,aes(x=estimator,y=coverage,colour=estimator)) +
  geom_hline(yintercept=0.95,linetype=2,colour="#52514E") +
  geom_errorbar(aes(ymin=coverage_mc_low,ymax=coverage_mc_high),width=0.15) + geom_point(size=2.8) +
  facet_wrap(~scenario,ncol=2) + scale_y_continuous(limits=c(0,1),labels=function(x)paste0(100*x,"%")) +
  scale_colour_manual(values=c("Callaway-Sant'Anna"="#2A78D6","Sun-Abraham"="#EB6834","Linear TWFE"="#D03B3B")) +
  labs(x=NULL,y="Interval coverage",title="Staggered-design validation with count-level parallel trends",
       subtitle="96 areas x 24 months; 200 replications; Wilson Monte Carlo intervals",
       caption="The final scenario deliberately violates identification. No estimator should be read as causal there.") +
  theme_minimal(base_size=11) + theme(legend.position="none",panel.grid.minor=element_blank(),
                                     axis.text.x=element_text(angle=12,hjust=1))
ggsave(file.path(dir,"heterogeneity-coverage.png"),q,width=9,height=6.5,dpi=180)
ggsave(file.path(dir,"heterogeneity-coverage.pdf"),q,width=9,height=6.5)
