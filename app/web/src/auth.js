import { PublicClientApplication } from '@azure/msal-browser'

export const tenantId = import.meta.env.VITE_ENTRA_TENANT_ID || ''
export const clientId = import.meta.env.VITE_ENTRA_CLIENT_ID || ''
export const audience = import.meta.env.VITE_ENTRA_AUDIENCE || ''
export const authConfigured = Boolean(tenantId && clientId && audience)

const scopeBase = audience.replace(/\/$/, '')
export const loginRequest = { scopes: authConfigured ? [`${scopeBase}/Quiz.Access`] : [] }

const msal = authConfigured
  ? new PublicClientApplication({
      auth: {
        clientId,
        authority: `https://login.microsoftonline.com/${tenantId}`,
        redirectUri: window.location.origin,
      },
      cache: { cacheLocation: 'sessionStorage' },
    })
  : null

let initializePromise = null

async function getClient() {
  if (!msal) throw new Error('Admin sign-in is not configured for this environment.')
  if (!initializePromise) initializePromise = msal.initialize()
  await initializePromise
  return msal
}

async function tokenForAccount(client, account, interactive) {
  try {
    return await client.acquireTokenSilent({ ...loginRequest, account })
  } catch {
    if (!interactive) return null
    return client.acquireTokenPopup({ ...loginRequest, account })
  }
}

export async function existingAdminSession() {
  if (!authConfigured) return null
  const client = await getClient()
  const account = client.getAllAccounts()[0]
  if (!account) return null
  const result = await tokenForAccount(client, account, false)
  if (!result) return null
  return { accessToken: result.accessToken, account }
}

export async function signInAdmin() {
  const client = await getClient()
  let account = client.getAllAccounts()[0]
  if (!account) {
    const login = await client.loginPopup(loginRequest)
    account = login.account
    if (login.accessToken) return { accessToken: login.accessToken, account }
  }
  const result = await tokenForAccount(client, account, true)
  return { accessToken: result.accessToken, account }
}

export async function signOutAdmin() {
  if (!authConfigured) return
  const client = await getClient()
  const account = client.getAllAccounts()[0]
  if (account) await client.logoutPopup({ account })
}
