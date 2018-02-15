-- User: sakila
-- DROP USER sakila;

CREATE USER sakila WITH
  LOGIN
  SUPERUSER
  CREATEDB
  CREATEROLE
  PASSWORD 'sakila';