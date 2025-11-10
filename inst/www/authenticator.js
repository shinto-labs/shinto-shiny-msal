// www/authenticator.js

// 1) Your Azure AD app settings --> Moved to msal_Authenticator.R

console.log("My CLIENT_ID is:", CLIENT_ID);
console.log("My AUTHORITY is:", AUTHORITY);

// 2) MSAL configuration
const msalConfig = {
  auth: {
    clientId: CLIENT_ID,
    authority: AUTHORITY,
    redirectUri: window.location.origin, //"http://localhost:3838"
    navigateToLoginRequestUrl: true
  },
  cache: {
    cacheLocation: "sessionStorage",
    storeAuthStateInCookie: true,
  },
  system: {
    loggerOptions: {
      loggerCallback: (level, message, containsPii) => {
        if (!containsPii) console.log(`MSAL: ${message}`);
      },
      logLevel: msal.LogLevel.Verbose
    }
  }
};

// 3) Scopes & loginRequest
const appScopes    = [`api://${CLIENT_ID}/login`, "openid", "profile", "email"];
// const appScopes    = ["api://7f65821e-6021-4717-93fa-e58969453898/login", "openid", "profile", "email"];
const loginRequest = { scopes: appScopes };

let msalInstance;

// 4) Acquire token silently (or redirect if needed), then send to Shiny
async function acquireToken(account) {
  try {
    // This line silently (without showing a login popup) asks Microsoft’s identity platform for an access token.
    // scopes means “what permissions are we requesting?” (e.g. "User.Read", "Mail.Read", or your own API’s scope).
    // account is the currently signed-in user.
    // If the user is already logged in and has a valid session, MSAL can issue a new token quietly (no re-login prompt).

    const response = await msalInstance.acquireTokenSilent({
      scopes:  appScopes,
      account: account
    });

    // Send token straight into Shiny. The accessToken value is a JWT (JSON Web Token)
    Shiny.setInputValue("accessToken", response.accessToken);

  } catch (err) {
    if (err instanceof msal.InteractionRequiredAuthError) {
      // fallback to interactive if needed
      await msalInstance.acquireTokenRedirect({
        scopes:  appScopes,
        account: account
      });
    } else {
      console.error("MSAL token error:", err);
    }
  }
}

// 5) Everything starts when Shiny’s WebSocket is open
$(document).on("shiny:connected", async function(event) {
  // Initialize MSAL
  msalInstance = new msal.PublicClientApplication(msalConfig);
  await msalInstance.initialize();

  // If just coming back from Azure AD redirect, handle it
  await msalInstance.handleRedirectPromise();

  // Do we have a logged-in account?
  const accounts = msalInstance.getAllAccounts();
  if (accounts.length === 0) {
    // No user: send them to sign in
    await msalInstance.loginRedirect(loginRequest);
  } else {
    // Already logged in: grab a token
    await acquireToken(accounts[0]);
  }
});
