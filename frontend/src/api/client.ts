import axios from 'axios'
import { auth, clearCredentials } from '@/auth'

const client = axios.create({
  baseURL: '/iris-operations/api/ioc',
  headers: { 'Content-Type': 'application/json' }
})

client.interceptors.request.use((config) => {
  if (auth.authenticated) {
    config.auth = { username: auth.username, password: auth.password }
  }
  return config
})

client.interceptors.response.use(
  (response) => response,
  (error) => {
    // The API explains failures in its envelope; without this the UI would only
    // ever show axios's "Request failed with status code …".
    const envelope = error.response?.data
    if (envelope && envelope.error && envelope.error.message) {
      error.message = envelope.error.message
    }
    if (error.response?.status === 401) {
      clearCredentials()
    }
    return Promise.reject(error)
  }
)

export default client
