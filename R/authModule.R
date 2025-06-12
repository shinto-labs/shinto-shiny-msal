#' @title MSAL Auth Serverside
#' @description The Serverside that retrieves the information from the accessToken (see auth.js), then returns it as a reactive
#' @param id id of the Shiny module
#' @export
authServer <- function(id){
  shiny::moduleServer(id, function(input, output, session){
    # tok  <- shiny::reactiveVal(NULL)
    # usr  <- shiny::reactiveVal(NULL)
    #
    # shiny::observeEvent(input$accessToken, {
    #   tok(input$accessToken)
    #   info <- jsonlite::fromJSON(input$userInfo)
    #   usr(info)
    # })
    #
    # # return a reactive list with $token and $user
    # shiny::reactive({
    #   list(token = tok(), user = usr())
    # })
  })
}
