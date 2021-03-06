# LOS Distributions to use. 

# Analysis of hospital length of stay with COVID-19
# Author: Naomi R Waterlow
# Date: 2020-05-06
################################################################################
#
# This script allows users to gerenate their own sample from a specificed distribution
# 
################################################################################
################################################################################

library(here)

# Load the functions
source(here::here("code","comb_dist_funcs.R"))
#Load and format the data
source(here::here("code","comb_dist_data.R"))

# Create the distribution
# Input: sample size
#        setting - "China" or "Rest_of_world",
#        type = "General" or "ICU"
# Output: samples - samples taken from desired distribution
#         parameters - weibull parameters and sample size for each fitted distribution.
#         errors - the magnitude of error for each fit.

n <- 100000

calculated_distribution <- 
    expand.grid(setting = c("China", "Rest_of_World"),
                type    = c("General", "ICU")) %>%
    dplyr::rowwise(.) %>%
    tidyr::nest(data = -c(setting, type)) %>%
    dplyr::ungroup(.) %>%
    dplyr::mutate(id = 1:nrow(.))

calculated_distribution$distribution <-
    dplyr::rowwise(calculated_distribution) %>%
    dplyr::group_split(.) %>%
    purrr::map(., ~create_own_distribution(n, .x$setting,  .x$type))

calculated_distribution <- tidyr::unnest_wider(calculated_distribution, distribution)

dplyr::select(calculated_distribution, setting, type, samples) %>%
    tidyr::unnest(samples) %>%
    dplyr::ungroup(.) %>%
    dplyr::group_by_at(.vars = dplyr::vars(-samples)) %>%
    dplyr::summarise_at(.vars = dplyr::vars(samples),
                        .funs = list(mean = mean,
                                     median = median,
                                     cv = function(x){sd(x)/mean(x)},
                                     q_25 = function(x){quantile(x, 0.25)},
                                     q_75 = function(x){quantile(x, 0.75)}))

distribution_samples <- 
    dplyr::select(calculated_distribution, setting, type, samples) %>%
    tidyr::unnest(samples) %>%
    dplyr::ungroup(.)

ggplot2::ggplot(data=distribution_samples, aes(x=samples)) +
    ggplot2::geom_histogram(binwidth = 1) +
    ggplot2::facet_grid(setting ~ type) +
    ggplot2::xlim(c(0, 60))


#extract the sample size
distribution_parameters <-
    dplyr::mutate(calculated_distribution, 
                  parameters = purrr::map(parameters,
                                          ~data.frame(t(.x)) %>%
                                              dplyr::rename(shape = X1,
                                                            scale = X2,
                                                            N     = X3))) %>%
    dplyr::select(setting, type, parameters) %>%
    tidyr::unnest(parameters) 

# fit distribution

distribution_samples %>%
    tidyr::nest(data = -c(setting, type)) %>%
    dplyr::mutate(
        fitdist = purrr::map(data,
                             ~fitdistrplus::fitdist(
                                 unlist(.x),
                                 distr = "weibull",
                                 method = "qme",
                                 probs = c(0.25, 0.75),
                                 start = list(shape = 3,
                                              scale = 27)
                             )),
        parameters = purrr::map(fitdist, "estimate")) %>%
    tidyr::unnest_wider(parameters) 
