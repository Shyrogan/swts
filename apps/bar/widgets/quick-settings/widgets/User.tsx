import { Variable } from "astal"
import { App } from "astal/gtk3"

const user = Variable("sebastien")
  .poll(5 * 1000, 'whoami')


export default function QuickSettingsUserWidget() {
  const icon = user().as((v) => `./assets/${v}.png`)
  return <box className="user">
    <icon icon={icon} />
    <label label={user().as((s) => s)} />
  </box>
}
