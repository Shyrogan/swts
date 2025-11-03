import AstalHyprland from "gi://AstalHyprland?version=0.1"
import { createBinding, With } from "gnim"

const hyprland = AstalHyprland.get_default()

export default function Title({ client }: Props) {
  const focusedClient = createBinding(hyprland, "focusedClient")
  return (
    <With value={focusedClient}>
      {(client) =>
        !!client ? (
          <box>
            <label label={client.initialTitle} class="font-bold text-base" />
            <label label=" " />
            <label label={client.title} class="text-base" />
          </box>
        ) : (
          <label label="" />
        )
      }
    </With>
  )
}
