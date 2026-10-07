import React from 'react'
import ReactDOM from 'react-dom/client'
import { MsalProvider } from '@azure/msal-react'

import App from './App'
import { msal } from './auth'

async function bootstrap() {
  await msal.initialize()

  ReactDOM.createRoot(document.getElementById('root')).render(
    React.createElement(
      React.StrictMode,
      null,
      React.createElement(
        MsalProvider,
        { instance: msal },
        React.createElement(App),
      ),
    ),
  )
}

bootstrap()
