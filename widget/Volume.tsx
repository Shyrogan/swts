import { bind } from "astal";
import { Gtk } from "astal/gtk3";
import AstalWp from "gi://AstalWp?version=0.1";

const wp = AstalWp.get_default()

export default function Volume() {
  if (!wp) return <></>

  const { CENTER } = Gtk.Align

  const speaker = bind(wp.audio, 'default_speaker')
  const speakerVolume = speaker.as((s) => s.volume / 100)
  const speakerIcon = speaker.as((s) => s.icon && s.icon.length > 0 && s.icon !== "audio-card-symbolic" ? s.icon : "audio-speakers-symbolic")

  const mic = bind(wp.audio, 'default_microphone')
  const micVolume = mic.as((s) => s.volume / 100)
  const micIcon = mic.as((s) => s.icon && s.icon.length > 0 && s.icon !== "audio-card-symbolic" ? s.icon : "audio-input-microphone-symbolic")

  return <box vertical className="bg-bg rounded p-2 mt-1" halign={Gtk.Align.CENTER}>
    <circularprogress halign={CENTER} valign={CENTER} value={speakerVolume} rounded className='text-border' startAt={0} endAt={1} >
      <icon icon={speakerIcon} className="p-2 bg-bg text-xs text-light" />
    </circularprogress>
    <circularprogress halign={CENTER} valign={CENTER} value={micVolume} rounded className='text-border pt-4' startAt={0} endAt={1} >
      <icon icon={micIcon} className="p-2 bg-bg text-xs text-light" />
    </circularprogress>
  </box>
}
