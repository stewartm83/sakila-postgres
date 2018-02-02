CREATE USER sakila_dwh WITH
  LOGIN
  SUPERUSER
  CREATEDB
  CREATEROLE
  PASSWORD 'sakila_dwh';

CREATE DATABASE sakila_dwh
WITH OWNER = sakila_dwh;

CREATE TABLE public.dim_actor
(
  actor_first_name  CHARACTER VARYING(45)                     NOT NULL,
  actor_key         SERIAL,
  actor_last_name   CHARACTER VARYING(45)                     NOT NULL,
  actor_last_update TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL,
  actor_id          INTEGER                                   NOT NULL,
  PRIMARY KEY (actor_key)
);

ALTER TABLE public.dim_actor
  OWNER TO postgres;

CREATE TABLE public.dim_customer (
  customer_key            SERIAL,
  customer_last_update    TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL,
  customer_id             INTEGER,
  customer_first_name     CHARACTER VARYING(45),
  customer_last_name      CHARACTER VARYING(45),
  customer_email          CHARACTER VARYING(50),
  customer_active         CHARACTER(3),
  customer_created        DATE,
  customer_address        CHARACTER VARYING(64),
  customer_district       CHARACTER VARYING(20),
  customer_postal_code    CHARACTER VARYING(10),
  customer_phone_number   CHARACTER VARYING(20),
  customer_city           CHARACTER VARYING(50),
  customer_country        CHARACTER VARYING(50),
  customer_version_number SMALLINT,
  customer_valid_from     DATE,
  customer_valid_through  DATE,
  PRIMARY KEY (customer_key)
);

CREATE INDEX idx_dim_customer_customer_id
  ON public.dim_customer USING BTREE
  (customer_id);

ALTER TABLE public.dim_customer
  OWNER TO postgres;

CREATE TABLE dim_date (
  date_key                INTEGER       NOT NULL,
  date_value              DATE          NOT NULL,
  date_short              CHARACTER(12) NOT NULL,
  date_medium             CHARACTER(16) NOT NULL,
  date_long               CHARACTER(24) NOT NULL,
  date_full               CHARACTER(32) NOT NULL,
  day_in_year             SMALLINT      NOT NULL,
  day_in_month            SMALLINT      NOT NULL,
  is_first_day_in_month   CHARACTER(10) NOT NULL,
  is_last_day_in_month    CHARACTER(10) NOT NULL,
  day_abbreviation        CHARACTER(3)  NOT NULL,
  day_name                CHARACTER(12) NOT NULL,
  week_in_year            SMALLINT      NOT NULL,
  week_in_month           SMALLINT      NOT NULL,
  is_first_day_in_week    CHARACTER(10) NOT NULL,
  is_last_day_in_week     CHARACTER(10) NOT NULL,
  month_number            SMALLINT      NOT NULL,
  month_abbreviation      CHARACTER(3)  NOT NULL,
  month_name              CHARACTER(12) NOT NULL,
  year2                   CHARACTER(2)  NOT NULL,
  year4                   SMALLINT      NOT NULL,
  quarter_name            CHARACTER(2)  NOT NULL,
  quarter_number          SMALLINT      NOT NULL,
  year_quarter            CHARACTER(7)  NOT NULL,
  year_month_number       CHARACTER(7)  NOT NULL,
  year_month_abbreviation CHARACTER(8)  NOT NULL,
  PRIMARY KEY (date_key),
  CONSTRAINT date_value UNIQUE (date_value)
);
CREATE INDEX idx_dim_date_date_value
  ON public.dim_date USING BTREE
  (date_value);

ALTER TABLE public.dim_date
  OWNER TO postgres;

CREATE TABLE dim_film (
  film_key                     SERIAL,
  film_last_update             TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL,
  film_title                   CHARACTER VARYING(64)                     NOT NULL,
  film_description             TEXT                                      NOT NULL,
  film_release_year            SMALLINT                                  NOT NULL,
  film_language                CHARACTER VARYING(20)                     NOT NULL,
  film_original_language       CHARACTER VARYING(20)                     NOT NULL,
  film_rental_duration         SMALLINT,
  film_rental_rate             DECIMAL(4, 2),
  film_duration                INTEGER,
  film_replacement_cost        DECIMAL(5, 2),
  film_rating_code             CHARACTER(5),
  film_rating_text             CHARACTER VARYING(30),
  film_has_trailers            CHARACTER(4),
  film_has_commentaries        CHARACTER(4),
  film_has_deleted_scenes      CHARACTER(4),
  film_has_behind_the_scenes   CHARACTER(4),
  film_in_category_action      CHARACTER(4),
  film_in_category_animation   CHARACTER(4),
  film_in_category_children    CHARACTER(4),
  film_in_category_classics    CHARACTER(4),
  film_in_category_comedy      CHARACTER(4),
  film_in_category_documentary CHARACTER(4),
  film_in_category_drama       CHARACTER(4),
  film_in_category_family      CHARACTER(4),
  film_in_category_foreign     CHARACTER(4),
  film_in_category_games       CHARACTER(4),
  film_in_category_horror      CHARACTER(4),
  film_in_category_music       CHARACTER(4),
  film_in_category_new         CHARACTER(4),
  film_in_category_scifi       CHARACTER(4),
  film_in_category_sports      CHARACTER(4),
  film_in_category_travel      CHARACTER(4),
  film_id                      INTEGER                                   NOT NULL,
  PRIMARY KEY (film_key)
);
ALTER TABLE public.dim_film
  OWNER TO postgres;

CREATE TABLE dim_film_actor_bridge (
  film_key               INTEGER       NOT NULL,
  actor_key              INTEGER       NOT NULL,
  actor_weighting_factor DECIMAL(3, 2) NOT NULL,
  PRIMARY KEY (film_key, actor_key),
  CONSTRAINT dim_actor_dim_film_actor_bridge_fk FOREIGN KEY (actor_key)
  REFERENCES public.dim_actor (actor_key)
);

ALTER TABLE public.dim_film_actor_bridge
  OWNER TO postgres;

CREATE TABLE dim_staff (
  staff_key            SERIAL,
  staff_last_update    TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL,
  staff_first_name     CHARACTER VARYING(45),
  staff_last_name      CHARACTER VARYING(45),
  staff_id             INTEGER,
  staff_store_id       INTEGER,
  staff_version_number SMALLINT,
  staff_valid_from     DATE,
  staff_valid_through  DATE,
  staff_active         CHARACTER(3),
  PRIMARY KEY (staff_key)
);

CREATE INDEX idx_dim_staff_staff_id
  ON public.dim_staff USING BTREE
  (staff_id);

ALTER TABLE public.dim_staff
  OWNER TO postgres;

CREATE TABLE dim_store (
  store_key                SERIAL,
  store_last_update        TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL,
  store_id                 INTEGER,
  store_address            CHARACTER VARYING(64),
  store_district           CHARACTER VARYING(20),
  store_postal_code        CHARACTER VARYING(10),
  store_phone_number       CHARACTER VARYING(20),
  store_city               CHARACTER VARYING(50),
  store_country            CHARACTER VARYING(50),
  store_manager_staff_id   INTEGER,
  store_manager_first_name CHARACTER VARYING(45),
  store_manager_last_name  CHARACTER VARYING(45),
  store_version_number     SMALLINT,
  store_valid_from         DATE,
  store_valid_through      DATE,
  PRIMARY KEY (store_key)
);

CREATE INDEX idx_dim_store_store_id
  ON public.dim_store USING BTREE
  (store_id);

ALTER TABLE public.dim_store
  OWNER TO postgres;

CREATE TABLE dim_time (
  time_key   INTEGER  NOT NULL,
  time_value TIME     NOT NULL,
  hours24    SMALLINT NOT NULL,
  hours12    SMALLINT,
  minutes    SMALLINT,
  seconds    SMALLINT,
  am_pm      CHARACTER(3),
  PRIMARY KEY (time_key),
  CONSTRAINT time_value UNIQUE (time_value)
);
ALTER TABLE public.dim_date
  OWNER TO postgres;

CREATE TABLE fact_rental (
  customer_key       INTEGER NOT NULL,
  staff_key          INTEGER NOT NULL,
  film_key           INTEGER NOT NULL,
  store_key          INTEGER NOT NULL,
  rental_date_key    INTEGER NOT NULL,
  return_date_key    INTEGER NOT NULL,
  rental_time_key    INTEGER NOT NULL,
  count_returns      INTEGER NOT NULL,
  count_rentals      INTEGER NOT NULL,
  rental_duration    INTEGER,
  rental_last_update DATE,
  rental_id          INTEGER
  ,
  CONSTRAINT dim_store_fact_rental_fk FOREIGN KEY (store_key)
  REFERENCES public.dim_store (store_key)

  ,
  CONSTRAINT dim_staff_fact_rental_fk FOREIGN KEY (staff_key)
  REFERENCES public.dim_staff (staff_key)

  ,
  CONSTRAINT dim_time_fact_rental_fk FOREIGN KEY (rental_time_key)
  REFERENCES public.dim_time (time_key)

  ,
  CONSTRAINT dim_customer_fact_rental_fk FOREIGN KEY (customer_key)
  REFERENCES public.dim_customer (customer_key)

  ,
  CONSTRAINT dim_film_fact_rental_fk FOREIGN KEY (film_key)
  REFERENCES public.dim_film (film_key)

  ,
  CONSTRAINT dim_date_fact_rental_fk FOREIGN KEY (rental_date_key)
  REFERENCES public.dim_date (date_key)
);
ALTER TABLE public.fact_rental
  OWNER TO postgres;

