import strutils, db_sqlite
include "index.nimf"       # Include the NimF template.
template playgroundStart*(db: DbConn) = exec(db, sql"""
  create table if not exists playground(
    id             integer         primary key,
    title          varchar(25)     not null,
    description    varchar(300)    not null,
    email          varchar(254)    not null,
    creation       timestamp       not null    default (strftime('%s', 'now'))
  );  """)                 # Create Playground DB Table.
