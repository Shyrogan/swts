type Props = {
  icon?: string
  onClick?: () => void
}

export default function QuickSettingsCircularButton({ icon, onClick }: Props) {
  return <button className="circular" onClick={onClick}>
    <icon icon={icon} />
  </button>
}
