import AstalBluetooth from "gi://AstalBluetooth?version=0.1"
import { createBinding, With } from "gnim"
import { cn } from "../../utils"

const bluetooth = AstalBluetooth.get_default()

export default function Quicksettings() {
  const isPowered = createBinding(bluetooth, "isPowered")
  return (
    <popover>
      <box class="bg-background px-4 py-3">
        <With value={isPowered}>
          {(value) =>
            value ? (
              <button
                class={cn("p-2", value && "bg-blue")}
                iconName="bluetooth"
                onClicked={() => bluetooth.toggle()}
              />
            ) : (
              <box />
            )
          }
        </With>
      </box>
    </popover>
  )
}
