package Test::DB;

use DBI;
use v5.10;

sub init_db {
    if (-e 't/bloodbowl.db') {
        unlink 't/bloodbowl.db';
    }

    my $dbh  = DBI->connect('dbi:SQLite:dbname=t/bloodbowl.db', '', '',
        { AutoCommit => 1, RaiseError => 1 });
    local $/ = ';';
    while (<DATA>) {
        next unless $_;
        s/^\s+|\s+$//g;
        $dbh->do($_);
    }
    return $dbh;
}

1;

__DATA__
CREATE TABLE coaches (
    id        INTEGER PRIMARY KEY,
    name      TEXT NOT NULL,
    email     TEXT NOT NULL,
    password  TEXT NOT NULL
);

INSERT INTO coaches (name, email, password) VALUES ('julio_f', 'julio.fraire@gmail.com', 'xxxx');
INSERT INTO coaches (name, email, password) VALUES ('user_a',  'user_a@gmail.com',       'wwww');
INSERT INTO coaches (name, email, password) VALUES ('user_b',  'user_b@gmail.com',       'yyyy');
INSERT INTO coaches (name, email, password) VALUES ('user_c',  'user_c@gmail.com',       'zzzz');

CREATE TABLE teams (
    id        INTEGER PRIMARY KEY,
    name      TEXT NOT NULL,
    coach     INTEGER,
    FOREIGN KEY (coach) REFERENCES coaches (id)
);

INSERT INTO teams (name, coach) VALUES ('Tinieblas', 1);

CREATE TABLE players (
    id        INTEGER PRIMARY KEY,
    name      TEXT NOT NULL,
    position  TEXT NOT NULL,
    team      INTEGER,
    FOREIGN KEY (team) REFERENCES teams (id)
);

INSERT INTO players (name, position, team) VALUES ('player1', 'trois-quarts', 1);
INSERT INTO players (name, position, team) VALUES ('player2', 'trois-quarts', 1);
INSERT INTO players (name, position, team) VALUES ('player3', 'blitzeur',     1);
INSERT INTO players (name, position, team) VALUES ('player4', 'recepteur',    1);
INSERT INTO players (name, position, team) VALUES ('player5', 'lanceur',      1);
