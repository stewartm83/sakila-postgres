-- Use postgres
CREATE USER sakila_dwh WITH
  LOGIN
  SUPERUSER
  CREATEDB
  CREATEROLE
  PASSWORD 'sakila_dwh';