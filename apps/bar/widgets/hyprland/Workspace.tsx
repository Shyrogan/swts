import { Binding } from "astal"

type Props = {
  isFocus: Binding<boolean> 
};

export default function Workspace({ isFocus }: Props) {
  return <box
    className="workspace" 
    setup={(self) => {
      self.toggleClassName("active", isFocus.get())
      self.hook(isFocus, () => self.toggleClassName("active", isFocus.get()))
    }}
  >
    <button/>
  </box>
}
