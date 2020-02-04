import strutils, db_sqlite, json
include "index.nimf"       # Include the NimF template.
template playgroundStart*(db: DbConn) = exec(db, sql"""
  create table if not exists playground(
    id             integer         primary key,
    creation       timestamp       not null    default (strftime('%s', 'now')),
    title          varchar(25)     not null,
    email          varchar(254)    not null,
    code           varchar(999)    not null,
    comment        varchar(99)     not null,
    target         varchar(9)      not null,
    mode           varchar(9)      not null,
    gc             varchar(9)      not null,
    stylecheck     varchar(9)      not null,
    exceptions     varchar(9)      not null,
    os             varchar(9)      not null,
    cpu            varchar(9)      not null,
    ssl            integer         not null    default 0,
    threads        integer         not null    default 0,
    strip          integer         not null    default 1,
    python         integer         not null    default 0,
    flto           integer         not null    default 0,
    fastmath       integer         not null    default 0,
    hardened       integer         not null    default 0,
    fontsize       integer         not null    default 12,
    fontfamily     varchar(9)      not null,
    expiration     integer         not null    default 7,
    stdin          varchar(99)     not null
  );  """)                 # Create Playground DB Table.
