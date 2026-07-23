-- Employee Promotion Database System
-- File: 05-generate-history.sql
-- Purpose: Populate request_history with more than 60,000 completed records.
-- Run after 01-schema.sql, 02-seed-data.sql, 03-procedures.sql, and 04-triggers.sql.
-- MySQL version: 8.0+
--
-- The history benchmark uses more than 60,000 rows with integer evaluation
-- grades from 1 to 20. This repeatable generator tops the table up to 60,001
-- rows while preserving existing historical records.

USE firms;

DELIMITER $$

DROP PROCEDURE IF EXISTS GenerateRequestHistory$$

CREATE PROCEDURE GenerateRequestHistory(
    IN p_target_rows INT UNSIGNED
)
procedure_body: BEGIN
    DECLARE v_existing_rows BIGINT UNSIGNED DEFAULT 0;
    DECLARE v_rows_to_add INT UNSIGNED DEFAULT 0;
    DECLARE v_employee_count INT UNSIGNED DEFAULT 0;
    DECLARE v_evaluator_count INT UNSIGNED DEFAULT 0;
    DECLARE v_job_count INT UNSIGNED DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        DROP TEMPORARY TABLE IF EXISTS tmp_history_sequence;
        DROP TEMPORARY TABLE IF EXISTS tmp_history_employees;
        DROP TEMPORARY TABLE IF EXISTS tmp_history_evaluators_one;
        DROP TEMPORARY TABLE IF EXISTS tmp_history_evaluators_two;
        DROP TEMPORARY TABLE IF EXISTS tmp_history_jobs;
        RESIGNAL;
    END;

    IF p_target_rows IS NULL OR p_target_rows <= 60000 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'The target must be greater than 60,000 rows.';
    END IF;

    -- Five decimal digits can generate at most 100,000 rows per execution.
    IF p_target_rows > 100000 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'This generator supports a maximum target of 100,000 rows.';
    END IF;

    SELECT COUNT(*)
      INTO v_existing_rows
      FROM request_history;

    IF v_existing_rows >= p_target_rows THEN
        SELECT
            'No rows were added because the target already exists.' AS message,
            v_existing_rows AS existing_rows,
            p_target_rows AS requested_target;
        LEAVE procedure_body;
    END IF;

    SET v_rows_to_add = p_target_rows - v_existing_rows;

    SELECT COUNT(*) INTO v_employee_count FROM employee;
    SELECT COUNT(*) INTO v_evaluator_count FROM evaluator;
    SELECT COUNT(*) INTO v_job_count FROM job;

    IF v_employee_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'At least one employee is required before history data can be generated.';
    END IF;

    IF v_evaluator_count < 2 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'At least two evaluators are required before history data can be generated.';
    END IF;

    IF v_job_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'At least one job is required before history data can be generated.';
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_history_sequence;
    DROP TEMPORARY TABLE IF EXISTS tmp_history_employees;
    DROP TEMPORARY TABLE IF EXISTS tmp_history_evaluators_one;
    DROP TEMPORARY TABLE IF EXISTS tmp_history_evaluators_two;
    DROP TEMPORARY TABLE IF EXISTS tmp_history_jobs;

    CREATE TEMPORARY TABLE tmp_history_sequence (
        sequence_number INT UNSIGNED NOT NULL,
        PRIMARY KEY (sequence_number)
    ) ENGINE = MEMORY;

    -- MySQL temporary tables cannot be referenced more than once in the same
    -- statement. Use five independent inline digit sets instead of joining one
    -- temporary digit table under five aliases.
    INSERT INTO tmp_history_sequence (sequence_number)
    SELECT
        d0.digit
        + (d1.digit * 10)
        + (d2.digit * 100)
        + (d3.digit * 1000)
        + (d4.digit * 10000)
        + 1 AS sequence_number
    FROM (
        SELECT 0 AS digit UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL
        SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL
        SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
    ) AS d0
    CROSS JOIN (
        SELECT 0 AS digit UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL
        SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL
        SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
    ) AS d1
    CROSS JOIN (
        SELECT 0 AS digit UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL
        SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL
        SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
    ) AS d2
    CROSS JOIN (
        SELECT 0 AS digit UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL
        SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL
        SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
    ) AS d3
    CROSS JOIN (
        SELECT 0 AS digit UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL
        SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL
        SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
    ) AS d4
    WHERE d0.digit
          + (d1.digit * 10)
          + (d2.digit * 100)
          + (d3.digit * 1000)
          + (d4.digit * 10000) < v_rows_to_add;

    CREATE TEMPORARY TABLE tmp_history_employees (
        row_number_value INT UNSIGNED NOT NULL,
        username VARCHAR(30) NOT NULL,
        PRIMARY KEY (row_number_value)
    ) ENGINE = MEMORY;

    INSERT INTO tmp_history_employees (row_number_value, username)
    SELECT
        ROW_NUMBER() OVER (ORDER BY e.username),
        e.username
    FROM employee AS e;

    -- MySQL cannot read the same temporary table twice in one statement.
    -- Keep two identical evaluator lookup tables so each is joined only once.
    CREATE TEMPORARY TABLE tmp_history_evaluators_one (
        row_number_value INT UNSIGNED NOT NULL,
        username VARCHAR(30) NOT NULL,
        PRIMARY KEY (row_number_value)
    ) ENGINE = MEMORY;

    INSERT INTO tmp_history_evaluators_one (row_number_value, username)
    SELECT
        ROW_NUMBER() OVER (ORDER BY ev.username),
        ev.username
    FROM evaluator AS ev;

    CREATE TEMPORARY TABLE tmp_history_evaluators_two (
        row_number_value INT UNSIGNED NOT NULL,
        username VARCHAR(30) NOT NULL,
        PRIMARY KEY (row_number_value)
    ) ENGINE = MEMORY;

    INSERT INTO tmp_history_evaluators_two (row_number_value, username)
    SELECT
        row_number_value,
        username
    FROM tmp_history_evaluators_one;

    CREATE TEMPORARY TABLE tmp_history_jobs (
        row_number_value INT UNSIGNED NOT NULL,
        job_id INT UNSIGNED NOT NULL,
        PRIMARY KEY (row_number_value)
    ) ENGINE = MEMORY;

    INSERT INTO tmp_history_jobs (row_number_value, job_id)
    SELECT
        ROW_NUMBER() OVER (ORDER BY j.id),
        j.id
    FROM job AS j;

    START TRANSACTION;

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
        evaluator_one.username,
        evaluator_two.username,
        selected_employee.username,
        selected_job.job_id,
        'completed',
        'active',
        1 + MOD(
            CRC32(
                CONCAT(
                    'history-grade-',
                    v_existing_rows + seq_row.sequence_number
                )
            ),
            20
        ) AS evaluation_grade,
        DATE_SUB(
            CURRENT_DATE,
            INTERVAL MOD(
                v_existing_rows + seq_row.sequence_number,
                1825
            ) DAY
        ) AS request_date,
        DATE_ADD(
            DATE_SUB(
                CURRENT_DATE,
                INTERVAL MOD(
                    v_existing_rows + seq_row.sequence_number,
                    1825
                ) DAY
            ),
            INTERVAL MOD(
                CRC32(
                    CONCAT(
                        'history-time-',
                        v_existing_rows + seq_row.sequence_number
                    )
                ),
                86400
            ) SECOND
        ) AS completed_at,
        FALSE
    FROM tmp_history_sequence AS seq_row
    JOIN tmp_history_employees AS selected_employee
      ON selected_employee.row_number_value = 1 + MOD(
          v_existing_rows + seq_row.sequence_number - 1,
          v_employee_count
      )
    JOIN tmp_history_jobs AS selected_job
      ON selected_job.row_number_value = 1 + MOD(
          v_existing_rows + seq_row.sequence_number - 1,
          v_job_count
      )
    JOIN tmp_history_evaluators_one AS evaluator_one
      ON evaluator_one.row_number_value = 1 + MOD(
          v_existing_rows + seq_row.sequence_number - 1,
          v_evaluator_count
      )
    JOIN tmp_history_evaluators_two AS evaluator_two
      ON evaluator_two.row_number_value = 1 + MOD(
          v_existing_rows + seq_row.sequence_number,
          v_evaluator_count
      )
    ORDER BY seq_row.sequence_number;

    COMMIT;

    DROP TEMPORARY TABLE IF EXISTS tmp_history_sequence;
    DROP TEMPORARY TABLE IF EXISTS tmp_history_employees;
    DROP TEMPORARY TABLE IF EXISTS tmp_history_evaluators_one;
    DROP TEMPORARY TABLE IF EXISTS tmp_history_evaluators_two;
    DROP TEMPORARY TABLE IF EXISTS tmp_history_jobs;

    SELECT
        'History generation completed successfully.' AS message,
        v_existing_rows AS rows_before,
        v_rows_to_add AS rows_added,
        (SELECT COUNT(*) FROM request_history) AS rows_after;
END$$

DELIMITER ;

-- Generate the 60,001 historical records used by the project.
CALL GenerateRequestHistory(60001);

-- Immediate verification summary.
SELECT
    COUNT(*) AS total_history_rows,
    MIN(evaluation_grade) AS minimum_grade,
    MAX(evaluation_grade) AS maximum_grade,
    COUNT(DISTINCT evaluation_grade) AS distinct_grade_values
FROM request_history;

SELECT
    evaluation_grade,
    COUNT(*) AS applications_with_grade
FROM request_history
GROUP BY evaluation_grade
ORDER BY evaluation_grade;
