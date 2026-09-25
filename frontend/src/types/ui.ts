/** Column definition shared by AppTable and the pages that feed it. */
export interface Column {
  key: string
  label: string
  align?: 'left' | 'right'
  width?: string
}
