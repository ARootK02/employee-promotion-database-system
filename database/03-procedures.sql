-- Employee Promotion Database System
-- File: 03-procedures.sql
-- Purpose: Install the stored routines for evaluation, application management, result processing, and history search.
-- Run after 01-schema.sql and 02-seed-data.sql.
-- MySQL version: 8.0+

USE firms;

DELIMITER $$

-- -----------------------------------------------------------------------------
-- Helper function
-- Calculates the qualification-based grade used when an evaluator grade is missing.
-- Degree points: BSc = 1, MSc = 2, PhD = 3.
-- Foreign-language points: 1 when at least one non-Greek language exists.
-- Project points: 1 per project.
-- The result is constrained to the normal evaluation range 1-20. A minimum of
-- 1 keeps the value 0 reserved for "evaluator not assigned" and canceled rows.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS CalculateQualificationScore$$

CREATE FUNCTION CalculateQualificationScore(
    p_employee_username VARCHAR(30)
)
RETURNS TINYINT UNSIGNED
READS SQL DATA
NOT DETERMINISTIC
BEGIN
    DECLARE v_degree_points INT DEFAULT 0;
    DECLARE v_language_points INT DEFAULT 0;
    DECLARE v_project_points INT DEFAULT 0;
    DECLARE v_total_points INT DEFAULT 0;

    SELECT COALESCE(
               SUM(
                   CASE d.bathmida
                       WHEN 'BSc' THEN 1
                       WHEN 'MSc' THEN 2
                       WHEN 'PhD' THEN 3
                       ELSE 0
                   END
               ),
               0
           )
      INTO v_degree_points
      FROM has_degree AS hd
      JOIN degree AS d
        ON d.titlos = hd.degr_title
       AND d.idryma = hd.degr_idryma
     WHERE hd.cand_username = p_employee_username;

    SELECT CASE
               WHEN EXISTS (
                   SELECT 1
                     FROM languages AS l
                    WHERE l.candid = p_employee_username
                      AND l.lang <> 'GR'
               ) THEN 1
               ELSE 0
           END
      INTO v_language_points;

    SELECT COUNT(*)
      INTO v_project_points
      FROM project AS p
     WHERE p.candid = p_employee_username;

    SET v_total_points =
        v_degree_points + v_language_points + v_project_points;

    RETURN CAST(LEAST(20, GREATEST(1, v_total_points)) AS UNSIGNED);
END$$

-- -----------------------------------------------------------------------------
-- 3.1.3.1
-- Returns:
--   0  -> the evaluator is not assigned to this employee/job request.
--   1-20 -> an existing evaluator grade or a qualification-based replacement
--           when the assigned evaluator has not entered a grade.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS GetEvaluationGrade$$

CREATE PROCEDURE GetEvaluationGrade(
    IN p_evaluator_username VARCHAR(30),
    IN p_employee_username VARCHAR(30),
    IN p_job_id INT UNSIGNED,
    OUT p_evaluation_grade INT
)
procedure_body: BEGIN
    DECLARE v_request_count INT DEFAULT 0;
    DECLARE v_stored_grade INT DEFAULT NULL;

    SET p_evaluation_grade = 0;

    SELECT COUNT(*)
      INTO v_request_count
      FROM promotion_request AS pr
     WHERE pr.employee_username = p_employee_username
       AND pr.job_id = p_job_id
       AND (
            pr.evaluator1_username = p_evaluator_username
            OR pr.evaluator2_username = p_evaluator_username
       );

    IF v_request_count = 0 THEN
        LEAVE procedure_body;
    END IF;

    SELECT CASE
               WHEN pr.evaluator1_username = p_evaluator_username
                   THEN pr.evaluation_grade1
               ELSE pr.evaluation_grade2
           END
      INTO v_stored_grade
      FROM promotion_request AS pr
     WHERE pr.employee_username = p_employee_username
       AND pr.job_id = p_job_id
       AND (
            pr.evaluator1_username = p_evaluator_username
            OR pr.evaluator2_username = p_evaluator_username
       )
     LIMIT 1;

    IF v_stored_grade IS NULL THEN
        SET p_evaluation_grade =
            CalculateQualificationScore(p_employee_username);
    ELSE
        SET p_evaluation_grade = v_stored_grade;
    END IF;
END$$

-- -----------------------------------------------------------------------------
-- 3.1.3.2
-- p_action values:
--   'i' -> insert a new active application.
--   'c' -> cancel an existing active application.
--   'a' -> reactivate an existing canceled application.
--
-- Evaluator 1 is the evaluator assigned to the job. Evaluator 2 is selected
-- from the same company, preferring the evaluator with the smallest current
-- active workload and then the most experience.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS manage_application$$

CREATE PROCEDURE manage_application(
    IN p_employee_username VARCHAR(30),
    IN p_job_id INT UNSIGNED,
    IN p_action CHAR(1)
)
procedure_body: BEGIN
    DECLARE v_action CHAR(1);
    DECLARE v_employee_exists INT DEFAULT 0;
    DECLARE v_job_exists INT DEFAULT 0;
    DECLARE v_request_exists INT DEFAULT 0;
    DECLARE v_active_count INT DEFAULT 0;
    DECLARE v_current_status VARCHAR(20) DEFAULT NULL;
    DECLARE v_start_date DATE DEFAULT NULL;
    DECLARE v_evaluator1 VARCHAR(30) DEFAULT NULL;
    DECLARE v_evaluator2 VARCHAR(30) DEFAULT NULL;
    DECLARE v_firm CHAR(9) DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_action = LOWER(TRIM(p_action));

    IF v_action NOT IN ('i', 'c', 'a') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Action must be i (insert), c (cancel), or a (activate).';
    END IF;

    SELECT COUNT(*)
      INTO v_employee_exists
      FROM employee AS e
     WHERE e.username = p_employee_username;

    IF v_employee_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'The specified employee does not exist.';
    END IF;

    SELECT COUNT(*)
      INTO v_job_exists
      FROM job AS j
     WHERE j.id = p_job_id;

    IF v_job_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'The specified job does not exist.';
    END IF;

    START TRANSACTION;

    SELECT COUNT(*)
      INTO v_request_exists
      FROM promotion_request AS pr
     WHERE pr.employee_username = p_employee_username
       AND pr.job_id = p_job_id;

    IF v_request_exists > 0 THEN
        SELECT pr.status
          INTO v_current_status
          FROM promotion_request AS pr
         WHERE pr.employee_username = p_employee_username
           AND pr.job_id = p_job_id
         LIMIT 1;
    END IF;

    IF v_action = 'i' THEN
        IF v_request_exists > 0 THEN
            IF v_current_status = 'canceled' THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'A canceled application already exists; use action a to reactivate it.';
            ELSE
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'An active application already exists for this employee and job.';
            END IF;
        END IF;

        SELECT j.start_date, j.job_evaluator, ev.firm
          INTO v_start_date, v_evaluator1, v_firm
          FROM job AS j
          JOIN evaluator AS ev
            ON ev.username = j.job_evaluator
         WHERE j.id = p_job_id;

        IF DATEDIFF(v_start_date, CURRENT_DATE) < 15 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Applications are not allowed fewer than 15 days before the job start date.';
        END IF;

        SELECT COUNT(*)
          INTO v_active_count
          FROM promotion_request AS pr
         WHERE pr.employee_username = p_employee_username
           AND pr.status = 'active';

        IF v_active_count >= 3 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'The employee already has three active applications.';
        END IF;

        SELECT ev.username
          INTO v_evaluator2
          FROM evaluator AS ev
         WHERE ev.firm = v_firm
           AND ev.username <> v_evaluator1
         ORDER BY (
             SELECT COUNT(*)
               FROM promotion_request AS workload
              WHERE workload.status = 'active'
                AND (
                     workload.evaluator1_username = ev.username
                     OR workload.evaluator2_username = ev.username
                )
         ) ASC,
         ev.exp_years DESC,
         ev.username ASC
         LIMIT 1;

        IF v_evaluator2 IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'A second evaluator from the job company is not available.';
        END IF;

        INSERT INTO promotion_request (
            evaluator1_username,
            evaluator2_username,
            employee_username,
            job_id,
            status,
            cancel_date,
            request_date,
            evaluation_grade1,
            evaluation_grade2
        ) VALUES (
            v_evaluator1,
            v_evaluator2,
            p_employee_username,
            p_job_id,
            'active',
            NULL,
            CURRENT_DATE,
            NULL,
            NULL
        );

        COMMIT;

        SELECT
            'Application created successfully.' AS message,
            p_employee_username AS employee_username,
            p_job_id AS job_id,
            v_evaluator1 AS evaluator1_username,
            v_evaluator2 AS evaluator2_username,
            'active' AS status;

    ELSEIF v_action = 'c' THEN
        IF v_request_exists = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'No application exists for this employee and job.';
        END IF;

        IF v_current_status = 'canceled' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'The application is already canceled.';
        END IF;

        SELECT j.start_date
          INTO v_start_date
          FROM job AS j
         WHERE j.id = p_job_id;

        IF DATEDIFF(v_start_date, CURRENT_DATE) < 10 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Cancellation is not allowed fewer than 10 days before the job start date.';
        END IF;

        UPDATE promotion_request AS pr
           SET pr.status = 'canceled',
               pr.cancel_date = CURRENT_DATE
         WHERE pr.employee_username = p_employee_username
           AND pr.job_id = p_job_id;

        COMMIT;

        SELECT
            'Application canceled successfully.' AS message,
            p_employee_username AS employee_username,
            p_job_id AS job_id,
            'canceled' AS status;

    ELSE
        IF v_request_exists = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'No application exists for this employee and job.';
        END IF;

        IF v_current_status = 'active' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'The application is already active.';
        END IF;

        SELECT COUNT(*)
          INTO v_active_count
          FROM promotion_request AS pr
         WHERE pr.employee_username = p_employee_username
           AND pr.status = 'active';

        IF v_active_count >= 3 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'The employee already has three active applications.';
        END IF;

        UPDATE promotion_request AS pr
           SET pr.status = 'active',
               pr.cancel_date = NULL
         WHERE pr.employee_username = p_employee_username
           AND pr.job_id = p_job_id;

        COMMIT;

        SELECT
            'Application reactivated successfully.' AS message,
            p_employee_username AS employee_username,
            p_job_id AS job_id,
            'active' AS status;
    END IF;
END$$

-- -----------------------------------------------------------------------------
-- 3.1.3.3
-- Completes every application for one job in a single transaction.
-- Missing active-request grades are replaced with the qualification score.
-- Canceled requests receive final grade 0. The active request with the highest
-- average wins; equal averages are resolved by the earliest request date.
-- Every processed row is moved to request_history and removed from the active
-- promotion_request table.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS EVALUATEPROMOTIONREQUEST$$

CREATE PROCEDURE EVALUATEPROMOTIONREQUEST(
    IN p_job_id INT UNSIGNED
)
procedure_body: BEGIN
    DECLARE v_job_exists INT DEFAULT 0;
    DECLARE v_request_count INT DEFAULT 0;
    DECLARE v_active_count INT DEFAULT 0;
    DECLARE v_winner_id BIGINT UNSIGNED DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        DROP TEMPORARY TABLE IF EXISTS tmp_job_results;
        RESIGNAL;
    END;

    SELECT COUNT(*)
      INTO v_job_exists
      FROM job AS j
     WHERE j.id = p_job_id;

    IF v_job_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'The specified job does not exist.';
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_job_results;

    CREATE TEMPORARY TABLE tmp_job_results (
        request_id BIGINT UNSIGNED NOT NULL,
        evaluator1_username VARCHAR(30) NOT NULL,
        evaluator2_username VARCHAR(30) NOT NULL,
        employee_username VARCHAR(30) NOT NULL,
        job_id INT UNSIGNED NOT NULL,
        original_status ENUM('active', 'canceled') NOT NULL,
        request_date DATE NOT NULL,
        effective_grade1 TINYINT UNSIGNED NOT NULL,
        effective_grade2 TINYINT UNSIGNED NOT NULL,
        final_grade DECIMAL(4, 2) NOT NULL,
        was_winner BOOLEAN NOT NULL DEFAULT FALSE,
        PRIMARY KEY (request_id)
    ) ENGINE = MEMORY;

    START TRANSACTION;

    SELECT COUNT(*)
      INTO v_request_count
      FROM promotion_request AS pr
     WHERE pr.job_id = p_job_id;

    IF v_request_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No applications exist for the specified job.';
    END IF;

    INSERT INTO tmp_job_results (
        request_id,
        evaluator1_username,
        evaluator2_username,
        employee_username,
        job_id,
        original_status,
        request_date,
        effective_grade1,
        effective_grade2,
        final_grade,
        was_winner
    )
    SELECT
        calculated.request_id,
        calculated.evaluator1_username,
        calculated.evaluator2_username,
        calculated.employee_username,
        calculated.job_id,
        calculated.original_status,
        calculated.request_date,
        calculated.effective_grade1,
        calculated.effective_grade2,
        CASE
            WHEN calculated.original_status = 'canceled' THEN 0
            ELSE ROUND(
                (calculated.effective_grade1 + calculated.effective_grade2) / 2,
                2
            )
        END AS final_grade,
        FALSE
    FROM (
        SELECT
            pr.id AS request_id,
            pr.evaluator1_username,
            pr.evaluator2_username,
            pr.employee_username,
            pr.job_id,
            pr.status AS original_status,
            pr.request_date,
            CASE
                WHEN pr.status = 'canceled' THEN 0
                ELSE COALESCE(
                    pr.evaluation_grade1,
                    CalculateQualificationScore(pr.employee_username)
                )
            END AS effective_grade1,
            CASE
                WHEN pr.status = 'canceled' THEN 0
                ELSE COALESCE(
                    pr.evaluation_grade2,
                    CalculateQualificationScore(pr.employee_username)
                )
            END AS effective_grade2
        FROM promotion_request AS pr
        WHERE pr.job_id = p_job_id
    ) AS calculated;

    SELECT COUNT(*)
      INTO v_active_count
      FROM tmp_job_results AS result_row
     WHERE result_row.original_status = 'active';

    IF v_active_count > 0 THEN
        SELECT result_row.request_id
          INTO v_winner_id
          FROM tmp_job_results AS result_row
         WHERE result_row.original_status = 'active'
         ORDER BY result_row.final_grade DESC,
                  result_row.request_date ASC,
                  result_row.request_id ASC
         LIMIT 1;

        UPDATE tmp_job_results AS result_row
           SET result_row.was_winner = TRUE
         WHERE result_row.request_id = v_winner_id;
    END IF;

    INSERT INTO request_history (
        evaluator1_username,
        evaluator2_username,
        employee_username,
        job_id,
        status,
        original_status,
        evaluation_grade,
        request_date,
        completed_at,
        was_winner
    )
    SELECT
        result_row.evaluator1_username,
        result_row.evaluator2_username,
        result_row.employee_username,
        result_row.job_id,
        'completed',
        result_row.original_status,
        result_row.final_grade,
        result_row.request_date,
        CURRENT_TIMESTAMP,
        result_row.was_winner
    FROM tmp_job_results AS result_row;

    DELETE FROM promotion_request
     WHERE job_id = p_job_id;

    COMMIT;

    -- Result set 1: every processed application.
    SELECT
        result_row.employee_username,
        result_row.job_id,
        result_row.original_status AS previous_status,
        result_row.effective_grade1 AS evaluator1_grade,
        result_row.effective_grade2 AS evaluator2_grade,
        result_row.final_grade,
        result_row.request_date,
        result_row.was_winner
    FROM tmp_job_results AS result_row
    ORDER BY result_row.was_winner DESC,
             result_row.final_grade DESC,
             result_row.request_date ASC,
             result_row.request_id ASC;

    -- Result set 2: a concise winner summary for the GUI and report.
    SELECT
        p_job_id AS job_id,
        winner.employee_username AS winner_username,
        winner.final_grade AS winning_grade,
        v_request_count AS processed_applications
    FROM (SELECT 1 AS placeholder) AS one_row
    LEFT JOIN tmp_job_results AS winner
      ON winner.was_winner = TRUE;

    DROP TEMPORARY TABLE IF EXISTS tmp_job_results;
END$$

-- -----------------------------------------------------------------------------
-- 3.1.3.4(a)
-- Returns completed applications whose final evaluation falls within the two
-- supplied bounds. The supporting grade index is installed in 06-indexes-and-
-- benchmarks.sql.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS findApplicationsByGrade$$

CREATE PROCEDURE findApplicationsByGrade(
    IN p_grade1 INT,
    IN p_grade2 INT
)
BEGIN
    DECLARE v_low_grade INT;
    DECLARE v_high_grade INT;

    IF p_grade1 IS NULL OR p_grade2 IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Both grade limits are required.';
    END IF;

    IF p_grade1 = p_grade2 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'The two grade limits must be different.';
    END IF;

    IF p_grade1 NOT BETWEEN 0 AND 20
       OR p_grade2 NOT BETWEEN 0 AND 20 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Grade limits must be between 0 and 20.';
    END IF;

    SET v_low_grade = LEAST(p_grade1, p_grade2);
    SET v_high_grade = GREATEST(p_grade1, p_grade2);

    SELECT
        rh.employee_username,
        rh.job_id
    FROM request_history AS rh
    WHERE rh.evaluation_grade BETWEEN v_low_grade AND v_high_grade
    ORDER BY rh.evaluation_grade ASC,
             rh.employee_username ASC,
             rh.job_id ASC;
END$$

-- -----------------------------------------------------------------------------
-- 3.1.3.4(b)
-- Returns completed applications evaluated by the supplied evaluator. The two
-- supporting evaluator indexes are installed in 06-indexes-and-benchmarks.sql.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS findApplicationsByEvaluator$$

CREATE PROCEDURE findApplicationsByEvaluator(
    IN p_evaluator_username VARCHAR(30)
)
BEGIN
    IF p_evaluator_username IS NULL
       OR CHAR_LENGTH(TRIM(p_evaluator_username)) = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'An evaluator username is required.';
    END IF;

    SELECT
        rh.employee_username,
        rh.job_id
    FROM request_history AS rh
    WHERE rh.evaluator1_username = p_evaluator_username
       OR rh.evaluator2_username = p_evaluator_username
    ORDER BY rh.employee_username ASC,
             rh.job_id ASC;
END$$

DELIMITER ;
