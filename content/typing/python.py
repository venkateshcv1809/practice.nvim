from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, TypeVar

T = TypeVar("T")


@dataclass(frozen=True, slots=True)
class User:
    id: int
    name: str
    email: str | None = None


def greet(user: User) -> str:
    host = (user.email or "local").split("@")[-1]
    return f"hello {user.name} @ {host}"


def take(items: Iterable[T], n: int) -> list[T]:
    out: list[T] = []
    for item in items:
        out.append(item)
        if len(out) == n:
            break
    return out


def load_names(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    return [line.strip() for line in text.splitlines() if line.strip()]


def classify(code: int) -> str:
    match code:
        case 200 | 201:
            return "ok"
        case 404:
            return "missing"
        case _ if 500 <= code < 600:
            return "error"
        case _:
            return "other"


async def fetch_user(user_id: int) -> User | None:
    if user_id <= 0:
        return None
    return User(id=user_id, name="ada")


def main() -> None:
    users = [User(1, "ada"), User(2, "grace", "g@ex.com")]
    names = [user.name for user in users if user.email]
    print(take(names, 2), classify(201))
    if (root := Path(".").resolve()) and root.exists():
        print(root)


if __name__ == "__main__":
    main()
