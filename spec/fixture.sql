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

INSERT INTO "some" (id, value) VALUES (1, 'Bah'), (2, 'Hah'), (3, 'Pah');

DROP TABLE IF EXISTS typey;
CREATE TABLE typey (
  korea BOOLEAN DEFAULT TRUE,
  japan DECIMAL(10,2),
  china TEXT);

DROP TABLE IF EXISTS autoid;
CREATE TABLE autoid (
  id SERIAL PRIMARY KEY NOT NULL,
  value VARCHAR(100));
