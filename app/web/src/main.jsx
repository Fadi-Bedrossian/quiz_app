import React from 'react'
import ReactDOM from 'react-dom/client'
import { MsalProvider } from '@azure/msal-react'

import App from './App'
import { msal } from './auth'

async function bootstrap() {
  await msal.initialize()
  ReactDOM.createRoot(document.getElementById('root')).render(
    <React.StrictMode>
      <MsalProvider instance={msal}>
        <App/>
      </MsalProvider>
    </React.StrictMode>,
  )
}

bootstrap()
