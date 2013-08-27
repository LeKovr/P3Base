/*
  Permission setup
*/

-- подключим переменные на случай индивидуального запуска
\i config.sql

/* ------------------------------------------------------------------------- */

GRANT ALL     ON ALL TABLES     IN SCHEMA :SCH TO :USR;
GRANT EXECUTE ON ALL FUNCTIONS  IN SCHEMA :SCH TO :USR;
GRANT USAGE   ON ALL SEQUENCES  IN SCHEMA :SCH TO :USR;
GRANT USAGE                     ON SCHEMA :SCH TO :USR;
