# Independent analytic/Monte Carlo audit for the balanced additive designs.
# It retains the 200-replication backend results and investigates their bias.
# Rscript inst/scripts/08-staggered-bias-audit.R
suppressMessages(devtools::load_all(quiet=TRUE))
dir <- file.path("inst","validation","research-upgrade")
backend <- utils::read.csv(file.path(dir,"simulation-replications.csv"))
n_a <- 96L
n_t <- 24L
g <- rep(c(8,12,16,NA_integer_),length.out=n_a)
cohort_effect <- c("8"=-10,"12"=-4,"16"=5)
treated <- outer(g,seq_len(n_t),function(a,t) !is.na(a) & t>=a)
M <- sum(treated)
control <- which(is.na(g))
w <- matrix(0,n_a,n_t)
for (cohort in c(8,12,16)) {
  group <- which(g==cohort)
  post <- cohort:n_t
  w[group,post] <- w[group,post] + 1/M
  w[group,cohort-1L] <- w[group,cohort-1L] - length(post)/M
  w[control,post] <- w[control,post] - length(group)/(M*length(control))
  w[control,cohort-1L] <- w[control,cohort-1L] + length(group)*length(post)/(M*length(control))
}
stopifnot(abs(sum(w))<1e-12)
paths <- list(heterogeneous_cohorts=rep(1,n_t),dynamic_cohorts=c(0,0.5,rep(1,n_t-2)))
rows <- list()
for (scenario in names(paths)) {
  effect <- matrix(0,n_a,n_t)
  for (cohort in c(8,12,16)) {
    group <- which(g==cohort)
    post <- cohort:n_t
    effect[group,post] <- matrix(rep(cohort_effect[as.character(cohort)]*paths[[scenario]][seq_along(post)],
                                     each=length(group)),nrow=length(group))
  }
  target <- mean(effect[treated])
  # Check the contrast against actual backend records before using the
  # faster equivalent Poisson-sum generator below.
  for (rep in seq_len(10)) {
    sim <- lamp_simulate(n_areas=n_a,n_months=n_t,design="staggered",adoption=c(8,12,16),
      effect=-6,cohort_effects=cohort_effect,
      dynamic_effect=if(scenario=="dynamic_cohorts")c(0,0.5,1)else NULL,
      base_rate=100,effect_scale="additive",seed=20261006L+rep)
    observed <- matrix(sim$affected_crime,n_a,n_t,byrow=TRUE)
    recorded <- backend$estimate[backend$scenario==scenario & backend$rep==rep &
                                   backend$estimator=="callaway_santanna"]
    stopifnot(length(recorded)==1L,abs(sum(w*observed)-recorded)<1e-8)
  }
  # Independent seed family; sum of independent Poisson type counts is
  # Poisson with their summed mean. No backend or estimated response enters
  # the oracle mean or variance calculation.
  for (rep in seq_len(10000)) {
    set.seed(40400000L+rep)
    alpha <- stats::rnorm(n_a,0,0.35)
    gamma <- 0.004*seq_len(n_t)+0.12*sin(2*pi*seq_len(n_t)/12)
    mu0 <- (12/13)*outer(100*exp(alpha),100*gamma,"+")
    mu1 <- mu0+effect
    stopifnot(min(mu1)>0,abs(sum(w*mu0))<1e-8,abs(sum(w*mu1)-target)<1e-8)
    y <- matrix(stats::rpois(length(mu1),as.vector(mu1)),n_a,n_t)
    estimate <- sum(w*y)
    oracle_se <- sqrt(sum(w^2*mu1))
    rows[[length(rows)+1L]] <- data.frame(rep=rep,seed=40400000L+rep,scenario=scenario,
      target=target,estimate=estimate,error=estimate-target,oracle_se=oracle_se,
      covered_oracle=abs(estimate-target)<=stats::qnorm(0.975)*oracle_se)
  }
  message("Completed independent bias audit: ",scenario)
}
result <- dplyr::bind_rows(rows)
summary <- result |>
  dplyr::group_by(.data$scenario) |>
  dplyr::summarise(n=dplyr::n(),bias=mean(.data$error),bias_mc_se=stats::sd(.data$error)/sqrt(dplyr::n()),
    oracle_coverage=mean(.data$covered_oracle),.groups="drop")
summary$bias_mc_low <- summary$bias-1.96*summary$bias_mc_se
summary$bias_mc_high <- summary$bias+1.96*summary$bias_mc_se
utils::write.csv(summary,file.path(dir,"staggered-bias-audit-summary.csv"),row.names=FALSE)
# Full oracle records are kept outside the package to avoid inflating the
# CRAN source; source/seed/algorithm are retained for exact regeneration.
saveRDS(result,file.path(tools::R_user_dir("streetlamp","cache"),"validation","staggered-bias-audit.rds"))
print(as.data.frame(summary),row.names=FALSE,digits=5)
