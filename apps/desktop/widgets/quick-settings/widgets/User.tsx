import { Variable } from "astal"

const user = Variable("")
  .poll(5 * 1000, 'whoami')

export default function QuickSettingsUserWidget() {
  return <box>
    <label label={user()} />
  </box>
}
