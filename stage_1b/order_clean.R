#----------------------------------------------------------------------------#

# Purpose:     Clear up and format generated master order file
# Author:      CM
# Date:        Nov 2016
# Language:    R (.R)

#----------------------------------------------------------------------------#

#----------------------------------------------------------------------------#
#                               Control Section                              #
#----------------------------------------------------------------------------#

# set-up
#-------------------------------------------------#
print(Sys.time())
current_date <- as.character(format(Sys.time(), "%d/%m/%Y")) 
start_time <- Sys.time()

# command line arguments
#-------------------------------------------------#
init_path                <- commandArgs(trailingOnly = TRUE)[1]
mod_order_path           <- commandArgs(trailingOnly = TRUE)[2]
helper_path_keyword      <- commandArgs(trailingOnly = TRUE)[3]
execution_id             <- commandArgs(trailingOnly = TRUE)[4]
log_path                 <- commandArgs(trailingOnly = TRUE)[5]
temp_path                <- commandArgs(trailingOnly = TRUE)[6]
archive_path             <- commandArgs(trailingOnly = TRUE)[7]
print(execution_id)

# dependencies
#-------------------------------------------------#
source(paste0(init_path, "/R_init.R"))

# parameters / helpers
#-------------------------------------------------#

# import the keyword file
key_word     <- as.data.table(read.xlsx(helper_path_keyword, 1 , 
    stringsAsFactors=F, header=T,startRow=1))
key_word[get(names(key_word[,c(1), with=F]))=="END", TYPE:="END"]
key_word[, TYPE:=na.locf(TYPE)]

# generate regx patterns - product type
temp_key     <- unique(key_word[TYPE=="Temperature" & !(is.na(Keyword)) & 
    Keyword %like% "[^ ]" ]$Keyword)
pressure_key <- unique(key_word[TYPE=="Pressure" & !(is.na(Keyword)) & 
    Keyword %like% "[^ ]" ]$Keyword)
zubehoer_key <- unique(key_word[TYPE=="Zubehoer" & !(is.na(Keyword)) & 
    Keyword %like% "[^ ]" ]$Keyword)

product_type_list <- c("temp_key", "pressure_key", "zubehoer_key")

for (i in product_type_list) {

    temp <- get(i)
    temp <- gsub("^[ ]*|[ ]*$", "", temp)
    temp <- gsub(" ", "", temp)
    temp <- gsub("-", "", temp)
    temp <- tolower(temp)
    temp <- paste0(temp, collapse="|")

    assign(i, temp)

}


#----------------------------------------------------------------------------#
#                                    Code                                    #
#----------------------------------------------------------------------------#

# obtain file list 
#----------------------------------------------------------------------------#
file_list  <- list.files(mod_order_path)
file_list  <- file_list[file_list %like% "txt"]
file_count <- length(file_list)
file_id    <- 1
start_id   <- 1

output_id <- 1
output_id_max <- 25

# iterate over files
#----------------------------------------------------------------------------#

lapply(file_list[start_id:length(file_list)], function(file_name) {

    print(sprintf("parse order: %d out of %d (file: %d)", file_id, file_count, output_id))
    print(file_name)

    file_name_pdf <- gsub("txt$", "pdf", file_name)
    print(file_name_pdf)

    # import text & identify products
    #-----------------------------------------#
    text <- readLines(paste0(mod_order_path, "/",file_name))
    text <- data.table(text_line=text)

    # identify project name
    #-----------------------------------------#
    project_raw <- ""
    text[, project_ext_ext:=project_raw]
    text[, project_ext:=project_raw]
    text[, project:=project_raw]

    if (nrow( text[text_line %like% "Projekt|LV|BV|Objekt"])>0) {
        project_raw <- text[text_line %like% "Projekt|LV|BV|Objekt"]
        project_raw <- project_raw[which.max(nchar(project_raw$text_line))]$text_line
        project_raw <- gsub("(Projekt|LV|BV|Objekt)(.*)", "\\2", project_raw)
        project_raw <- gsub("Sachbearbeiter|Datum", "", project_raw)
        project_raw <- gsub("[ ]{2,}", " ", project_raw)
        project_raw <- gsub(" |-|/|,|:|%|'|,|\\|=|„|\\?|\\\f|ä|ö|ü|@|\\]|\\[|\\$", "_",project_raw)
        project_raw <- gsub("\\.", "", project_raw)
        project_raw <- gsub("^_|_{2,}|_$", "", project_raw)
        if (nchar(project_raw)>0)  text[, project_ext:=paste0(project_raw)]
    } 

    header_alt <- paste0(text[text_line!=""][1:20]$text_line, collapse=" ")
    header_alt <- strsplit(header_alt,"Menge|Preis|EP|GP|preis|Position|Text|Einheit|Pos\\.|OZ", 
                    perl=TRUE)[[1]][1]
    header_alt <- gsub("(Projekt|LV|BV|Objekt|Leistungsverzeichnis|Leistungspositionen|Aufstellung)(.*)", "\\2", header_alt)
    header_alt <- gsub("Sachbearbeiter|Datum", "", header_alt)
    header_alt <- gsub("[ ]{2,}", " ", header_alt)
    header_alt <- gsub(" |-|/|,|:|%|'|,|\\|=|„\\?|\\\f|ä|ö|ü|@|\\]|\\[|\\$", "_",header_alt)
    header_alt <- gsub("\\.", "", header_alt)
    header_alt <- gsub("^_|_{2,}|_$", "", header_alt)
    header_alt <- substring(header_alt, 1, 150)
    if (nchar(header_alt)>0)  text[, project_ext_ext:=paste0(header_alt)]

    print(project_raw)
    print(header_alt)

    # generate shortened version
    project_raw_short <- paste0("_", substring(project_raw, 1, min(15, nchar(project_raw))))
    if (nchar(project_raw_short)>1)  text[, project:=project_raw_short]

    # identify product breaks
    #-----------------------------------------#
    text[,item:=""]
    text[which(text_line %like% "^[ ]*#"), item:=1:length(which(text_line %like% "^[ ]*#"))]
    text[, item:=as.integer(item)]

    if (is.na(text[1]$item)) text[1, item:=0]
    text[, item:=na.locf(item)]
    text <- text[!(item==0)]

    if (nrow(text)>0 && nrow(text[!(text_line %like% "^#")])>0) {

    # clean 
    #-----------------------------------------#
    text[,text_line_mod:=""]
    text[!(text_line %like% "^[ ]*#"), text_line_mod:=gsub("(.*)([ ]{15,})([a-zA-Z*]{1,}.*)", 
        "\\3", text_line), by=.I]
    text[(text_line %like% "^[ ]*#"), text_line_mod:=gsub("(#order-item: [0-9]*)(.*)", 
        "\\1", text_line), by=.I]

    print(head(text))

    text[, text_line_mod:=gsub("^[ ]*", "", text_line_mod), 
        by=1:nrow(text)]
    text[, text_line_mod:=gsub("[ ]*$", "", text_line_mod), 
        by=1:nrow(text)]
    text[, text_line_mod:=gsub("((Stck|Stk|St)( )[0-9]*)(.*)", "\\1", text_line_mod), 
        by=1:nrow(text)]

    # process
    #-----------------------------------------#

    # record origin file
    text[, origin_file_name:=gsub("\\.txt", "", file_name)]

    # record date
    text[, date_processed:=current_date]

    # clean
    text[!(text_line_mod %like% "[a-zA-Z]{3,}") & !(text_line_mod %like% "(Stck|Stk|St)( |$)"), 
        text_line_mod:=""]
    text <- text[!(text_line_mod=="")]

    text <- text[!(text_line_mod %like% "Seite|Datum|Ubertrag|Projekt|@|Mail|Fax|Tel|GmbH|Str\\.")]
    text[,text_line_mod:=gsub("[\\* ]*Eventualposition", "", text_line_mod),by=1:nrow(text)]
    text[,text_line_mod:=gsub("(,|\\.|\\\")$", "", text_line_mod), by=1:nrow(text)]
    text[,text_line_mod:=gsub("^[ ]*|[ ]*$", "", text_line_mod), by=1:nrow(text)]

    # location clean
    location_header <- c("Karlsruhe|Datum|Seite")
    location_header_pattern <- gsub("\\|$", "", paste0(location_header, sep="|"))
    text <- text[!(text_line_mod %like% location_header_pattern)]


    # identify product count
    text[, piece_count:="/"]
    if (nrow(text[text_line_mod %like% "(Stck|Stk|St)( |$)"])>0) {
        text[text_line_mod %like% "(Stck|Stk|St)( |$)", 
            c("piece_count"):=gsub("[^0-9,]","", text_line_mod), by=.I]
        text[, c("piece_count"):=paste0(get("piece_count")[!(get("piece_count")=="/")], 
          collapse=" --- "), by=c("item")]
    } 

    # clean extended
    text <- text[!(text_line_mod %like% "(Stck|Stk|St)( |$)")]
    text[, text_line_mod:=gsub("Übertrag:", "",text_line_mod )]

    # collapse
    #-----------------------------------------#
    text[, prod_desc:=paste0(text_line_mod[!(text_line_mod %like% "^[ ]*#")], 
        collapse="\n"), by=c("item")]
    text[, c("hist_id_1","hist_price_1", 
        "hist_id_2", "hist_price_2", "hist_id_3","hist_price_3"):=""]
    dt_final <- text[, .(date_processed, prod_desc, hist_id_1, hist_price_1, 
        hist_id_2, hist_price_2, hist_id_3,hist_price_3,
        origin_file_name, project, item, piece_count, project_ext, project_ext_ext)]
    dt_final <- unique(dt_final, by=c("item"))
    setnames(dt_final, c("date_processed", "prod_desc", 
        "historical product ID #1", "historical price #1", 
        "historical product ID #2", "historical price #2",
        "historical product ID #3","historical price #3",
        "source order file name","project","source order-item number", 
        "piece count", "project name", "project name ext"))

    # clean
    dt_final[, prod_desc:=gsub("\n$", "",prod_desc )]
    dt_final[, prod_desc:=gsub("[\n]{2,}", "\n",prod_desc )]
    

    # identify product type 
    #-----------------------------------------#
    dt_final[, product_type:=""]

    dt_final[, prod_desc_temp:=tolower(prod_desc)]
    dt_final[, prod_desc_temp:=gsub(" ","", prod_desc_temp), by=1:nrow(dt_final)]
    dt_final[, prod_desc_temp:=gsub("-","", prod_desc_temp), by=1:nrow(dt_final)]

    print(dt_final)
    dt_final[!is.na(get("historical product ID #1")) & prod_desc_temp %like% temp_key, 
        product_type:="temperature "]
    dt_final[!is.na(get("historical product ID #1")) & prod_desc_temp %like% pressure_key, 
        product_type:=paste0(product_type, "pressure ")]
    dt_final[!is.na(get("historical product ID #1")) & prod_desc_temp %like% zubehoer_key, 
        product_type:=paste0(product_type, "zubehoer ")]

    dt_final[,prod_desc_temp:=NULL]

    # identify item ID (internal)
    #-----------------------------------------#
    dt_final[, c("item number"):=gsub("(^[0-9\\.]*) (.*)", "\\1", get("prod_desc")), 
        by=1:nrow(dt_final)]
    dt_final[get("item number") %like% "[a-zA-Z]", c("item number"):="/"]

    # subset to identified products
    #-----------------------------------------#
    dt_final <- dt_final[product_type!=""]


    # output
    #-----------------------------------------#
    print(dt_final)

    dt_final_identified <- dt_final
    dt_final_identified[, master_product_id:=0]

    output_file   <- paste0(temp_path, "/", "order_master_",
        execution_id,".csv")
    
    if (file.exists (gsub("\\.csv", paste0("_identified_", output_id, ".csv"), 
        output_file))) {

        dt_final_identified_orig      <- as.data.table(read.csv(gsub("\\.csv", 
                paste0("_identified_", output_id, ".csv"), output_file), 
                stringsAsFactors=F, check.names=FALSE))

        dt_final_identified <- rbindlist(list(dt_final_identified_orig, 
            dt_final_identified), use.names=T,fill=T)

    }

    # generate master product id
    dt_final_identified[,master_product_id:=1:nrow(dt_final_identified)]
    setcolorder(dt_final_identified, c("master_product_id", setdiff(names(
        dt_final_identified), "master_product_id")))

    set_na_zero(dt_final_identified, "  ")
    write.csv(dt_final_identified, gsub("\\.csv", paste0("_identified_", 
        output_id, ".csv"), output_file), row.names=FALSE, quote=TRUE)
    }

    file_id <<- file_id + 1

    if ((file_id - ((output_id-1)*output_id_max)) > output_id_max) {
        output_id <<- output_id + 1
    }

    # rename original pdf
    file_name_pdf_updated <- gsub("\\.pdf$", paste0(project_raw_short, ".pdf"), 
        file_name_pdf)
    file_name_text_updated <- gsub("\\.txt$", paste0(project_raw_short, ".txt"), 
        file_name)


    if (nrow(dt_final)>0) {

     file_name_pdf_updated_KEYWORD  <- gsub("\\.pdf$", "_KEYWORD.pdf", file_name_pdf_updated)
     file_name_text_updated_KEYWORD <- gsub("\\.txt$", "_KEYWORD.txt", file_name_text_updated)

     file.rename(paste0(mod_order_path, "/",file_name_pdf),
        paste0(mod_order_path, "/",file_name_pdf_updated_KEYWORD))
     file.rename(paste0(mod_order_path, "/",file_name),
        paste0(mod_order_path, "/",file_name_text_updated_KEYWORD))

   } else {

     file.rename(paste0(mod_order_path, "/",file_name_pdf),
        paste0(mod_order_path, "/",file_name_pdf_updated))
     file.rename(paste0(mod_order_path, "/",file_name),
        paste0(mod_order_path, "/",file_name_text_updated))

   }

})


# combine the generated csv files
# -------------------------------------

# file list
file_list_update <- list.files(temp_path)[ list.files(temp_path) %like% "csv"]
file_list_update <- file_list_update[file_list_update %like% execution_id & 
    file_list_update %like% "order_master"]
file_count_final <- length(file_list_update)

# settings
file_id       <- 1
start_id      <- 1
output_id     <- 1
output_id_max <- 8

# import email master (to be merged in)
email_file <- fread(paste0(temp_path, "/", "order_email_master_", 
    execution_id, ".csv"), header=FALSE)
email_file[, name_temp:=gsub("(.*_)(RAW)(.*)", "\\2\\3", V1), by=1:nrow(email_file)]
email_file[V2 %like% "Content", V2:=""]
email_file[, V2:=gsub("</a>", "", V2)]
email_file[, V2:=gsub("<wbr class.*>", "", V2)]
email_file[, V2:=gsub("<<|>>| |:|\\[|\\]", "", V2)]

# loop over files
for (i in seq(1:ceiling(file_count_final/output_id_max))) {

    min_file <- (i-1)*output_id_max+1
    max_file <- min(min_file+output_id_max-1,file_count_final )

    temp <- lapply(min_file:max_file, function(x) as.data.table(read.csv(paste0(
        temp_path, "/", file_list_update[x]), 
        stringsAsFactors=F, check.names=FALSE)))
    temp_comb <- as.data.table(rbindlist(temp))
    temp_comb[, master_order_id:=as.integer(gsub("(^[0-9]*)(_.*)", "\\1", 
        get("source order file name"))),  by=1:nrow(temp_comb)]
    temp_comb[, master_product_id:=NULL]
    temp_comb[, master_id:=paste0(master_order_id, "_",  
        get("source order-item number")),  by=1:nrow(temp_comb)]

    # merge in email master
    temp_comb[, name_temp:=paste0(get("source order file name"), ".pdf"), by=1:nrow(temp_comb)]
    temp_comb[, name_temp:=gsub("(.*_)(RAW_)(.*)", "\\2\\3", name_temp),  by=1:nrow(temp_comb)]
    temp_comb <- email_file[, .(name_temp, V2)][temp_comb, on=c(name_temp="name_temp"), nomatch=NA]
    temp_comb[, name_temp:=NULL]
    setnames(temp_comb, "V2", "source_email")

    # format
    temp_comb[, execution_id:=gsub("(.*)(RAW_)(.*)($)", "\\3", 
        get("source order file name")), by=1:nrow(temp_comb)]

    setcolorder(temp_comb, c("master_id", "master_order_id", 
        setdiff(names(temp_comb), c("source_email","master_id", 
        "master_order_id", "execution_id", "project name", "project name ext")), 
        "source_email", "project name","project name ext", "execution_id"))

    output_file <- paste0(mod_order_path, "/", "order_master_",
        execution_id,"_",i,".xlsx")

    # save 
    write.xlsx(x = temp_comb, file = output_file, 
        sheetName = "Master Record", 
        row.names = FALSE, append=TRUE)

}


# clear up files (delete/move to archive)
# ---------------------------

# delete temp files
temp_list <- list.files(temp_path)
inv_lapply(temp_list, function(x) file.rename(paste0(temp_path, "/", x), 
     paste0(archive_path, "/",  x)))

# move files to archive
move_list <- list.files(mod_order_path)
inv_lapply(move_list, function(x) file.rename(paste0(mod_order_path, "/", x), 
    paste0(archive_path, "/",  x)))


# log
# -------------------------
end_time <-  Sys.time()

for (log_file in c(paste0(log_path, "/stage_b_ii.txt"), 
    paste0(log_path, "/stage_b_ii_",execution_id, ".txt"))) {

    sink(log_file, append=TRUE)

    cat(sprintf("\n\n##################\n"))
    cat(sprintf("Execution ID: %s\n", execution_id))
    cat(sprintf("Date: %s\n", current_date))
    cat("\n\n")
    cat(sprintf("Number of PDFs: %d\n", file_count))
    cat(sprintf("Runtime (minutes): %f\n\n", round(as.numeric(end_time - start_time)/60, 1)))

    sink()
}

#----------------------------------------------------------------------------#
#                                    End                                     #
#----------------------------------------------------------------------------#
