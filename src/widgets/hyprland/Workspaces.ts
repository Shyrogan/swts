import Button from "./Button";

export default function() {
  return Widget.Box({
    className: "workspaces",
    children: Array.from({ length: 10 }, (_, i) => Button(i + 1))
  })
}
