SHELL := /bin/bash
LATEXMK_FLAGS = --pdf --cd
RM := rm -f

volumes := core
books := $(volumes)
book_pdfs := $(books:%=%.pdf)

common_files := $(wildcard common/*.tex)

core_deps := #Core has no dependencies

all: $(book_pdfs)

clean:
	@(\
		shopt -s globstar;\
		$(RM) **/*.aux **/*.log **/*.out **/*.toc **/*.fls;\
		$(RM) **/*.fdb_latexmk;\
	)
Clean: clean
	@(\
		shopt -s globstar;\
		$(RM) **/*.pdf **/*.dvi;\
	)
spellcheck:
	@for file in $$(find -name "*.tex" -not -path "./common/*"); do \
		aspell check --per-conf=./aspell.conf $$file;\
	done

.PHONY: all clean Clean spellcheck

#.SECONDARY with no prerequisites means that intermediate files are not deleted on completion.
.SECONDARY:

###############
#Website stuff.
###############

website_dir := website
website_pdfs := $(book_pdfs:%=$(website_dir)/%)

$(website_dir)/%.pdf: %.pdf
	@cp $< $@

website: $(website_pdfs)

.PHONY: website

######################
#The books themselves.
######################

#First, define a bunch of prerequisites for the books.
#Use = instead of := to ensure they are recursively expanded.
#That is, they are expanded in the context of the make rule where they are used, not now, where they are defined.

#The .tex for the main file for the book.
prereq_main_tex = $$*/$$*.tex
#All the other .tex files in the same folder.
prereq_extra_tex = $$(wildcard $$*/*.tex)

.SECONDEXPANSION:

%.pdf: $(prereq_main_tex) $(prereq_extra_tex) $(common_files)
	latexmk $(LATEXMK_FLAGS) --jobname="$(basename $@)" $<
	mv "$*/$@" "$@"
