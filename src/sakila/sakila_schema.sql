--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.3
-- Dumped by pg_dump version 10beta1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = ON;
SET check_function_bodies = FALSE;
SET client_min_messages = WARNING;
SET row_security = OFF;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;

--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: mpaa_rating; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE MPAA_RATING AS ENUM (
  'G',
  'PG',
  'PG-13',
  'R',
  'NC-17'
);


ALTER TYPE MPAA_RATING
OWNER TO postgres;

--
-- Name: year; Type: DOMAIN; Schema: public; Owner: postgres
--

CREATE DOMAIN year AS INTEGER
  CONSTRAINT year_check CHECK (((VALUE >= 1901) AND (VALUE <= 2155)));


ALTER DOMAIN year
OWNER TO postgres;

--
-- Name: _group_concat(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _group_concat(TEXT, TEXT)
  RETURNS TEXT
LANGUAGE SQL IMMUTABLE
AS $_$
SELECT CASE
       WHEN $2 IS NULL
         THEN $1
       WHEN $1 IS NULL
         THEN $2
       ELSE $1 || ', ' || $2
       END
$_$;


ALTER FUNCTION public._group_concat( TEXT, TEXT )
OWNER TO postgres;

--
-- Name: film_in_stock(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION film_in_stock(p_film_id INTEGER, p_store_id INTEGER, OUT p_film_count INTEGER)
  RETURNS SETOF INTEGER
LANGUAGE SQL
AS $_$
SELECT inventory_id
FROM inventory
WHERE film_id = $1
      AND store_id = $2
      AND inventory_in_stock(inventory_id);
$_$;


ALTER FUNCTION public.film_in_stock(p_film_id INTEGER, p_store_id INTEGER, OUT p_film_count INTEGER )
OWNER TO postgres;

--
-- Name: film_not_in_stock(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION film_not_in_stock(p_film_id INTEGER, p_store_id INTEGER, OUT p_film_count INTEGER)
  RETURNS SETOF INTEGER
LANGUAGE SQL
AS $_$
SELECT inventory_id
FROM inventory
WHERE film_id = $1
      AND store_id = $2
      AND NOT inventory_in_stock(inventory_id);
$_$;


ALTER FUNCTION public.film_not_in_stock(p_film_id INTEGER, p_store_id INTEGER, OUT p_film_count INTEGER )
OWNER TO postgres;

--
-- Name: get_customer_balance(integer, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_customer_balance(p_customer_id INTEGER, p_effective_date TIMESTAMP WITHOUT TIME ZONE)
  RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
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
$$;


ALTER FUNCTION public.get_customer_balance(p_customer_id INTEGER, p_effective_date TIMESTAMP WITHOUT TIME ZONE )
OWNER TO postgres;

--
-- Name: inventory_held_by_customer(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION inventory_held_by_customer(p_inventory_id INTEGER)
  RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_customer_id INTEGER;
BEGIN

  SELECT customer_id
  INTO v_customer_id
  FROM rental
  WHERE return_date IS NULL
        AND inventory_id = p_inventory_id;

  RETURN v_customer_id;
END $$;


ALTER FUNCTION public.inventory_held_by_customer(p_inventory_id INTEGER )
OWNER TO postgres;

--
-- Name: inventory_in_stock(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION inventory_in_stock(p_inventory_id INTEGER)
  RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
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
END $$;


ALTER FUNCTION public.inventory_in_stock(p_inventory_id INTEGER )
OWNER TO postgres;

--
-- Name: last_day(timestamp without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION last_day(TIMESTAMP WITHOUT TIME ZONE)
  RETURNS DATE
LANGUAGE SQL IMMUTABLE STRICT
AS $_$
SELECT CASE
       WHEN EXTRACT(MONTH FROM $1) = 12
         THEN
           (((EXTRACT(YEAR FROM $1) + 1) OPERATOR (pg_catalog.||) '-01-01') :: DATE - INTERVAL '1 day') :: DATE
       ELSE
         ((EXTRACT(YEAR FROM $1) OPERATOR (pg_catalog.||) '-' OPERATOR (pg_catalog.||) (EXTRACT(MONTH FROM $1) + 1)
           OPERATOR (pg_catalog.||) '-01') :: DATE - INTERVAL '1 day') :: DATE
       END
$_$;


ALTER FUNCTION public.last_day( TIMESTAMP WITHOUT TIME ZONE )
OWNER TO postgres;

--
-- Name: last_updated(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION last_updated()
  RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.last_update = CURRENT_TIMESTAMP;
  RETURN NEW;
END $$;


ALTER FUNCTION public.last_updated()
OWNER TO postgres;

--
-- Name: customer_customer_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE customer_customer_id_seq
START WITH 1
INCREMENT BY 1
NO MINVALUE
NO MAXVALUE
CACHE 1;


ALTER TABLE customer_customer_id_seq
  OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = FALSE;

--
-- Name: customer; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE customer (
  customer_id INTEGER DEFAULT nextval('customer_customer_id_seq' :: REGCLASS) NOT NULL,
  store_id    SMALLINT                                                        NOT NULL,
  first_name  CHARACTER VARYING(45)                                           NOT NULL,
  last_name   CHARACTER VARYING(45)                                           NOT NULL,
  email       CHARACTER VARYING(50),
  address_id  SMALLINT                                                        NOT NULL,
  activebool  BOOLEAN DEFAULT TRUE                                            NOT NULL,
  create_date DATE DEFAULT ('now' :: TEXT) :: DATE                            NOT NULL,
  last_update TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
  active      INTEGER
);


ALTER TABLE customer
  OWNER TO postgres;

--
-- Name: rewards_report(integer, numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION rewards_report(min_monthly_purchases INTEGER, min_dollar_amount_purchased NUMERIC)
  RETURNS SETOF CUSTOMER
LANGUAGE plpgsql SECURITY DEFINER
AS $_$
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
$_$;


ALTER FUNCTION public.rewards_report(min_monthly_purchases INTEGER, min_dollar_amount_purchased NUMERIC )
OWNER TO postgres;

--
-- Name: group_concat(text); Type: AGGREGATE; Schema: public; Owner: postgres
--

CREATE AGGREGATE group_concat( TEXT ) (
SFUNC = _group_concat,
STYPE = TEXT
);


ALTER AGGREGATE public.group_concat( TEXT )
OWNER TO postgres;

--
-- Name: actor_actor_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE actor_actor_id_seq
START WITH 1
INCREMENT BY 1
NO MINVALUE
NO MAXVALUE
CACHE 1;


ALTER TABLE actor_actor_id_seq
  OWNER TO postgres;

--
-- Name: actor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE actor (
  actor_id    INTEGER DEFAULT nextval('actor_actor_id_seq' :: REGCLASS) NOT NULL,
  first_name  CHARACTER VARYING(45)                                     NOT NULL,
  last_name   CHARACTER VARYING(45)                                     NOT NULL,
  last_update TIMESTAMP WITHOUT TIME ZONE DEFAULT now()                 NOT NULL
);


ALTER TABLE actor
  OWNER TO postgres;

--
-- Name: category_category_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE category_category_id_seq
START WITH 1
INCREMENT BY 1
NO MINVALUE
NO MAXVALUE
CACHE 1;


ALTER TABLE category_category_id_seq
  OWNER TO postgres;

--
-- Name: category; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE category (
  category_id INTEGER DEFAULT nextval('category_category_id_seq' :: REGCLASS) NOT NULL,
  name        CHARACTER VARYING(25)                                           NOT NULL,
  last_update TIMESTAMP WITHOUT TIME ZONE DEFAULT now()                       NOT NULL
);


ALTER TABLE category
  OWNER TO postgres;

--
-- Name: film_film_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE film_film_id_seq
START WITH 1
INCREMENT BY 1
NO MINVALUE
NO MAXVALUE
CACHE 1;


ALTER TABLE film_film_id_seq
  OWNER TO postgres;

--
-- Name: film; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE film (
  film_id              INTEGER DEFAULT nextval('film_film_id_seq' :: REGCLASS) NOT NULL,
  title                CHARACTER VARYING(255)                                  NOT NULL,
  description          TEXT,
  release_year         YEAR,
  language_id          SMALLINT                                                NOT NULL,
  original_language_id SMALLINT,
  rental_duration      SMALLINT DEFAULT 3                                      NOT NULL,
  rental_rate          NUMERIC(4, 2) DEFAULT 4.99                              NOT NULL,
  length               SMALLINT,
  replacement_cost     NUMERIC(5, 2) DEFAULT 19.99                             NOT NULL,
  rating               MPAA_RATING DEFAULT 'G' :: MPAA_RATING,
  last_update          TIMESTAMP WITHOUT TIME ZONE DEFAULT now()               NOT NULL,
  special_features     TEXT [],
  fulltext             TSVECTOR                                                NOT NULL
);


ALTER TABLE film
  OWNER TO postgres;

--
-- Name: film_actor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE film_actor (
  actor_id    SMALLINT                                  NOT NULL,
  film_id     SMALLINT                                  NOT NULL,
  last_update TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL
);


ALTER TABLE film_actor
  OWNER TO postgres;

--
-- Name: film_category; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE film_category (
  film_id     SMALLINT                                  NOT NULL,
  category_id SMALLINT                                  NOT NULL,
  last_update TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL
);


ALTER TABLE film_category
  OWNER TO postgres;

--
-- Name: actor_info; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW actor_info AS
  SELECT
    a.actor_id,
    a.first_name,
    a.last_name,
    group_concat(DISTINCT (((c.name) :: TEXT || ': ' :: TEXT) || (SELECT group_concat((f.title) :: TEXT) AS group_concat
                                                                  FROM ((film f
                                                                    JOIN film_category fc_1
                                                                      ON ((f.film_id = fc_1.film_id)))
                                                                    JOIN film_actor fa_1
                                                                      ON ((f.film_id = fa_1.film_id)))
                                                                  WHERE ((fc_1.category_id = c.category_id) AND
                                                                         (fa_1.actor_id = a.actor_id))
                                                                  GROUP BY fa_1.actor_id))) AS film_info
  FROM (((actor a
    LEFT JOIN film_actor fa ON ((a.actor_id = fa.actor_id)))
    LEFT JOIN film_category fc ON ((fa.film_id = fc.film_id)))
    LEFT JOIN category c ON ((fc.category_id = c.category_id)))
  GROUP BY a.actor_id, a.first_name, a.last_name;


ALTER TABLE actor_info
  OWNER TO postgres;

--
-- Name: address_address_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE address_address_id_seq
START WITH 1
INCREMENT BY 1
NO MINVALUE
NO MAXVALUE
CACHE 1;


ALTER TABLE address_address_id_seq
  OWNER TO postgres;

--
-- Name: address; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE address (
  address_id  INTEGER DEFAULT nextval('address_address_id_seq' :: REGCLASS) NOT NULL,
  address     CHARACTER VARYING(50)                                         NOT NULL,
  address2    CHARACTER VARYING(50),
  district    CHARACTER VARYING(20)                                         NOT NULL,
  city_id     SMALLINT                                                      NOT NULL,
  postal_code CHARACTER VARYING(10),
  phone       CHARACTER VARYING(20)                                         NOT NULL,
  last_update TIMESTAMP WITHOUT TIME ZONE DEFAULT now()                     NOT NULL
);


ALTER TABLE address
  OWNER TO postgres;

--
-- Name: city_city_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE city_city_id_seq
START WITH 1
INCREMENT BY 1
NO MINVALUE
NO MAXVALUE
CACHE 1;


ALTER TABLE city_city_id_seq
  OWNER TO postgres;

--
-- Name: city; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE city (
  city_id     INTEGER DEFAULT nextval('city_city_id_seq' :: REGCLASS) NOT NULL,
  city        CHARACTER VARYING(50)                                   NOT NULL,
  country_id  SMALLINT                                                NOT NULL,
  last_update TIMESTAMP WITHOUT TIME ZONE DEFAULT now()               NOT NULL
);


ALTER TABLE city
  OWNER TO postgres;

--
-- Name: country_country_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE country_country_id_seq
START WITH 1
INCREMENT BY 1
NO MINVALUE
NO MAXVALUE
CACHE 1;


ALTER TABLE country_country_id_seq
  OWNER TO postgres;

--
-- Name: country; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE country (
  country_id  INTEGER DEFAULT nextval('country_country_id_seq' :: REGCLASS) NOT NULL,
  country     CHARACTER VARYING(50)                                         NOT NULL,
  last_update TIMESTAMP WITHOUT TIME ZONE DEFAULT now()                     NOT NULL
);


ALTER TABLE country
  OWNER TO postgres;

--
-- Name: customer_list; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW customer_list AS
  SELECT
    cu.customer_id                                                       AS id,
    (((cu.first_name) :: TEXT || ' ' :: TEXT) || (cu.last_name) :: TEXT) AS name,
    a.address,
    a.postal_code                                                        AS "zip code",
    a.phone,
    city.city,
    country.country,
    CASE
    WHEN cu.activebool
      THEN 'active' :: TEXT
    ELSE '' :: TEXT
    END                                                                  AS notes,
    cu.store_id                                                          AS sid
  FROM (((customer cu
    JOIN address a ON ((cu.address_id = a.address_id)))
    JOIN city ON ((a.city_id = city.city_id)))
    JOIN country ON ((city.country_id = country.country_id)));


ALTER TABLE customer_list
  OWNER TO postgres;

--
-- Name: film_list; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW film_list AS
  SELECT
    film.film_id                                                                             AS fid,
    film.title,
    film.description,
    category.name                                                                            AS category,
    film.rental_rate                                                                         AS price,
    film.length,
    film.rating,
    group_concat((((actor.first_name) :: TEXT || ' ' :: TEXT) || (actor.last_name) :: TEXT)) AS actors
  FROM ((((category
    LEFT JOIN film_category ON ((category.category_id = film_category.category_id)))
    LEFT JOIN film ON ((film_category.film_id = film.film_id)))
    JOIN film_actor ON ((film.film_id = film_actor.film_id)))
    JOIN actor ON ((film_actor.actor_id = actor.actor_id)))
  GROUP BY film.film_id, film.title, film.description, category.name, film.rental_rate, film.length, film.rating;


ALTER TABLE film_list
  OWNER TO postgres;

--
-- Name: inventory_inventory_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE inventory_inventory_id_seq
START WITH 1
INCREMENT BY 1
NO MINVALUE
NO MAXVALUE
CACHE 1;


ALTER TABLE inventory_inventory_id_seq
  OWNER TO postgres;

--
-- Name: inventory; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE inventory (
  inventory_id INTEGER DEFAULT nextval('inventory_inventory_id_seq' :: REGCLASS) NOT NULL,
  film_id      SMALLINT                                                          NOT NULL,
  store_id     SMALLINT                                                          NOT NULL,
  last_update  TIMESTAMP WITHOUT TIME ZONE DEFAULT now()                         NOT NULL
);


ALTER TABLE inventory
  OWNER TO postgres;

--
-- Name: language_language_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE language_language_id_seq
START WITH 1
INCREMENT BY 1
NO MINVALUE
NO MAXVALUE
CACHE 1;


ALTER TABLE language_language_id_seq
  OWNER TO postgres;

--
-- Name: language; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE language (
  language_id INTEGER DEFAULT nextval('language_language_id_seq' :: REGCLASS) NOT NULL,
  name        CHARACTER(20)                                                   NOT NULL,
  last_update TIMESTAMP WITHOUT TIME ZONE DEFAULT now()                       NOT NULL
);


ALTER TABLE language
  OWNER TO postgres;

--
-- Name: nicer_but_slower_film_list; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW nicer_but_slower_film_list AS
  SELECT
    film.film_id                                                     AS fid,
    film.title,
    film.description,
    category.name                                                    AS category,
    film.rental_rate                                                 AS price,
    film.length,
    film.rating,
    group_concat((((upper("substring"((actor.first_name) :: TEXT, 1, 1)) ||
                    lower("substring"((actor.first_name) :: TEXT, 2))) ||
                   upper("substring"((actor.last_name) :: TEXT, 1, 1))) ||
                  lower("substring"((actor.last_name) :: TEXT, 2)))) AS actors
  FROM ((((category
    LEFT JOIN film_category ON ((category.category_id = film_category.category_id)))
    LEFT JOIN film ON ((film_category.film_id = film.film_id)))
    JOIN film_actor ON ((film.film_id = film_actor.film_id)))
    JOIN actor ON ((film_actor.actor_id = actor.actor_id)))
  GROUP BY film.film_id, film.title, film.description, category.name, film.rental_rate, film.length, film.rating;


ALTER TABLE nicer_but_slower_film_list
  OWNER TO postgres;

--
-- Name: payment_payment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE payment_payment_id_seq
START WITH 1
INCREMENT BY 1
NO MINVALUE
NO MAXVALUE
CACHE 1;


ALTER TABLE payment_payment_id_seq
  OWNER TO postgres;

--
-- Name: payment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE payment (
  payment_id   INTEGER DEFAULT nextval('payment_payment_id_seq' :: REGCLASS) NOT NULL,
  customer_id  SMALLINT                                                      NOT NULL,
  staff_id     SMALLINT                                                      NOT NULL,
  rental_id    INTEGER                                                       NOT NULL,
  amount       NUMERIC(5, 2)                                                 NOT NULL,
  payment_date TIMESTAMP WITHOUT TIME ZONE                                   NOT NULL
);


ALTER TABLE payment
  OWNER TO postgres;

--
-- Name: payment_p2017_01; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE payment_p2017_01 (
  CONSTRAINT payment_p2017_01_payment_date_check CHECK ((
    (payment_date >= '2017-01-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE) AND
    (payment_date < '2017-02-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE)))
)
  INHERITS (payment);


ALTER TABLE payment_p2017_01
  OWNER TO postgres;

--
-- Name: payment_p2017_02; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE payment_p2017_02 (
  CONSTRAINT payment_p2017_02_payment_date_check CHECK ((
    (payment_date >= '2017-02-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE) AND
    (payment_date < '2017-03-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE)))
)
  INHERITS (payment);


ALTER TABLE payment_p2017_02
  OWNER TO postgres;

--
-- Name: payment_p2017_03; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE payment_p2017_03 (
  CONSTRAINT payment_p2017_03_payment_date_check CHECK ((
    (payment_date >= '2017-03-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE) AND
    (payment_date < '2017-04-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE)))
)
  INHERITS (payment);


ALTER TABLE payment_p2017_03
  OWNER TO postgres;

--
-- Name: payment_p2017_04; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE payment_p2017_04 (
  CONSTRAINT payment_p2017_04_payment_date_check CHECK ((
    (payment_date >= '2017-04-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE) AND
    (payment_date < '2017-05-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE)))
)
  INHERITS (payment);


ALTER TABLE payment_p2017_04
  OWNER TO postgres;

--
-- Name: payment_p2017_05; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE payment_p2017_05 (
  CONSTRAINT payment_p2017_05_payment_date_check CHECK ((
    (payment_date >= '2017-05-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE) AND
    (payment_date < '2017-06-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE)))
)
  INHERITS (payment);


ALTER TABLE payment_p2017_05
  OWNER TO postgres;

--
-- Name: payment_p2017_06; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE payment_p2017_06 (
  CONSTRAINT payment_p2017_06_payment_date_check CHECK ((
    (payment_date >= '2017-06-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE) AND
    (payment_date < '2017-07-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE)))
)
  INHERITS (payment);


ALTER TABLE payment_p2017_06
  OWNER TO postgres;

--
-- Name: rental_rental_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE rental_rental_id_seq
START WITH 1
INCREMENT BY 1
NO MINVALUE
NO MAXVALUE
CACHE 1;


ALTER TABLE rental_rental_id_seq
  OWNER TO postgres;

--
-- Name: rental; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE rental (
  rental_id    INTEGER DEFAULT nextval('rental_rental_id_seq' :: REGCLASS) NOT NULL,
  rental_date  TIMESTAMP WITHOUT TIME ZONE                                 NOT NULL,
  inventory_id INTEGER                                                     NOT NULL,
  customer_id  SMALLINT                                                    NOT NULL,
  return_date  TIMESTAMP WITHOUT TIME ZONE,
  staff_id     SMALLINT                                                    NOT NULL,
  last_update  TIMESTAMP WITHOUT TIME ZONE DEFAULT now()                   NOT NULL
);


ALTER TABLE rental
  OWNER TO postgres;

--
-- Name: sales_by_film_category; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW sales_by_film_category AS
  SELECT
    c.name        AS category,
    sum(p.amount) AS total_sales
  FROM (((((payment p
    JOIN rental r ON ((p.rental_id = r.rental_id)))
    JOIN inventory i ON ((r.inventory_id = i.inventory_id)))
    JOIN film f ON ((i.film_id = f.film_id)))
    JOIN film_category fc ON ((f.film_id = fc.film_id)))
    JOIN category c ON ((fc.category_id = c.category_id)))
  GROUP BY c.name
  ORDER BY (sum(p.amount)) DESC;


ALTER TABLE sales_by_film_category
  OWNER TO postgres;

--
-- Name: staff_staff_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE staff_staff_id_seq
START WITH 1
INCREMENT BY 1
NO MINVALUE
NO MAXVALUE
CACHE 1;


ALTER TABLE staff_staff_id_seq
  OWNER TO postgres;

--
-- Name: staff; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE staff (
  staff_id    INTEGER DEFAULT nextval('staff_staff_id_seq' :: REGCLASS) NOT NULL,
  first_name  CHARACTER VARYING(45)                                     NOT NULL,
  last_name   CHARACTER VARYING(45)                                     NOT NULL,
  address_id  SMALLINT                                                  NOT NULL,
  email       CHARACTER VARYING(50),
  store_id    SMALLINT                                                  NOT NULL,
  active      BOOLEAN DEFAULT TRUE                                      NOT NULL,
  username    CHARACTER VARYING(16)                                     NOT NULL,
  password    CHARACTER VARYING(40),
  last_update TIMESTAMP WITHOUT TIME ZONE DEFAULT now()                 NOT NULL,
  picture     BYTEA
);


ALTER TABLE staff
  OWNER TO postgres;

--
-- Name: store_store_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE store_store_id_seq
START WITH 1
INCREMENT BY 1
NO MINVALUE
NO MAXVALUE
CACHE 1;


ALTER TABLE store_store_id_seq
  OWNER TO postgres;

--
-- Name: store; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE store (
  store_id         INTEGER DEFAULT nextval('store_store_id_seq' :: REGCLASS) NOT NULL,
  manager_staff_id SMALLINT                                                  NOT NULL,
  address_id       SMALLINT                                                  NOT NULL,
  last_update      TIMESTAMP WITHOUT TIME ZONE DEFAULT now()                 NOT NULL
);


ALTER TABLE store
  OWNER TO postgres;

--
-- Name: sales_by_store; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW sales_by_store AS
  SELECT
    (((c.city) :: TEXT || ',' :: TEXT) || (cy.country) :: TEXT)        AS store,
    (((m.first_name) :: TEXT || ' ' :: TEXT) || (m.last_name) :: TEXT) AS manager,
    sum(p.amount)                                                      AS total_sales
  FROM (((((((payment p
    JOIN rental r ON ((p.rental_id = r.rental_id)))
    JOIN inventory i ON ((r.inventory_id = i.inventory_id)))
    JOIN store s ON ((i.store_id = s.store_id)))
    JOIN address a ON ((s.address_id = a.address_id)))
    JOIN city c ON ((a.city_id = c.city_id)))
    JOIN country cy ON ((c.country_id = cy.country_id)))
    JOIN staff m ON ((s.manager_staff_id = m.staff_id)))
  GROUP BY cy.country, c.city, s.store_id, m.first_name, m.last_name
  ORDER BY cy.country, c.city;


ALTER TABLE sales_by_store
  OWNER TO postgres;

--
-- Name: staff_list; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW staff_list AS
  SELECT
    s.staff_id                                                         AS id,
    (((s.first_name) :: TEXT || ' ' :: TEXT) || (s.last_name) :: TEXT) AS name,
    a.address,
    a.postal_code                                                      AS "zip code",
    a.phone,
    city.city,
    country.country,
    s.store_id                                                         AS sid
  FROM (((staff s
    JOIN address a ON ((s.address_id = a.address_id)))
    JOIN city ON ((a.city_id = city.city_id)))
    JOIN country ON ((city.country_id = country.country_id)));


ALTER TABLE staff_list
  OWNER TO postgres;

--
-- Name: payment_p2017_01 payment_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_01
  ALTER COLUMN payment_id SET DEFAULT nextval('payment_payment_id_seq' :: REGCLASS);

--
-- Name: payment_p2017_02 payment_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_02
  ALTER COLUMN payment_id SET DEFAULT nextval('payment_payment_id_seq' :: REGCLASS);

--
-- Name: payment_p2017_03 payment_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_03
  ALTER COLUMN payment_id SET DEFAULT nextval('payment_payment_id_seq' :: REGCLASS);

--
-- Name: payment_p2017_04 payment_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_04
  ALTER COLUMN payment_id SET DEFAULT nextval('payment_payment_id_seq' :: REGCLASS);

--
-- Name: payment_p2017_05 payment_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_05
  ALTER COLUMN payment_id SET DEFAULT nextval('payment_payment_id_seq' :: REGCLASS);

--
-- Name: payment_p2017_06 payment_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_06
  ALTER COLUMN payment_id SET DEFAULT nextval('payment_payment_id_seq' :: REGCLASS);

--
-- Name: actor actor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY actor
  ADD CONSTRAINT actor_pkey PRIMARY KEY (actor_id);

--
-- Name: address address_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY address
  ADD CONSTRAINT address_pkey PRIMARY KEY (address_id);

--
-- Name: category category_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY category
  ADD CONSTRAINT category_pkey PRIMARY KEY (category_id);

--
-- Name: city city_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY city
  ADD CONSTRAINT city_pkey PRIMARY KEY (city_id);

--
-- Name: country country_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY country
  ADD CONSTRAINT country_pkey PRIMARY KEY (country_id);

--
-- Name: customer customer_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY customer
  ADD CONSTRAINT customer_pkey PRIMARY KEY (customer_id);

--
-- Name: film_actor film_actor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY film_actor
  ADD CONSTRAINT film_actor_pkey PRIMARY KEY (actor_id, film_id);

--
-- Name: film_category film_category_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY film_category
  ADD CONSTRAINT film_category_pkey PRIMARY KEY (film_id, category_id);

--
-- Name: film film_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY film
  ADD CONSTRAINT film_pkey PRIMARY KEY (film_id);

--
-- Name: inventory inventory_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY inventory
  ADD CONSTRAINT inventory_pkey PRIMARY KEY (inventory_id);

--
-- Name: language language_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY language
  ADD CONSTRAINT language_pkey PRIMARY KEY (language_id);

--
-- Name: payment payment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment
  ADD CONSTRAINT payment_pkey PRIMARY KEY (payment_id);

--
-- Name: rental rental_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY rental
  ADD CONSTRAINT rental_pkey PRIMARY KEY (rental_id);

--
-- Name: staff staff_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY staff
  ADD CONSTRAINT staff_pkey PRIMARY KEY (staff_id);

--
-- Name: store store_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY store
  ADD CONSTRAINT store_pkey PRIMARY KEY (store_id);

--
-- Name: film_fulltext_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX film_fulltext_idx
  ON film USING GIST (fulltext);

--
-- Name: idx_actor_last_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_actor_last_name
  ON actor USING BTREE (last_name);

--
-- Name: idx_fk_address_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fk_address_id
  ON customer USING BTREE (address_id);

--
-- Name: idx_fk_city_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fk_city_id
  ON address USING BTREE (city_id);

--
-- Name: idx_fk_country_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fk_country_id
  ON city USING BTREE (country_id);

--
-- Name: idx_fk_customer_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fk_customer_id
  ON payment USING BTREE (customer_id);

--
-- Name: idx_fk_film_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fk_film_id
  ON film_actor USING BTREE (film_id);

--
-- Name: idx_fk_inventory_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fk_inventory_id
  ON rental USING BTREE (inventory_id);

--
-- Name: idx_fk_language_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fk_language_id
  ON film USING BTREE (language_id);

--
-- Name: idx_fk_original_language_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fk_original_language_id
  ON film USING BTREE (original_language_id);

--
-- Name: idx_fk_payment_p2017_01_customer_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fk_payment_p2017_01_customer_id
  ON payment_p2017_01 USING BTREE (customer_id);

--
-- Name: idx_fk_payment_p2017_01_staff_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fk_payment_p2017_01_staff_id
  ON payment_p2017_01 USING BTREE (staff_id);

--
-- Name: idx_fk_payment_p2017_02_customer_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fk_payment_p2017_02_customer_id
  ON payment_p2017_02 USING BTREE (customer_id);

--
-- Name: idx_fk_payment_p2017_02_staff_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fk_payment_p2017_02_staff_id
  ON payment_p2017_02 USING BTREE (staff_id);

--
-- Name: idx_fk_payment_p2017_03_customer_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fk_payment_p2017_03_customer_id
  ON payment_p2017_03 USING BTREE (customer_id);

--
-- Name: idx_fk_payment_p2017_03_staff_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fk_payment_p2017_03_staff_id
  ON payment_p2017_03 USING BTREE (staff_id);

--
-- Name: idx_fk_payment_p2017_04_customer_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fk_payment_p2017_04_customer_id
  ON payment_p2017_04 USING BTREE (customer_id);

--
-- Name: idx_fk_payment_p2017_04_staff_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fk_payment_p2017_04_staff_id
  ON payment_p2017_04 USING BTREE (staff_id);

--
-- Name: idx_fk_payment_p2017_05_customer_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fk_payment_p2017_05_customer_id
  ON payment_p2017_05 USING BTREE (customer_id);

--
-- Name: idx_fk_payment_p2017_05_staff_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fk_payment_p2017_05_staff_id
  ON payment_p2017_05 USING BTREE (staff_id);

--
-- Name: idx_fk_payment_p2017_06_customer_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fk_payment_p2017_06_customer_id
  ON payment_p2017_06 USING BTREE (customer_id);

--
-- Name: idx_fk_payment_p2017_06_staff_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fk_payment_p2017_06_staff_id
  ON payment_p2017_06 USING BTREE (staff_id);

--
-- Name: idx_fk_staff_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fk_staff_id
  ON payment USING BTREE (staff_id);

--
-- Name: idx_fk_store_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fk_store_id
  ON customer USING BTREE (store_id);

--
-- Name: idx_last_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_last_name
  ON customer USING BTREE (last_name);

--
-- Name: idx_store_id_film_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_store_id_film_id
  ON inventory USING BTREE (store_id, film_id);

--
-- Name: idx_title; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_title
  ON film USING BTREE (title);

--
-- Name: idx_unq_manager_staff_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_unq_manager_staff_id
  ON store USING BTREE (manager_staff_id);

--
-- Name: idx_unq_rental_rental_date_inventory_id_customer_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_unq_rental_rental_date_inventory_id_customer_id
  ON rental USING BTREE (rental_date, inventory_id, customer_id);

--
-- Name: payment payment_insert_p2017_01; Type: RULE; Schema: public; Owner: postgres
--

CREATE RULE payment_insert_p2017_01 AS
ON INSERT TO payment
  WHERE ((new.payment_date >= '2017-01-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE) AND (new.payment_date <
                                                                                         '2017-02-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE)) DO INSTEAD INSERT INTO payment_p2017_01 (payment_id, customer_id, staff_id, rental_id, amount, payment_date)
VALUES (DEFAULT, new.customer_id, new.staff_id, new.rental_id, new.amount, new.payment_date);

--
-- Name: payment payment_insert_p2017_02; Type: RULE; Schema: public; Owner: postgres
--

CREATE RULE payment_insert_p2017_02 AS
ON INSERT TO payment
  WHERE ((new.payment_date >= '2017-02-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE) AND (new.payment_date <
                                                                                         '2017-03-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE)) DO INSTEAD INSERT INTO payment_p2017_02 (payment_id, customer_id, staff_id, rental_id, amount, payment_date)
VALUES (DEFAULT, new.customer_id, new.staff_id, new.rental_id, new.amount, new.payment_date);

--
-- Name: payment payment_insert_p2017_03; Type: RULE; Schema: public; Owner: postgres
--

CREATE RULE payment_insert_p2017_03 AS
ON INSERT TO payment
  WHERE ((new.payment_date >= '2017-03-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE) AND (new.payment_date <
                                                                                         '2017-04-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE)) DO INSTEAD INSERT INTO payment_p2017_03 (payment_id, customer_id, staff_id, rental_id, amount, payment_date)
VALUES (DEFAULT, new.customer_id, new.staff_id, new.rental_id, new.amount, new.payment_date);

--
-- Name: payment payment_insert_p2017_04; Type: RULE; Schema: public; Owner: postgres
--

CREATE RULE payment_insert_p2017_04 AS
ON INSERT TO payment
  WHERE ((new.payment_date >= '2017-04-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE) AND (new.payment_date <
                                                                                         '2017-05-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE)) DO INSTEAD INSERT INTO payment_p2017_04 (payment_id, customer_id, staff_id, rental_id, amount, payment_date)
VALUES (DEFAULT, new.customer_id, new.staff_id, new.rental_id, new.amount, new.payment_date);

--
-- Name: payment payment_insert_p2017_05; Type: RULE; Schema: public; Owner: postgres
--

CREATE RULE payment_insert_p2017_05 AS
ON INSERT TO payment
  WHERE ((new.payment_date >= '2017-05-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE) AND (new.payment_date <
                                                                                         '2017-06-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE)) DO INSTEAD INSERT INTO payment_p2017_05 (payment_id, customer_id, staff_id, rental_id, amount, payment_date)
VALUES (DEFAULT, new.customer_id, new.staff_id, new.rental_id, new.amount, new.payment_date);

--
-- Name: payment payment_insert_p2017_06; Type: RULE; Schema: public; Owner: postgres
--

CREATE RULE payment_insert_p2017_06 AS
ON INSERT TO payment
  WHERE ((new.payment_date >= '2017-06-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE) AND (new.payment_date <
                                                                                         '2017-07-01 00:00:00' :: TIMESTAMP WITHOUT TIME ZONE)) DO INSTEAD INSERT INTO payment_p2017_06 (payment_id, customer_id, staff_id, rental_id, amount, payment_date)
VALUES (DEFAULT, new.customer_id, new.staff_id, new.rental_id, new.amount, new.payment_date);

--
-- Name: film film_fulltext_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER film_fulltext_trigger
BEFORE INSERT OR UPDATE ON film
FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('fulltext', 'pg_catalog.english', 'title', 'description');

--
-- Name: actor last_updated; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER last_updated
BEFORE UPDATE ON actor
FOR EACH ROW EXECUTE PROCEDURE last_updated();

--
-- Name: address last_updated; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER last_updated
BEFORE UPDATE ON address
FOR EACH ROW EXECUTE PROCEDURE last_updated();

--
-- Name: category last_updated; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER last_updated
BEFORE UPDATE ON category
FOR EACH ROW EXECUTE PROCEDURE last_updated();

--
-- Name: city last_updated; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER last_updated
BEFORE UPDATE ON city
FOR EACH ROW EXECUTE PROCEDURE last_updated();

--
-- Name: country last_updated; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER last_updated
BEFORE UPDATE ON country
FOR EACH ROW EXECUTE PROCEDURE last_updated();

--
-- Name: customer last_updated; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER last_updated
BEFORE UPDATE ON customer
FOR EACH ROW EXECUTE PROCEDURE last_updated();

--
-- Name: film last_updated; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER last_updated
BEFORE UPDATE ON film
FOR EACH ROW EXECUTE PROCEDURE last_updated();

--
-- Name: film_actor last_updated; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER last_updated
BEFORE UPDATE ON film_actor
FOR EACH ROW EXECUTE PROCEDURE last_updated();

--
-- Name: film_category last_updated; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER last_updated
BEFORE UPDATE ON film_category
FOR EACH ROW EXECUTE PROCEDURE last_updated();

--
-- Name: inventory last_updated; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER last_updated
BEFORE UPDATE ON inventory
FOR EACH ROW EXECUTE PROCEDURE last_updated();

--
-- Name: language last_updated; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER last_updated
BEFORE UPDATE ON language
FOR EACH ROW EXECUTE PROCEDURE last_updated();

--
-- Name: rental last_updated; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER last_updated
BEFORE UPDATE ON rental
FOR EACH ROW EXECUTE PROCEDURE last_updated();

--
-- Name: staff last_updated; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER last_updated
BEFORE UPDATE ON staff
FOR EACH ROW EXECUTE PROCEDURE last_updated();

--
-- Name: store last_updated; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER last_updated
BEFORE UPDATE ON store
FOR EACH ROW EXECUTE PROCEDURE last_updated();

--
-- Name: address address_city_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY address
  ADD CONSTRAINT address_city_id_fkey FOREIGN KEY (city_id) REFERENCES city (city_id) ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: city city_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY city
  ADD CONSTRAINT city_country_id_fkey FOREIGN KEY (country_id) REFERENCES country (country_id) ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: customer customer_address_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY customer
  ADD CONSTRAINT customer_address_id_fkey FOREIGN KEY (address_id) REFERENCES address (address_id) ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: customer customer_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY customer
  ADD CONSTRAINT customer_store_id_fkey FOREIGN KEY (store_id) REFERENCES store (store_id) ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: film_actor film_actor_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY film_actor
  ADD CONSTRAINT film_actor_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES actor (actor_id) ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: film_actor film_actor_film_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY film_actor
  ADD CONSTRAINT film_actor_film_id_fkey FOREIGN KEY (film_id) REFERENCES film (film_id) ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: film_category film_category_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY film_category
  ADD CONSTRAINT film_category_category_id_fkey FOREIGN KEY (category_id) REFERENCES category (category_id) ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: film_category film_category_film_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY film_category
  ADD CONSTRAINT film_category_film_id_fkey FOREIGN KEY (film_id) REFERENCES film (film_id) ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: film film_language_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY film
  ADD CONSTRAINT film_language_id_fkey FOREIGN KEY (language_id) REFERENCES language (language_id) ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: film film_original_language_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY film
  ADD CONSTRAINT film_original_language_id_fkey FOREIGN KEY (original_language_id) REFERENCES language (language_id) ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: inventory inventory_film_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY inventory
  ADD CONSTRAINT inventory_film_id_fkey FOREIGN KEY (film_id) REFERENCES film (film_id) ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: inventory inventory_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY inventory
  ADD CONSTRAINT inventory_store_id_fkey FOREIGN KEY (store_id) REFERENCES store (store_id) ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: payment payment_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment
  ADD CONSTRAINT payment_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customer (customer_id) ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: payment_p2017_01 payment_p2017_01_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_01
  ADD CONSTRAINT payment_p2017_01_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customer (customer_id);

--
-- Name: payment_p2017_01 payment_p2017_01_rental_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_01
  ADD CONSTRAINT payment_p2017_01_rental_id_fkey FOREIGN KEY (rental_id) REFERENCES rental (rental_id);

--
-- Name: payment_p2017_01 payment_p2017_01_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_01
  ADD CONSTRAINT payment_p2017_01_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff (staff_id);

--
-- Name: payment_p2017_02 payment_p2017_02_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_02
  ADD CONSTRAINT payment_p2017_02_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customer (customer_id);

--
-- Name: payment_p2017_02 payment_p2017_02_rental_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_02
  ADD CONSTRAINT payment_p2017_02_rental_id_fkey FOREIGN KEY (rental_id) REFERENCES rental (rental_id);

--
-- Name: payment_p2017_02 payment_p2017_02_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_02
  ADD CONSTRAINT payment_p2017_02_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff (staff_id);

--
-- Name: payment_p2017_03 payment_p2017_03_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_03
  ADD CONSTRAINT payment_p2017_03_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customer (customer_id);

--
-- Name: payment_p2017_03 payment_p2017_03_rental_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_03
  ADD CONSTRAINT payment_p2017_03_rental_id_fkey FOREIGN KEY (rental_id) REFERENCES rental (rental_id);

--
-- Name: payment_p2017_03 payment_p2017_03_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_03
  ADD CONSTRAINT payment_p2017_03_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff (staff_id);

--
-- Name: payment_p2017_04 payment_p2017_04_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_04
  ADD CONSTRAINT payment_p2017_04_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customer (customer_id);

--
-- Name: payment_p2017_04 payment_p2017_04_rental_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_04
  ADD CONSTRAINT payment_p2017_04_rental_id_fkey FOREIGN KEY (rental_id) REFERENCES rental (rental_id);

--
-- Name: payment_p2017_04 payment_p2017_04_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_04
  ADD CONSTRAINT payment_p2017_04_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff (staff_id);

--
-- Name: payment_p2017_05 payment_p2017_05_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_05
  ADD CONSTRAINT payment_p2017_05_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customer (customer_id);

--
-- Name: payment_p2017_05 payment_p2017_05_rental_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_05
  ADD CONSTRAINT payment_p2017_05_rental_id_fkey FOREIGN KEY (rental_id) REFERENCES rental (rental_id);

--
-- Name: payment_p2017_05 payment_p2017_05_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_05
  ADD CONSTRAINT payment_p2017_05_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff (staff_id);

--
-- Name: payment_p2017_06 payment_p2017_06_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_06
  ADD CONSTRAINT payment_p2017_06_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customer (customer_id);

--
-- Name: payment_p2017_06 payment_p2017_06_rental_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_06
  ADD CONSTRAINT payment_p2017_06_rental_id_fkey FOREIGN KEY (rental_id) REFERENCES rental (rental_id);

--
-- Name: payment_p2017_06 payment_p2017_06_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_p2017_06
  ADD CONSTRAINT payment_p2017_06_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff (staff_id);

--
-- Name: payment payment_rental_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment
  ADD CONSTRAINT payment_rental_id_fkey FOREIGN KEY (rental_id) REFERENCES rental (rental_id) ON UPDATE CASCADE ON DELETE SET NULL;

--
-- Name: payment payment_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment
  ADD CONSTRAINT payment_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff (staff_id) ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: rental rental_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY rental
  ADD CONSTRAINT rental_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customer (customer_id) ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: rental rental_inventory_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY rental
  ADD CONSTRAINT rental_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES inventory (inventory_id) ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: rental rental_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY rental
  ADD CONSTRAINT rental_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff (staff_id) ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: staff staff_address_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY staff
  ADD CONSTRAINT staff_address_id_fkey FOREIGN KEY (address_id) REFERENCES address (address_id) ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: staff staff_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY staff
  ADD CONSTRAINT staff_store_id_fkey FOREIGN KEY (store_id) REFERENCES store (store_id);

--
-- Name: store store_address_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY store
  ADD CONSTRAINT store_address_id_fkey FOREIGN KEY (address_id) REFERENCES address (address_id) ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- PostgreSQL database dump complete
--

