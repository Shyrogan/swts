import PowerProfiles from "gi://AstalPowerProfiles"
import { bind } from "astal"

type Props = {
  label?: boolean;
}

export default function PowerProfile({ label }: Props) {
  const powerProfiles = PowerProfiles.get_default()
  const profile = bind(powerProfiles, "active_profile")
  const icon = bind(powerProfiles, "icon_name")

  return <box className="power-profile">
    <icon icon={icon}/>
    <label visible={label} label={profile} />
  </box>
}
