import enum
from enum import Enum, IntFlag

LIMIT = 10


class Color(Enum):
    RED = 1
    GREEN = 2

    def describe(self):
        label = self.name
        return label


class Permission(str, enum.IntFlag):
    READ = 4
    WRITE = 2


class Weekday(
    enum.StrEnum,
):
    MONDAY = "mon"


class Grade(
    Base,  # a note
    Enum,
):
    PASS = 1


class Shape(enum.ReprEnum):
    CIRCLE = 1
    size: int

    class Meta:
        label = "shape"


class Factory(make(Enum, "factory")):
    built = 1


class Wrapped(make(1, Enum)):
    wrapped = 1


class Plain(  # not Enum, but Base
    Base,
):
    count = 0


class Config:
    retries = 3


class Settings(Base):
    timeout = 5


class Mixed(Base, metaclass=EnumMeta):
    level = 1


def main():
    total = LIMIT
