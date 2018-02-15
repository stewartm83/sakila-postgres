
-- Type: mpaa_rating

-- DROP TYPE public.mpaa_rating;

CREATE TYPE public.MPAA_RATING AS ENUM
('G', 'PG', 'PG-13', 'R', 'NC-17');

ALTER TYPE public.MPAA_RATING
OWNER TO sakila;

-- DOMAIN: public.year

-- DROP DOMAIN public.year;

CREATE DOMAIN public.year
AS INTEGER;

ALTER DOMAIN public.year
OWNER TO sakila;

ALTER DOMAIN public.year
ADD CONSTRAINT year_check CHECK (VALUE >= 1901 AND VALUE <= 2155);

-- Table: public.actor

-- DROP TABLE public.actor;

CREATE TABLE public.actor
(
  actor_id    SERIAL,
  first_name  CHARACTER VARYING(45)       NOT NULL,
  last_name   CHARACTER VARYING(45)       NOT NULL,
  last_update TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
  CONSTRAINT actor_pkey PRIMARY KEY (actor_id)
);

ALTER TABLE public.actor
  OWNER TO sakila;

-- Index: idx_actor_last_name

-- DROP INDEX public.idx_actor_last_name;

CREATE INDEX idx_actor_last_name
  ON public.actor USING BTREE
  (last_name);

-- Trigger: last_updated

-- DROP TRIGGER last_updated ON public.actor;

CREATE TRIGGER last_updated
BEFORE UPDATE
  ON public.actor
FOR EACH ROW
EXECUTE PROCEDURE public.last_updated();

-- Table: public.address

-- DROP TABLE public.address;

CREATE TABLE public.address
(
  address_id  SERIAL,
  address     CHARACTER VARYING(50)       NOT NULL,
  address2    CHARACTER VARYING(50),
  district    CHARACTER VARYING(20)       NOT NULL,
  city_id     SMALLINT                    NOT NULL,
  postal_code CHARACTER VARYING(10),
  phone       CHARACTER VARYING(20)       NOT NULL,
  last_update TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
  CONSTRAINT address_pkey PRIMARY KEY (address_id),
  CONSTRAINT address_city_id_fkey FOREIGN KEY (city_id)
  REFERENCES public.city (city_id) MATCH SIMPLE
  ON UPDATE CASCADE
  ON DELETE RESTRICT
);

ALTER TABLE public.address
  OWNER TO sakila;

-- Index: idx_fk_city_id

-- DROP INDEX public.idx_fk_city_id;

CREATE INDEX idx_fk_city_id
  ON public.address USING BTREE
  (city_id);

-- Trigger: last_updated

-- DROP TRIGGER last_updated ON public.address;

CREATE TRIGGER last_updated
BEFORE UPDATE
  ON public.address
FOR EACH ROW
EXECUTE PROCEDURE public.last_updated();

-- Table: public.category

-- DROP TABLE public.category;

CREATE TABLE public.category
(
  category_id SERIAL,
  name        CHARACTER VARYING(25)       NOT NULL,
  last_update TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
  CONSTRAINT category_pkey PRIMARY KEY (category_id)
);

ALTER TABLE public.category
  OWNER TO sakila;

-- Trigger: last_updated

-- DROP TRIGGER last_updated ON public.category;

CREATE TRIGGER last_updated
BEFORE UPDATE
  ON public.category
FOR EACH ROW
EXECUTE PROCEDURE public.last_updated();

-- Table: public.city

-- DROP TABLE public.city;

CREATE TABLE public.city
(
  city_id     SERIAL,
  city        CHARACTER VARYING(50)       NOT NULL,
  country_id  SMALLINT                    NOT NULL,
  last_update TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
  CONSTRAINT city_pkey PRIMARY KEY (city_id),
  CONSTRAINT city_country_id_fkey FOREIGN KEY (country_id)
  REFERENCES public.country (country_id) MATCH SIMPLE
  ON UPDATE CASCADE
  ON DELETE RESTRICT
);

ALTER TABLE public.city
  OWNER TO sakila;

-- Index: idx_fk_country_id

-- DROP INDEX public.idx_fk_country_id;

CREATE INDEX idx_fk_country_id
  ON public.city USING BTREE
  (country_id);

-- Trigger: last_updated

-- DROP TRIGGER last_updated ON public.city;

CREATE TRIGGER last_updated
BEFORE UPDATE
  ON public.city
FOR EACH ROW
EXECUTE PROCEDURE public.last_updated();

-- Table: public.country

-- DROP TABLE public.country;

CREATE TABLE public.country
(
  country_id  SERIAL,
  country     CHARACTER VARYING(50)       NOT NULL,
  last_update TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
  CONSTRAINT country_pkey PRIMARY KEY (country_id)
);

ALTER TABLE public.country
  OWNER TO sakila;

-- Trigger: last_updated

-- DROP TRIGGER last_updated ON public.country;

CREATE TRIGGER last_updated
BEFORE UPDATE
  ON public.country
FOR EACH ROW
EXECUTE PROCEDURE public.last_updated();

-- Table: public.customer

-- DROP TABLE public.customer;

CREATE TABLE public.customer
(
  customer_id SERIAL,
  store_id    SMALLINT              NOT NULL,
  first_name  CHARACTER VARYING(45) NOT NULL,
  last_name   CHARACTER VARYING(45) NOT NULL,
  email       CHARACTER VARYING(50),
  address_id  SMALLINT              NOT NULL,
  activebool  BOOLEAN               NOT NULL DEFAULT TRUE,
  create_date DATE                  NOT NULL DEFAULT ('now' :: TEXT) :: DATE,
  last_update TIMESTAMP WITHOUT TIME ZONE    DEFAULT now(),
  active      INTEGER,
  CONSTRAINT customer_pkey PRIMARY KEY (customer_id),
  CONSTRAINT customer_address_id_fkey FOREIGN KEY (address_id)
  REFERENCES public.address (address_id) MATCH SIMPLE
  ON UPDATE CASCADE
  ON DELETE RESTRICT,
  CONSTRAINT customer_store_id_fkey FOREIGN KEY (store_id)
  REFERENCES public.store (store_id) MATCH SIMPLE
  ON UPDATE CASCADE
  ON DELETE RESTRICT
);

ALTER TABLE public.customer
  OWNER TO sakila;

-- Index: idx_fk_address_id

-- DROP INDEX public.idx_fk_address_id;

CREATE INDEX idx_fk_address_id
  ON public.customer USING BTREE
  (address_id);

-- Index: idx_fk_store_id

-- DROP INDEX public.idx_fk_store_id;

CREATE INDEX idx_fk_store_id
  ON public.customer USING BTREE
  (store_id);

-- Index: idx_last_name

-- DROP INDEX public.idx_last_name;

CREATE INDEX idx_last_name
  ON public.customer USING BTREE
  (last_name);

-- Trigger: last_updated

-- DROP TRIGGER last_updated ON public.customer;

CREATE TRIGGER last_updated
BEFORE UPDATE
  ON public.customer
FOR EACH ROW
EXECUTE PROCEDURE public.last_updated();

-- Table: public.film

-- DROP TABLE public.film;

CREATE TABLE public.film
(
  film_id              SERIAL,
  title                CHARACTER VARYING(255)      NOT NULL,
  description          TEXT,
  release_year         YEAR,
  language_id          SMALLINT                    NOT NULL,
  original_language_id SMALLINT,
  rental_duration      SMALLINT                    NOT NULL DEFAULT 3,
  rental_rate          NUMERIC(4, 2)               NOT NULL DEFAULT 4.99,
  length               SMALLINT,
  replacement_cost     NUMERIC(5, 2)               NOT NULL DEFAULT 19.99,
  rating               MPAA_RATING                          DEFAULT 'G' :: MPAA_RATING,
  last_update          TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
  special_features     TEXT [],
  fulltext             TSVECTOR                    NOT NULL,
  CONSTRAINT film_pkey PRIMARY KEY (film_id),
  CONSTRAINT film_language_id_fkey FOREIGN KEY (language_id)
  REFERENCES public.language (language_id) MATCH SIMPLE
  ON UPDATE CASCADE
  ON DELETE RESTRICT,
  CONSTRAINT film_original_language_id_fkey FOREIGN KEY (original_language_id)
  REFERENCES public.language (language_id) MATCH SIMPLE
  ON UPDATE CASCADE
  ON DELETE RESTRICT
);

ALTER TABLE public.film
  OWNER TO sakila;

-- Index: film_fulltext_idx

-- DROP INDEX public.film_fulltext_idx;

CREATE INDEX film_fulltext_idx
  ON public.film USING GIST
  (fulltext);

-- Index: idx_fk_language_id

-- DROP INDEX public.idx_fk_language_id;

CREATE INDEX idx_fk_language_id
  ON public.film USING BTREE
  (language_id);

-- Index: idx_fk_original_language_id

-- DROP INDEX public.idx_fk_original_language_id;

CREATE INDEX idx_fk_original_language_id
  ON public.film USING BTREE
  (original_language_id);

-- Index: idx_title

-- DROP INDEX public.idx_title;

CREATE INDEX idx_title
  ON public.film USING BTREE
  (title);

-- Trigger: film_fulltext_trigger

-- DROP TRIGGER film_fulltext_trigger ON public.film;

CREATE TRIGGER film_fulltext_trigger
BEFORE INSERT OR UPDATE
  ON public.film
FOR EACH ROW
EXECUTE PROCEDURE tsvector_update_trigger('fulltext', 'pg_catalog.english', 'title', 'description');

-- Trigger: last_updated

-- DROP TRIGGER last_updated ON public.film;

CREATE TRIGGER last_updated
BEFORE UPDATE
  ON public.film
FOR EACH ROW
EXECUTE PROCEDURE public.last_updated();

-- Table: public.film_actor

-- DROP TABLE public.film_actor;

CREATE TABLE public.film_actor
(
  actor_id    SMALLINT                    NOT NULL,
  film_id     SMALLINT                    NOT NULL,
  last_update TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
  CONSTRAINT film_actor_pkey PRIMARY KEY (actor_id, film_id),
  CONSTRAINT film_actor_actor_id_fkey FOREIGN KEY (actor_id)
  REFERENCES public.actor (actor_id) MATCH SIMPLE
  ON UPDATE CASCADE
  ON DELETE RESTRICT,
  CONSTRAINT film_actor_film_id_fkey FOREIGN KEY (film_id)
  REFERENCES public.film (film_id) MATCH SIMPLE
  ON UPDATE CASCADE
  ON DELETE RESTRICT
);

ALTER TABLE public.film_actor
  OWNER TO sakila;

-- Index: idx_fk_film_id

-- DROP INDEX public.idx_fk_film_id;

CREATE INDEX idx_fk_film_id
  ON public.film_actor USING BTREE
  (film_id);

-- Trigger: last_updated

-- DROP TRIGGER last_updated ON public.film_actor;

CREATE TRIGGER last_updated
BEFORE UPDATE
  ON public.film_actor
FOR EACH ROW
EXECUTE PROCEDURE public.last_updated();

-- Table: public.film_category

-- DROP TABLE public.film_category;

CREATE TABLE public.film_category
(
  film_id     SMALLINT                    NOT NULL,
  category_id SMALLINT                    NOT NULL,
  last_update TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
  CONSTRAINT film_category_pkey PRIMARY KEY (film_id, category_id),
  CONSTRAINT film_category_category_id_fkey FOREIGN KEY (category_id)
  REFERENCES public.category (category_id) MATCH SIMPLE
  ON UPDATE CASCADE
  ON DELETE RESTRICT,
  CONSTRAINT film_category_film_id_fkey FOREIGN KEY (film_id)
  REFERENCES public.film (film_id) MATCH SIMPLE
  ON UPDATE CASCADE
  ON DELETE RESTRICT
);

ALTER TABLE public.film_category
  OWNER TO sakila;

-- Trigger: last_updated

-- DROP TRIGGER last_updated ON public.film_category;

CREATE TRIGGER last_updated
BEFORE UPDATE
  ON public.film_category
FOR EACH ROW
EXECUTE PROCEDURE public.last_updated();

-- Table: public.inventory

-- DROP TABLE public.inventory;

CREATE TABLE public.inventory
(
  inventory_id SERIAL,
  film_id      SMALLINT                    NOT NULL,
  store_id     SMALLINT                    NOT NULL,
  last_update  TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
  CONSTRAINT inventory_pkey PRIMARY KEY (inventory_id),
  CONSTRAINT inventory_film_id_fkey FOREIGN KEY (film_id)
  REFERENCES public.film (film_id) MATCH SIMPLE
  ON UPDATE CASCADE
  ON DELETE RESTRICT,
  CONSTRAINT inventory_store_id_fkey FOREIGN KEY (store_id)
  REFERENCES public.store (store_id) MATCH SIMPLE
  ON UPDATE CASCADE
  ON DELETE RESTRICT
);

ALTER TABLE public.inventory
  OWNER TO sakila;

-- Index: idx_store_id_film_id

-- DROP INDEX public.idx_store_id_film_id;

CREATE INDEX idx_store_id_film_id
  ON public.inventory USING BTREE
  (store_id, film_id);

-- Trigger: last_updated

-- DROP TRIGGER last_updated ON public.inventory;

CREATE TRIGGER last_updated
BEFORE UPDATE
  ON public.inventory
FOR EACH ROW
EXECUTE PROCEDURE public.last_updated();

-- Table: public.language

-- DROP TABLE public.language;

CREATE TABLE public.language
(
  language_id INTEGER                     NOT NULL DEFAULT nextval(
      'language_language_id_seq' :: REGCLASS),
  name        CHARACTER(20)               NOT NULL,
  last_update TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
  CONSTRAINT language_pkey PRIMARY KEY (language_id)
);

ALTER TABLE public.language
  OWNER TO sakila;

-- Trigger: last_updated

-- DROP TRIGGER last_updated ON public.language;

CREATE TRIGGER last_updated
BEFORE UPDATE
  ON public.language
FOR EACH ROW
EXECUTE PROCEDURE public.last_updated();

-- Table: public.payment

-- DROP TABLE public.payment;

CREATE TABLE public.payment
(
  payment_id   SERIAL,
  customer_id  SMALLINT                    NOT NULL,
  staff_id     SMALLINT                    NOT NULL,
  rental_id    INTEGER                     NOT NULL,
  amount       NUMERIC(5, 2)               NOT NULL,
  payment_date TIMESTAMP WITHOUT TIME ZONE NOT NULL,
  CONSTRAINT payment_pkey PRIMARY KEY (payment_id),
  CONSTRAINT payment_customer_id_fkey FOREIGN KEY (customer_id)
  REFERENCES public.customer (customer_id) MATCH SIMPLE
  ON UPDATE CASCADE
  ON DELETE RESTRICT,
  CONSTRAINT payment_rental_id_fkey FOREIGN KEY (rental_id)
  REFERENCES public.rental (rental_id) MATCH SIMPLE
  ON UPDATE CASCADE
  ON DELETE SET NULL,
  CONSTRAINT payment_staff_id_fkey FOREIGN KEY (staff_id)
  REFERENCES public.staff (staff_id) MATCH SIMPLE
  ON UPDATE CASCADE
  ON DELETE RESTRICT
);

ALTER TABLE public.payment
  OWNER TO sakila;

-- Index: idx_fk_customer_id

-- DROP INDEX public.idx_fk_customer_id;

CREATE INDEX idx_fk_customer_id
  ON public.payment USING BTREE
  (customer_id);

-- Index: idx_fk_staff_id

-- DROP INDEX public.idx_fk_staff_id;

CREATE INDEX idx_fk_staff_id
  ON public.payment USING BTREE
  (staff_id);

-- Rule: payment_insert_p2017_01 ON public.payment

-- DROP Rule payment_insert_p2017_01 ON public.payment;

CREATE OR REPLACE RULE payment_insert_p2017_01 AS
ON INSERT TO public.payment
  WHERE new.payment_date >= '2017-01-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE AND
        new.payment_date < '2017-02-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE
DO INSTEAD
  INSERT INTO payment_p2017_01 (payment_id, customer_id, staff_id, rental_id, amount, payment_date)
  VALUES (DEFAULT, new.customer_id, new.staff_id, new.rental_id, new.amount, new.payment_date);

-- Rule: payment_insert_p2017_02 ON public.payment

-- DROP Rule payment_insert_p2017_02 ON public.payment;

CREATE OR REPLACE RULE payment_insert_p2017_02 AS
ON INSERT TO public.payment
  WHERE new.payment_date >= '2017-02-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE AND
        new.payment_date < '2017-03-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE
DO INSTEAD
  INSERT INTO payment_p2017_02 (payment_id, customer_id, staff_id, rental_id, amount, payment_date)
  VALUES (DEFAULT, new.customer_id, new.staff_id, new.rental_id, new.amount, new.payment_date);

-- Rule: payment_insert_p2017_03 ON public.payment

-- DROP Rule payment_insert_p2017_03 ON public.payment;

CREATE OR REPLACE RULE payment_insert_p2017_03 AS
ON INSERT TO public.payment
  WHERE new.payment_date >= '2017-03-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE AND
        new.payment_date < '2017-04-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE
DO INSTEAD
  INSERT INTO payment_p2017_03 (payment_id, customer_id, staff_id, rental_id, amount, payment_date)
  VALUES (DEFAULT, new.customer_id, new.staff_id, new.rental_id, new.amount, new.payment_date);

-- Rule: payment_insert_p2017_04 ON public.payment

-- DROP Rule payment_insert_p2017_04 ON public.payment;

CREATE OR REPLACE RULE payment_insert_p2017_04 AS
ON INSERT TO public.payment
  WHERE new.payment_date >= '2017-04-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE AND
        new.payment_date < '2017-05-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE
DO INSTEAD
  INSERT INTO payment_p2017_04 (payment_id, customer_id, staff_id, rental_id, amount, payment_date)
  VALUES (DEFAULT, new.customer_id, new.staff_id, new.rental_id, new.amount, new.payment_date);

-- Rule: payment_insert_p2017_05 ON public.payment

-- DROP Rule payment_insert_p2017_05 ON public.payment;

CREATE OR REPLACE RULE payment_insert_p2017_05 AS
ON INSERT TO public.payment
  WHERE new.payment_date >= '2017-05-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE AND
        new.payment_date < '2017-06-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE
DO INSTEAD
  INSERT INTO payment_p2017_05 (payment_id, customer_id, staff_id, rental_id, amount, payment_date)
  VALUES (DEFAULT, new.customer_id, new.staff_id, new.rental_id, new.amount, new.payment_date);

-- Rule: payment_insert_p2017_06 ON public.payment

-- DROP Rule payment_insert_p2017_06 ON public.payment;

CREATE OR REPLACE RULE payment_insert_p2017_06 AS
ON INSERT TO public.payment
  WHERE new.payment_date >= '2017-06-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE AND
        new.payment_date < '2017-07-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE
DO INSTEAD
  INSERT INTO payment_p2017_06 (payment_id, customer_id, staff_id, rental_id, amount, payment_date)
  VALUES (DEFAULT, new.customer_id, new.staff_id, new.rental_id, new.amount, new.payment_date);

-- Table: public.payment_p2017_01

-- DROP TABLE public.payment_p2017_01;

CREATE TABLE public.payment_p2017_01
(
  payment_id,
  customer_id,
  staff_id,
  rental_id,
  amount,
  payment_date,
  CONSTRAINT payment_p2017_01_customer_id_fkey FOREIGN KEY (customer_id)
  REFERENCES PUBLIC.customer (customer_id) MATCH SIMPLE
                                           ON UPDATE NO ACTION
                                           ON DELETE NO ACTION,
  CONSTRAINT payment_p2017_01_rental_id_fkey FOREIGN KEY (rental_id)
  REFERENCES PUBLIC.rental (rental_id) MATCH SIMPLE
                                       ON UPDATE NO ACTION
                                       ON DELETE NO ACTION,
  CONSTRAINT payment_p2017_01_staff_id_fkey FOREIGN KEY (staff_id)
  REFERENCES PUBLIC.staff (staff_id) MATCH SIMPLE
                                     ON UPDATE NO ACTION
                                     ON DELETE NO ACTION,
  CONSTRAINT payment_p2017_01_payment_date_check CHECK (payment_date >= '2017-01-01 00:00:00':: TIMESTAMP WITHOUT TIME ZONE AND payment_date < '2017-02-01 00:00:00':: TIMESTAMP WITHOUT TIME ZONE)
)INHERITS ( PUBLIC.payment);

ALTER TABLE public.payment_p2017_01
  OWNER TO sakila;

-- Index: idx_fk_payment_p2017_01_customer_id

-- DROP INDEX public.idx_fk_payment_p2017_01_customer_id;

CREATE INDEX idx_fk_payment_p2017_01_customer_id
  ON public.payment_p2017_01 USING BTREE
  (customer_id);

-- Index: idx_fk_payment_p2017_01_staff_id

-- DROP INDEX public.idx_fk_payment_p2017_01_staff_id;

CREATE INDEX idx_fk_payment_p2017_01_staff_id
  ON public.payment_p2017_01 USING BTREE
  (staff_id);

-- Table: public.payment_p2017_02

-- DROP TABLE public.payment_p2017_02;

CREATE TABLE public.payment_p2017_02
(
  payment_id,
  customer_id,
  staff_id,
  rental_id,
  amount,
  payment_date,
  CONSTRAINT payment_p2017_02_customer_id_fkey FOREIGN KEY (customer_id)
  REFERENCES PUBLIC.customer (customer_id) MATCH SIMPLE
                                           ON UPDATE NO ACTION
                                           ON DELETE NO ACTION,
  CONSTRAINT payment_p2017_02_rental_id_fkey FOREIGN KEY (rental_id)
  REFERENCES PUBLIC.rental (rental_id) MATCH SIMPLE
                                       ON UPDATE NO ACTION
                                       ON DELETE NO ACTION,
  CONSTRAINT payment_p2017_02_staff_id_fkey FOREIGN KEY (staff_id)
  REFERENCES PUBLIC.staff (staff_id) MATCH SIMPLE
                                     ON UPDATE NO ACTION
                                     ON DELETE NO ACTION,
  CONSTRAINT payment_p2017_02_payment_date_check CHECK (payment_date >= '2017-02-01 00:00:00':: TIMESTAMP WITHOUT TIME ZONE AND payment_date < '2017-03-01 00:00:00':: TIMESTAMP WITHOUT TIME ZONE)
)INHERITS ( PUBLIC.payment);

ALTER TABLE public.payment_p2017_02
  OWNER TO sakila;

-- Index: idx_fk_payment_p2017_02_customer_id

-- DROP INDEX public.idx_fk_payment_p2017_02_customer_id;

CREATE INDEX idx_fk_payment_p2017_02_customer_id
  ON public.payment_p2017_02 USING BTREE
  (customer_id);

-- Index: idx_fk_payment_p2017_02_staff_id

-- DROP INDEX public.idx_fk_payment_p2017_02_staff_id;

CREATE INDEX idx_fk_payment_p2017_02_staff_id
  ON public.payment_p2017_02 USING BTREE
  (staff_id);

-- Table: public.payment_p2017_03

-- DROP TABLE public.payment_p2017_03;

CREATE TABLE public.payment_p2017_03
(
  payment_id,
  customer_id,
  staff_id,
  rental_id,
  amount,
  payment_date,
  CONSTRAINT payment_p2017_03_customer_id_fkey FOREIGN KEY (customer_id)
  REFERENCES PUBLIC.customer (customer_id) MATCH SIMPLE
                                           ON UPDATE NO ACTION
                                           ON DELETE NO ACTION,
  CONSTRAINT payment_p2017_03_rental_id_fkey FOREIGN KEY (rental_id)
  REFERENCES PUBLIC.rental (rental_id) MATCH SIMPLE
                                       ON UPDATE NO ACTION
                                       ON DELETE NO ACTION,
  CONSTRAINT payment_p2017_03_staff_id_fkey FOREIGN KEY (staff_id)
  REFERENCES PUBLIC.staff (staff_id) MATCH SIMPLE
                                     ON UPDATE NO ACTION
                                     ON DELETE NO ACTION,
  CONSTRAINT payment_p2017_03_payment_date_check CHECK (payment_date >= '2017-03-01 00:00:00':: TIMESTAMP WITHOUT TIME ZONE AND payment_date < '2017-04-01 00:00:00':: TIMESTAMP WITHOUT TIME ZONE)
)INHERITS ( PUBLIC.payment);

ALTER TABLE public.payment_p2017_03
  OWNER TO sakila;

-- Index: idx_fk_payment_p2017_03_customer_id

-- DROP INDEX public.idx_fk_payment_p2017_03_customer_id;

CREATE INDEX idx_fk_payment_p2017_03_customer_id
  ON public.payment_p2017_03 USING BTREE
  (customer_id);

-- Index: idx_fk_payment_p2017_03_staff_id

-- DROP INDEX public.idx_fk_payment_p2017_03_staff_id;

CREATE INDEX idx_fk_payment_p2017_03_staff_id
  ON public.payment_p2017_03 USING BTREE
  (staff_id);

-- Table: public.payment_p2017_04

-- DROP TABLE public.payment_p2017_04;

CREATE TABLE public.payment_p2017_04
(
  payment_id,
  customer_id,
  staff_id,
  rental_id,
  amount,
  payment_date,
  CONSTRAINT payment_p2017_04_customer_id_fkey FOREIGN KEY (customer_id)
  REFERENCES PUBLIC.customer (customer_id) MATCH SIMPLE
                                           ON UPDATE NO ACTION
                                           ON DELETE NO ACTION,
  CONSTRAINT payment_p2017_04_rental_id_fkey FOREIGN KEY (rental_id)
  REFERENCES PUBLIC.rental (rental_id) MATCH SIMPLE
                                       ON UPDATE NO ACTION
                                       ON DELETE NO ACTION,
  CONSTRAINT payment_p2017_04_staff_id_fkey FOREIGN KEY (staff_id)
  REFERENCES PUBLIC.staff (staff_id) MATCH SIMPLE
                                     ON UPDATE NO ACTION
                                     ON DELETE NO ACTION,
  CONSTRAINT payment_p2017_04_payment_date_check CHECK (payment_date >= '2017-04-01 00:00:00':: TIMESTAMP WITHOUT TIME ZONE AND payment_date < '2017-05-01 00:00:00':: TIMESTAMP WITHOUT TIME ZONE)
)INHERITS( PUBLIC.payment);

ALTER TABLE public.payment_p2017_04
  OWNER TO sakila;

-- Index: idx_fk_payment_p2017_04_customer_id

-- DROP INDEX public.idx_fk_payment_p2017_04_customer_id;

CREATE INDEX idx_fk_payment_p2017_04_customer_id
  ON public.payment_p2017_04 USING BTREE
  (customer_id);

-- Index: idx_fk_payment_p2017_04_staff_id

-- DROP INDEX public.idx_fk_payment_p2017_04_staff_id;

CREATE INDEX idx_fk_payment_p2017_04_staff_id
  ON public.payment_p2017_04 USING BTREE
  (staff_id);

-- Table: public.payment_p2017_05

-- DROP TABLE public.payment_p2017_05;

CREATE TABLE public.payment_p2017_05
(
  payment_id,
  customer_id,
  staff_id,
  rental_id,
  amount,
  payment_date,
  CONSTRAINT payment_p2017_05_customer_id_fkey FOREIGN KEY (customer_id)
  REFERENCES PUBLIC.customer (customer_id) MATCH SIMPLE
                                           ON UPDATE NO ACTION
                                           ON DELETE NO ACTION,
  CONSTRAINT payment_p2017_05_rental_id_fkey FOREIGN KEY (rental_id)
  REFERENCES PUBLIC.rental (rental_id) MATCH SIMPLE
                                       ON UPDATE NO ACTION
                                       ON DELETE NO ACTION,
  CONSTRAINT payment_p2017_05_staff_id_fkey FOREIGN KEY (staff_id)
  REFERENCES PUBLIC.staff (staff_id) MATCH SIMPLE
                                     ON UPDATE NO ACTION
                                     ON DELETE NO ACTION,
  CONSTRAINT payment_p2017_05_payment_date_check CHECK (payment_date >= '2017-05-01 00:00:00':: TIMESTAMP WITHOUT TIME ZONE AND payment_date < '2017-06-01 00:00:00':: TIMESTAMP WITHOUT TIME ZONE)
)INHERITS ( PUBLIC.payment);

ALTER TABLE public.payment_p2017_05
  OWNER TO sakila;

-- Index: idx_fk_payment_p2017_05_customer_id

-- DROP INDEX public.idx_fk_payment_p2017_05_customer_id;

CREATE INDEX idx_fk_payment_p2017_05_customer_id
  ON public.payment_p2017_05 USING BTREE
  (customer_id);

-- Index: idx_fk_payment_p2017_05_staff_id

-- DROP INDEX public.idx_fk_payment_p2017_05_staff_id;

CREATE INDEX idx_fk_payment_p2017_05_staff_id
  ON public.payment_p2017_05 USING BTREE
  (staff_id);

-- Table: public.payment_p2017_06

-- DROP TABLE public.payment_p2017_06;

CREATE TABLE public.payment_p2017_06
(
  payment_id,
  customer_id,
  staff_id,
  rental_id,
  amount,
  payment_date,
  CONSTRAINT payment_p2017_06_customer_id_fkey FOREIGN KEY (customer_id)
  REFERENCES PUBLIC.customer (customer_id) MATCH SIMPLE
                                           ON UPDATE NO ACTION
                                           ON DELETE NO ACTION,
  CONSTRAINT payment_p2017_06_rental_id_fkey FOREIGN KEY (rental_id)
  REFERENCES PUBLIC.rental (rental_id) MATCH SIMPLE
                                       ON UPDATE NO ACTION
                                       ON DELETE NO ACTION,
  CONSTRAINT payment_p2017_06_staff_id_fkey FOREIGN KEY (staff_id)
  REFERENCES PUBLIC.staff (staff_id) MATCH SIMPLE
                                     ON UPDATE NO ACTION
                                     ON DELETE NO ACTION,
  CONSTRAINT payment_p2017_06_payment_date_check CHECK (payment_date >= '2017-06-01 00:00:00':: TIMESTAMP WITHOUT TIME ZONE AND payment_date < '2017-07-01 00:00:00':: TIMESTAMP WITHOUT TIME ZONE)
)INHERITS ( PUBLIC.payment);

ALTER TABLE public.payment_p2017_06
  OWNER TO sakila;

-- Index: idx_fk_payment_p2017_06_customer_id

-- DROP INDEX public.idx_fk_payment_p2017_06_customer_id;

CREATE INDEX idx_fk_payment_p2017_06_customer_id
  ON public.payment_p2017_06 USING BTREE
  (customer_id);

-- Index: idx_fk_payment_p2017_06_staff_id

-- DROP INDEX public.idx_fk_payment_p2017_06_staff_id;

CREATE INDEX idx_fk_payment_p2017_06_staff_id
  ON public.payment_p2017_06 USING BTREE
  (staff_id);

-- Table: public.rental

-- DROP TABLE public.rental;

CREATE TABLE public.rental
(
  rental_id    SERIAL,
  rental_date  TIMESTAMP WITHOUT TIME ZONE NOT NULL,
  inventory_id INTEGER                     NOT NULL,
  customer_id  SMALLINT                    NOT NULL,
  return_date  TIMESTAMP WITHOUT TIME ZONE,
  staff_id     SMALLINT                    NOT NULL,
  last_update  TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
  CONSTRAINT rental_pkey PRIMARY KEY (rental_id),
  CONSTRAINT rental_customer_id_fkey FOREIGN KEY (customer_id)
  REFERENCES public.customer (customer_id) MATCH SIMPLE
  ON UPDATE CASCADE
  ON DELETE RESTRICT,
  CONSTRAINT rental_inventory_id_fkey FOREIGN KEY (inventory_id)
  REFERENCES public.inventory (inventory_id) MATCH SIMPLE
  ON UPDATE CASCADE
  ON DELETE RESTRICT,
  CONSTRAINT rental_staff_id_fkey FOREIGN KEY (staff_id)
  REFERENCES public.staff (staff_id) MATCH SIMPLE
  ON UPDATE CASCADE
  ON DELETE RESTRICT
);

ALTER TABLE public.rental
  OWNER TO sakila;

-- Index: idx_fk_inventory_id

-- DROP INDEX public.idx_fk_inventory_id;

CREATE INDEX idx_fk_inventory_id
  ON public.rental USING BTREE
  (inventory_id);

-- Index: idx_unq_rental_rental_date_inventory_id_customer_id

-- DROP INDEX public.idx_unq_rental_rental_date_inventory_id_customer_id;

CREATE UNIQUE INDEX idx_unq_rental_rental_date_inventory_id_customer_id
  ON public.rental USING BTREE
  (rental_date, inventory_id, customer_id);

-- Trigger: last_updated

-- DROP TRIGGER last_updated ON public.rental;

CREATE TRIGGER last_updated
BEFORE UPDATE
  ON public.rental
FOR EACH ROW
EXECUTE PROCEDURE public.last_updated();

-- Table: public.staff

-- DROP TABLE public.staff;

CREATE TABLE public.staff
(
  staff_id    SERIAL,
  first_name  CHARACTER VARYING(45)       NOT NULL,
  last_name   CHARACTER VARYING(45)       NOT NULL,
  address_id  SMALLINT                    NOT NULL,
  email       CHARACTER VARYING(50),
  store_id    SMALLINT                    NOT NULL,
  active      BOOLEAN                     NOT NULL DEFAULT TRUE,
  username    CHARACTER VARYING(16)       NOT NULL,
  password    CHARACTER VARYING(40),
  last_update TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
  picture     BYTEA,
  CONSTRAINT staff_pkey PRIMARY KEY (staff_id),
  CONSTRAINT staff_address_id_fkey FOREIGN KEY (address_id)
  REFERENCES public.address (address_id) MATCH SIMPLE
  ON UPDATE CASCADE
  ON DELETE RESTRICT,
  CONSTRAINT staff_store_id_fkey FOREIGN KEY (store_id)
  REFERENCES public.store (store_id) MATCH SIMPLE
  ON UPDATE NO ACTION
  ON DELETE NO ACTION
);

ALTER TABLE public.staff
  OWNER TO sakila;

-- Trigger: last_updated

-- DROP TRIGGER last_updated ON public.staff;

CREATE TRIGGER last_updated
BEFORE UPDATE
  ON public.staff
FOR EACH ROW
EXECUTE PROCEDURE public.last_updated();

-- Table: public.store

-- DROP TABLE public.store;

CREATE TABLE public.store
(
  store_id         SERIAL,
  manager_staff_id SMALLINT                    NOT NULL,
  address_id       SMALLINT                    NOT NULL,
  last_update      TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
  CONSTRAINT store_pkey PRIMARY KEY (store_id),
  CONSTRAINT store_address_id_fkey FOREIGN KEY (address_id)
  REFERENCES public.address (address_id) MATCH SIMPLE
  ON UPDATE CASCADE
  ON DELETE RESTRICT
);

ALTER TABLE public.store
  OWNER TO sakila;

-- Index: idx_unq_manager_staff_id

-- DROP INDEX public.idx_unq_manager_staff_id;

CREATE UNIQUE INDEX idx_unq_manager_staff_id
  ON public.store USING BTREE
  (manager_staff_id);

-- Trigger: last_updated

-- DROP TRIGGER last_updated ON public.store;

CREATE TRIGGER last_updated
BEFORE UPDATE
  ON public.store
FOR EACH ROW
EXECUTE PROCEDURE public.last_updated();

-- FUNCTION: public.last_updated()

-- DROP FUNCTION public.last_updated();

CREATE FUNCTION public.last_updated()
  RETURNS TRIGGER
LANGUAGE 'plpgsql'
COST 100
VOLATILE NOT LEAKPROOF
AS $BODY$

BEGIN
  NEW.last_update = CURRENT_TIMESTAMP;
  RETURN NEW;
END
$BODY$;

ALTER FUNCTION public.last_updated()
OWNER TO sakila;

-- FUNCTION: public._group_concat(text, text)

-- DROP FUNCTION public._group_concat(text, text);

CREATE OR REPLACE FUNCTION public._group_concat(
    TEXT,
    TEXT)
  RETURNS TEXT
LANGUAGE 'sql'

COST 100
IMMUTABLE
AS $BODY$

SELECT CASE
       WHEN $2 IS NULL
         THEN $1
       WHEN $1 IS NULL
         THEN $2
       ELSE $1 || ', ' || $2
       END

$BODY$;

ALTER FUNCTION public._group_concat( TEXT, TEXT )
OWNER TO sakila;

-- FUNCTION: public.rewards_report(integer, numeric)

-- DROP FUNCTION public.rewards_report(integer, numeric);

CREATE OR REPLACE FUNCTION public.rewards_report(
  min_monthly_purchases       INTEGER,
  min_dollar_amount_purchased NUMERIC)
  RETURNS SETOF CUSTOMER
LANGUAGE 'plpgsql'

COST 100
VOLATILE SECURITY DEFINER
ROWS 1000
AS $BODY$

DECLARE
  last_month_start DATE;
  last_month_end   DATE;
  rr               RECORD;
  tmpSQL           TEXT;
BEGIN

  /* Some sanity checks... */
  IF min_monthly_purchases = 0
  THEN
    RAISE EXCEPTION 'Minimum monthly purchases parameter must be > 0';
  END IF;
  IF min_dollar_amount_purchased = 0.00
  THEN
    RAISE EXCEPTION 'Minimum monthly dollar amount purchased parameter must be > $0.00';
  END IF;

  last_month_start := CURRENT_DATE - '3 month' :: INTERVAL;
  last_month_start := to_date(
      (extract(YEAR FROM last_month_start) || '-' || extract(MONTH FROM last_month_start) || '-01'), 'YYYY-MM-DD');
  last_month_end := LAST_DAY(last_month_start);

  /*
  Create a temporary storage area for Customer IDs.
  */
  CREATE TEMPORARY TABLE tmpCustomer (
    customer_id INTEGER NOT NULL PRIMARY KEY
  );

  /*
  Find all customers meeting the monthly purchase requirements
  */

  tmpSQL := 'INSERT INTO tmpCustomer (customer_id)
        SELECT p.customer_id
        FROM payment AS p
        WHERE DATE(p.payment_date) BETWEEN ' || quote_literal(last_month_start) || ' AND ' ||
            quote_literal(last_month_end) || '
        GROUP BY customer_id
        HAVING SUM(p.amount) > ' || min_dollar_amount_purchased || '
        AND COUNT(customer_id) > ' || min_monthly_purchases;

  EXECUTE tmpSQL;

  /*
  Output ALL customer information of matching rewardees.
  Customize output as needed.
  */
  FOR rr IN EXECUTE 'SELECT c.* FROM tmpCustomer AS t INNER JOIN customer AS c ON t.customer_id = c.customer_id' LOOP
    RETURN NEXT rr;
  END LOOP;

  /* Clean up */
  tmpSQL := 'DROP TABLE tmpCustomer';
  EXECUTE tmpSQL;

  RETURN;
END

$BODY$;

ALTER FUNCTION public.rewards_report( INTEGER, NUMERIC )
OWNER TO sakila;

-- FUNCTION: public.last_day(timestamp without time zone)

-- DROP FUNCTION public.last_day(timestamp without time zone);

CREATE OR REPLACE FUNCTION public.last_day(
    TIMESTAMP WITHOUT TIME ZONE)
  RETURNS DATE
LANGUAGE 'sql'

COST 100
IMMUTABLE STRICT
AS $BODY$

SELECT CASE
       WHEN EXTRACT(MONTH FROM $1) = 12
         THEN
           (((EXTRACT(YEAR FROM $1) + 1) OPERATOR (pg_catalog.||) '-01-01') :: DATE - INTERVAL '1 day') :: DATE
       ELSE
         ((EXTRACT(YEAR FROM $1) OPERATOR (pg_catalog.||) '-' OPERATOR (pg_catalog.||) (EXTRACT(MONTH FROM $1) + 1)
           OPERATOR (pg_catalog.||) '-01') :: DATE - INTERVAL '1 day') :: DATE
       END

$BODY$;

ALTER FUNCTION public.last_day( TIMESTAMP WITHOUT TIME ZONE )
OWNER TO sakila;

-- FUNCTION: public.inventory_in_stock(integer)

-- DROP FUNCTION public.inventory_in_stock(integer);

CREATE OR REPLACE FUNCTION public.inventory_in_stock(
  p_inventory_id INTEGER)
  RETURNS BOOLEAN
LANGUAGE 'plpgsql'

COST 100
VOLATILE
AS $BODY$

DECLARE
  v_rentals INTEGER;
  v_out     INTEGER;
BEGIN
  -- AN ITEM IS IN-STOCK IF THERE ARE EITHER NO ROWS IN THE rental TABLE
  -- FOR THE ITEM OR ALL ROWS HAVE return_date POPULATED

  SELECT count(*)
  INTO v_rentals
  FROM rental
  WHERE inventory_id = p_inventory_id;

  IF v_rentals = 0
  THEN
    RETURN TRUE;
  END IF;

  SELECT COUNT(rental_id)
  INTO v_out
  FROM inventory
    LEFT JOIN rental USING (inventory_id)
  WHERE inventory.inventory_id = p_inventory_id
        AND rental.return_date IS NULL;

  IF v_out > 0
  THEN
    RETURN FALSE;
  ELSE
    RETURN TRUE;
  END IF;
END
$BODY$;

ALTER FUNCTION public.inventory_in_stock( INTEGER )
OWNER TO sakila;

-- FUNCTION: public.inventory_held_by_customer(integer)

-- DROP FUNCTION public.inventory_held_by_customer(integer);

CREATE OR REPLACE FUNCTION public.inventory_held_by_customer(
  p_inventory_id INTEGER)
  RETURNS INTEGER
LANGUAGE 'plpgsql'

COST 100
VOLATILE
AS $BODY$

DECLARE
  v_customer_id INTEGER;
BEGIN

  SELECT customer_id
  INTO v_customer_id
  FROM rental
  WHERE return_date IS NULL
        AND inventory_id = p_inventory_id;

  RETURN v_customer_id;
END
$BODY$;

ALTER FUNCTION public.inventory_held_by_customer( INTEGER )
OWNER TO sakila;

-- FUNCTION: public.get_customer_balance(integer, timestamp without time zone)

-- DROP FUNCTION public.get_customer_balance(integer, timestamp without time zone);

CREATE OR REPLACE FUNCTION public.get_customer_balance(
  p_customer_id    INTEGER,
  p_effective_date TIMESTAMP WITHOUT TIME ZONE)
  RETURNS NUMERIC
LANGUAGE 'plpgsql'

COST 100
VOLATILE
AS $BODY$

--#OK, WE NEED TO CALCULATE THE CURRENT BALANCE GIVEN A CUSTOMER_ID AND A DATE
--#THAT WE WANT THE BALANCE TO BE EFFECTIVE FOR. THE BALANCE IS:
--#   1) RENTAL FEES FOR ALL PREVIOUS RENTALS
--#   2) ONE DOLLAR FOR EVERY DAY THE PREVIOUS RENTALS ARE OVERDUE
--#   3) IF A FILM IS MORE THAN RENTAL_DURATION * 2 OVERDUE, CHARGE THE REPLACEMENT_COST
--#   4) SUBTRACT ALL PAYMENTS MADE BEFORE THE DATE SPECIFIED
DECLARE
  v_rentfees DECIMAL(5, 2); --#FEES PAID TO RENT THE VIDEOS INITIALLY
  v_overfees INTEGER; --#LATE FEES FOR PRIOR RENTALS
  v_payments DECIMAL(5, 2); --#SUM OF PAYMENTS MADE PREVIOUSLY
BEGIN
  SELECT COALESCE(SUM(film.rental_rate), 0)
  INTO v_rentfees
  FROM film, inventory, rental
  WHERE film.film_id = inventory.film_id
        AND inventory.inventory_id = rental.inventory_id
        AND rental.rental_date <= p_effective_date
        AND rental.customer_id = p_customer_id;

  SELECT COALESCE(SUM(IF((rental.return_date - rental.rental_date) > (film.rental_duration * '1 day' :: INTERVAL),
                         ((rental.return_date - rental.rental_date) - (film.rental_duration * '1 day' :: INTERVAL)),
                         0)), 0)
  INTO v_overfees
  FROM rental, inventory, film
  WHERE film.film_id = inventory.film_id
        AND inventory.inventory_id = rental.inventory_id
        AND rental.rental_date <= p_effective_date
        AND rental.customer_id = p_customer_id;

  SELECT COALESCE(SUM(payment.amount), 0)
  INTO v_payments
  FROM payment
  WHERE payment.payment_date <= p_effective_date
        AND payment.customer_id = p_customer_id;

  RETURN v_rentfees + v_overfees - v_payments;
END

$BODY$;

ALTER FUNCTION public.get_customer_balance( INTEGER, TIMESTAMP WITHOUT TIME ZONE )
OWNER TO sakila;

-- FUNCTION: public.film_not_in_stock(integer, integer)

-- DROP FUNCTION public.film_not_in_stock(integer, integer);

CREATE OR REPLACE FUNCTION public.film_not_in_stock(
      p_film_id    INTEGER,
      p_store_id   INTEGER,
  OUT p_film_count INTEGER)
  RETURNS SETOF INTEGER
LANGUAGE 'sql'

COST 100
VOLATILE
ROWS 1000
AS $BODY$

SELECT inventory_id
FROM inventory
WHERE film_id = $1
      AND store_id = $2
      AND NOT inventory_in_stock(inventory_id);

$BODY$;

ALTER FUNCTION public.film_not_in_stock( INTEGER, INTEGER )
OWNER TO sakila;

-- FUNCTION: public.film_in_stock(integer, integer)

-- DROP FUNCTION public.film_in_stock(integer, integer);

CREATE OR REPLACE FUNCTION public.film_in_stock(
      p_film_id    INTEGER,
      p_store_id   INTEGER,
  OUT p_film_count INTEGER)
  RETURNS SETOF INTEGER
LANGUAGE 'sql'

COST 100
VOLATILE
ROWS 1000
AS $BODY$

SELECT inventory_id
FROM inventory
WHERE film_id = $1
      AND store_id = $2
      AND inventory_in_stock(inventory_id);

$BODY$;

ALTER FUNCTION public.film_in_stock( INTEGER, INTEGER )
OWNER TO sakila;

-- View: public.staff_list

-- DROP VIEW public.staff_list;

CREATE OR REPLACE VIEW public.staff_list AS
  SELECT
    s.staff_id                                                   AS id,
    (s.first_name :: TEXT || ' ' :: TEXT) || s.last_name :: TEXT AS name,
    a.address,
    a.postal_code                                                AS "zip code",
    a.phone,
    city.city,
    country.country,
    s.store_id                                                   AS sid
  FROM staff s
    JOIN address a ON s.address_id = a.address_id
    JOIN city ON a.city_id = city.city_id
    JOIN country ON city.country_id = country.country_id;

ALTER TABLE public.staff_list
  OWNER TO sakila;

-- View: public.sales_by_store

-- DROP VIEW public.sales_by_store;

CREATE OR REPLACE VIEW public.sales_by_store AS
  SELECT
    (c.city :: TEXT || ',' :: TEXT) || cy.country :: TEXT        AS store,
    (m.first_name :: TEXT || ' ' :: TEXT) || m.last_name :: TEXT AS manager,
    sum(p.amount)                                                AS total_sales
  FROM payment p
    JOIN rental r ON p.rental_id = r.rental_id
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN store s ON i.store_id = s.store_id
    JOIN address a ON s.address_id = a.address_id
    JOIN city c ON a.city_id = c.city_id
    JOIN country cy ON c.country_id = cy.country_id
    JOIN staff m ON s.manager_staff_id = m.staff_id
  GROUP BY cy.country, c.city, s.store_id, m.first_name, m.last_name
  ORDER BY cy.country, c.city;

ALTER TABLE public.sales_by_store
  OWNER TO sakila;

-- View: public.sales_by_film_category

-- DROP VIEW public.sales_by_film_category;

CREATE OR REPLACE VIEW public.sales_by_film_category AS
  SELECT
    c.name        AS category,
    sum(p.amount) AS total_sales
  FROM payment p
    JOIN rental r ON p.rental_id = r.rental_id
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN film f ON i.film_id = f.film_id
    JOIN film_category fc ON f.film_id = fc.film_id
    JOIN category c ON fc.category_id = c.category_id
  GROUP BY c.name
  ORDER BY (sum(p.amount)) DESC;

ALTER TABLE public.sales_by_film_category
  OWNER TO sakila;

-- View: public.nicer_but_slower_film_list

-- DROP VIEW public.nicer_but_slower_film_list;

CREATE OR REPLACE VIEW public.nicer_but_slower_film_list AS
  SELECT
    film.film_id                                                                                               AS fid,
    film.title,
    film.description,
    category.name                                                                                              AS category,
    film.rental_rate                                                                                           AS price,
    film.length,
    film.rating,
    group_concat(
        ((upper("substring"(actor.first_name :: TEXT, 1, 1)) || lower("substring"(actor.first_name :: TEXT, 2))) ||
         upper("substring"(actor.last_name :: TEXT, 1, 1))) || lower("substring"(actor.last_name :: TEXT, 2))) AS actors
  FROM category
    LEFT JOIN film_category ON category.category_id = film_category.category_id
    LEFT JOIN film ON film_category.film_id = film.film_id
    JOIN film_actor ON film.film_id = film_actor.film_id
    JOIN actor ON film_actor.actor_id = actor.actor_id
  GROUP BY film.film_id, film.title, film.description, category.name, film.rental_rate, film.length, film.rating;

ALTER TABLE public.nicer_but_slower_film_list
  OWNER TO sakila;

-- View: public.film_list

-- DROP VIEW public.film_list;

CREATE OR REPLACE VIEW public.film_list AS
  SELECT
    film.film_id                                                                       AS fid,
    film.title,
    film.description,
    category.name                                                                      AS category,
    film.rental_rate                                                                   AS price,
    film.length,
    film.rating,
    group_concat((actor.first_name :: TEXT || ' ' :: TEXT) || actor.last_name :: TEXT) AS actors
  FROM category
    LEFT JOIN film_category ON category.category_id = film_category.category_id
    LEFT JOIN film ON film_category.film_id = film.film_id
    JOIN film_actor ON film.film_id = film_actor.film_id
    JOIN actor ON film_actor.actor_id = actor.actor_id
  GROUP BY film.film_id, film.title, film.description, category.name, film.rental_rate, film.length, film.rating;

ALTER TABLE public.film_list
  OWNER TO sakila;

-- View: public.customer_list

-- DROP VIEW public.customer_list;

CREATE OR REPLACE VIEW public.customer_list AS
  SELECT
    cu.customer_id                                                 AS id,
    (cu.first_name :: TEXT || ' ' :: TEXT) || cu.last_name :: TEXT AS name,
    a.address,
    a.postal_code                                                  AS "zip code",
    a.phone,
    city.city,
    country.country,
    CASE
    WHEN cu.activebool
      THEN 'active' :: TEXT
    ELSE '' :: TEXT
    END                                                            AS notes,
    cu.store_id                                                    AS sid
  FROM customer cu
    JOIN address a ON cu.address_id = a.address_id
    JOIN city ON a.city_id = city.city_id
    JOIN country ON city.country_id = country.country_id;

ALTER TABLE public.customer_list
  OWNER TO sakila;

-- View: public.actor_info

-- DROP VIEW public.actor_info;

CREATE OR REPLACE VIEW public.actor_info AS
  SELECT
    a.actor_id,
    a.first_name,
    a.last_name,
    group_concat(DISTINCT (c.name :: TEXT || ': ' :: TEXT) || ((SELECT group_concat(f.title :: TEXT) AS group_concat
                                                                FROM film f
                                                                  JOIN film_category fc_1 ON f.film_id = fc_1.film_id
                                                                  JOIN film_actor fa_1 ON f.film_id = fa_1.film_id
                                                                WHERE fc_1.category_id = c.category_id AND
                                                                      fa_1.actor_id = a.actor_id
                                                                GROUP BY fa_1.actor_id))) AS film_info
  FROM actor a
    LEFT JOIN film_actor fa ON a.actor_id = fa.actor_id
    LEFT JOIN film_category fc ON fa.film_id = fc.film_id
    LEFT JOIN category c ON fc.category_id = c.category_id
  GROUP BY a.actor_id, a.first_name, a.last_name;

ALTER TABLE public.actor_info
  OWNER TO sakila;
