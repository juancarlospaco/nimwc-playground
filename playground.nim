import strutils, db_sqlite, json, strtabs, osproc, random, packages/docutils/rstgen
include "index.nimf"       # Include the NimF template.

template playgroundStart*(db: DbConn) =
  exec(db, sql"""
    create table if not exists playground(
      id             integer         primary key,
      creation       timestamp       not null    default (strftime('%s', 'now')),
      url            varchar(9)      not null    unique,
      filejson       varchar(999)    not null,
      code           varchar(999)    not null,
      comment        varchar(99)     not null,
      target         varchar(9)      not null,
      mode           varchar(9)      not null,
      gc             varchar(9)      not null,
      stylecheck     varchar(9)      not null,
      exceptions     varchar(9)      not null,
      cpu            varchar(9)      not null,
      ssl            integer         not null    default 0,
      threads        integer         not null    default 0,
      strip          integer         not null    default 1,
      python         integer         not null    default 0,
      flto           integer         not null    default 0,
      fastmath       integer         not null    default 0,
      marchnative    integer         not null    default 0,
      fontsize       integer         not null    default 15,
      fontfamily     varchar(9)      not null,
      expiration     integer         not null    default 7
    );
  """)                 # Create Playground DB Table.
