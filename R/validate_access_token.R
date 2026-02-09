#' @title Validate Access Token MSAL
#' @description We want to validate the access token given to the input of the application. This function helps in doing so.
#' The general idea:
#' Client logs in → gets access token from Entra ID.
#' Client sends token to your backend.
#' Backend reads token header → sees kid (which key was used to sign it).
#' Backend calls get_jwks() → gets current keys.
#' Backend finds the key with matching kid.
#' Backend uses that key to verify the signature.
#' Backend checks claims ((aud), iss, exp, tid, etc.).
#' If everything matches → token is valid → allow access.
#' @importFrom jose jwt_split read_jwk jwt_decode_sig
#' @importFrom jsonlite toJSON
#' @importFrom glue glue
#' @param token retrieved access token at starting the application which needs to be checked
#' @param tenant_id tenant ID given from the msal config. Can be NULL, will then not be checked but replaced with common.
#' @param app_id App ID from Azure (equals client ID, can be found in the MSAL config)
#' @param skew_secs Allowed clock skew in seconds when checking expiration timestamp and “not before” timestamp in seconds. Default = 300 secs = 5 minutes
#' @returns Either a JSON object with userInfo or FALSE if not all the checks have passed
#' @export
validate_access_token <- function(token, tenant_id,
                                  app_id,
                                  skew_secs  = 300){
  # audience   = API_AUD,
  # issuer,
  # require_scopes = character(),
  # require_roles  = character()) {

  if (is.null(token) || !nzchar(token)){
    missing_token_check <- FALSE
    stop("Missing bearer token")
  } else {
    missing_token_check <- TRUE
  }

  if((is.null(app_id) || is.na(app_id) || length(app_id) == 0)){
    app_id_present <- FALSE
    stop("No app_id given")
  } else {
    app_id_present <- TRUE
  }

  # Header lezen voor kid
  parts <- jose::jwt_split(token)
  kid <- parts$header$kid
  if((is.null(kid) || is.na(kid) || length(kid) == 0)){
    missing_kid_check <- FALSE
    stop("Token header has no 'kid'")
  } else {
    missing_kid_check <- TRUE
  }


  payload_tid <- parts$payload$tid
  if((is.null(payload_tid) || is.na(payload_tid) || length(payload_tid) == 0)){
    missing_tid_check <- FALSE
    stop("Token contains has no 'tid'")
  } else {
    missing_tid_check <- TRUE
  }

  if(is.null(tenant_id)){
    tid <- "common"
  } else {
    tid <- tenant_id
  }

  # if(tid != payload_tid){
  #   matching_tids <- FALSE
  #   stop("given tenant_id does not match with tid in payload")
  # } else {
  #   matching_tids <- TRUE
  # }


  token_version <- parts$payload$ver

  # Publieke sleutel ophalen via JWKS
  jwks <- get_jwks(tenant_id = tid, token_version = token_version)
  jwk  <- find_jwk_by_kid(kid, jwks)
  if((is.null(jwk) || any(is.na(jwk)) || length(jwk) == 0)){
    matching_jwk_check <- FALSE
    stop("No matching JWK for kid")
  } else {
    matching_jwk_check <- TRUE
  }

  pubkey <- jose::read_jwk(file = jwk)

  # Signature + claims decoderen/valideren
  claims <- jose::jwt_decode_sig(token, pubkey)

  # Tijd-validatie met clock skew
  now <- as.numeric(Sys.time())
  exp <- as.numeric(claims$exp %||% 0)
  nbf <- as.numeric(claims$nbf %||% 0)
  if (now > exp + skew_secs){
    token_not_expired <- FALSE
    stop("Token expired")
  } else {
    token_not_expired <- TRUE
  }
  if (now + skew_secs < nbf) {
    token_already_valid <- FALSE
    stop("Token not yet valid (nbf)")
  } else {
    token_already_valid <- TRUE
  }

  # # Issuer
  # if(token_version == "2.0"){
  #   issuer <- sprintf("https://login.microsoftonline.com/%s/v2.0", payload_tid)
  # } else {
  #   issuer <- sprintf("https://sts.windows.net/%s/", payload_tid)
  # }
  #
  #
  # if (!identical(claims$iss, issuer)){
  #   issuer_valid <- FALSE
  #   stop(sprintf("Invalid issuer: %s", claims$iss))
  # } else {
  #   issuer_valid <- TRUE
  # }

  if(token_version == "2.0"){
    if (!identical(claims$aud, app_id)){
      appid_valid <- FALSE
      stop(sprintf("Invalid appid: %s (comparing to claims$aud), app_id in token is  %s", claims$aud, app_id))
    } else {
      appid_valid <- TRUE
    }
  } else if(token_version == "1.0"){
    futile.logger::flog.info("Version 1.0, this is the app_id:")
    futile.logger::flog.info(app_id)
    version_1_token <- glue:glue("api://{app_id}")
    futile.logger::flog.info(app_id)
    if (!identical(claims$aud, version_1_token)){
      appid_valid <- FALSE
      stop(sprintf("Invalid appid: %s (comparing to claims$aud), app_id in token is %s", claims$aud, version_1_token))
    } else {
      appid_valid <- TRUE
    }
  }


  # # Audience
  # aud <- claims$aud
  # aud_ok <- FALSE
  # if (is.character(aud)) {
  #   aud_ok <- (aud == audience)
  # } else if (is.list(aud) || is.vector(aud)) {
  #   aud_ok <- any(unlist(aud) == audience)
  # }
  # if (!aud_ok) stop(sprintf("Invalid audience: %s", paste(aud, collapse = ",")))

  # # Scopes/Rollen (optioneel)
  # if (length(require_scopes)) {
  #   token_scopes <- strsplit(claims$scp %||% "", " +")[[1]]
  #   if (!all(require_scopes %in% token_scopes))
  #     stop(sprintf("Missing required scopes: %s",
  #                  paste(setdiff(require_scopes, token_scopes), collapse = ", ")))
  # }
  # if (length(require_roles)) {
  #   token_roles <- claims$roles %||% character()
  #   if (!all(require_roles %in% token_roles))
  #     stop(sprintf("Missing required roles: %s",
  #                  paste(setdiff(require_roles, token_roles), collapse = ", ")))
  # }


  if(all(missing_token_check, app_id_present, missing_kid_check, missing_tid_check, matching_jwk_check,
         token_not_expired, token_already_valid, appid_valid)){
    name <- claims$name
    email <- tolower(claims$email)
    iss <- claims$iss
    sub <- claims$sub
    msal_userid <- glue::glue("{iss}:{sub}")

    user_info_list <- list(
      name = name,
      email = email,
      msal_userid = msal_userid
    )

    user_info <- jsonlite::toJSON(user_info_list, pretty = TRUE)

    return(user_info)

  } else {
    return(FALSE)
  }


}

#' @title openId config ophalen/discovery document
#' @description retrieve the OpenID-config for a tenant. The returned information of this function is used to validate:
#' - Who issued the token (issuer)
#' - Where the public keys are (jwks_uri) to check the signature of the token
#' - Which endpoints and features are supported by the provider
#'
#' This function is only used internally and will not be exported.
#' @importFrom httr2 request req_perform resp_body_json
#' @param tenant_id tenant id from the access token.
#' @param token_version Version of token, determines from which url the config needs to be retrieved
#' @returns JSON. OpenID Connect discovery document (JSON with settings, claims and endpoints) of Microsoft Entra ID for given tenant_id
get_openid_config <- function(tenant_id, token_version) {
  if((is.null(tenant_id) || is.na(tenant_id) || length(tenant_id) == 0)){
    stop("No tenant_id given")
  } else {
    if((is.null(token_version) || is.na(token_version) || length(token_version) == 0)){
      stop("No token_version given")
    } else {
      if(token_version == "1.0"){
        url <- sprintf("https://login.microsoftonline.com/%s/.well-known/openid-configuration", tenant_id)
      } else {
        url <- sprintf("https://login.microsoftonline.com/%s/v2.0/.well-known/openid-configuration", tenant_id)
      }

      resp <- httr2::request(url) |> httr2::req_perform()
      resp_json <- httr2::resp_body_json(resp)

      return(resp_json)
    }
  }
}

#' @title Get the JSON Web Key Set from the discovery document
#' @description using the openID Connect discovery document, retrieve the keys from the JSON Web Key Set.
#' This is a standardized JSON format that contains all public keys a provider (here: Microsoft Entra ID) is currently using.
#' These are retrieved by reading jwks_uri from the discovery document. Here Microsoft publishes all the current public keys used to sign access tokens.
#' Your backend never sees the private key. Instead, you use the corresponding public key from JWKS to verify the signature of the JSON Web Tokens (JWT).
#' @importFrom httr2 request req_perform resp_body_json
#' @param tenant_id tenant id from the access token.
#' @param token_version version of accesstoken (1.0 or 2.0), to be passed along to `get_open_config`
#' @returns JSON. The JSON contains public keys in asymmetric cryptography (RSA in this case) that Microsoft uses as a private key to sign
#' JWT when they issue them.
get_jwks <- function(tenant_id, token_version) {
  if((is.null(tenant_id) || is.na(tenant_id) || length(tenant_id) == 0)){
    stop("No tenant_id given")
  } else {
    conf <- get_openid_config(tenant_id, token_version = token_version)
    jwks_uri <- conf$jwks_uri
    jwks <- httr2::request(jwks_uri) |> httr2::req_perform() |> httr2::resp_body_json()
    jwks_keys <- jwks$keys

    return(jwks_keys)
  }


}

#' @title Find the JSON Web Key matching the key id in the provided JSON Web Token
#' @description This function is needed so we can determine which key to use to verify this token signature.
#' @param kid key id - a string taken form the JWT Token header. Used to pick the right key from the JWKS
#' @param keys a list of public keys (from JWKS) from Microsoft
#' @returns The matching key or NULL
find_jwk_by_kid <- function(kid, keys) {
  if((is.null(kid) || is.na(kid) || length(kid) == 0)){
    stop("No kid given")
  } else {
    if((is.null(keys) || any(is.na(keys)) || length(keys) == 0)){
      stop("No keys given")
    } else {
      for (k in keys) if (identical(k$kid, kid)) return(k)
      NULL
    }
  }

}

openssl::signature_verify
