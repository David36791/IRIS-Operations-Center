import { reactive } from 'vue'

// Credentials are kept in memory only and never persisted, so they are gone
// when the tab is reloaded.
export const auth = reactive({
  username: '',
  password: '',
  authenticated: false
})

// Development convenience: seed from .env.local so the dev server does not ask
// for credentials on every reload. Vite only exposes VITE_* in dev this way,
// and the file is gitignored; the deployed build still shows the login form.
const devUser = import.meta.env.DEV ? import.meta.env.VITE_IOC_USER : undefined
const devPass = import.meta.env.DEV ? import.meta.env.VITE_IOC_PASS : undefined

// Both are needed: seeding a blank password would sign the tab in as a user it
// cannot authenticate as, and every request would answer 401 with no way back
// to the form. With no password set, the form is shown instead.
if (devUser && devPass) {
  auth.username = String(devUser)
  auth.password = String(devPass)
  auth.authenticated = true
}

export function setCredentials(username: string, password: string) {
  auth.username = username
  auth.password = password
  auth.authenticated = true
}

export function clearCredentials() {
  auth.username = ''
  auth.password = ''
  auth.authenticated = false
}
