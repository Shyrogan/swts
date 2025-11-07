import AstalMpris from "gi://AstalMpris?version=0.1"
import { createBinding, For, With } from "gnim"

const mpris = AstalMpris.get_default()

export default function Mpris() {
  const players = createBinding(mpris, "players")
  return (
    <For each={players}>
      {(player) =>
        !!player ? (
          <box class="space-x-2">
            <label
              label={createBinding(player, "artist")}
              class="font-bold text-base"
            />
            <label label={createBinding(player, "title")} class="text-base" />
          </box>
        ) : (
          <box />
        )
      }
    </For>
  )
}
