#' Retrieves name, symbol, slug and rank for all tokens at specific historic date
#'
#' List all of the crypto currencies that exist/have existed on CoinMarketCap between specific dates.
#' This list is used as a basis to scrape historical market data using \code{crypto_history()}.
#' It retrieves name, slug, symbol and rank of crypto currencies from
#' CoinMarketCap and creates URLS for the \code{scraper()} to use.
#'
#' @param coin Name, symbol or slug of crypto currency
#' @param start_date_hist Start date to retrieve coin history from, format yyyymmdd
#' @param end_date_hist End date to retrieve coin history from, format yyyymmdd, if not provided, today will be assumed
#' @param date_gap 'months', date gap when checking for historically existing coins,  between 'start_date_hist' and
#' 'end_date_hist'
#'
#' @return List of (historically existing)cryptocurrencies in a tibble:
#'   \item{symbol}{Coin symbol (not-unique)}
#'   \item{name}{Coin name}
#'   \item{slug}{Coin URL slug (unique)}
#'   \item{exchange_url}{Exchange market tables urls for scraping}
#'
#' Required dependency that is used in function call \code{getCoins()}.
#' @importFrom tibble tibble
#' @importFrom jsonlite fromJSON
#' @importFrom lubridate today ymd
#' @importFrom dplyr left_join mutate rename
#'
#' @examples
#' \dontrun{
#' coin <- "kin"
#' coins <- crypto_list(coin)
#'
#' # return all coins
#' coin_list <- crypto_list()
#'
#' # return all coins listed in 2015
#' coin_list_2015 <- crypto_list(start_date_hist="20150101",end_date_hist="20151231",date_gap="months")
#'
#' }
#'
#' @name crypto_list_old
#'
#' @export
#'
  crypto_list_old <- function(coin = NULL,
           start_date_hist = NULL,
           end_date_hist = NULL,
           date_gap ="months") {
    # get current coins
      out_list <- out_list_recent <- NULL
      if (!is.null(start_date_hist)){
        # create dates
        if (is.null(end_date_hist)) end_date_hist <- lubridate::today()
        dates <- as.Date(seq(ymd(start_date_hist),ymd(end_date_hist),date_gap))
        pb <- progress_bar$new(format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
                                total = length(dates), clear = FALSE)
        for (i in 1:length(dates)){
          pb$tick()
          attributes <- paste0("https://coinmarketcap.com/historical/",format(dates[i], "%Y%m%d"),"/")
          out_list <- dplyr::bind_rows(out_list,scraper_hist(attributes, sleep = NULL) %>% dplyr::mutate(hist_date=dates[i]))
        }
      }
      coins <- out_list
      # always get list for data validation
      json   <- "https://s2.coinmarketcap.com/generated/search/quick_search.json"
      out_list_recent  <- jsonlite::fromJSON(json) %>% dplyr::as_tibble()
      # validate name & slug via symbol from recent list
      if (!is.null(coins)){
        coins <- coins %>% dplyr::rename(symbol=Symbol,name=Name) %>%
          dplyr::left_join(out_list_recent %>% select(symbol,name,slug) %>% dplyr::rename(slug_main=slug, name_main=name),by="symbol") %>%
          dplyr::mutate(name=ifelse(is.na(name_main),name,name_main),slug=ifelse(is.na(slug_main),slug,slug_main)) %>% dplyr::select(symbol, name, slug, hist_date)
      }
      if (is.null(end_date_hist)|is.null(coins)){
        coins <- bind_rows(coins,out_list_recent %>% dplyr::select(name,symbol,slug) %>% dplyr::mutate(hist_date=lubridate::today())) %>% dplyr::as_tibble()
      }
    # get historic coins
    if (!is.null(coin)) {
      name   <- coins$name %>% unique()
      slug   <- coins$slug %>% unique()
      symbol <- coins$symbol %>% unique()
      c1     <- subset(coins, toupper(name) %in% toupper(coin))
      c2     <- subset(coins, symbol %in% toupper(coin))
      c3     <- subset(coins, slug %in% tolower(coin))
      coins  <- tibble::tibble()
      if (nrow(c1) > 0) { coins     <- rbind(coins, c1 %>% select(-hist_date)) }
      if (nrow(c2) > 0) { coins     <- rbind(coins, c2 %>% select(-hist_date)) }
      if (nrow(c3) > 0) { coins     <- rbind(coins, c3 %>% select(-hist_date)) }
      if (nrow(coins) > 1L) { coins <- unique(coins) }
    }
    coins <-
      tibble::tibble(
        symbol = coins$symbol,
        name   = coins$name,
        slug   = coins$slug
      ) %>% unique
    exchangeurl <- paste0("https://coinmarketcap.com/currencies/", coins$slug, "/#markets")
    exchange_url       <- c(exchangeurl)
    coins$symbol       <- as.character(toupper(coins$symbol))
    coins$name         <- as.character(coins$name)
    coins$slug         <- as.character(coins$slug)
    coins$exchange_url <- as.character(exchange_url)
    return(coins)
  }
