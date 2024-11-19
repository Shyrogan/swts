import BatteryService from "gi://AstalBattery"
import { bind } from "astal"

const battery = BatteryService.get_default()

const isVisible = bind(battery, "isPresent")
const iconName = bind(battery, "batteryIconName")
const percent = bind(battery, "percentage").as((v) => (v * 100).toPrecision(2) + "%")

type Props = {
  label?: boolean;
}

export default function Battery({ label }: Props) {
  return <box className="battery" visible={isVisible}>
    <icon icon={iconName}/>
    <label visible={label} label={percent} />
  </box>
}
