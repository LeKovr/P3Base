/*
  Функции приложения

*/

\i config.sql
SET SEARCH_PATH TO :SCH, public;

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION session_link(
  a__sid CHAR(72)
, a_id  INTEGER
) RETURNS BOOL VOLATILE LANGUAGE 'plpgsql' AS
$_$
  -- session_link Привязать к сессии идентификатор пользователя
  -- a__sid: идентификатор сессии
  -- a_id:  идентификатор пользователя
  BEGIN
    -- сохранить время логина в учетной записи
    UPDATE app.account SET
      login_at = now()
      WHERE id = a_id
    ;

    UPDATE app.session SET account_id = a_id WHERE id = a__sid;
    IF NOT FOUND THEN
      INSERT INTO app.session (id, account_id) VALUES
        (a__sid, a_id)
      ;
      RETURN FALSE; -- сессия не найдена, создана
    END IF;
    RETURN TRUE;
  END
$_$;

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION account_purge(a_age INTERVAL DEFAULT '3 months') 
RETURNS BOOL VOLATILE LANGUAGE 'plpgsql' AS
$_$
  -- account_purge  Удаление учетных записей, по которым не было авторизаций более заданного времени
  -- a_age: заданное время
  BEGIN
    DELETE FROM app.account 
      WHERE COALESCE (login_at, created_at) < now() - $1
    ;
    RAISE NOTICE 'account_purge called'; -- сохранить в логах информацию о факте удаления
    RETURN TRUE; -- TODO: row_count
  END;
$_$;

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION session_purge(a__sid CHAR(72)) 
RETURNS BOOL VOLATILE LANGUAGE 'plpgsql' AS
$_$
  -- session_purge  Удаление учетной записи заданной сессии
  -- a__sid: заданная сессия
  DECLARE
    v_id INTEGER;
  BEGIN
    SELECT INTO v_id account_id
      FROM app.session
      WHERE id = a__sid
    ;
    IF FOUND AND v_id IS NOT NULL THEN
      DELETE FROM app.account WHERE id = v_id;
      RETURN TRUE;
    END IF;
    RETURN FALSE;
  END;
$_$;

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION login(
  a__sid      CHAR(72)
, a_user      TEXT
, a_password  TEXT
) RETURNS SETOF account VOLATILE LANGUAGE 'plpgsql' AS
$_$
  -- login   Авторизация пользователя
  -- a__sid:      идентификатор сессии
  -- a_user:      логин пользователя
  -- a_password:  пароль
  DECLARE
    r app.account%ROWTYPE;
  BEGIN
    SELECT INTO r *
      FROM app.account
      WHERE login = a_user
    ;
    IF FOUND THEN
      IF r.password <> a_password THEN
        RAISE EXCEPTION '[2001, "Wrong password"]';
      END IF;
      r.password := NULL; -- значение этого поля наружу не отдаем
      RETURN NEXT r;
      PERFORM app.session_link(a__sid, r.id);
    END IF;
    RETURN;
  END
$_$;

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION register(
  a__sid         CHAR(72)
, a_login       TEXT
, a_password    TEXT
, a_name        TEXT
, a_needs_login BOOL DEFAULT FALSE  
) RETURNS SETOF account VOLATILE LANGUAGE 'plpgsql' AS
$_$
  -- register Регистрация учетной записи
  -- a__sid:        идентификатор сессии
  -- a_login:       логин пользователя
  -- a_password:    пароль
  -- a_name:        имя пользователя
  -- a_needs_login: авторизовать при успехе
  DECLARE
    r app.account%ROWTYPE;
  BEGIN
    IF EXISTS(SELECT 1 FROM app.account WHERE login = a_login) THEN
      RAISE EXCEPTION '[2002, "Login already exists"]';
    END IF;
    INSERT INTO app.account (login, password, name) VALUES
      (a_login, a_password, a_name)
      RETURNING * INTO r
    ;
    r.password := NULL; -- значение этого поля наружу не отдаем
    RETURN NEXT r;
    IF a_needs_login THEN
      PERFORM app.session_link(a__sid, r.id);
    END IF;
    RETURN;
  END
$_$;

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE RULE no_new_empty_session AS ON INSERT TO session WHERE
 NEW.session_data = '{}'
 DO INSTEAD NOTHING
;
