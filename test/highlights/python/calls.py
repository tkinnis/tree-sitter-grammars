@Tracked
def make(name):
    person = Person(name)
    print(person)
    return describe(person)
