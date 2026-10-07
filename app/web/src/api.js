import { authDisabled, loginRequest, msal } from './auth'

async function token() {
  if (authDisabled) return null
  let account = msal.getAllAccounts()[0]
  if (!account) {
    const login = await msal.loginPopup(loginRequest)
    account = login.account
  }
  try {
    const result = await msal.acquireTokenSilent({ ...loginRequest, account })
    return result.accessToken
  } catch {
    const result = await msal.acquireTokenPopup(loginRequest)
    return result.accessToken
  }
}

export async function request(path, options = {}) {
  const accessToken = await token()
  const headers = { 'Content-Type': 'application/json', ...(options.headers || {}) }
  if (accessToken) headers.Authorization = `Bearer ${accessToken}`
  const response = await fetch(path, { ...options, headers })
  if (!response.ok) {
    let detail = `${response.status} ${response.statusText}`
    try { detail = (await response.json()).detail || detail } catch { /* no-op */ }
    throw new Error(detail)
  }
  if (response.status === 204) return null
  return response.json()
}
