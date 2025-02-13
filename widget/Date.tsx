import { Variable } from "astal";

const hour = Variable<number>(0).poll(
  500,
  "date +'%H'",
  (out: string, prev: number) => parseInt(out),
);
const minute = Variable<number>(0).poll(
  500,
  "date +'%M'",
  (out: string, prev: number) => parseInt(out),
);
const dm = Variable<number>(0).poll(
  500,
  "date +'%d%m'",
  (out: string, prev: number) => parseInt(out),
);
const year = Variable<number>(0).poll(
  500,
  "date +'%Y'",
  (out: string, prev: number) => parseInt(out),
);

const transform = (v: number) =>
  v.toString().length % 2 == 0 ? v.toString() : "0" + v.toString();

export default function Date() {
  return <box vertical className="bg-bg rounded p-2">
    <label className="text-light font-bold text-xxs" label={dm(transform)} />
    <label className="text-light font-semibold" label={hour(transform)} />
    <label className="text-light font-semibold" label={minute(transform)} />
    <label className="text-light font-bold text-xxs" label={year(transform)} />
  </box>
}
