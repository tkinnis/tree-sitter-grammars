from enum import Enum
import enum
from typing import Generic


class Box(Generic[str, Enum, int]):
    item = 1


class Built(make(str, Enum, int)):
    value = 2


class Colour(
    # c
    Enum,
):
    RED = 1


class Access(
    int,  # bitmask
    enum.IntFlag,
):
    READ = 4
    label: str


class Multi(Base, Mixin):
    count = 0


class Status(Enum):
    PENDING = "pending"

    def is_ready(self):
        return False
