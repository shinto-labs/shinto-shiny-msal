#' @title MSAL Auth UI
#' @description This UI is used to inject the javascript into de the headers of the page
#' @param id id of the Shiny module
#' @export
authUI <- function(id = NULL) {
  ns <- shiny::NS(id)

  htmltools::tagList(
    htmltools::tags$head(
      # Load MSAL from CDN
      htmltools::tags$script(src = "https://alcdn.msauth.net/browser/2.34.0/js/msal-browser.min.js"),
      # Include custom auth logic
      htmltools::tags$script(src = "myPackageAssets/wes.js")
    ),
    htmltools::tags$div(id = ns("placeholder"))
  )


}
