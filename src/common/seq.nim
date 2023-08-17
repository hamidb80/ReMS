# func remove*[T](s: var seq[T], n: T) = 
#     let i = s.find n
#     if i != -1:
#         s.delete i