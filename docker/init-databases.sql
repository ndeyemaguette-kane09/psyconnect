-- Script exécuté automatiquement par le container postgres au premier démarrage
-- (monté dans /docker-entrypoint-initdb.d/)
-- Crée les 5 bases de données applicatives de PsyConnect.
-- L'utilisateur "postgres" existe déjà (créé par l'image officielle).

CREATE DATABASE psyconnect_auth;
CREATE DATABASE psyconnect_user;
CREATE DATABASE psyconnect_appointment;
CREATE DATABASE psyconnect_payment;
CREATE DATABASE psyconnect_notification;
CREATE DATABASE psyconnect_session;
