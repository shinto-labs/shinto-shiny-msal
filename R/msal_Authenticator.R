#' @title MSAL Auth UI
#' @description This UI is used to inject the javascript into de the headers of the page
#' @importFrom shiny addResourcePath
#' @importFrom htmltools tagList tags
#' @param client_id The Client ID needed in the authenticator script for Azure AD app settings
#' @param authority The Authority token needed in the authenticator script for Azure AD app settings
#' @export
msal_Authenticator <- function(client_id, authority) {

  shiny::addResourcePath(
    prefix = 'wwwAuthenticator',
    directoryPath = system.file('www', package='shintoshinymsal'))

  htmltools::tagList(
    htmltools::tags$script(src = "https://alcdn.msauth.net/browser/2.34.0/js/msal-browser.min.js"),
    tags$script(HTML(sprintf("const CLIENT_ID = '%s';", client_id))),
    tags$script(HTML(sprintf("const AUTHORITY = '%s';", authority))),
    htmltools::tags$script(src="wwwAuthenticator/authenticator.js"),
    htmltools::tags$div()
  )

}
