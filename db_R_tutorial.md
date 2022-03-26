---
title: "Hacking Medical Physics with R"
author: |
  Michael Wieland  
  mchl.wieland@gmail.com
date: "2022-03-27"
output: 
  html_document: 
    highlight: pygments
    theme: flatly
    toc: yes
    toc_float: yes
    toc_depth: 3
    code_folding: show
    keep_md: yes
---


```r
knitr::opts_chunk$set(echo = TRUE)

library(tidyverse)
library(readxl)
library(ggthemes)
library(kableExtra)
library(tibble)
library(DBI)
#library(RSQLite)
# https://cran.r-project.org/web/packages/RSQLite/vignettes/RSQLite.html
```

## Short Description
This is a R/RStudio-Version for Part 2 of the article series "Hacking Medical Physics" by Jonas Andersson and Gavin Poludniowski (GitRepo: [rvbCMTS/EMP-News](https://github.com/rvbCMTS/EMP-News.git)) in the newsletter of the European Federation of Organisations for Medical Physics (EFOMP)^[[European Medical Physics News](https://www.efomp.org/index.php?r=fc&id=emp-news)]. GitRepo for this R/RStudio version: [Michael Wieland - Hacking Medical Physics - R Version](https://github.com/michaelwiel/hacking_medphys_R_part2.git).

### Ressources and Preparation
In order to run this R Markdown file you need to install RStudio with R ([RStudio Installer](https://www.rstudio.com/products/rstudio/download/)).  

Ressources to get started with R:  

* [RStudio Education - Beginners](https://education.rstudio.com/learn/beginner/)  
* [RStudio Support - Getting Started with R](https://support.rstudio.com/hc/en-us/articles/201141096-Getting-Started-with-R)  
* [RStudio Book Collection](https://www.rstudio.com/products/rstudio/download/)  
* [ggplot2 - Elegent Graphics for Data Analysis](https://ggplot2-book-solutions-3ed.netlify.app/index.html)  

I will make heavy use of the package collection `tidyverse` and the "pipe"-operator (` %>% `). To learn more have a look at: [`tidyverse` - R packages for data science](https://www.tidyverse.org/).  
If you have not installed the packages loaded in the `setup code chunk` (see above) start with installing them via `Tools` -> `Install Packages`.

### Executing Code
You can run the code in the RStudio console window or directly in the R Markdown file by clicking on the little "Play"-button in the top right hand corner of the code chunks:

![Code chunk example - Execute code with play button in the top right hand corner](figures/example_codechunk.png)

## Reading in Data
If your data files reside in the working directory you can access them in a relative fashion. My current working directory is the folder where this R Markdown-file is stored and the data files are stored in a subfolder called "reports".

### Reading an Excel File
My preferred method to read Excel files is to use the `readxl`-package:


```r
read_xls(path = "reports/StaffDoses_1.xls") %>% 
  head(5)
```

```
## # A tibble: 5 x 18
##   `Customer name`  `Customer UID` Department `Department UID` Name  `Person UID`
##   <chr>            <chr>          <chr>      <chr>            <chr> <chr>       
## 1 Hogsmeade Royal~ 141            Nuclear M~ 1                Seve~ 12368       
## 2 Hogsmeade Royal~ 141            Nuclear M~ 1                Harr~ 12369       
## 3 Hogsmeade Royal~ 141            Nuclear M~ 1                Parv~ 12370       
## 4 Hogsmeade Royal~ 141            Nuclear M~ 1                Parv~ 12370       
## 5 Hogsmeade Royal~ 141            Nuclear M~ 1                Cedr~ 12371       
## # ... with 12 more variables: Radiation type <chr>, Hp(10) <chr>,
## #   Hp(0.07) <chr>, User type <chr>, Dosimeter type <chr>,
## #   Dosimeter placement <chr>, Dosimeter UID <chr>,
## #   Measurement period (start) <chr>, Measurement period (end) <chr>,
## #   Read date <chr>, Report date <chr>, Report UID <chr>
```

_Note for R Newcomers:_ If you know the order of the arguments of a function you don't have to supply the argument names. If you open the help for the function `read_xls` by typing `?read_xls` in the console the description of the function includes the list of arguments:  
<br>
`read_xls(path, sheet = NULL, range = NULL, col_names = TRUE, col_types = NULL, ...)`  
<br>
Since `path` is the first argument we could also read in the data by just writing `read_xls("reports/StaffDoses_1.xls")`. It is of course faster to type but on the other side makes the code harder to read if you don't know the function. The second thing to note is that there are a lot of other mandatory arguments but they all have a default value. For example `col_names` is set to `TRUE` by default and this will cause the function to regard the first line in the Excel file as column names and not as data.  


### Fixing the column names
Reading the Excel file with the function `read_xls` from the package `readxl` gives a decent first result. A few things should be changed though in order to work with the data properly. There are a lot of code style guides out there^[[Coding style, coding etiquette](https://blog.r-hub.io/2022/03/21/code-style/)] but I am going to adhere to the following convention of naming the variable names (column titles)^[[Social Science Computing Cooperative - Naming Variables](https://sscc.wisc.edu/sscc/pubs/DWE/book/4-2-naming-variables.html)]:  

> * Use only lower case.  
> * Use the underscore, "_" as a replacment for spaces to separate words (called __snake coding__).
> * ...

Assuming that the reports are always delivered in the same format and structure we can fix the column headers once and use them later on to replace the column names for all reports.


```r
report_column_names <- read_xls(path = "reports/StaffDoses_1.xls",
                                n_max = 0) %>% 
  # to extract the column names we don't need any data therefore we read in n=0 lines
  colnames() %>% # extracting the column names as a vector
  tolower() %>% # convert upper case to lower case
  gsub(pattern = " ", 
       replacement = "_") %>% # replacing blanks with underscores
  gsub(pattern = "[().]", 
       replacement = "")  # deleting round brackets and dots; 
    # the square-brackets function as list operator (all characters inside the square-brackets are identified)

#checking the result:
report_column_names
```

```
##  [1] "customer_name"            "customer_uid"            
##  [3] "department"               "department_uid"          
##  [5] "name"                     "person_uid"              
##  [7] "radiation_type"           "hp10"                    
##  [9] "hp007"                    "user_type"               
## [11] "dosimeter_type"           "dosimeter_placement"     
## [13] "dosimeter_uid"            "measurement_period_start"
## [15] "measurement_period_end"   "read_date"               
## [17] "report_date"              "report_uid"
```

### Read in all reports from a folder
To read in all files from a folder we can make use of the function `read.files()` that gives a list of all files in a folder.


```r
list.files(path = "reports") # get a list of all files from a folder
```

```
##  [1] "StaffDoses_1.xls"  "StaffDoses_10.xls" "StaffDoses_11.xls"
##  [4] "StaffDoses_12.xls" "StaffDoses_13.xls" "StaffDoses_14.xls"
##  [7] "StaffDoses_15.xls" "StaffDoses_16.xls" "StaffDoses_17.xls"
## [10] "StaffDoses_18.xls" "StaffDoses_19.xls" "StaffDoses_2.xls" 
## [13] "StaffDoses_20.xls" "StaffDoses_21.xls" "StaffDoses_22.xls"
## [16] "StaffDoses_23.xls" "StaffDoses_24.xls" "StaffDoses_25.xls"
## [19] "StaffDoses_26.xls" "StaffDoses_27.xls" "StaffDoses_28.xls"
## [22] "StaffDoses_3.xls"  "StaffDoses_4.xls"  "StaffDoses_5.xls" 
## [25] "StaffDoses_6.xls"  "StaffDoses_7.xls"  "StaffDoses_8.xls" 
## [28] "StaffDoses_9.xls"
```

```r
all_reports_to_read_in <- list.files("reports") # read the list of file names into a character vector

# number of reports in the folder:
length(all_reports_to_read_in)
```

```
## [1] 28
```

```r
all_reports <- data.frame() # create an empty dataframe

for (i in 1:length(all_reports_to_read_in)) { # a for-loop to read in all reports
  
  # reading in the i-th report into variable "rep":
  rep <- read_xls(path = paste0("reports/", all_reports_to_read_in[i])) 
  
  all_reports <- rbind(all_reports, rep) # binding together the reports rowwise
}  

colnames(all_reports) <- report_column_names # replacing the column names with the fixed names (see above)
```

### Fix data types
Some data wrangling is needed to get the right data types: 

* All numerical variables should be defined as `double` or `integer`,  
* Replace semicolons with dots in decimal numbers so R can recognize them as numbers ("English convention" for decimal numbers),  
* Create a column `status` before converting `hp10` and `hp007` to numeric in order not to lose information. Where `hp10` and `hp007` have the values "B", "NR" or `NA` (B: Below Measurement Treshold; NR: Not returned; `NA`: Missing Value) we transfer those values to the new column, if the values are numeric we set the value in the new column to "OK".  

To fix the dates I needed a work around because my machine `locale` is set to German but the dates in the reports have abbreviated month names in English. One way to read in the data correctly with little coding is to set the `locale` on the machine to English temporarily. For date-time conversion to and from character see [`strptime`](https://www.rdocumentation.org/packages/base/versions/3.6.2/topics/strptime).




```r
# getting locale
loc <- Sys.getlocale("LC_TIME") # storing the machine locale setting for time and dates in variable "loc"
Sys.setlocale("LC_TIME", locale = "English") # setting the machine locale for time and dates to "English"
```

```
## [1] "English_United States.1252"
```

```r
# the value for "locale" is depending on the operating system. For Windows the value is "English".
# check the help page with "?Sys.setlocale()" if you are not using Windows.


all_reports_fixed <- all_reports %>% 
  # At first we replace the colon with dots as comma sign 
    # (needed to convert to numeric later on)
  # with the function mutate we create new columns based on existing ones 
    # or modify the content of existing columns
  mutate(hp10 = str_replace_all(hp10, 
                                pattern = ",", 
                                replacement = ".")) %>% 
  mutate(hp007 = str_replace_all(hp007, 
                                 pattern = ",", 
                                 replacement = ".")) %>% 
  # before we convert hp10 and hp007 to numeric we create a new column 
    # with non-numeric values of hp007 in order not to lose information
    # "B": Below Measurement Threshold, 
    # "NR": Not returned, 
    # "NA": missing value; 
    # "OK" where a numeric value exists for the variables hp007)
  mutate(status = case_when(hp007 == "B" ~ "B",
                            hp007 == "NR" ~ "NR",
                            is.na(hp007) ~ NA_character_,
                            is.numeric(as.numeric(hp007)) ~ "OK")) %>% 
  # next we convert columns with numbers to numeric 
    # (non-numeric values in hp10 and hp007 will be converted to NA automatically)
  mutate(across(c(customer_uid, department_uid, person_uid, hp10, hp007, dosimeter_uid, report_uid), 
                as.numeric)) %>% 
  # next we convert the columns representing dates from "character" to "date"
    # with "format = '%d-%b-%Y'" we tell R that the date is in the form "01-Dec-2021"
  mutate(across(c(measurement_period_start:report_date), 
                as.Date, 
                format = "%d-%b-%Y")) %>% 
  # to make sure we have no duplicated data (same report read in more than once) 
  # we eliminate duplicates with the function "distinct"... after grouping by person_uid and dosimeter_uid
  group_by(person_uid, dosimeter_uid) %>% 
  distinct(report_uid, .keep_all = TRUE) %>%
  ungroup()

head(all_reports_fixed)
```

```
## # A tibble: 6 x 19
##   customer_name     customer_uid department   department_uid name     person_uid
##   <chr>                    <dbl> <chr>                 <dbl> <chr>         <dbl>
## 1 Hogsmeade Royal ~          141 Nuclear Med~              1 Severus~      12368
## 2 Hogsmeade Royal ~          141 Nuclear Med~              1 Harry P~      12369
## 3 Hogsmeade Royal ~          141 Nuclear Med~              1 Parvati~      12370
## 4 Hogsmeade Royal ~          141 Nuclear Med~              1 Parvati~      12370
## 5 Hogsmeade Royal ~          141 Nuclear Med~              1 Cedric ~      12371
## 6 Hogsmeade Royal ~          141 Nuclear Med~              1 Cedric ~      12371
## # ... with 13 more variables: radiation_type <chr>, hp10 <dbl>, hp007 <dbl>,
## #   user_type <chr>, dosimeter_type <chr>, dosimeter_placement <chr>,
## #   dosimeter_uid <dbl>, measurement_period_start <date>,
## #   measurement_period_end <date>, read_date <date>, report_date <date>,
## #   report_uid <dbl>, status <chr>
```

```r
Sys.setlocale("LC_TIME", locale = loc) # setting back the locale 
```

```
## [1] "German_Austria.1252"
```

#--------  
__Comment Michael: Discussion necessary regarding status column__  


#--------


## Using R with SQL

### Ressources and Motivation
For this part I am drawing heavily on the following ressources:  

* [RStudio - Databases using R](https://db.rstudio.com/)  
* [Simona Picardi - Reproducible Data Science - Chapter 07 - Interfacing Databases in R with RSQLite](https://ecorepsci.github.io/reproducible-science/rsqlite.html)  
* [SQLite Tutorial](https://www.sqlitetutorial.net/)  


For a limited number of files like in the example above working with a database is not necessary but databases have several advantages^[[opentextbc.ca - Database Design](https://opentextbc.ca/dbdesign01/chapter/chapter-3-characteristics-and-benefits-of-a-database)]:  

>* Data Independence (your colleagues might want to access the data with Python or Matlab)  
>* Insulation between data and program  
>* Support for multiple views of data (subsets of the data for different users)  
>* Centralized control over data  
>* Data can be shared  
>* Redundancy can be reduced (ideally each data item is stored in only one place)  
>* Integrity constraints (rules that dictate what can be entered or edited)  
>* Security constraints  

If you are new to SQL and you want to have a possibilty to "look into" a SQLite database check out the leightweight and open source GUI [SQLiteStudio](https://sqlitestudio.pl/).
<br>
To connect R to a database management system (DBMS) we need the [`DBI`-package](https://dbi.r-dbi.org/) and [`RSQLite`](https://rsqlite.r-dbi.org/). If you not have done it already go ahead and install the `RSQLite`-package which will automatically install the `DBI`-package. For detailed information on the `DBI` functions we will use, see the [DBI - Reference](https://dbi.r-dbi.org/reference/).

### Creating (or opening a connection to) a Database
With the funciton `dbConnect` you create a database file or open a connection to an already existing database.  
See [RSQLite Packages Vignette](https://rsqlite.r-dbi.org/reference/sqlite) for a list of optional arguments. The argument `flags` specifies the connection mode:  

* SQLITE_RWC: open the database in read/write mode and create the database file if it does not already exist [DEFAULT];  
* SQLITE_RW: open the database in read/write mode. Raise an error if the file does not already exist;  
* SQLITE_RO: open the database in read only mode. Raise an error if the file does not already exist.  

Since a database can hold many different kinds of data, not only personnel dosimeter readings, I will call the database `medical_physics_db.sqlite`.

```r
mp_db_conn <- dbConnect(drv = RSQLite::SQLite(), 
                        dbname = "medical_physics_db.sqlite")
# opening the connection to the database "medical_physics_db.sqlite" and 
# creating a connection object called "mp_db_conn" that represents the database.
```


### Creating a Table for the Dosimeter Data
In a database all data is stored in tables. For simplicity we will create a single table for the staff dosimeter readings and don't go into details of optimal table design like [functional dependencies](https://opentextbc.ca/dbdesign01/chapter/chapter-11-functional-dependencies/) and [normalization](https://en.wikipedia.org/wiki/Database_normalization). 
<br>








#### Our First Table
Before we create our final personnel dosimeter table we are going to have a look at some useful functions and run a view tests. As data we will use a subset (first 10 rows) of the cleaned data we already prepared before (section "Fix data types"). 


```r
# In SQL there are several possibilities to handle date, I prefer "text"; 
# details see here: https://www.sqlite.org/lang_datefunc.html 
# Therefore we first change the data type of the date columns to text
all_reports_fixed_dateastext <- all_reports_fixed %>% 
  mutate(across(c(measurement_period_start:report_date), as.character))

# storing the first 10 rows in a seperate dataframe
arf_rows01to10 <- all_reports_fixed_dateastext[1:10,]
```

The easiest way to create a table is by using the function `dbWriteTable` which takes a dataframe as argument and writes the data into a table.  


```r
# creating a table from a dataframe
dbWriteTable(conn = mp_db_conn,
             name = "test01",
             value  = arf_rows01to10,
             overwrite = TRUE)
# I set the argument "overwrite" to TRUE in case you run this script more than once.
  # If you write data to a table with dbWriteTable() there are three possibilites:
  # 1) The table exists but you want to overwrite it: use the "overwrite = TRUE"
  # 2) The table exists and you want to add data: use "append = TRUE"
  # 3) The table does not exist: neither overwrite or append have to be used
# If the table exists but you neither set append or overwrite to TRUE you will get an error message 

#check if it worked by listing all tables of a database:
dbListTables(conn = mp_db_conn)
```

```
## [1] "test01"
```

Now we execute our first SQL queries with `dbGetQuery()` which returns the result of the query as dataframe.


```r
dbGetQuery(conn = mp_db_conn,
           statement = "SELECT * FROM test01") %>% 
  tibble::tibble()
```

```
## # A tibble: 10 x 19
##    customer_name    customer_uid department    department_uid name    person_uid
##    <chr>                   <dbl> <chr>                  <dbl> <chr>        <dbl>
##  1 Hogsmeade Royal~          141 Nuclear Medi~              1 Severu~      12368
##  2 Hogsmeade Royal~          141 Nuclear Medi~              1 Harry ~      12369
##  3 Hogsmeade Royal~          141 Nuclear Medi~              1 Parvat~      12370
##  4 Hogsmeade Royal~          141 Nuclear Medi~              1 Parvat~      12370
##  5 Hogsmeade Royal~          141 Nuclear Medi~              1 Cedric~      12371
##  6 Hogsmeade Royal~          141 Nuclear Medi~              1 Cedric~      12371
##  7 Hogsmeade Royal~          141 Nuclear Medi~              1 Ron We~      12372
##  8 Hogsmeade Royal~          141 Nuclear Medi~              1 Tom Ma~      12373
##  9 Hogsmeade Royal~          141 Diagnostic R~              2 Hermio~      12374
## 10 Hogsmeade Royal~          141 Diagnostic R~              2 Albus ~      12375
## # ... with 13 more variables: radiation_type <chr>, hp10 <dbl>, hp007 <dbl>,
## #   user_type <chr>, dosimeter_type <chr>, dosimeter_placement <chr>,
## #   dosimeter_uid <dbl>, measurement_period_start <chr>,
## #   measurement_period_end <chr>, read_date <chr>, report_date <chr>,
## #   report_uid <dbl>, status <chr>
```

```r
# Conversion of the resulting dataframe into a tibble (a special form of dataframe) 
  # only for visualisation reasons (more compact output in the rendered html)

# Let's select a subset of columns
dbGetQuery(conn = mp_db_conn,
           statement = "SELECT name, person_uid, dosimeter_uid, report_uid,
                        STRFTIME('%Y-%m', report_date) as report_month 
                        FROM test01")
```

```
##                  name person_uid dosimeter_uid report_uid report_month
## 1       Severus Snape      12368         90072       1137      2019-12
## 2        Harry Potter      12369         90073       1137      2019-12
## 3       Parvati Patil      12370         90075       1137      2019-12
## 4       Parvati Patil      12370         90076       1137      2019-12
## 5      Cedric Diggory      12371         90077       1137      2019-12
## 6      Cedric Diggory      12371         90078       1137      2019-12
## 7         Ron Weasley      12372         90079       1137      2019-12
## 8  Tom Marvolo Riddle      12373         90080       1137      2019-12
## 9   Hermione Grainger      12374         90081       1137      2019-12
## 10   Albus Dumbledore      12375         90082       1137      2019-12
```

```r
# See the structure of the table by using built in pragma statements
  # (https://www.sqlite.org/pragma.html) in a query
dbGetQuery(conn = mp_db_conn,
           statement = "pragma table_info('test01')")
```

```
##    cid                     name type notnull dflt_value pk
## 1    0            customer_name TEXT       0         NA  0
## 2    1             customer_uid REAL       0         NA  0
## 3    2               department TEXT       0         NA  0
## 4    3           department_uid REAL       0         NA  0
## 5    4                     name TEXT       0         NA  0
## 6    5               person_uid REAL       0         NA  0
## 7    6           radiation_type TEXT       0         NA  0
## 8    7                     hp10 REAL       0         NA  0
## 9    8                    hp007 REAL       0         NA  0
## 10   9                user_type TEXT       0         NA  0
## 11  10           dosimeter_type TEXT       0         NA  0
## 12  11      dosimeter_placement TEXT       0         NA  0
## 13  12            dosimeter_uid REAL       0         NA  0
## 14  13 measurement_period_start TEXT       0         NA  0
## 15  14   measurement_period_end TEXT       0         NA  0
## 16  15                read_date TEXT       0         NA  0
## 17  16              report_date TEXT       0         NA  0
## 18  17               report_uid REAL       0         NA  0
## 19  18                   status TEXT       0         NA  0
```

As you can see from the output we don't have a primary key (all "pk" are set to 0) and neither have we set a UNIQUE constraint.  
<br>
Let's see what happens if we add some more data. This time we create a dataframe with rows 10 to 12 from `all_reports_fixed_dateastext`. Row 10 is already in the database and rows 11 and 12 are new data.


```r
arf_rows10to12 <- all_reports_fixed_dateastext[10:12,]

dbWriteTable(conn = mp_db_conn,
             name = "test01",
             value = arf_rows10to12,
             append = TRUE) 
# if there is already a table with the given name we have to 
# set one of the arguments "append" or "overwrite" to true, 
# otherwise we will get an error message

dbGetQuery(conn = mp_db_conn,
           statement = "SELECT name, person_uid, dosimeter_uid, 
                        STRFTIME('%Y-%m', report_date) AS report_month
                        FROM test01") %>% 
  tibble()
```

```
## # A tibble: 13 x 4
##    name               person_uid dosimeter_uid report_month
##    <chr>                   <dbl>         <dbl> <chr>       
##  1 Severus Snape           12368         90072 2019-12     
##  2 Harry Potter            12369         90073 2019-12     
##  3 Parvati Patil           12370         90075 2019-12     
##  4 Parvati Patil           12370         90076 2019-12     
##  5 Cedric Diggory          12371         90077 2019-12     
##  6 Cedric Diggory          12371         90078 2019-12     
##  7 Ron Weasley             12372         90079 2019-12     
##  8 Tom Marvolo Riddle      12373         90080 2019-12     
##  9 Hermione Grainger       12374         90081 2019-12     
## 10 Albus Dumbledore        12375         90082 2019-12     
## 11 Albus Dumbledore        12375         90082 2019-12     
## 12 Filius Flitwick         12376         90083 2019-12     
## 13 Neville Longbottom      12377         90084 2019-12
```

Now we have 13 rows in the table which means that we created a duplicate by adding row 10 a second time (entry for the dosimeter reading of Albus Dumbledore from December 2019).  


#### Table with Constraints
In order to avoid duplicates we need constraints like a `PRIMARY KEY` and/or a `UNIQUE` constraint.
There are different strategies to implement constraints but for consistency reasons we will build our dosimeter readings table analogous to the Python tutorial "by hand" and call it `staffdose`.  
As `PRIMARY KEY` we add an `id`-column and set a `UNIQUE`-constraint with `report_uid, person_uid, dosimeter_placement`.  
<br>
First we delete the table `test01` with the function `dbExecute`. This function executes data manipulation statements without returning a result set.

```r
# First we clean up the database by deleting the test01-table
dbExecute(conn = mp_db_conn, 
          statement = "DROP TABLE IF EXISTS test01")
```

```
## [1] 0
```

```r
# If you run this script a second time 
# you will get an error message if you try to create a table that already exists.
# Therefore we will run the command "DROP TABLE IF EXISTS" 
  # to delete the table "staffdose" should it already exist:
dbExecute(conn = mp_db_conn, 
          statement = "DROP TABLE IF EXISTS staffdose")
```

```
## [1] 0
```

```r
# check content of the database
dbListTables(conn = mp_db_conn)
```

```
## character(0)
```

```r
# creating the table
dbExecute(conn = mp_db_conn,
          statement = 
            "CREATE TABLE staffdose (
                id INTEGER NOT NULL PRIMARY KEY,
                customer_name VARCHAR,
                customer_uid INTEGER,
                department VARCHAR,
                department_uid INTEGER,
                name VARCHAR,
                person_uid INTEGER,
                radiation_type VARCHAR,
                hp10 DOUBLE,
                hp007 DOUBLE,
                user_type VARCHAR,
                dosimeter_type VARCHAR,
                dosimeter_placement VARCHAR,
                dosimeter_uid INTEGER,
                measurement_period_start TEXT,
                measurement_period_end TEXT,
                read_date TEXT,
                report_date TEXT,
                report_uid DOUBLE,
                status VARCHAR,
                UNIQUE(report_uid, person_uid, dosimeter_placement)
            );")
```

```
## [1] 0
```

```r
# check if it worked
dbListTables(conn = mp_db_conn)
```

```
## [1] "staffdose"
```

```r
dbListFields(conn = mp_db_conn,
             name = "staffdose")
```

```
##  [1] "id"                       "customer_name"           
##  [3] "customer_uid"             "department"              
##  [5] "department_uid"           "name"                    
##  [7] "person_uid"               "radiation_type"          
##  [9] "hp10"                     "hp007"                   
## [11] "user_type"                "dosimeter_type"          
## [13] "dosimeter_placement"      "dosimeter_uid"           
## [15] "measurement_period_start" "measurement_period_end"  
## [17] "read_date"                "report_date"             
## [19] "report_uid"               "status"
```

```r
# check if "id" is the primary key of the table:
dbGetQuery(conn = mp_db_conn, 
           statement = "pragma table_info('staffdose')") %>% 
  head(1)
```

```
##   cid name    type notnull dflt_value pk
## 1   0   id INTEGER       1         NA  1
```

```r
# the id-column should have the values 1 for "notnull" and "pk" (primary key)
```

Let's try again, add data and then try to add some more data including duplicates:


```r
# adding data
dbAppendTable(conn = mp_db_conn,
             name = "staffdose",
             value = arf_rows01to10)
```

```
## [1] 10
```

```r
# check if data was added
dbGetQuery(conn = mp_db_conn,
           statement = "SELECT name, person_uid, dosimeter_placement, dosimeter_uid, report_uid FROM staffdose")
```

```
##                  name person_uid dosimeter_placement dosimeter_uid report_uid
## 1       Severus Snape      12368                Body         90072       1137
## 2        Harry Potter      12369                Body         90073       1137
## 3       Parvati Patil      12370                Body         90075       1137
## 4       Parvati Patil      12370           Left hand         90076       1137
## 5      Cedric Diggory      12371                Body         90077       1137
## 6      Cedric Diggory      12371          Right hand         90078       1137
## 7         Ron Weasley      12372                Body         90079       1137
## 8  Tom Marvolo Riddle      12373                Body         90080       1137
## 9   Hermione Grainger      12374                Body         90081       1137
## 10   Albus Dumbledore      12375                Body         90082       1137
```

```r
# add dataset with rows already contained in the table
dbWriteTable(conn = mp_db_conn,
             name = "staffdose",
             value = arf_rows10to12,
             append = TRUE)
```

```
## Error: UNIQUE constraint failed: staffdose.report_uid, staffdose.person_uid, staffdose.dosimeter_placement
```

Now you should get an error message like: 
`UNIQUE constraint failed: staffdose.report_uid, staffdose.person_uid, staffdose.dosimeter_placement`.  
<br>
We have achieved our goal to prevent duplicates but unfortunately there is no easy way to just add unique data with any of the functions of the packages `DBI` or `RSQLite`. To solve this problem we need a workaround. 

#### Adding only unique Data
For details and source of the following approach see the forum thread "[RStudio Community - Creating and populating a SQLite database via R - How to ignore duplicate rows?](https://community.rstudio.com/t/creating-and-populating-a-sqlite-database-via-r-how-to-ignore-duplicate-rows/85470/3)".

For the work around we will use a second table called `stage` with the same structure as `staffdose` but without any constraints. The table `stage` will therefore accept any data even if it already exists in `staffdose`. First we will read in the new data into the intermediary table `stage` and can then transfer only the new data 
to the table `staffdose` with the command `INSERT OR IGNORE INTO staffdose`:


```r
# we use "DROP TABLE IF EXISTS" in case we run the script more than once
dbExecute(conn = mp_db_conn, 
          statement = "DROP TABLE IF EXISTS stage")
```

```
## [1] 0
```

```r
# creating the stage table
dbExecute(conn = mp_db_conn,
          statement = 
            "CREATE TABLE stage (
                id INTEGER,
                customer_name VARCHAR,
                customer_uid INTEGER,
                department VARCHAR,
                department_uid INTEGER,
                name VARCHAR,
                person_uid INTEGER,
                radiation_type VARCHAR,
                hp10 DOUBLE,
                hp007 DOUBLE,
                user_type VARCHAR,
                dosimeter_type VARCHAR,
                dosimeter_placement VARCHAR,
                dosimeter_uid INTEGER,
                measurement_period_start TEXT,
                measurement_period_end TEXT,
                read_date TEXT,
                report_date TEXT,
                report_uid DOUBLE,
                status VARCHAR
            );")
```

```
## [1] 0
```

To make life a little bit easier in the future we will define a function `dbAppendUniqueStaffDose` that will read in new data into the `stage` table and then transfers only the unique data to the `staffdose` table:


```r
dbAppendUniqueStaffDose <- function(connection, newreportdata) {
  # function to add only unique data to the staffdose table
    # by using the stage table as intermediary
  
  # wiping clean stage table
  dbExecute(connection, "DELETE FROM stage")
  
  # add the new data to the stage table
  dbAppendTable(connection, "stage", newreportdata)
  
  # transfer only unique data from the stage table to the staffdose table
  dbExecute(connection, "INSERT OR IGNORE INTO staffdose SELECT * FROM stage")
}
```

Now we can add data successfully without getting an error message, even if it contains duplicates that violate the `UNIQUE`-constraint we defined:


```r
dbAppendUniqueStaffDose(connection = mp_db_conn,
                        newreportdata = arf_rows10to12)
```

```
## [1] 2
```

```r
# The output should be "##[1] 2" -> Two rows added (out of the 3 rows 2 were new data)


# Let's view the table:
check <- dbGetQuery(conn = mp_db_conn, 
                    statement = "SELECT name, person_uid, dosimeter_placement, dosimeter_uid, report_uid FROM staffdose"); check
```

```
##                  name person_uid dosimeter_placement dosimeter_uid report_uid
## 1       Severus Snape      12368                Body         90072       1137
## 2        Harry Potter      12369                Body         90073       1137
## 3       Parvati Patil      12370                Body         90075       1137
## 4       Parvati Patil      12370           Left hand         90076       1137
## 5      Cedric Diggory      12371                Body         90077       1137
## 6      Cedric Diggory      12371          Right hand         90078       1137
## 7         Ron Weasley      12372                Body         90079       1137
## 8  Tom Marvolo Riddle      12373                Body         90080       1137
## 9   Hermione Grainger      12374                Body         90081       1137
## 10   Albus Dumbledore      12375                Body         90082       1137
## 11    Filius Flitwick      12376                Body         90083       1137
## 12 Neville Longbottom      12377                Body         90084       1137
```

```r
# looks good

# Check if the data of the first 12 rows is really without duplicates
  # by comparing the table content with the data from the dataframe 
check == all_reports_fixed[1:12, 
                           c("name", "person_uid", "dosimeter_placement", "dosimeter_uid", "report_uid")]
```

```
##       name person_uid dosimeter_placement dosimeter_uid report_uid
##  [1,] TRUE       TRUE                TRUE          TRUE       TRUE
##  [2,] TRUE       TRUE                TRUE          TRUE       TRUE
##  [3,] TRUE       TRUE                TRUE          TRUE       TRUE
##  [4,] TRUE       TRUE                TRUE          TRUE       TRUE
##  [5,] TRUE       TRUE                TRUE          TRUE       TRUE
##  [6,] TRUE       TRUE                TRUE          TRUE       TRUE
##  [7,] TRUE       TRUE                TRUE          TRUE       TRUE
##  [8,] TRUE       TRUE                TRUE          TRUE       TRUE
##  [9,] TRUE       TRUE                TRUE          TRUE       TRUE
## [10,] TRUE       TRUE                TRUE          TRUE       TRUE
## [11,] TRUE       TRUE                TRUE          TRUE       TRUE
## [12,] TRUE       TRUE                TRUE          TRUE       TRUE
```

```r
# if we have only TRUEs we only added unuique data

# Let's add all the data to the staffdose table with the function we created
dbAppendUniqueStaffDose(connection = mp_db_conn, 
                        newreportdata = all_reports_fixed_dateastext)
```

```
## [1] 600
```

### Data Analysis with SQL and R

#### Hp(10) - Summary Statistics by Department and Year

```r
# Preparing the parameterized query
# params:
stat <- "OK"
dos_type <- "Badge"
year <- c(2020,2021)

# query and graph
dbGetQuery(conn = mp_db_conn,
           statement = 
             "SELECT hp10, department, STRFTIME('%Y', measurement_period_end) AS report_year 
                FROM staffdose WHERE hp10>=0 
                AND status = ? AND dosimeter_type = ?
                AND report_year BETWEEN ? AND ?",
                params = c(stat, dos_type, year)) %>% 
  ggplot(aes(x=report_year, y=hp10)) +
  geom_boxplot() +
  scale_y_continuous(limits = c(0, NA), 
                      # set lower bound to 0 and let ggplot automatically set upper bound
                     breaks = pretty(c(0, max(all_reports_fixed$hp10, na.rm = T)), 
                                     n=10)) + 
                      # getting 10 breaks in the y-axis from 0 to maximum value of hp10
  labs(x = "", y = "Hp(10) [mSv]", # Axis names
       title = "Summary Statistics for monthly Hp(10) values",
       subtitle = "  by department and year",
       caption = "Hacking Medical Physics. Data and Idea: J. Andersson and G. Poludniowski") +
  # tweaking the plot style (optional) with the function "theme":
  theme(panel.background = element_blank(),
        panel.grid.major.y = element_line(linetype = 3, color = "gray"),
        panel.spacing.x = unit(1, "cm"),
        strip.text = element_text(face = "bold", color = "white"),
        strip.background = element_rect(fill = "#7395D1")) +
  facet_wrap(~ department) # split up the data into subplots for the different departments
```

![](db_R_tutorial_files/figure-html/sql_datana_sumstat-1.png)<!-- -->

#### Number of Staff Dose Readings per Dosimeter Type

```r
# params:
stat = "NR"

# query and print table
dbGetQuery(conn = mp_db_conn,
           statement = 
             "SELECT COUNT(hp10) AS hp10, COUNT(hp007) AS hp007, dosimeter_type  
              FROM staffdose 
              WHERE status != ?
              GROUP BY dosimeter_type",
              params = stat) %>% 
  relocate(dosimeter_type) %>% # setting dosimeter_type as first column
  kable(align = "lcc", # kable is a function to produce tables
        col.names = c("Dosimeter Type", "Hp(10)", "Hp(0.07)"), 
        caption = "Number of dosimeter readings per dosimeter type") %>% 
  kable_styling(bootstrap_options = c("striped", "hover")) # a function to further tweak tables
```

<table class="table table-striped table-hover" style="margin-left: auto; margin-right: auto;">
<caption>Number of dosimeter readings per dosimeter type</caption>
 <thead>
  <tr>
   <th style="text-align:left;"> Dosimeter Type </th>
   <th style="text-align:center;"> Hp(10) </th>
   <th style="text-align:center;"> Hp(0.07) </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Badge </td>
   <td style="text-align:center;"> 403 </td>
   <td style="text-align:center;"> 403 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Ring </td>
   <td style="text-align:center;"> 0 </td>
   <td style="text-align:center;"> 47 </td>
  </tr>
</tbody>
</table>

#### Individuals who did not return their Dosimeters

```r
# params:
stat = "NR"

# query and print table
dbGetQuery(conn = mp_db_conn,
           statement = 
             "SELECT name, COUNT(status) as instances
              FROM staffdose
              WHERE status = ?
              GROUP BY name
              ORDER BY instances DESC",
              params = stat) %>% 
  kable(align = "lc", # kable is a function to produce tables
        col.names = c("Name", "Instances"), 
        caption = "Number of times a dosimeter was not returned per person") %>% 
  kable_styling(bootstrap_options = c("striped", "hover")) # a function to further tweak tables
```

<table class="table table-striped table-hover" style="margin-left: auto; margin-right: auto;">
<caption>Number of times a dosimeter was not returned per person</caption>
 <thead>
  <tr>
   <th style="text-align:left;"> Name </th>
   <th style="text-align:center;"> Instances </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Tom Marvolo Riddle </td>
   <td style="text-align:center;"> 28 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Luna Lovegood </td>
   <td style="text-align:center;"> 14 </td>
  </tr>
</tbody>
</table>

#### Total badge HP(10) Staff Dose Readings per Department

```r
#params
stat = "OK"
year = 2020
dos_type = "Badge"

#query and graph
dbGetQuery(conn = mp_db_conn,
           statement = 
             "SELECT name, department, SUM(hp10) AS hp10_total, STRFTIME('%Y', measurement_period_end) AS report_year
              FROM staffdose
              WHERE hp10>0 AND report_year = ? AND status = ? AND dosimeter_type = ?
              GROUP BY name",
              params = c(year, stat, dos_type)) %>% 
  ggplot(aes(x=reorder(name, desc(hp10_total)), y=hp10_total, fill = department)) +
  geom_col() +
  scale_fill_manual(values = c("#6186B0", "#B06186", "#86B061")) +
  labs(x = "", y = "HP(10) [mSv]", fill = "",
       title = "Total Dose per Person for 2020",
       subtitle = "   Badge HP(10)") +
  coord_flip() +
  theme(legend.position = "bottom",
        panel.background = element_blank(),
        panel.grid.major.y = element_line(linetype = 3, color = "gray"))
```

![](db_R_tutorial_files/figure-html/sql_total_dose_2020-1.png)<!-- -->

### SQL Engine in R Markdown
As I will discuss in the next section, R Markdown is an incredible powerful tool. One of its cool features is its ability to ["speak" SQL](https://bookdown.org/yihui/R Markdown/language-engines.html#sql) and other languages. You can not only use R code chunks but others too. When using a SQL code chunk you don't need the `DBI`-functions, you can write native SQL queries.  
Here is an example of a SQL code chunk (note that it starts with `sql` instead of `r` and you have to provide a connection to a database):  

![Example of a SQL code chunk](figures/example_codechunk_sql.png)


```sql
-- comments can be added by starting the line with two minus signs
SELECT name, department, hp10 FROM staffdose WHERE hp10>=0 LIMIT 5
```


<div class="knitsql-table">
<table>
<caption>5 records</caption>
 <thead>
  <tr>
   <th style="text-align:left;"> name </th>
   <th style="text-align:left;"> department </th>
   <th style="text-align:right;"> hp10 </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Severus Snape </td>
   <td style="text-align:left;"> Nuclear Medicine </td>
   <td style="text-align:right;"> 0.09 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Cedric Diggory </td>
   <td style="text-align:left;"> Nuclear Medicine </td>
   <td style="text-align:right;"> 0.11 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Albus Dumbledore </td>
   <td style="text-align:left;"> Diagnostic Radiology </td>
   <td style="text-align:right;"> 0.08 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Filius Flitwick </td>
   <td style="text-align:left;"> Diagnostic Radiology </td>
   <td style="text-align:right;"> 0.11 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Neville Longbottom </td>
   <td style="text-align:left;"> Diagnostic Radiology </td>
   <td style="text-align:right;"> 0.13 </td>
  </tr>
</tbody>
</table>

</div>

### Closing the connection to the database
When we are finished we close the connection to the database:

```r
dbDisconnect(mp_db_conn)
```


## Reporting with R Markdown
R is one of the most important statistics software solutions out there and together with RStudio and its integration of [R Markdown](https://R Markdown.rstudio.com/) it is an incredible versatile tool for data analysis and reporting. The tutorial you are reading is compiled from a R Markdown file.  
<br>
From the [R Markdown website](https://R Markdown.rstudio.com/):

> R Markdown supports dozens of static and dynamic output formats including HTML, PDF, MS Word, Beamer, HTML5 slides, Tufte-style handouts, books, dashboards, shiny applications, scientific articles, websites, and more ([see gallery](https://R Markdown.rstudio.com/gallery.html)). 

You might have to write reports for your department, your hospital, the authorities, ... where you have to present data. With [knitr](https://yihui.org/knitr/) you can convert your R Markdown file into a Word document and even use word-templates you create or your organization provides for you. With an additional Latex-Installation like [TinyTeX](https://yihui.org/tinytex/) you can create pdf-documents and there are many more options.  
<br>

The easiest way to start is to create a report as html-file that you can then print to pdf with your browser. Check out the `sample_report.Rmd`-file for an example. I also included a parameterization for departments and years in the YAML-header. With that parameterization you can create reports for each department and year from one R Markdown file. More on parameterized reports: [R Markdown: The Definitive Guide - Chapter 15](https://bookdown.org/yihui/RMarkdown/parameterized-reports.html). 


## Bonus

### Extended Function for reading in Data to the Table staffdose


```r
mp_db_conn <- dbConnect(drv = RSQLite::SQLite(),
                        dbname = "medical_physics_db.sqlite")

dbAppendUniqueDataToStaffdose_Ext <- function(path_data = "reports", 
                                              file_name_beginning = "StaffDose") {
  # function to add unique data to table "staffdose" in "medical_physics_db.sqlite"
  
  # checking and fixing arguments
  
  # checking file path
  path_data <- as.character(path_data)
  if(!dir.exists(path_data)==TRUE) stop(paste0("Directory ", path_data, " does not exist -> data import not possible"))
  
  file_name_beginning <- as.character(file_name_beginning)
  if(length(list.files(path = path_data, pattern = ".xls$")) == 0) stop("No xls-files in given folder")
  
  # opening connection to an exising database
    # error if database does not exist
  con <- dbConnect(drv = RSQLite::SQLite(), 
                   dbname = "medical_physics_db.sqlite",
                   flags = SQLITE_RW)

  # reading in all xls-files that start with "StaffDose"
  file_list_reports <- list.files(path = path_data,
                                  pattern = file_name_beginning)
  # stop if no files in file path or expression not matching
  if(length(file_list_reports) == 0) stop(paste0("Files in folder do not match \'", file_name_beginning, "\'"))

  # create an empty dataframe
  all_reps <- data.frame() 

  for (i in 1:length(file_list_reports)) { # a for-loop to read in all reports
    # reading in the i-th report into variable "rep":
    rep_loop <- read_xls(path = paste0(path_data, "/", file_list_reports[i])) 
    all_reps <- rbind(all_reps, rep_loop) # binding together the reports rowwise
  }  
  colnames(all_reps) <- dbListFields(conn = con,
                                     name = "staffdose")[-1]
  
  # getting locale
  loc <- Sys.getlocale("LC_TIME") # storing the machine locale setting for time and dates in variable "loc"
  Sys.setlocale("LC_TIME", locale = "English") # setting the machine locale for time and dates to "English"

  all_reps_fixed <- all_reps %>% 
  mutate(hp10 = str_replace_all(hp10, 
                                pattern = ",", 
                                replacement = ".")) %>% 
  mutate(hp007 = str_replace_all(hp007, 
                                 pattern = ",", 
                                 replacement = ".")) %>% 
  mutate(status = case_when(hp007 == "B" ~ "B",
                            hp007 == "NR" ~ "NR",
                            is.na(hp007) ~ NA_character_,
                            is.numeric(as.numeric(hp007)) ~ "OK")) %>% 
  mutate(across(c(customer_uid, department_uid, person_uid, hp10, hp007, dosimeter_uid, report_uid), 
                as.numeric)) %>% 
  mutate(across(c(measurement_period_start:report_date), 
                as.Date, 
                format = "%d-%b-%Y")) %>% 
  group_by(person_uid, dosimeter_uid) %>% 
  distinct(report_uid, .keep_all = TRUE) %>%
  ungroup()

  Sys.setlocale("LC_TIME", locale = loc) # setting back the locale 
  
  # wiping clean stage table
  dbExecute(con, "DELETE FROM stage")
  
  # add the new data to the stage table
  dbAppendTable(con, "stage", all_reps_fixed)
  
  # transfer only unique data from the stage table to the staffdose table
  dbExecute(con, "INSERT OR IGNORE INTO staffdose SELECT * FROM stage")
  
  # wiping clean stage table
  dbExecute(con, "DELETE FROM stage")

  # terminating connection
  dbDisconnect(conn = con)
  
# add messages for
  # read in files
  # successfully added data -> how to check?! (compare db content to data)
  
  # copy imported files to "imported folder"
 # or move files: https://r-lang.com/how-to-move-files-in-r/
  
}

dbAppendUniqueDataToStaffdose_Ext(path_data = "test")
dbAppendUniqueDataToStaffdose_Ext(file_name_beginning = "test")
dbAppendUniqueDataToStaffdose_Ext()

dbGetQuery(mp_db_conn, "SELECT * FROM staffdose")
dbExecute(mp_db_conn, "DELETE FROM staffdose")

dbDisconnect(conn = mp_db_conn)
```
