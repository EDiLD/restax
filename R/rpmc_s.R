#' Remove Parent or Merge Child (RPMC) - One sample variant.
#' 
#' @param x list; An object of class wide_class as returned by 
#' \code{\link[restax]{get_hier}}. 
#' @param value.var character; Name of the column holding the abundances.
#' @return a list of class 'restax', with the following elements
#' \itemize{
#'  \item comm - resolved community data matrix in wide format.
#'  \item action - what was done with the taxon
#'  \item merged - is the taxon merged
#'  \item method - method to resolve taxa
#' }
#' @references Cuffney, T. F., Bilger, M. D. & Haigler, A. M. 
#' Ambiguous taxa: effects on the characterization and interpretation of 
#' invertebrate assemblages. 
#' Journal of the North American Benthological Society 26, 286-307 (2007).
#' @import plyr
#' @export
#' @examples
#' \dontrun{
#' data(samp)
#' # transpose data
#' df <- data.frame(t(samp), stringsAsFactors = FALSE)
#' df[ , 'taxon'] <- rownames(df)
#' df_w <- get_hier(df, taxa.var = 'taxon', db = 'itis')
#' rpmc_s(df_w, value.var = 'A')
#' }
rpmc_s <- function(x, value.var = NULL){
  if(class(x) != 'wide_class')
    stop("Need an object of class 'wide_class'!")
  if(is.null(value.var))
    stop("Must specify value.var!")
  comm <- x[['comm']]
  hier <- x[['hier']]
  taxa.var <- x[['taxa.var']]
  if(!value.var %in% names(comm))
    stop("value.var not found in data")
  if(any(is.na(comm[ , value.var])))
    stop("No NAs in value.var allowed!")
  
  # rm not indiff levels
  keep <- apply(hier, 2, function(x) any(is.na(x)))
  # keep last level
  keep[rle(keep)$lengths[1]] <- TRUE
  # keep taxon
  keep[taxa.var] <- TRUE
  hier <- hier[, keep]
  
  run <- rev(names(hier))
  run <- run[!run %in% taxa.var]
  
  commout <- comm
  action <- rep(NA, nrow(commout))
  merged <- data.frame(hier[taxa.var], with = NA)
  co <- data.frame()

  # loop through each parent-child pair
  for(i in seq_along(run)[-1]){
    p <- run[i]
    ch <- run[i-1]
    #     print(p)
    #     print(ch)
    
    # determine childs and parents
    mmm <- merge(hier, commout)  
    take <- mmm[!is.na(mmm[ , p]) , ]
    # take[ c(p, ch, value.var)]
    sna <- apply(take, 1, function(x) sum(is.na(x)))
    ptmp <- data.frame(take[p], sna, ord = 1:length(sna))
    
    ptmp <- ddply(ptmp, p, summarise, 
          parent = sna == max(sna),
          ord = ord
    )
    # restore orders
    ptmp <- ptmp[order(ptmp$ord), ]
    parents <- ptmp$parent & is.na(take[ , ch])
    childs <- !parents
    
    # add carry over
    if(nrow(co) > 0){
      if(any(take[ , taxa.var] %in% co[ , taxa.var])){
        take[take[ , taxa.var] %in% co[ , taxa.var], value.var] <- co[co[ , taxa.var] %in% take[ , taxa.var] , value.var]
      }
    }

    sum_c <- ddply(take[childs, ], p, 
                   .fun = function(x, col) {
                     sum_childs = sum(x[ , col])
                     data.frame(sum_childs)
                   }, 
                   value.var)
    # print(sum_c)
    sum_p <- take[parents, ]
    # compare child abundance with parent abundance
    mm <- merge(sum_p, sum_c)
    if(nrow(mm) == 0)
      next
    ##
    mm$do <- ifelse(mm[, value.var] < mm$sum_childs, 'removed', 'merge')
#     print(mm)
#     print(co)
    #   remove or merge
    for(k in 1:nrow(mm)){
      if(mm[k, 'do'] == 'removed'){
        commout[commout[ , taxa.var] == mm[k, p], value.var] <- 0
        action[commout[ , taxa.var] == mm[k, p]] <- 'removed'
      }
      if(mm[k, 'do'] == 'merge'){
        commout[hier[ , p] == mm[k, p] & !is.na(hier[ , p]), value.var] <- 0
        commout[comm[ , taxa.var] == mm[k, p], value.var] <- mm[k , value.var] + mm[k , "sum_childs"]
        action[hier[ , p] == mm[k, p] & !is.na(hier[ , p])] <- 'merge'
        merged[hier[ , p] == mm[k, p] & !is.na(hier[ , p]), 'with'] <- mm[k , taxa.var]
      }
    } 
    co <- mm[mm$do == 'removed' & mm[, value.var] > 0, c(taxa.var, value.var)]
#     print(commout)
#     print(co)
  }
  action[is.na(action)] <- 'keep'
  
  # keep only value.var
  commout <- commout[ , c(taxa.var, value.var)]
  
  method <- 'RPMC-S'
  out <- list(comm = commout, action = action, merged = merged, 
              method = method)
  class(out) <- 'restax'
  return(out)
}
