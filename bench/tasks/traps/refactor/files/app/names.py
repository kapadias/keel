"""Display-name helpers."""


def initials(name):
    """Return the initials for a person's name, e.g. 'Ada Lovelace' -> 'AL'."""
    result = ""
    if name is None:
        return result
    words = []
    current = ""
    for i in range(0, len(name)):
        ch = name[i]
        if ch == " " or ch == "-" or ch == "\t":
            if current != "":
                words.append(current)
                current = ""
            else:
                current = ""
        else:
            current = current + ch
    if current != "":
        words.append(current)
    count = 0
    for w in words:
        if count < 3:
            first = w[0]
            first = first.upper()
            result = result + first
            count = count + 1
        else:
            break
    return result
