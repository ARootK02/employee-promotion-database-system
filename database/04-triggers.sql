-- Employee Promotion Database System
-- File: 04-triggers.sql
-- Purpose: Install the audit, application-rule, and project-numbering triggers.
-- Run after 01-schema.sql, 02-seed-data.sql, and 03-procedures.sql.
-- MySQL version: 8.0+

USE firms;

DELIMITER $$

-- Automatically assigns a project number that is sequential for each employee.
DROP TRIGGER IF EXISTS trg_project_before_insert_number$$
CREATE TRIGGER trg_project_before_insert_number
BEFORE INSERT ON project
FOR EACH ROW
BEGIN
    DECLARE v_next_number SMALLINT UNSIGNED;

    IF NEW.num IS NULL OR NEW.num = 0 THEN
        SELECT COALESCE(MAX(p.num), 0) + 1
          INTO v_next_number
          FROM project AS p
         WHERE p.candid = NEW.candid;

        SET NEW.num = v_next_number;
    END IF;
END$$

-- Prevents duplicate evaluators, late applications, and a fourth active application.
DROP TRIGGER IF EXISTS trg_promotion_request_before_insert$$
CREATE TRIGGER trg_promotion_request_before_insert
BEFORE INSERT ON promotion_request
FOR EACH ROW
trigger_body: BEGIN
    DECLARE v_start_date DATE DEFAULT NULL;
    DECLARE v_active_count INT DEFAULT 0;
    IF NEW.evaluator1_username = NEW.evaluator2_username THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The two evaluators must be different.'; END IF;
    SELECT j.start_date
      INTO v_start_date
      FROM job AS j
     WHERE j.id = NEW.job_id
     LIMIT 1;

    IF v_start_date IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'The specified job does not exist.';
    END IF;

    -- The insertion date must be the actual database date, not caller supplied.
    SET NEW.request_date = CURRENT_DATE;

    IF NEW.status = 'active' THEN
        IF DATEDIFF(v_start_date, CURRENT_DATE) < 15 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Applications are not allowed fewer than 15 days before the job start date.';
        END IF;

        SELECT COUNT(*)
          INTO v_active_count
          FROM promotion_request AS pr
         WHERE pr.employee_username = NEW.employee_username
           AND pr.status = 'active';

        IF v_active_count >= 3 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'The employee already has three active applications.';
        END IF;

        SET NEW.cancel_date = NULL;
    ELSEIF NEW.status = 'canceled' THEN
        SET NEW.cancel_date = COALESCE(NEW.cancel_date, CURRENT_DATE);
    ELSE
        SET NEW.cancel_date = NULL;
    END IF;
END$$

-- Enforces cancellation and reactivation rules and synchronizes cancel_date.
DROP TRIGGER IF EXISTS trg_promotion_request_before_update$$
CREATE TRIGGER trg_promotion_request_before_update
BEFORE UPDATE ON promotion_request
FOR EACH ROW
trigger_body: BEGIN
    DECLARE v_start_date DATE DEFAULT NULL;
    DECLARE v_active_count INT DEFAULT 0;
    IF NEW.evaluator1_username = NEW.evaluator2_username THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The two evaluators must be different.'; END IF;
    SELECT j.start_date
      INTO v_start_date
      FROM job AS j
     WHERE j.id = NEW.job_id
     LIMIT 1;

    IF v_start_date IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'The specified job does not exist.';
    END IF;

    IF OLD.status <> 'canceled' AND NEW.status = 'canceled' THEN
        IF DATEDIFF(v_start_date, CURRENT_DATE) < 10 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Cancellation is not allowed fewer than 10 days before the job start date.';
        END IF;

        SET NEW.cancel_date = CURRENT_DATE;
    ELSEIF OLD.status = 'canceled' AND NEW.status = 'active' THEN
        SELECT COUNT(*)
          INTO v_active_count
          FROM promotion_request AS pr
         WHERE pr.employee_username = NEW.employee_username
           AND pr.status = 'active'
           AND pr.id <> OLD.id;

        IF v_active_count >= 3 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'The employee already has three active applications.';
        END IF;

        SET NEW.cancel_date = NULL;
    ELSEIF NEW.status IN ('active', 'completed') THEN
        SET NEW.cancel_date = NULL;
    ELSEIF NEW.status = 'canceled' AND NEW.cancel_date IS NULL THEN
        SET NEW.cancel_date = COALESCE(OLD.cancel_date, CURRENT_DATE);
    END IF;
END$$

-- Audit triggers for job.
DROP TRIGGER IF EXISTS trg_job_after_insert_audit$$
CREATE TRIGGER trg_job_after_insert_audit
AFTER INSERT ON job
FOR EACH ROW
BEGIN
    INSERT INTO dba_log (
        actor_username,
        table_name,
        action_type,
        record_key,
        old_data,
        new_data
    ) VALUES (
        CURRENT_USER(),
        'job',
        'INSERT',
        CAST(NEW.id AS CHAR),
        NULL,
        JSON_OBJECT(
            'id', NEW.id,
            'start_date', NEW.start_date,
            'salary', NEW.salary,
            'position', NEW.position,
            'edra', NEW.edra,
            'job_evaluator', NEW.job_evaluator,
            'announce_date', NEW.announce_date,
            'submission_date', NEW.submission_date
        )
    );
END$$

DROP TRIGGER IF EXISTS trg_job_after_update_audit$$
CREATE TRIGGER trg_job_after_update_audit
AFTER UPDATE ON job
FOR EACH ROW
BEGIN
    INSERT INTO dba_log (
        actor_username,
        table_name,
        action_type,
        record_key,
        old_data,
        new_data
    ) VALUES (
        CURRENT_USER(),
        'job',
        'UPDATE',
        CAST(NEW.id AS CHAR),
        JSON_OBJECT(
            'id', OLD.id,
            'start_date', OLD.start_date,
            'salary', OLD.salary,
            'position', OLD.position,
            'edra', OLD.edra,
            'job_evaluator', OLD.job_evaluator,
            'announce_date', OLD.announce_date,
            'submission_date', OLD.submission_date
        ),
        JSON_OBJECT(
            'id', NEW.id,
            'start_date', NEW.start_date,
            'salary', NEW.salary,
            'position', NEW.position,
            'edra', NEW.edra,
            'job_evaluator', NEW.job_evaluator,
            'announce_date', NEW.announce_date,
            'submission_date', NEW.submission_date
        )
    );
END$$

DROP TRIGGER IF EXISTS trg_job_after_delete_audit$$
CREATE TRIGGER trg_job_after_delete_audit
AFTER DELETE ON job
FOR EACH ROW
BEGIN
    INSERT INTO dba_log (
        actor_username,
        table_name,
        action_type,
        record_key,
        old_data,
        new_data
    ) VALUES (
        CURRENT_USER(),
        'job',
        'DELETE',
        CAST(OLD.id AS CHAR),
        JSON_OBJECT(
            'id', OLD.id,
            'start_date', OLD.start_date,
            'salary', OLD.salary,
            'position', OLD.position,
            'edra', OLD.edra,
            'job_evaluator', OLD.job_evaluator,
            'announce_date', OLD.announce_date,
            'submission_date', OLD.submission_date
        ),
        NULL
    );
END$$

-- Audit triggers for user. Password values are deliberately not copied to log.
DROP TRIGGER IF EXISTS trg_user_after_insert_audit$$
CREATE TRIGGER trg_user_after_insert_audit
AFTER INSERT ON `user`
FOR EACH ROW
BEGIN
    INSERT INTO dba_log (
        actor_username,
        table_name,
        action_type,
        record_key,
        old_data,
        new_data
    ) VALUES (
        CURRENT_USER(),
        'user',
        'INSERT',
        NEW.username,
        NULL,
        JSON_OBJECT(
            'username', NEW.username,
            'name', NEW.name,
            'lastname', NEW.lastname,
            'reg_date', NEW.reg_date,
            'email', NEW.email
        )
    );
END$$

DROP TRIGGER IF EXISTS trg_user_after_update_audit$$
CREATE TRIGGER trg_user_after_update_audit
AFTER UPDATE ON `user`
FOR EACH ROW
BEGIN
    INSERT INTO dba_log (
        actor_username,
        table_name,
        action_type,
        record_key,
        old_data,
        new_data
    ) VALUES (
        CURRENT_USER(),
        'user',
        'UPDATE',
        NEW.username,
        JSON_OBJECT(
            'username', OLD.username,
            'name', OLD.name,
            'lastname', OLD.lastname,
            'reg_date', OLD.reg_date,
            'email', OLD.email
        ),
        JSON_OBJECT(
            'username', NEW.username,
            'name', NEW.name,
            'lastname', NEW.lastname,
            'reg_date', NEW.reg_date,
            'email', NEW.email
        )
    );
END$$

DROP TRIGGER IF EXISTS trg_user_after_delete_audit$$
CREATE TRIGGER trg_user_after_delete_audit
AFTER DELETE ON `user`
FOR EACH ROW
BEGIN
    INSERT INTO dba_log (
        actor_username,
        table_name,
        action_type,
        record_key,
        old_data,
        new_data
    ) VALUES (
        CURRENT_USER(),
        'user',
        'DELETE',
        OLD.username,
        JSON_OBJECT(
            'username', OLD.username,
            'name', OLD.name,
            'lastname', OLD.lastname,
            'reg_date', OLD.reg_date,
            'email', OLD.email
        ),
        NULL
    );
END$$

-- Audit triggers for degree.
DROP TRIGGER IF EXISTS trg_degree_after_insert_audit$$
CREATE TRIGGER trg_degree_after_insert_audit
AFTER INSERT ON degree
FOR EACH ROW
BEGIN
    INSERT INTO dba_log (
        actor_username,
        table_name,
        action_type,
        record_key,
        old_data,
        new_data
    ) VALUES (
        CURRENT_USER(),
        'degree',
        'INSERT',
        CONCAT(NEW.titlos, ' | ', NEW.idryma),
        NULL,
        JSON_OBJECT(
            'titlos', NEW.titlos,
            'idryma', NEW.idryma,
            'bathmida', NEW.bathmida
        )
    );
END$$

DROP TRIGGER IF EXISTS trg_degree_after_update_audit$$
CREATE TRIGGER trg_degree_after_update_audit
AFTER UPDATE ON degree
FOR EACH ROW
BEGIN
    INSERT INTO dba_log (
        actor_username,
        table_name,
        action_type,
        record_key,
        old_data,
        new_data
    ) VALUES (
        CURRENT_USER(),
        'degree',
        'UPDATE',
        CONCAT(NEW.titlos, ' | ', NEW.idryma),
        JSON_OBJECT(
            'titlos', OLD.titlos,
            'idryma', OLD.idryma,
            'bathmida', OLD.bathmida
        ),
        JSON_OBJECT(
            'titlos', NEW.titlos,
            'idryma', NEW.idryma,
            'bathmida', NEW.bathmida
        )
    );
END$$

DROP TRIGGER IF EXISTS trg_degree_after_delete_audit$$
CREATE TRIGGER trg_degree_after_delete_audit
AFTER DELETE ON degree
FOR EACH ROW
BEGIN
    INSERT INTO dba_log (
        actor_username,
        table_name,
        action_type,
        record_key,
        old_data,
        new_data
    ) VALUES (
        CURRENT_USER(),
        'degree',
        'DELETE',
        CONCAT(OLD.titlos, ' | ', OLD.idryma),
        JSON_OBJECT(
            'titlos', OLD.titlos,
            'idryma', OLD.idryma,
            'bathmida', OLD.bathmida
        ),
        NULL
    );
END$$

DELIMITER ;
