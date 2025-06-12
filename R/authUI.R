auth_dependency <- function() {
  htmlDependency(
    name    = "myAuth",
    version = "0.1.0",
    src     = c(file = "www"),
    script  = c("wes.js")
  )
}

#' @title MSAL Auth UI
#' @description This UI is used to inject the javascript into de the headers of the page
#' @param id id of the Shiny module
#' @export
authUI <- function(id = NULL) {
  ns <- shiny::NS(id)

  htmltools::tagList(
    auth_dependency(),
    htmltools::tags$div(id = ns("placeholder"))
  )


}
