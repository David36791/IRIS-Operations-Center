<script setup lang="ts">
import { ref } from 'vue'
import { RouterView } from 'vue-router'
import { auth, setCredentials } from '@/auth'
import client from '@/api/client'

const username = ref('')
const password = ref('')
const error = ref<string | null>(null)
const busy = ref(false)

async function signIn() {
  error.value = null
  busy.value = true
  setCredentials(username.value, password.value)
  try {
    await client.get('/health')
  } catch {
    error.value = 'Sign-in failed — check the username and password.'
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <main v-if="!auth.authenticated" class="login">
    <h1>IRIS Operations Center</h1>
    <form @submit.prevent="signIn">
      <label>
        Username
        <input v-model="username" autocomplete="username" autofocus />
      </label>
      <label>
        Password
        <input v-model="password" type="password" autocomplete="current-password" />
      </label>
      <button type="submit" :disabled="busy">{{ busy ? 'Signing in…' : 'Sign in' }}</button>
    </form>
    <p v-if="error" class="error">{{ error }}</p>
  </main>

  <RouterView v-else />
</template>

<style scoped>
.login {
  font-family: system-ui, sans-serif;
  max-width: 320px;
  margin: 80px auto;
  padding: 0 24px;
}
form {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
label {
  display: flex;
  flex-direction: column;
  gap: 4px;
  font-size: 14px;
  color: #444;
}
input {
  padding: 8px;
  border: 1px solid #ccc;
  border-radius: 4px;
  font-size: 14px;
}
button {
  padding: 10px;
  border: 0;
  border-radius: 4px;
  background: #2c3e91;
  color: #fff;
  font-size: 14px;
  cursor: pointer;
}
button:disabled {
  opacity: 0.6;
  cursor: default;
}
.error {
  color: #b00020;
  font-size: 14px;
}
</style>
