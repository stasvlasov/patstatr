## ================================================================================
## Tools for working with PatStat Raw Data (PATSTAT Biblio 2017 Autumn)
## Version: 2018-11-27
## Author: Stas Vlasov (stas.vlasov@outlook.com)
## ================================================================================



## --------------------------------------------------------------------------------
## Load or Install Packages (for testing)
## --------------------------------------------------------------------------------
## for(pkg in c('pbapply'
##            , "stringi"
##            , 'stringr'
##            , 'data.table'
##            , 'dplyr'
##            , 'magrittr'
##            ))
##     if(!require(pkg, character.only = TRUE)) {
##         install.packages(pkg, repos = 'http://cloud.r-project.org')
##         library(pkg, character.only = TRUE)
##     }
## --------------------------------------------------------------------------------






## ================================================================================
## Utilites functions
## ================================================================================

is.0 <- function(x) length(x) == 0

## Calculates number of lines a file has
get.file.nlines <- function(file.name, dir.path = getwd()) {
    file.name %>%
        file.path(dir.path, .) %>%
        normalizePath %>% 
        paste("grep -c $", .) %>%
        system(intern = TRUE) %>%
        as.numeric
}


## --------------------------------------------------------------------------------
#' Reads PatStat .txt files and saves them to .rds (also optional in batches)
#' 
#' @param file File name (.txt is expected)
#' @param dir Directory where the file is. Default is in working directory "patstat-txt"
#' @param dir.rds Where to save. Default is in working directory "patstat-rds"
#' @param batch.lines How many lines is to read in one batch (10^7 is recomended). The default is 0, meanning that reading will be done in one batch as a single file.
#' @param file.lines Length of the .tsv file. The default is 0. If it is not changed and batch.lines is specified then it will try to calculate it with grep.
#' @return Saved file(s) path.
#' @import magrittr stringr data.table
#' @export
patstatr.save.rds <- function(file
                           , dir = file.path(getwd(), "patstat-txt")
                           , dir.rds = file.path(getwd(), "patstat-rds")
                           , batch.lines = 0
                           , file.lines = 0) {
    if(!dir.exists(dir.rds)) dir.create(dir.rds)
    if(batch.lines == 0) {
        file.rds.path <- file %>%
            str_replace("\\.txt$", "") %>% 
            paste0(".rds") %>%
            file.path(dir.rds, .)
        if(file.rds.path %>% file.exists) {
            message("File ", file, " exists. Delete it if you want to replace.")
            return()
        }
        field.names <- 
            file.path(dir, file) %>%
            fread(nrows = 1
                , header = FALSE
                , sep = ",") %>%
            make.names
        file.path(dir, file) %>%
            fread(showProgress = TRUE
                , strip.white = FALSE
                , quote = "\""
                , sep = ","
                , stringsAsFactors = FALSE
                , colClasses = rep("character", length(field.names))) %>%
            saveRDS(file = file.rds.path)
        return(file.rds.path)
    } else {
        if(file.lines == 0) {
            message("Counting lines in the input file...")
            file.lines <- get.file.nlines(file, dir)
            message("The file '", file, "' has - ", file.lines, " lines.")
        }
        batch.file.format <- paste0("%0", nchar(file.lines), "d")
        ## Set start read rows for fread
        rows.skip <- seq(from = 1
                       , to = file.lines
                       , by = batch.lines) %>%
            extract(. != file.lines)
        rows.read <- rows.skip[-1] %>%
            c(file.lines) %>%
            '-'(rows.skip)
        field.names <- 
            file.path(dir, file) %>%
            fread(nrows = 1
                , header = FALSE) %>%
            make.names
        sapply(1:length(rows.read), function(i) {
            ## extract batch
            message("* Reading lines from ", rows.skip[i])
            started <- Sys.time()
            file.rds.path <- file %>%
                str_replace("\\.tsv$", "") %>%
                paste0("-"
                     , sprintf(batch.file.format, rows.skip[i]), "-"  # add padding
                     , sprintf(batch.file.format, rows.skip[i] + rows.read[i] - 1)
                     , ".rds") %>%
                file.path(dir.rds, .)
            if(file.rds.path %>% file.exists) {
                message("File exists. Delete it if you want to replace.")
            } else {
                message("  - Started: ", date())
                file.path(dir, file) %>%
                    fread(nrows = rows.read[i]
                        , header = FALSE
                        , skip = rows.skip[i]
                        , showProgress = TRUE
                        , strip.white = FALSE
                        , quote = "\""
                        , sep = ","
                        , stringsAsFactors = FALSE
                        , colClasses = rep("character", length(field.names))) %>%
                    set_names(field.names) %>% 
                    saveRDS(file.rds.path)
                gc()
                message("  - Done! (in ", as.numeric(Sys.time() - started) %>% round, " minutes)")
            }
            return(file.rds.path)
        }) %>% return
    }
}
## --------------------------------------------------------------------------------



## Tests
## --------------------------------------------------------------------------------

## On Ubuntu
## setwd("/media/stas/fe3504fe-4d3c-400e-b4b8-21717db89682/data/patstat/patstat-biblio-2017-autumn")

## "tls906_part01.txt" %>% 
## get.file.nlines("/media/stas/fe3504fe-4d3c-400e-b4b8-21717db89682/data/patstat/patstat-biblio-2017-autumn/patstat-txt/")
## ## 12500001

## "tls906_part01.txt" %>% patstatr.save.rds(
##                             batch.lines = 5*10^6
##                           , file.lines = 12500001)






## --------------------------------------------------------------------------------
#' Filter tables of PatStat raw data
#'
#' @description
#' Similar to dplyr::filter but for tables of PatStat raw data data saved in multiple .rds files
#' @param file.dir A path to directory with .rds files. Default is in working directory "patstat-rds".
#' @param file.pattern A pattern for getting a file or a set of files (data batches)
#' @param progress.bar Whether to show progress bar (with pbapply package). Default is TRUE
#' @param cols Which column to select. Default is all columns.
#' @param ... A filtering conditions to fetch certain rows. (See dplyr::filter)
#' @return A data.table with a subset the data.
#' @import pbapply magrittr data.table dplyr
#' @export
patstatr.filter <- function(file.pattern, ...
                         , file.dir = file.path(getwd(), "patstat-rds")
                         , progress.bar = TRUE
                         , cols = character(0)) {
    if(progress.bar) {
        file.dir %>%
            file.path(list.files(., pattern = file.pattern)) %>% 
            pblapply(function(file.path) 
                file.path %>%
                readRDS %>% 
                filter(...) %>%
                select(if(cols %>% is.0) everything() else cols)) %>% 
            rbindlist %>% 
            return
    } else {
        file.dir %>%
            file.path(list.files(., pattern = file.pattern)) %>%
            lapply(function(file.path) 
                file.path %>%
                readRDS %>% 
                filter(...) %>%
                select(if(cols %>% is.0) everything() else cols)) %>% 
            rbindlist %>% 
            return
    }
}
## --------------------------------------------------------------------------------



## Tests
## --------------------------------------------------------------------------------
## patstatr.filter.test <-
##     patstatr.filter("^tls906_.*"
##                   , han_name == "THERMO FISHER SCIENTIFIC")




