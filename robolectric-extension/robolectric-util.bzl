def safe_name(name_):
  return name_.replace(':', '_').replace('-', '_').replace('.', '_')

# Creates a list where each item maps to func_ applied to the corresponding item in list_.
# See https://docs.python.org/2/library/functions.html#map
def map(func_, list_):
  newlist = []
  for item in list_:
    newlist.append(func_(item))
  return newlist
