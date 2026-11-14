enum Color(val rgb: Int):
  case Red extends Color(0xff0000)
  case Green, Blue extends Color(0x0000ff)

  def label: String = toString

enum Tree[+T] {
  case Leaf(value: T)
  case Empty
}

class Forest
