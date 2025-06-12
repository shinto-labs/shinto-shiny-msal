#' @title MSAL Auth UI
#' @description This UI is used to inject the javascript into de the headers of the page
#' @importFrom shiny addResourcePath
#' @importFrom htmltools tagList tags
#' @export
msal_Authenticator <- function() {

  shiny::addResourcePath(
    prefix = 'wwwAuthenticator',
    directoryPath = system.file('www', package='shintoshinymsal'))

  htmltools::tagList(
    htmltools::tags$script(src = "https://alcdn.msauth.net/browser/2.34.0/js/msal-browser.min.js"),
    htmltools::tags$script(src="wwwAuthenticator/authenticator.js"),
    htmltools::tags$div()
  )

}
