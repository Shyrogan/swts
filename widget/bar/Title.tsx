import AstalHyprland from "gi://AstalHyprland?version=0.1"
import { createBinding, createComputed, With } from "gnim"

const hyprland = AstalHyprland.get_default()

export default function Title() {
  const focusedClient = createBinding(hyprland, "focusedClient")
  return (
    <With value={focusedClient}>
      {(focusedClient) =>
        focusedClient ? <ClientTitle client={focusedClient} /> : <box />
      }
    </With>
  )
}

function ClientTitle({ client }: { client: AstalHyprland.Client }) {
  const lastClass = client.class.split(".").findLast((v) => v) || ""
  const name = `${lastClass.substring(0, 1).toUpperCase()}${lastClass.substring(1)}`
  const title = client.title.replaceAll(" - Brave", "").replaceAll(name, "")

  return (
    <box class="pl-2 space-x-2">
      <label label={name} class="font-bold" />
      <label label={title} />
    </box>
  )
}
