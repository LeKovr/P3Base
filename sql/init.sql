/*
  Create application schema with permanent objects

*/
/* ------------------------------------------------------------------------- */

-- подключим переменные на случай индивидуального запуска
\i config.sql

/* ------------------------------------------------------------------------- */

DROP SCHEMA IF EXISTS :SCH CASCADE;

/* ------------------------------------------------------------------------- */

CREATE SCHEMA :SCH;
SET LOCAL SEARCH_PATH TO :SCH, public;

/* ------------------------------------------------------------------------- */
CREATE TABLE account (
  id                INTEGER PRIMARY KEY
, login             TEXT NOT NULL UNIQUE
, password          TEXT NOT NULL
, is_password_clear BOOL NOT NULL DEFAULT TRUE
, name              TEXT
, created_at        TIMESTAMP(0) DEFAULT CURRENT_TIMESTAMP
, login_at          TIMESTAMP(0)
);
/*
  r account   Учетные записи пользователей
  * id                - Уникальный идентификатор пользователя
  * login             - Логин для авторизации
  * password          - Пароль
  * is_password_clear - Пароль хранится в открытом виде (ЗАРЕЗЕРВИРОВАНО)
  * name              - Отображаемое имя пользователя
  * created_at        - Момент регистрации
  * login_at          - Момент последней авторизации
*/
CREATE SEQUENCE account_id_seq; -- Счетчик для account.id
ALTER TABLE account ALTER COLUMN id SET DEFAULT NEXTVAL('account_id_seq');

/* ------------------------------------------------------------------------- */
CREATE TABLE session (
  id            CHAR(72) PRIMARY KEY
, account_id    INTEGER REFERENCES account ON DELETE CASCADE
, session_data  TEXT
, created_at    TIMESTAMP(0) DEFAULT CURRENT_TIMESTAMP
, updated_at    TIMESTAMP(0) DEFAULT CURRENT_TIMESTAMP
);
/*
  r session   Сессии пользователей
  * id                - Уникальный идентификатор сессии (генерится приложением)
  * account_id        - Удентификатор пользователя или NULL
  * session_data      - Данные сессии в формате JSON
  * created_at        - Момент первого запроса
  * updated_at        - Момент последнего запроса
*/

