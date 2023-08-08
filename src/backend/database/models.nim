macro table(name, body) = discard


table User:
  id
  name
  username
  role
  
table Auth:
  id
  platform # Bale
  # cookie # NO! use JWT
  timestamp


table Asset:
  id
  # uuid
  # revision
  # forked_from
  owner
  path
  timestamp

table Note:
  id
  # uuid
  # revision
  # forked_from
  owner
  data # json
  compiled # html
  timestamp

table Board:
  id
  # revision
  # forked_from
  owner
  title
  description
  data # json
  timestamp

table Tag:
  id
  owner
  name
  has_value
  is_universal
  timestamp

table TagUse:
  id
  owner
  tag
  ?note
  ?board
  ?asset
  timestamp
  value
