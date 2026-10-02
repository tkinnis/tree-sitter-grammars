fun pick(items: List<Int>): Int {
    for (item in items) {
        if (item < 0) continue
        if (item > 9) break
        if (item == 5) return item
    }
    items.forEach { if (it == 1) return@forEach }
    throw IllegalStateException("none")
}
