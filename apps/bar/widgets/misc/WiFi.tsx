import Network from "gi://AstalNetwork"
import { bind } from "astal"

type Props = {
  label?: boolean;
}

export default function WiFi({ label }: Props) {
  const network = Network.get_default()
  const wifi = bind(network, "wifi")

  return <box className="wifi">
    <icon icon={wifi.as((w) => w.get_icon_name())}/>
    <label visible={label} label={wifi.as((w) => w?.get_ssid() || "")} />
  </box>
}
