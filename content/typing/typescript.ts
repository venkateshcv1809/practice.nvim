type Id = string | number;
type Result<T, E = Error> = { ok: true; value: T } | { ok: false; error: E };

interface User {
  readonly id: Id;
  name: string;
  email?: string;
}

type Point = { x: number; y: number };
const origin = { x: 0, y: 0 } as const;
const shifted = { ...origin, x: 12 } satisfies Point;

enum Mode {
  Read = 'read',
  Write = 'write',
}

function greet(user: User): string {
  const city = user.email?.split('@')[1] ?? 'local';
  return `hello ${user.name} @ ${city}`;
}

async function load(id: Id): Promise<Result<User>> {
  const row = await fetch(`/api/users/${id}`);
  if (!row.ok) return { ok: false, error: new Error(row.statusText) };
  const value = (await row.json()) as User;
  return { ok: true, value };
}

function mapPair<A, B>(a: A, b: B): [A, B] {
  return [a, b];
}

const [left, right] = mapPair(1, 'two');
const names = ['ada', 'grace', 'barbara'] as const;
for (const name of names) {
  console.log(greet({ id: 7, name }));
}

export class Counter {
  #n = 0;
  inc(by = 1) {
    this.#n += by;
    return this.#n;
  }
}

export type { User, Result };
export { Mode, load };
