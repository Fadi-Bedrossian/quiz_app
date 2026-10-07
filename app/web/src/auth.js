import { PublicClientApplication } from '@azure/msal-browser'

export const authDisabled = import.meta.env.VITE_AUTH_DISABLED === 'true'
export const clientId = import.meta.env.VITE_ENTRA_CLIENT_ID || ''
export const tenantId = import.meta.env.VITE_ENTRA_TENANT_ID || ''
export const audience = import.meta.env.VITE_ENTRA_AUDIENCE || `api://${clientId}`

export const msal = new PublicClientApplication({
  auth: {
    clientId,
    authority: `https://login.microsoftonline.com/${tenantId}`,
    redirectUri: window.location.origin,
  },
  cache: { cacheLocation: 'sessionStorage' },
})

export const loginRequest = { scopes: [`${audience}/Quiz.Access`] }
