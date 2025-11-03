export function cn(...classes: (string | boolean | undefined)[]) {
  return classes.filter((s) => !!s).join(" ")
}
