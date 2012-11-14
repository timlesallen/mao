DROP TABLE IF EXISTS empty;
CREATE TABLE empty (
  id INT,
  value VARCHAR(200));

DROP TABLE IF EXISTS one;
CREATE TABLE one (
  id INT,
  value VARCHAR(200));

INSERT INTO one (id, value) VALUES (42, 'Hello, Dave.');

DROP TABLE IF EXISTS "some";
CREATE TABLE "some" (
  id INT,
  value VARCHAR(100));

INSERT INTO "some" (id, value) VALUES (1, 'Bah'), (2, 'Hah'), (3, 'Hello, Dave.');

DROP TABLE IF EXISTS typey;
CREATE TABLE typey (
  korea BOOLEAN DEFAULT TRUE,
  japan DECIMAL(10,2),
  china TEXT);

DROP TABLE IF EXISTS autoid;
CREATE TABLE autoid (
  id SERIAL PRIMARY KEY NOT NULL,
  value VARCHAR(100));

DROP TABLE IF EXISTS times;
CREATE TABLE times (
  id SERIAL PRIMARY KEY NOT NULL,
  time TIMESTAMP WITHOUT TIME ZONE NOT NULL);

INSERT INTO times (time) VALUES ('2012-11-10T19:45:00Z');
