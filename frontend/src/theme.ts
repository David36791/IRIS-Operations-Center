import { ref, watchEffect } from 'vue'

const KEY = 'ioc-theme'

/** Theme is a display preference, so it is kept between visits. */
export const theme = ref<'light' | 'dark'>(
  (typeof localStorage !== 'undefined' && (localStorage.getItem(KEY) as 'light' | 'dark')) || 'light'
)

watchEffect(() => {
  if (typeof document === 'undefined') return
  document.documentElement.dataset.theme = theme.value
  localStorage.setItem(KEY, theme.value)
})

export function toggleTheme() {
  theme.value = theme.value === 'dark' ? 'light' : 'dark'
}
