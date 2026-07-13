-- Creates one database per service (database-per-service; see ADR-0002).
-- Runs once, on first Postgres container init.
CREATE DATABASE aegis_authz;
CREATE DATABASE aegis_identity;
CREATE DATABASE aegis_tenant;
-- Placeholders for the services being built out:
CREATE DATABASE aegis_mfa;
CREATE DATABASE aegis_saml;
CREATE DATABASE aegis_social;
CREATE DATABASE aegis_scim;
CREATE DATABASE aegis_admin;
