#
# Simulation STUDY PERFORMED IN
#
# Nicole Krämer, Juliane Schäfer, Anne-Laure Boulesteix
# "Regularized estimation of large-scale gene association networks using graphical Gaussian models"
# BMC Bioinformatics, 2009

# authors of the original script:
#
# Juliane Schäfer   (JSchaefer@uhbs.ch)
# Nicole Krämer     (nkraemer@cs.tu-berlin.de)
#
# authors of some modifications for reproducing the experiments in:
# "A partial orthogonalization method for simulation covariance and
# concentration graph matrices", Proceedings of Machine Learning Research (PGM
# 2018).
# "Generating random Gaussian graphical models", arXiv 2019.
# Irene Córdoba 	(irene.cordoba@upm.es)
# Gherardo Varando	(gherardo.varando@math.ku.dk)

# LICENCE
#
# This program is free software: you can redistribute it and/or modify it under the terms
# of the GNU General Public License as published by the Free Software Foundation, either
# version 3 of the License, or(at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.

###########################
###### load packages ######
###########################
library("foreach")
# added by irene.cordoba@upm.es because parcor::performance.pcor is bugged for
# now (version 0.2.6 of the package)
source("performance.pcor.R")


############################
###### set parameters ######
############################

p <- 100 # no of variables
n <- seq(25, 200, 25) # number of observations
R <- 20 # number of replications of the experiment
K <- 5 # number of cross-validation splits
# changed from 0.05 to 0.25 by irene.cordoba@upm.es
d <- c(0.05, 0.10, 0.15, 0.20, 0.25) # density of the network
# end of change
xx <- seq(0, 1, length = 200) # x-axis for the RoC plots

f_sample <- c(
  "diagdom" = gmat::diagdom,
  "port" = gmat::port,
  "port_chol" = gmat::port_chol
)
method <- names(f_sample)

##################################
###### performance criteria ######
##################################

m <- matrix(0, R, length(n))
# mean-squared error
MSE.adalasso <- MSE.lasso <- MSE.shrink <- MSE.pls <- MSE.ridge <- m
# number of selected edges
selected.adalasso <- selected.lasso <- selected.shrink <- selected.pls <- selected.ridge <- m
# power
power.adalasso <- power.lasso <- power.shrink <- power.pls <- power.ridge <- m
# positive predictive value
ppv.adalasso <- ppv.lasso <- ppv.shrink <- ppv.pls <- ppv.ridge <- m
# computation time
time.shrink <- time.adalasso <- time.pls <- time.ridge <- m
# false positive rates and true positive rates for the cv-optimal model
fpr.lasso <- fpr.adalasso <- tpr.lasso <- tpr.adalasso <- fpr.pls <- tpr.pls <- fpr.shrink <- tpr.shrink <- fpr.ridge <- tpr.ridge <- m
# true positive rate for the RoC plots
TPR.shrink <- TPR.ridge <- TPR.pls <- array(dim = c(R, length(n), length(xx)))

############################
###### run simulation ######
############################

n_cores_max <- parallel::detectCores() - 1
n_cores <- min(n_cores_max, length(d) * length(method))
cl <- parallel::makeCluster(n_cores, outfile = "")
doParallel::registerDoParallel(cl)

foreach(k = 1:length(d)) %:%
  foreach(j = 1:length(method)) %dopar% {
    for (l in 1:R) {
      for (i in 1:length(n)) {
        true.pcor <- f_sample[[method[j]]](p = p, d = d[k])[, , 1]
        x <- MASS::mvrnorm(n = n[i], mu = rep(0, p), Sigma = solve(true.pcor))
        #############
        # shrinkage #
        #############
        time.shrink[l, i] <- system.time(pc <- corpcor::pcor.shrink(x))[3]
        MSE.shrink[l, i] <- sum((pc - true.pcor)^2)
        time.shrink[l, i] <- time.shrink[l, i] + system.time(performance <- performance.pcor_fixed(pc, true.pcor, fdr = TRUE, verbose = FALSE, plot = FALSE))[3]
        selected.shrink[l, i] <- performance$num.selected
        power.shrink[l, i] <- performance$power
        ppv.shrink[l, i] <- performance$ppv
        fpr <- sort(performance$FPR)
        tpr <- sort(performance$TPR)
        if ((length(fpr) > 0) & (length(tpr) > 0)) {
          fn <- stepfun(fpr, c(0, tpr))
          TPR.shrink[l, i, ] <- fn(xx)
          tpr.shrink[l, i] <- performance$tpr
          fpr.shrink[l, i] <- performance$fpr
        }
        #########################
        # Partial Least Squares #
        #########################
        time.pls[l, i] <- system.time(pc <- parcor::pls.net(x, k = K)$pcor)[3]
        MSE.pls[l, i] <- sum((pc - true.pcor)^2)
        time.pls[l, i] <- time.pls[l, i] + system.time(performance <- performance.pcor_fixed(pc, true.pcor, fdr = TRUE, verbose = FALSE, plot = FALSE))[3]
        selected.pls[l, i] <- performance$num.selected
        power.pls[l, i] <- performance$power
        ppv.pls[l, i] <- performance$ppv
        fpr <- sort(performance$FPR)
        tpr <- sort(performance$TPR)
        if ((length(fpr) > 0) & (length(tpr) > 0)) {
          fn <- stepfun(fpr, c(0, tpr))
          TPR.pls[l, i, ] <- fn(xx)
          tpr.pls[l, i] <- performance$tpr
          fpr.pls[l, i] <- performance$fpr
        }
        ######################
        # Lasso and Adalasso #
        ######################
        time.adalasso[l, i] <- system.time(fit <- parcor::adalasso.net(x, k = K, both = TRUE))[3]
        # lasso
        pc <- fit$pcor.lasso
        MSE.lasso[l, i] <- sum((pc - true.pcor)^2)
        performance <- performance.pcor_fixed(pc, true.pcor, fdr = FALSE)
        selected.lasso[l, i] <- performance$num.selected
        power.lasso[l, i] <- performance$power
        ppv.lasso[l, i] <- performance$ppv
        fpr.lasso[l, i] <- performance$fpr
        tpr.lasso[l, i] <- performance$tpr
        # adaptive Lasso
        pc <- fit$pcor.adalasso
        MSE.adalasso[l, i] <- sum((pc - true.pcor)^2)
        performance <- performance.pcor_fixed(pc, true.pcor, fdr = FALSE)
        selected.adalasso[l, i] <- performance$num.selected
        power.adalasso[l, i] <- performance$power
        ppv.adalasso[l, i] <- performance$ppv
        fpr.adalasso[l, i] <- performance$fpr
        tpr.adalasso[l, i] <- performance$tpr
        ####################
        # Ridge Regression #
        ####################
        time.ridge[l, i] <- system.time(dummy <- parcor::ridge.net(x, k = K, plot.it = FALSE))[3]
        pc <- dummy$pcor
        MSE.ridge[l, i] <- sum((pc - true.pcor)^2)
        time.ridge[l, i] <- time.ridge[l, i] + system.time(performance <- performance.pcor_fixed(pc, true.pcor, fdr = TRUE, verbose = FALSE, plot = FALSE))[3]
        selected.ridge[l, i] <- performance$num.selected
        power.ridge[l, i] <- performance$power
        ppv.ridge[l, i] <- performance$ppv
        fpr <- sort(performance$FPR)
        tpr <- sort(performance$TPR)
        if ((length(fpr) > 0) & (length(tpr) > 0)) {
          fn <- stepfun(fpr, c(0, tpr))
          TPR.ridge[l, i, ] <- fn(xx)
          tpr.ridge[l, i] <- performance$tpr
          fpr.ridge[l, i] <- performance$fpr
        }
      }
    }

    wd <- getwd()
    dir.create(paste0(wd, "/res_kramer_", method[j], "_", d[k]), showWarnings = FALSE)
    for (obj_name in ls()) {
      saveRDS(get(obj_name),
        file = paste0(
          "res_kramer_", method[j], "_", d[k], "/", obj_name, ".rds"
        )
      )
    }
  }

parallel::stopCluster(cl)
