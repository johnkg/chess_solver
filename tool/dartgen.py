# Small helpers for the generators that write Dart source.
def ds(s):
    """Dart single-quoted string literal."""
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"


def dlist(items):
    return '[' + ', '.join(ds(i) for i in items) + ']'
