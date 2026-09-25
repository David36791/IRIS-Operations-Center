import { ref } from 'vue'

/**
 * Whether the command palette is open. Shared because it is opened from two
 * places: the Cmd/Ctrl+K shortcut and the sidebar entry, which lives outside
 * the palette component.
 */
export const paletteOpen = ref(false)

export function openPalette() {
  paletteOpen.value = true
}
