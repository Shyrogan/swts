import Network from "gi://AstalNetwork"
import { bind } from "astal"

const network = Network.get_default()

const wifi = bind(network, "wifi")
const isVisible = wifi.as((w) => w.ref_sink)

type Props = {
  label?: boolean;
}

export default function Battery({ label }: Props) {
  return <box className="wifi">
    <icon icon={iconName}/>
    <label visible={label} label={percent} />
  </box>
}
