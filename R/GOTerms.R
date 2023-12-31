setClass("GOTerms",
    representation(
        GOID="character",       # a single string (mono-valued)
        Term="character",       # a single string (mono-valued)
        Ontology="character",   # a single string (mono-valued)
        Definition="character", # a single string (mono-valued)
        Synonym="character",    # any length including 0 (multi-valued)
        Secondary="character"   # any length including 0 (multi-valued)
    )
)

### The mono-valued slots are also the mandatory slots.
.GONODE_MONOVALUED_SLOTS <- c("GOID", "Term", "Ontology", "Definition")


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Initialization.
###

setMethod("initialize", "GOTerms",
    function(.Object, ...)
    {
        args <- list(...)
        argnames <- names(args)
        if (is.null(argnames) || any(argnames == ""))
            stop("all arguments must be named")
        argnames <- match.arg(argnames, slotNames(.Object), several.ok=TRUE)
        if (!(all(.GONODE_MONOVALUED_SLOTS %in% argnames))) {
            s <- paste(.GONODE_MONOVALUED_SLOTS, collapse=", ")
            stop("arguments ", s, " are mandatory")
        }
        for (i in seq_len(length(args))) {
            argname <- argnames[i]
            value <- args[[i]]
            if ((argname %in% .GONODE_MONOVALUED_SLOTS)) {
                if (length(value) != 1)
                    stop("can't assign ", length(value),
                         " values to mono-valued slot ", argname)
            } else {
                value <- value[!(value %in% c(NA, ""))]
            }
            slot(.Object, argname) <- value
        }
        .Object
    }
)

GOTerms <- function(GOId, term, ontology, synonym = "", secondary = "",
                    definition = ""){
    return(new("GOTerms", GOID = GOId, Term = term,
               Synonym = synonym, Secondary = secondary,
               Definition = definition, Ontology = ontology))
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### The "GOID", "Term", "Ontology", "Definition", "Synonym" and "Secondary" 
### generics (accessor methods).
###


setMethod("GOID", "GOTerms", function(object) object@GOID)

setMethod("Term", "GOTerms", function(object) object@Term)

setMethod("Ontology", "GOTerms", function(object) object@Ontology)

setMethod("Definition", "GOTerms", function(object) object@Definition)

setMethod("Synonym", "GOTerms", function(object) object@Synonym)

setMethod("Secondary", "GOTerms", function(object) object@Secondary)


##.GOid2go_termField() retrieves ids of type field from go_term
.GOid2go_termField <- function(ids, field){
##     message(cat("Before SQL \n")) ##test
    sql <- sprintf("SELECT go_id, %s
                    FROM go_term
                    WHERE go_id IN ('%s')",
                   field,
                   paste(ids, collapse="','"))
    res <- dbGetQuery(GO.db::GO_dbconn(), sql)
    if(dim(res)[1]==0 && dim(res)[2]==0){
        stop("None of your IDs match IDs from GO.  Are you sure you have valid IDs?")
    }else{
        ans <- res[[2]]
        names(ans) <- res[[1]]
        return(ans[ids]) ##This only works because each GO ID is unique (and therefore a decent index ID)
    }
}

setMethod("GOID", "GOTermsAnnDbBimap",function(object) .GOid2go_termField(keys(object),"go_id") )
setMethod("GOID", "character",function(object) .GOid2go_termField(object,"go_id") )

setMethod("Term", "GOTermsAnnDbBimap",function(object) .GOid2go_termField(keys(object),"term") )
setMethod("Term", "character",function(object) .GOid2go_termField(object,"term") )

setMethod("Ontology", "GOTermsAnnDbBimap",function(object) .GOid2go_termField(keys(object),"ontology") )
setMethod("Ontology", "character",function(object) .GOid2go_termField(object,"ontology") )

setMethod("Definition", "GOTermsAnnDbBimap",function(object) .GOid2go_termField(keys(object),"definition") )
setMethod("Definition", "character",function(object) .GOid2go_termField(object,"definition") )


##.GOid2go_synonymField() retrieves ids of type field from go_synonym
.GOid2go_synonymField <- function(ids, field){
    sql <- paste0("SELECT gt.go_id, gs.",field,"
                  FROM go_term AS gt, go_synonym AS gs
                  WHERE gt._id=gs._id AND go_id IN ('",paste(ids, collapse="','"),"')")
    res <- dbGetQuery(GO.db::GO_dbconn(), sql)
    if(dim(res)[1]==0 && dim(res)[2]==0){
        stop("None of your IDs match IDs from GO.  Are you sure you have valid IDs?")
    }else{
        ans = split(res[,2],res[,1])
        return(ans[ids])##once again (this time in list context), we are indexing with unique IDs.
    }
}

setMethod("Synonym", "GOTermsAnnDbBimap",function(object) .GOid2go_synonymField(keys(object),"synonym") )
setMethod("Synonym", "character",function(object) .GOid2go_synonymField(object,"synonym") )

setMethod("Secondary", "GOTermsAnnDbBimap",function(object) .GOid2go_synonymField(keys(object),"secondary") )
setMethod("Secondary", "character",function(object) .GOid2go_synonymField(object,"secondary") )




### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### The "show" methods.
###

setMethod("show", "GOTerms",
    function(object)
    {
        s <- character(0)
        for (slotname in slotNames(object)) {
            x <- slot(object, slotname)
            if ((slotname %in% .GONODE_MONOVALUED_SLOTS) && length(x) != 1) {
                warning("mono-valued slot ", slotname,
                        " contains ", length(x), " values")
            } else {
                if (length(x) == 0)
                    next
            }
            s <- c(s, paste0(slotname, ": ", x))
        }
        cat(strwrap(s, exdent=4), sep="\n")
    }
)



### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### The methods to construct a GOFrame or a GOAllFrame
###

.attachGO <- function(con){
  requireNamespace("GO.db")
  GOLoc = system.file("extdata", "GO.sqlite", package="GO.db")
  attachSQL = paste0("ATTACH '", GOLoc, "' AS go;")
  dbAttach(con, attachSQL)
}


.testGOFrame <- function(x, organism=""){
  drv <- dbDriver("SQLite")
  con <- dbConnect(drv)
  ##Test that some GOIDs are real and that the evidence codes are legit.
  .attachGO(con)
  GOIDs = x[,1]
  eviCodes = x[,2]
  realGOIDs = as.character(dbGetQuery(con, "SELECT go_id FROM go_term;")[,1])
  ##Test that the data.frame has some rows of data in it
  if(!dim(x)[1]>0){
    stop("There are no rows of data in the data.frame supplied to make a GOFrame.")
  }
  ## TODO, Add evidence codes to GO.sqlite so that we can test this properly
  ## without any hard coding

  realEviCodes = c(
      "EXP", "IDA", "IPI", "IMP", "IGI", "IEP",
      "HTP", "HDA", "HMP", "HGI", "HEP",
      "ISS", "ISO", "ISA", "ISM", "IGC", "IBA", "IBD", "IKR", "IRD", "RCA",
      "TAS", "NAS",
      "IC", "ND",
      "IEA"
  )


  if(is.na(table(GOIDs %in% realGOIDs)["TRUE"])){
    stop("None of elements in the 1st column of your data.frame object are legitimate GO IDs.")
  }

  if (any(bad <- !eviCodes %in% realEviCodes)) {
      msg <- sprintf("invalid GO Evidence codes: '%s'",
                     paste(unique(eviCodes[bad]), collapse="' '"))
      stop(msg)
  }
  if(length(x[,1]) != length(x[,2]) || length(x[,1]) != length(x[,3])){
    stop("You need to have evidence codes and genes for all your GO IDs.")
  }
   if(organism!=""){
    new("GOFrame", data = x, organism = organism)
   }else{new("GOFrame", data = x)}
}

setMethod("GOFrame", signature=signature(x="data.frame", organism="character"), function(x, organism){.testGOFrame(x, organism)})
setMethod("GOFrame", signature=signature(x="data.frame", organism="missing"), function(x){.testGOFrame(x)})


## Helper method for converting GOFrame type data.frames into GOAllFrame objects
.convertGOtoGO2ALL = function(frame, type = c("BP","CC","MF")){
  drv <- dbDriver("SQLite")
  con <- dbConnect(drv)
  ##require type to be legit
  type <- match.arg(type)
    
  ##Now Make a table
  dbExecute(con, "CREATE TABLE data (go_id VARCHAR(10), evidence VARCHAR(3), gene_id INTEGER)")
  ##populate it with the stuff in frame:
  clnVals = frame
  sqlIns <- "INSERT INTO data (go_id, evidence, gene_id) VALUES (?,?,?)"
  dbBegin(con)
  res <- dbSendQuery(con,sqlIns, params=unclass(unname(clnVals)))
  dbClearResult(res)
  dbCommit(con)  
  
  ##Now I have to make a 'go_data' table from 'data' that to INSURE that all
  ##the GO IDs are also in GO.db...
  .attachGO(con)  
  go_dataSQL = paste0(  "CREATE TABLE go_data as
    SELECT t.go_id AS go_id, g.evidence as evidence, g.gene_id AS gene_id
    FROM data AS g, go.go_term AS t
    WHERE g.go_id=t.go_id AND t.ontology='",toupper(type),"'")
  dbExecute(con,go_dataSQL)
  dbExecute(con,"CREATE INDEX gdgo on go_data(go_id)")

  ##Now I have to make the literal table from GO
  offspringSQL <- paste0("CREATE TABLE go_offspring_literal as
      SELECT t1.go_id AS go_id, t2.go_id AS offspring_id
      FROM   go.go_",tolower(type),"_offspring as o, go.go_term as t1, go.go_term as t2 
      WHERE  o._id = t1._id AND o._offspring_id = t2._id")
  dbExecute(con, offspringSQL)
  dbExecute(con,"CREATE INDEX literalo on go_offspring_literal(offspring_id)")
  dbExecute(con,"CREATE INDEX literalgo on go_offspring_literal(go_id)")

  ##Now I need to make the final table:
  finalSQL = paste0("CREATE TABLE go_all_data as
   SELECT t.go_id as go_id, g.evidence AS evidence,
           g.gene_id as gene_id
   FROM   go_data as g CROSS JOIN               
           go_offspring_literal as o CROSS JOIN
           go.go_term as t
   WHERE  o.go_id=t.go_id and o.offspring_id=g.go_id and  
           t.ontology='",toupper(type),"'
  UNION
   SELECT go_id, evidence, gene_id
   FROM   go_data")
  dbExecute(con,finalSQL)
  ##And return
  res =  dbGetQuery(con, "SELECT * FROM go_all_data")
  dbDisconnect(con)
  return(res)
}


## Method to make GOAllFrame objects from GOFrame objects
setMethod("GOAllFrame", "GOFrame", function(x){
  bp = .convertGOtoGO2ALL(x@data,"BP")
  mf = .convertGOtoGO2ALL(x@data,"MF")
  cc = .convertGOtoGO2ALL(x@data,"CC")
  res =  rbind(bp,mf,cc)
  new("GOAllFrame", data = res, organism = x@organism) 
})


## Method to access the data in a GOFrame object
setMethod("getGOFrameData", "GOFrame", function(x){x@data})
setMethod("getGOFrameData", "GOAllFrame", function(x){x@data})







### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Methods to construct a KEGGFrame
###

.testKEGGFrame <- function(x, organism=""){
    ##Test that some KEGGIDs are real and that the evidence codes are legit.
    KEGGIDs <- x[,1]
    kegg_query <- data.frame(keggList("pathway"))
    ids <- rownames(kegg_query)
    realKEGGIDs <- substr(ids, 4, nchar(ids))

    ##Test that the data.frame has some rows of data in it
    if(!dim(x)[1]>0){
      stop("There are no rows of data in the data.frame supplied to make a KEGGFrame.")
    }
    if(!any(KEGGIDs %in% realKEGGIDs)){
      stop("None of elements in the 1st column of your data.frame object are legitimate KEGG IDs.")
    }
    if(length(x[,1]) != length(x[,2])){ ## TODO, I don't think that this is going to test this effectively...  I probbaly need a different test.
      stop("You need to have genes for all your KEGG IDs.")
    }
    if(organism!=""){
    new("KEGGFrame", data = x, organism = organism)
    }else{new("KEGGFrame", data = x)}
}

setMethod("KEGGFrame", c(x="data.frame", organism="character"), .testKEGGFrame)
setMethod("KEGGFrame", c(x="data.frame", organism="missing"), .testKEGGFrame)

## Method to access the data in a KEGGFrame object
setMethod("getKEGGFrameData", "KEGGFrame", function(x){x@data})

organismKEGGFrame <- function() {
    org <- data.frame(keggList("organism")[,c("species", "organism")])
    org$species <- gsub("\\s*\\([^\\)]+\\)", "", org$species)
    org
}

#######################################################################
## Now add a convenience method to just represent the GO as a graph.
## This method should take arg for which ontology the user wants, and
## return a graph.
## users who want less can just use subgraph.
## weight of graph edges will always be 1 for each edge

makeGOGraph <- function(ont = c("bp","mf","cc")){
    match.arg(ont)
    df <- switch(ont,
                 "bp"= toTable(GO.db::GOBPPARENTS),
                 "mf"= toTable(GO.db::GOMFPARENTS),
                 "cc"= toTable(GO.db::GOCCPARENTS)
                 )
    graph::ftM2graphNEL(as.matrix(df[, 1:2]), W=rep(1,dim(df)[1])) 
}

## f = makeGOGraph("bp")
