import AstalHyprland from "gi://AstalHyprland?version=0.1"
import { createBinding, createComputed, With } from "gnim"

const hyprland = AstalHyprland.get_default()

export default function Title() {
  const focusedClient = createBinding(hyprland, "focusedClient")
  const appName = createComputed((get) => {
    const last =
      get(focusedClient)
        .class.split(".")
        .findLast((v) => v) || ""
    return `${last.substring(0, 1).toUpperCase()}${last.substring(1)}`
  })
  const title = createComputed((get) => {
    const fullTitle = get(focusedClient).title
    const name = get(appName)
    return fullTitle.replaceAll(" - Brave", "").replaceAll(name, "")
  })

  return (
    <With value={focusedClient}>
      {(focusedClient) =>
        focusedClient ? (
          <box class="pl-2 space-x-2">
            <label label={appName} class="font-bold" />
            <label label={title} />
          </box>
        ) : (
          <box />
        )
      }
    </With>
  )
}
