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
