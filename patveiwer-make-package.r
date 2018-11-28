## Creates OrbisR package

## --------------------------------------------------------------------------------
## Load or Install Packages
## --------------------------------------------------------------------------------
for(pkg in c('pbapply'
           , 'stringr'
           , 'data.table'
           , 'dplyr'
           , 'magrittr'
           , 'devtools'
           , 'roxygen2'))
    if(!require(pkg, character.only = TRUE)) {
        install.packages(pkg, repos = 'http://cloud.r-project.org', quiet = TRUE)
        library(pkg, character.only = TRUE)
    }
## --------------------------------------------------------------------------------


## Making a package
## --------------------------------------------------------------------------------
setwd("~/org/data/patstat/patstatr")

## Updates package info
person("Stas", "Vlasov", 
       email = "s.vlasov@uvt.nl", 
       role  = c("aut", "cre")) %>% 
    {paste0("'",., "'")} %>%
    {options(devtools.desc.author = .)}



## Assume that it runs from "harmonizer" directory
list(Title  = "Tools for working with raw PATSTAT database"
   , Date = "2018-11-27"
   , License = "MIT License"
   , Description = "Set of functions that help to prepare, to load into R session and to search PATSTAT data"
   , References = "patstat-biblio-2017-autumn-txt") %>% 
    {setup(rstudio = FALSE
         , description = .)}


## Update name spaces and documentation for functions
roxygenise()

document()



## Testing
## --------------------------------------------------------------------------------
install(".")

## install_github("stasvlasov/patstatr")
library('patstatr')






