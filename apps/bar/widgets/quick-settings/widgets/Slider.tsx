type Props = {
  min?: number
  max?: number
}

export default function QuickSettingsSlider({ min, max }: Props) {
  return <slider vertical={false} min={min || 0} max={max || 100} value={50} />
}
