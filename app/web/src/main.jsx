import React from 'react'
import ReactDOM from 'react-dom/client'
import { MsalProvider } from '@azure/msal-react'

import App from './App'
import { authDisabled, msal } from './auth'

async function bootstrap() {
  const root = ReactDOM.createRoot(document.getElementById('root'))

  if (authDisabled) {
    root.render(
      React.createElement(
        React.StrictMode,
        null,
        React.createElement(App),
      ),
    )
    return
  }

  await msal.initialize()

  root.render(
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
