// www/auth.js

// 1) Your Azure AD app settings
const CLIENT_ID   = "96a5a27a-2bd0-4e04-a886-abcea4ecd645";
const AUTHORITY   = "https://login.microsoftonline.com/d0cf79cd-0bf3-42f9-8b79-cc2564ea9747";

// 2) MSAL configuration
const msalConfig = {
  auth: {
    clientId: CLIENT_ID,
    authority: AUTHORITY,
    redirectUri: window.location.origin,
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
const appScopes    = ["openid", "profile", "email"];
const loginRequest = { scopes: appScopes };

let msalInstance;

// 4) Acquire token silently (or redirect if needed), then send to Shiny
async function acquireToken(account) {
  try {
    const response = await msalInstance.acquireTokenSilent({
      scopes:  appScopes,
      account: account
    });

    // Send token + userInfo straight into Shiny
    Shiny.setInputValue("accessTokenNew", response.accessToken);

    const userInfo = {
      email: account.username,
      name:  account.name,
      roles: account.idTokenClaims?.roles || [],
      oid: account.idTokenClaims?.oid
    };
    Shiny.setInputValue("userInfoNew", JSON.stringify(userInfo));

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
    msalInstance.loginRedirect(loginRequest);
  } else {
    // Already logged in: grab a token
    await acquireToken(accounts[0]);
  }
});
