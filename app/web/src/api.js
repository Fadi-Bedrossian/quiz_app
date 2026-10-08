export async function request(path, options = {}, accessToken = '') {
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
