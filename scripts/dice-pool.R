#!/usr/bin/env Rscript
suppressPackageStartupMessages(library(optparse))

###########
#Constants.
###########

pool_size <- 8
die_sizes <- c(6,12,10,8)

critical_results <- 7
clean_results <- c(6,8)
partial_results <- c(5,9)

#The filename to pass in for interactive display.
interactive_graphics_file <- "-"

#Maps file extensions to a function to open them, and a scaling factor.
plot_formats <- list(
	"pdf" = pdf,
	"svg" = svg,
	"ps" = postscript,
	"png" = png,
	"jpg" = jpeg,
	"jpeg" = jpeg,
	"tif" = tiff,
	"tiff" = tiff,
	"bmp" = bmp
)

plot_width <- 14 #Inches.
plot_height <- 7 #Inches.
plot_res <- 300 #Pixels per inch.

##################
#Argument parsing.
##################

usage = "%prog [options] SKILL1 SKILL2 SKILL3"
description = "Takes the three numbers that constitute a skill level, and prints a couple of diagnostic plots of success probabilities."
option_list <- list(
	make_option(
		c("-n", "--num-draws"), dest = "n", type = "integer", default = 25000,
		help = "The number of random draws to make from a distribution [default %default]."
	),
	make_option(
		c("-o", "--output"), dest = "output", type = "character", default = interactive_graphics_file,
		help = "The name of a pdf to output the plot to [by default, the plot is displayed with X11]."
	)
)
parser <- OptionParser(usage = usage, description = description, option_list = option_list)
arguments <- parse_args(parser, positional_arguments = 3)

skills <- as.integer(arguments$args)

######################
#Function definitions.
######################

#Returns of a list (length n) of vectors (length pool_size) of rolls.
get_rolls <- function(n, skills = c(0,0,0)) {
	num_dice <- -diff(c(pool_size, skills, 0))
	lapply(1:n, function(dummy) {
		unlist(lapply(seq_along(num_dice), function(i) {
			sample(die_sizes[i], num_dice[i], replace=TRUE)
		}))
	})
}

#Returns a data frame with n rows, and columns for number of criticals, cleans, and total successes.
#This is cumulative: cleans include criticals.
get_results <- function(n, skills = c(0,0,0)) {
	rolls <- get_rolls(n, skills)
	count_in <- function(rolls, category) {
		sapply(rolls, function(x) {sum(x %in% category)})
	}
	data.frame(
		criticals = count_in(rolls, critical_results),
		cleans = count_in(rolls, c(critical_results, clean_results)),
		total = count_in(rolls, c(critical_results, clean_results, partial_results))
	)
}

#Returns a matrix suitable for making a stacked bar graph.
#Each column of the bar graph corresponds to a given target, and gives the chance of succeeding at that target.
#Each bar is subdivided by the number of partials required, with the chance of succeeding with 0 partials at the bottom.
#Note that the bottom of the plot corresponds to the top of the matrix.
#The matrix is labelled with appropriate row and column names.
get_bar_mat <- function(n, skills = c(0,0,0)) {
	results <- get_results(n, skills)
	mat <- sapply(1:pool_size, function(target) {
		sapply(0:pool_size, function(partials) {
			sum(results$total >= target & pmax(target - results$cleans, 0) == partials) / nrow(results)
		})
	})
	rownames(mat) <- 0:pool_size
	colnames(mat) <- 1:pool_size
	return(mat)
}

#Returns a table of the probabilities of getting at least 0:pool_size crits.
get_bar_crits <- function(n, skills = c(0,0,0)) {
	results <- get_results(n, skills)
	#table() skips missing values, so we use tabulate instead().
	counts <- tabulate(results$criticals, pool_size)
	names(counts) <- 1:pool_size
	cum_counts <- rev(cumsum(rev(counts)))
	return(cum_counts / nrow(results))
}

open_graphics <- function(filename, width, height) {
	if(filename == interactive_graphics_file) {
		X11(width = width, height = height)
	} else {
		ext <- tolower(tools::file_ext(filename))
		graphics_func <- plot_formats[[ext]]
		if(is.null(graphics_func)) {
			stop(sprintf("Unrecongised file extension: %s", ext))
		}
		args <- list(filename, width = width, height = height)
		#png(), jpeg(), etc default to width and height in px, so we need to convert them to inches.
		if(!is.null(formals(graphics_func)$units)) {
			args$units <- "in"
			args$res <- plot_res
		}
		do.call(graphics_func, args)
	}
}

plot_wait <- function() {
	while(!is.null(dev.list())) {
		Sys.sleep(1)
	}
}

##########
#The body.
##########

mat <- get_bar_mat(arguments$options$n, skills = skills)
crits <- get_bar_crits(arguments$options$n, skills = skills)

open_graphics(arguments$options$output, plot_width, plot_height)

par(mfrow=c(1,2))

barplot(mat,
	ylim = c(0,1),
	main = "Probability of success, by target number",
	xlab = "Target",
	ylab = "Probability of success",
	legend.text = TRUE,
	args.legend = list(title = "Required partials")
)

barplot(crits,
	ylim = c(0,1),
	main = "Probability of critical success, by magnitude",
	xlab = "Number of criticals",
	ylab = "Cumulative probability"
)

if(arguments$options$output == interactive_graphics_file) {
	plot_wait()
}
