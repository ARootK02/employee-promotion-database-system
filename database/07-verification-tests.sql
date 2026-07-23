-- Employee Promotion Database System
-- File: 07-verification-tests.sql
-- Purpose: Verify the complete Part A database implementation without leaving
--          test records behind.
-- Run after 01-schema.sql through 06-indexes-and-benchmarks.sql.
-- MySQL version: 8.0+
--
-- The final result set lists every check as PASS or FAIL. Functional tests use
-- temporary records that are removed before completion. The script restores affected
-- AUTO_INCREMENT counters after testing.

USE firms;

DROP TEMPORARY TABLE IF EXISTS verification_results;

CREATE TEMPORARY TABLE verification_results (
    result_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    category VARCHAR(60) NOT NULL,
    test_name VARCHAR(160) NOT NULL,
    expected_result VARCHAR(255) NOT NULL,
    actual_result VARCHAR(255) NOT NULL,
    status ENUM('PASS', 'FAIL') NOT NULL,
    details VARCHAR(1000) NULL,
    PRIMARY KEY (result_id)
) ENGINE = MEMORY;

-- -----------------------------------------------------------------------------
-- 1. Schema, routine, trigger, and index installation checks
-- -----------------------------------------------------------------------------
INSERT INTO verification_results (
    category,
    test_name,
    expected_result,
    actual_result,
    status,
    details
)
SELECT
    'Installation',
    'Active database',
    'firms',
    DATABASE(),
    IF(DATABASE() = 'firms', 'PASS', 'FAIL'),
    'The verification script must run against the firms database.';

INSERT INTO verification_results (
    category,
    test_name,
    expected_result,
    actual_result,
    status,
    details
)
SELECT
    'Installation',
    'Required table count',
    '16',
    CAST(COUNT(*) AS CHAR),
    IF(COUNT(*) = 16, 'PASS', 'FAIL'),
    'The complete relational design contains 16 base tables.'
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_type = 'BASE TABLE';

DROP TEMPORARY TABLE IF EXISTS expected_routines;
CREATE TEMPORARY TABLE expected_routines (
    routine_name VARCHAR(64) NOT NULL,
    routine_type ENUM('PROCEDURE', 'FUNCTION') NOT NULL,
    PRIMARY KEY (routine_name, routine_type)
) ENGINE = MEMORY;

INSERT INTO expected_routines (routine_name, routine_type) VALUES
    ('CalculateQualificationScore', 'FUNCTION'),
    ('GetEvaluationGrade', 'PROCEDURE'),
    ('manage_application', 'PROCEDURE'),
    ('EVALUATEPROMOTIONREQUEST', 'PROCEDURE'),
    ('findApplicationsByGrade', 'PROCEDURE'),
    ('findApplicationsByEvaluator', 'PROCEDURE'),
    ('GenerateRequestHistory', 'PROCEDURE');

INSERT INTO verification_results (
    category,
    test_name,
    expected_result,
    actual_result,
    status,
    details
)
SELECT
    'Installation',
    CONCAT('Routine installed: ', expected.routine_name),
    expected.routine_type,
    COALESCE(actual.routine_type, 'MISSING'),
    IF(actual.routine_name IS NOT NULL, 'PASS', 'FAIL'),
    'Checks the required stored routines and the two supporting routines.'
FROM expected_routines AS expected
LEFT JOIN information_schema.routines AS actual
  ON actual.routine_schema = DATABASE()
 AND actual.routine_name = expected.routine_name
 AND actual.routine_type = expected.routine_type
ORDER BY expected.routine_type, expected.routine_name;

INSERT INTO verification_results (
    category,
    test_name,
    expected_result,
    actual_result,
    status,
    details
)
SELECT
    'Installation',
    'Required trigger count',
    '12',
    CAST(COUNT(*) AS CHAR),
    IF(COUNT(*) = 12, 'PASS', 'FAIL'),
    'Twelve triggers implement project numbering, application rules, and auditing.'
FROM information_schema.triggers
WHERE trigger_schema = DATABASE();

DROP TEMPORARY TABLE IF EXISTS expected_indexes;
CREATE TEMPORARY TABLE expected_indexes (
    index_name VARCHAR(64) NOT NULL,
    PRIMARY KEY (index_name)
) ENGINE = MEMORY;

INSERT INTO expected_indexes (index_name) VALUES
    ('idx_history_grade_employee_job'),
    ('idx_history_evaluator1_employee_job'),
    ('idx_history_evaluator2_employee_job');

INSERT INTO verification_results (
    category,
    test_name,
    expected_result,
    actual_result,
    status,
    details
)
SELECT
    'Installation',
    CONCAT('History index installed: ', expected.index_name),
    'installed',
    IF(actual.index_name IS NULL, 'missing', 'installed'),
    IF(actual.index_name IS NULL, 'FAIL', 'PASS'),
    'Checks the indexes used by the two history-search procedures.'
FROM expected_indexes AS expected
LEFT JOIN (
    SELECT DISTINCT index_name
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'request_history'
) AS actual
  ON actual.index_name = expected.index_name
ORDER BY expected.index_name;

-- -----------------------------------------------------------------------------
-- 2. Minimum seed row counts for the three-member team
-- -----------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS minimum_seed_counts;
CREATE TEMPORARY TABLE minimum_seed_counts (
    table_name VARCHAR(64) NOT NULL,
    minimum_rows INT UNSIGNED NOT NULL,
    PRIMARY KEY (table_name)
) ENGINE = MEMORY;

INSERT INTO minimum_seed_counts (table_name, minimum_rows) VALUES
    ('applies', 18),
    ('degree', 18),
    ('employee', 18),
    ('etairia', 9),
    ('evaluator', 18),
    ('has_degree', 12),
    ('job', 24),
    ('languages', 12),
    ('project', 21),
    ('requires', 24),
    ('subject', 24),
    ('user', 36);

INSERT INTO verification_results (
    category,
    test_name,
    expected_result,
    actual_result,
    status,
    details
)
SELECT
    'Seed data',
    CONCAT('Minimum rows in ', counts.table_name),
    CONCAT('>= ', minimums.minimum_rows),
    CAST(counts.actual_rows AS CHAR),
    IF(counts.actual_rows >= minimums.minimum_rows, 'PASS', 'FAIL'),
    'The minimum equals the per-member requirement multiplied by three team members.'
FROM minimum_seed_counts AS minimums
JOIN (
    SELECT 'applies' AS table_name, COUNT(*) AS actual_rows FROM applies
    UNION ALL SELECT 'degree', COUNT(*) FROM degree
    UNION ALL SELECT 'employee', COUNT(*) FROM employee
    UNION ALL SELECT 'etairia', COUNT(*) FROM etairia
    UNION ALL SELECT 'evaluator', COUNT(*) FROM evaluator
    UNION ALL SELECT 'has_degree', COUNT(*) FROM has_degree
    UNION ALL SELECT 'job', COUNT(*) FROM job
    UNION ALL SELECT 'languages', COUNT(*) FROM languages
    UNION ALL SELECT 'project', COUNT(*) FROM project
    UNION ALL SELECT 'requires', COUNT(*) FROM requires
    UNION ALL SELECT 'subject', COUNT(*) FROM subject
    UNION ALL SELECT 'user', COUNT(*) FROM `user`
) AS counts
  ON counts.table_name = minimums.table_name
ORDER BY counts.table_name;

INSERT INTO verification_results (
    category,
    test_name,
    expected_result,
    actual_result,
    status,
    details
)
SELECT
    'Seed data',
    'Public-safe demonstration emails',
    'all use example.com',
    CONCAT(
        SUM(email LIKE '%@example.com'),
        ' of ',
        COUNT(*)
    ),
    IF(SUM(email LIKE '%@example.com') = COUNT(*), 'PASS', 'FAIL'),
    'The seed file must not contain real-looking personal email addresses.'
FROM `user`;

-- -----------------------------------------------------------------------------
-- 3. Data integrity and history-volume checks
-- -----------------------------------------------------------------------------
INSERT INTO verification_results (
    category,
    test_name,
    expected_result,
    actual_result,
    status,
    details
)
SELECT
    'Integrity',
    'Duplicate employee/job promotion requests',
    '0 duplicate groups',
    CAST(COUNT(*) AS CHAR),
    IF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Each employee may have at most one current request for a particular job.'
FROM (
    SELECT employee_username, job_id
    FROM promotion_request
    GROUP BY employee_username, job_id
    HAVING COUNT(*) > 1
) AS duplicate_requests;

INSERT INTO verification_results (
    category,
    test_name,
    expected_result,
    actual_result,
    status,
    details
)
SELECT
    'Integrity',
    'Requests with the same evaluator twice',
    '0',
    CAST(COUNT(*) AS CHAR),
    IF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Every request must be evaluated by two distinct evaluators.'
FROM promotion_request
WHERE evaluator1_username = evaluator2_username;

INSERT INTO verification_results (
    category,
    test_name,
    expected_result,
    actual_result,
    status,
    details
)
SELECT
    'Integrity',
    'Employees exceeding three active requests',
    '0 employees',
    CAST(COUNT(*) AS CHAR),
    IF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'The active-application limit is three per employee.'
FROM (
    SELECT employee_username
    FROM promotion_request
    WHERE status = 'active'
    GROUP BY employee_username
    HAVING COUNT(*) > 3
) AS excessive_active_requests;

INSERT INTO verification_results (
    category,
    test_name,
    expected_result,
    actual_result,
    status,
    details
)
SELECT
    'Integrity',
    'Invalid cancellation-date states',
    '0',
    CAST(COUNT(*) AS CHAR),
    IF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Canceled requests require a cancellation date; active/completed requests must not have one.'
FROM promotion_request
WHERE (status = 'canceled' AND cancel_date IS NULL)
   OR (status IN ('active', 'completed') AND cancel_date IS NOT NULL);

INSERT INTO verification_results (
    category,
    test_name,
    expected_result,
    actual_result,
    status,
    details
)
SELECT
    'History',
    'History row requirement',
    '> 60000 rows',
    CAST(COUNT(*) AS CHAR),
    IF(COUNT(*) > 60000, 'PASS', 'FAIL'),
    'Assignment section 3.1.2.3 requires more than 60,000 completed records.'
FROM request_history;

INSERT INTO verification_results (
    category,
    test_name,
    expected_result,
    actual_result,
    status,
    details
)
SELECT
    'History',
    'Generated integer grades from 1 to 20',
    '> 60000 valid rows',
    CAST(SUM(
        evaluation_grade BETWEEN 1 AND 20
        AND evaluation_grade = FLOOR(evaluation_grade)
    ) AS CHAR),
    IF(
        SUM(
            evaluation_grade BETWEEN 1 AND 20
            AND evaluation_grade = FLOOR(evaluation_grade)
        ) > 60000,
        'PASS',
        'FAIL'
    ),
    'Canceled applications processed later may validly add grade 0 rows; the generated benchmark dataset must still contain more than 60,000 integer grades from 1 to 20.'
FROM request_history;

INSERT INTO verification_results (
    category,
    test_name,
    expected_result,
    actual_result,
    status,
    details
)
SELECT
    'History',
    'All twenty generated grade values represented',
    '20 distinct values from 1 to 20',
    CAST(COUNT(DISTINCT evaluation_grade) AS CHAR),
    IF(COUNT(DISTINCT evaluation_grade) = 20, 'PASS', 'FAIL'),
    'Evaluates the generated rows only; grade 0 is excluded from this check.'
FROM request_history
WHERE evaluation_grade BETWEEN 1 AND 20
  AND evaluation_grade = FLOOR(evaluation_grade);

INSERT INTO verification_results (
    category,
    test_name,
    expected_result,
    actual_result,
    status,
    details
)
SELECT
    'History',
    'Grade-range search has matches',
    '> 0 rows for grades 7-12',
    CAST(COUNT(*) AS CHAR),
    IF(COUNT(*) > 0, 'PASS', 'FAIL'),
    'Equivalent data check for findApplicationsByGrade without printing thousands of rows.'
FROM request_history
WHERE evaluation_grade BETWEEN 7 AND 12;

INSERT INTO verification_results (
    category,
    test_name,
    expected_result,
    actual_result,
    status,
    details
)
SELECT
    'History',
    'Evaluator search has matches',
    '> 0 rows for eval01',
    CAST(COUNT(*) AS CHAR),
    IF(COUNT(*) > 0, 'PASS', 'FAIL'),
    'Equivalent data check for findApplicationsByEvaluator without printing thousands of rows.'
FROM request_history
WHERE evaluator1_username = 'eval01'
   OR evaluator2_username = 'eval01';

-- -----------------------------------------------------------------------------
-- 4. Qualification and evaluation-grade routine checks
-- -----------------------------------------------------------------------------
SET @qualification_emp01 = CalculateQualificationScore('emp01');

INSERT INTO verification_results (
    category,
    test_name,
    expected_result,
    actual_result,
    status,
    details
) VALUES (
    'Stored routines',
    'Qualification score for emp01',
    '4',
    CAST(@qualification_emp01 AS CHAR),
    IF(@qualification_emp01 = 4, 'PASS', 'FAIL'),
    'BSc (1) + at least one foreign language (1) + two projects (2).'
);

SET @evaluation_grade = -1;
CALL GetEvaluationGrade('eval01', 'emp01', 1, @evaluation_grade);

INSERT INTO verification_results (
    category,
    test_name,
    expected_result,
    actual_result,
    status,
    details
) VALUES (
    'Stored routines',
    'GetEvaluationGrade returns a stored grade',
    '16',
    CAST(@evaluation_grade AS CHAR),
    IF(@evaluation_grade = 16, 'PASS', 'FAIL'),
    'eval01 has a stored grade of 16 for emp01 and job 1.'
);

SET @evaluation_grade = -1;
CALL GetEvaluationGrade('eval03', 'emp02', 2, @evaluation_grade);

INSERT INTO verification_results (
    category,
    test_name,
    expected_result,
    actual_result,
    status,
    details
) VALUES (
    'Stored routines',
    'GetEvaluationGrade calculates a missing grade',
    '5',
    CAST(@evaluation_grade AS CHAR),
    IF(@evaluation_grade = 5, 'PASS', 'FAIL'),
    'MSc (2) + at least one foreign language (1) + two projects (2).'
);

SET @evaluation_grade = -1;
CALL GetEvaluationGrade('eval18', 'emp01', 1, @evaluation_grade);

INSERT INTO verification_results (
    category,
    test_name,
    expected_result,
    actual_result,
    status,
    details
) VALUES (
    'Stored routines',
    'GetEvaluationGrade rejects an unassigned evaluator',
    '0',
    CAST(@evaluation_grade AS CHAR),
    IF(@evaluation_grade = 0, 'PASS', 'FAIL'),
    'The evaluator is not assigned to this employee/job request.'
);

-- -----------------------------------------------------------------------------
-- 5. Trigger tests performed inside rollback-only transactions
-- -----------------------------------------------------------------------------
DELIMITER $$

DROP PROCEDURE IF EXISTS RunVerificationTriggerTests$$

CREATE PROCEDURE RunVerificationTriggerTests()
BEGIN
    DECLARE v_error_caught BOOLEAN DEFAULT FALSE;
    DECLARE v_job1 INT UNSIGNED DEFAULT NULL;
    DECLARE v_job2 INT UNSIGNED DEFAULT NULL;
    DECLARE v_job3 INT UNSIGNED DEFAULT NULL;
    DECLARE v_job4 INT UNSIGNED DEFAULT NULL;
    DECLARE v_expected_project_num INT UNSIGNED DEFAULT 0;
    DECLARE v_actual_project_num INT UNSIGNED DEFAULT 0;
    DECLARE v_log_count_before BIGINT UNSIGNED DEFAULT 0;
    DECLARE v_log_count_after BIGINT UNSIGNED DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Automatic project numbering.
    START TRANSACTION;

    SELECT COALESCE(MAX(num), 0) + 1
      INTO v_expected_project_num
      FROM project
     WHERE candid = 'emp18';

    INSERT INTO project (candid, num, descr, url)
    VALUES (
        'emp18',
        0,
        'Temporary verification project',
        'https://example.com/projects/verification'
    );

    SELECT num
      INTO v_actual_project_num
      FROM project
     WHERE candid = 'emp18'
       AND descr = 'Temporary verification project'
     LIMIT 1;

    INSERT INTO verification_results (
        category,
        test_name,
        expected_result,
        actual_result,
        status,
        details
    ) VALUES (
        'Triggers',
        'Automatic project numbering',
        CAST(v_expected_project_num AS CHAR),
        CAST(v_actual_project_num AS CHAR),
        IF(v_actual_project_num = v_expected_project_num, 'PASS', 'FAIL'),
        'The trigger assigns the next project number independently for each employee.'
    );

    ROLLBACK;

    -- Prevent insertion fewer than 15 days before start_date.
    START TRANSACTION;

    INSERT INTO job (
        start_date,
        salary,
        position,
        edra,
        job_evaluator,
        announce_date,
        submission_date
    ) VALUES (
        CURRENT_DATE + INTERVAL 14 DAY,
        3000,
        'Temporary Late-Application Test',
        'Test Location',
        'eval01',
        CURRENT_TIMESTAMP,
        CURRENT_DATE + INTERVAL 5 DAY
    );

    SET v_job1 = LAST_INSERT_ID();
    SET v_error_caught = FALSE;

    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
            SET v_error_caught = TRUE;

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
            'eval01',
            'eval02',
            'emp18',
            v_job1,
            'active',
            NULL,
            CURRENT_DATE,
            NULL,
            NULL
        );
    END;

    INSERT INTO verification_results (
        category,
        test_name,
        expected_result,
        actual_result,
        status,
        details
    ) VALUES (
        'Triggers',
        'Late application is rejected',
        'SQL exception',
        IF(v_error_caught, 'SQL exception', 'insert succeeded'),
        IF(v_error_caught, 'PASS', 'FAIL'),
        'New requests are forbidden when fewer than 15 days remain before the job start date.'
    );

    ROLLBACK;

    -- Prevent a fourth active request.
    START TRANSACTION;

    INSERT INTO job (start_date, salary, position, edra, job_evaluator, announce_date, submission_date)
    VALUES (CURRENT_DATE + INTERVAL 90 DAY, 3000, 'Temporary Active Limit Test 1', 'Test Location', 'eval01', CURRENT_TIMESTAMP, CURRENT_DATE + INTERVAL 60 DAY);
    SET v_job1 = LAST_INSERT_ID();

    INSERT INTO job (start_date, salary, position, edra, job_evaluator, announce_date, submission_date)
    VALUES (CURRENT_DATE + INTERVAL 91 DAY, 3000, 'Temporary Active Limit Test 2', 'Test Location', 'eval01', CURRENT_TIMESTAMP, CURRENT_DATE + INTERVAL 60 DAY);
    SET v_job2 = LAST_INSERT_ID();

    INSERT INTO job (start_date, salary, position, edra, job_evaluator, announce_date, submission_date)
    VALUES (CURRENT_DATE + INTERVAL 92 DAY, 3000, 'Temporary Active Limit Test 3', 'Test Location', 'eval01', CURRENT_TIMESTAMP, CURRENT_DATE + INTERVAL 60 DAY);
    SET v_job3 = LAST_INSERT_ID();

    INSERT INTO job (start_date, salary, position, edra, job_evaluator, announce_date, submission_date)
    VALUES (CURRENT_DATE + INTERVAL 93 DAY, 3000, 'Temporary Active Limit Test 4', 'Test Location', 'eval01', CURRENT_TIMESTAMP, CURRENT_DATE + INTERVAL 60 DAY);
    SET v_job4 = LAST_INSERT_ID();

    INSERT INTO promotion_request (
        evaluator1_username, evaluator2_username, employee_username, job_id,
        status, cancel_date, request_date, evaluation_grade1, evaluation_grade2
    ) VALUES
        ('eval01', 'eval02', 'emp18', v_job1, 'active', NULL, CURRENT_DATE, NULL, NULL),
        ('eval01', 'eval02', 'emp18', v_job2, 'active', NULL, CURRENT_DATE, NULL, NULL),
        ('eval01', 'eval02', 'emp18', v_job3, 'active', NULL, CURRENT_DATE, NULL, NULL);

    SET v_error_caught = FALSE;

    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
            SET v_error_caught = TRUE;

        INSERT INTO promotion_request (
            evaluator1_username, evaluator2_username, employee_username, job_id,
            status, cancel_date, request_date, evaluation_grade1, evaluation_grade2
        ) VALUES (
            'eval01', 'eval02', 'emp18', v_job4,
            'active', NULL, CURRENT_DATE, NULL, NULL
        );
    END;

    INSERT INTO verification_results (
        category,
        test_name,
        expected_result,
        actual_result,
        status,
        details
    ) VALUES (
        'Triggers',
        'Fourth active request is rejected',
        'SQL exception',
        IF(v_error_caught, 'SQL exception', 'insert succeeded'),
        IF(v_error_caught, 'PASS', 'FAIL'),
        'An employee may have no more than three active requests.'
    );

    ROLLBACK;

    -- Prevent cancellation fewer than 10 days before start_date.
    START TRANSACTION;

    INSERT INTO job (
        start_date, salary, position, edra, job_evaluator,
        announce_date, submission_date
    ) VALUES (
        CURRENT_DATE + INTERVAL 60 DAY,
        3000,
        'Temporary Cancellation-Date Test',
        'Test Location',
        'eval01',
        CURRENT_TIMESTAMP,
        CURRENT_DATE + INTERVAL 5 DAY
    );
    SET v_job1 = LAST_INSERT_ID();

    INSERT INTO promotion_request (
        evaluator1_username, evaluator2_username, employee_username, job_id,
        status, cancel_date, request_date, evaluation_grade1, evaluation_grade2
    ) VALUES (
        'eval01', 'eval02', 'emp18', v_job1,
        'active', NULL, CURRENT_DATE, NULL, NULL
    );

    UPDATE job
       SET start_date = CURRENT_DATE + INTERVAL 9 DAY
     WHERE id = v_job1;

    SET v_error_caught = FALSE;

    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
            SET v_error_caught = TRUE;

        UPDATE promotion_request
           SET status = 'canceled'
         WHERE employee_username = 'emp18'
           AND job_id = v_job1;
    END;

    INSERT INTO verification_results (
        category,
        test_name,
        expected_result,
        actual_result,
        status,
        details
    ) VALUES (
        'Triggers',
        'Late cancellation is rejected',
        'SQL exception',
        IF(v_error_caught, 'SQL exception', 'update succeeded'),
        IF(v_error_caught, 'PASS', 'FAIL'),
        'Cancellation is forbidden when fewer than 10 days remain before the job start date.'
    );

    ROLLBACK;

    -- Prevent reactivation when the employee already has three active requests.
    START TRANSACTION;

    INSERT INTO job (start_date, salary, position, edra, job_evaluator, announce_date, submission_date)
    VALUES (CURRENT_DATE + INTERVAL 100 DAY, 3000, 'Temporary Reactivation Test 1', 'Test Location', 'eval01', CURRENT_TIMESTAMP, CURRENT_DATE + INTERVAL 70 DAY);
    SET v_job1 = LAST_INSERT_ID();

    INSERT INTO job (start_date, salary, position, edra, job_evaluator, announce_date, submission_date)
    VALUES (CURRENT_DATE + INTERVAL 101 DAY, 3000, 'Temporary Reactivation Test 2', 'Test Location', 'eval01', CURRENT_TIMESTAMP, CURRENT_DATE + INTERVAL 70 DAY);
    SET v_job2 = LAST_INSERT_ID();

    INSERT INTO job (start_date, salary, position, edra, job_evaluator, announce_date, submission_date)
    VALUES (CURRENT_DATE + INTERVAL 102 DAY, 3000, 'Temporary Reactivation Test 3', 'Test Location', 'eval01', CURRENT_TIMESTAMP, CURRENT_DATE + INTERVAL 70 DAY);
    SET v_job3 = LAST_INSERT_ID();

    INSERT INTO job (start_date, salary, position, edra, job_evaluator, announce_date, submission_date)
    VALUES (CURRENT_DATE + INTERVAL 103 DAY, 3000, 'Temporary Reactivation Test 4', 'Test Location', 'eval01', CURRENT_TIMESTAMP, CURRENT_DATE + INTERVAL 70 DAY);
    SET v_job4 = LAST_INSERT_ID();

    INSERT INTO promotion_request (
        evaluator1_username, evaluator2_username, employee_username, job_id,
        status, cancel_date, request_date, evaluation_grade1, evaluation_grade2
    ) VALUES
        ('eval01', 'eval02', 'emp18', v_job1, 'active', NULL, CURRENT_DATE, NULL, NULL),
        ('eval01', 'eval02', 'emp18', v_job2, 'active', NULL, CURRENT_DATE, NULL, NULL),
        ('eval01', 'eval02', 'emp18', v_job3, 'active', NULL, CURRENT_DATE, NULL, NULL),
        ('eval01', 'eval02', 'emp18', v_job4, 'canceled', CURRENT_DATE, CURRENT_DATE, NULL, NULL);

    SET v_error_caught = FALSE;

    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
            SET v_error_caught = TRUE;

        UPDATE promotion_request
           SET status = 'active'
         WHERE employee_username = 'emp18'
           AND job_id = v_job4;
    END;

    INSERT INTO verification_results (
        category,
        test_name,
        expected_result,
        actual_result,
        status,
        details
    ) VALUES (
        'Triggers',
        'Reactivation above the active limit is rejected',
        'SQL exception',
        IF(v_error_caught, 'SQL exception', 'update succeeded'),
        IF(v_error_caught, 'PASS', 'FAIL'),
        'A canceled request cannot be reactivated when the employee already has three active requests.'
    );

    ROLLBACK;

    -- Audit insert, update, and delete actions.
    START TRANSACTION;

    SELECT COUNT(*)
      INTO v_log_count_before
      FROM dba_log;

    INSERT INTO degree (titlos, idryma, bathmida)
    VALUES ('Temporary Verification Degree', 'Verification Institute', 'BSc');

    UPDATE degree
       SET bathmida = 'MSc'
     WHERE titlos = 'Temporary Verification Degree'
       AND idryma = 'Verification Institute';

    DELETE FROM degree
     WHERE titlos = 'Temporary Verification Degree'
       AND idryma = 'Verification Institute';

    SELECT COUNT(*)
      INTO v_log_count_after
      FROM dba_log;

    INSERT INTO verification_results (
        category,
        test_name,
        expected_result,
        actual_result,
        status,
        details
    ) VALUES (
        'Triggers',
        'Degree audit records insert, update, and delete',
        '3 new log rows',
        CONCAT(v_log_count_after - v_log_count_before, ' new log rows'),
        IF(v_log_count_after - v_log_count_before = 3, 'PASS', 'FAIL'),
        'The transaction is rolled back after counting, so no test degree or log entries remain.'
    );

    ROLLBACK;
END$$

DELIMITER ;

CALL RunVerificationTriggerTests();
DROP PROCEDURE IF EXISTS RunVerificationTriggerTests;

-- -----------------------------------------------------------------------------
-- 6. Functional workflow tests with explicit cleanup
-- -----------------------------------------------------------------------------
DELIMITER $$

DROP PROCEDURE IF EXISTS RunVerificationWorkflowTests$$

CREATE PROCEDURE RunVerificationWorkflowTests()
BEGIN
    DECLARE v_job_id INT UNSIGNED DEFAULT NULL;
    DECLARE v_status VARCHAR(20) DEFAULT NULL;
    DECLARE v_evaluator1 VARCHAR(30) DEFAULT NULL;
    DECLARE v_evaluator2 VARCHAR(30) DEFAULT NULL;
    DECLARE v_cancel_date DATE DEFAULT NULL;
    DECLARE v_history_count INT DEFAULT 0;
    DECLARE v_winner_count INT DEFAULT 0;
    DECLARE v_canceled_grade_count INT DEFAULT 0;
    DECLARE v_remaining_count INT DEFAULT 0;
    DECLARE v_original_sql_safe_updates BOOLEAN DEFAULT FALSE;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- The verification cleanup intentionally targets temporary rows by job.
        -- Disable Workbench safe-update restrictions during cleanup, then restore
        -- the session setting that was active before propagating the error.
        SET SESSION SQL_SAFE_UPDATES = 0;

        DELETE FROM promotion_request
         WHERE job_id = v_job_id;

        DELETE FROM request_history
         WHERE job_id = v_job_id;

        DELETE FROM job
         WHERE id = v_job_id;

        DELETE FROM dba_log
         WHERE table_name = 'job'
           AND record_key = CAST(v_job_id AS CHAR);

        SET SESSION SQL_SAFE_UPDATES = v_original_sql_safe_updates;
        RESIGNAL;
    END;

    SET v_original_sql_safe_updates = @@SESSION.SQL_SAFE_UPDATES;
    SET SESSION SQL_SAFE_UPDATES = 0;

    -- manage_application: insert, cancel, and reactivate.
    INSERT INTO job (
        start_date,
        salary,
        position,
        edra,
        job_evaluator,
        announce_date,
        submission_date
    ) VALUES (
        CURRENT_DATE + INTERVAL 120 DAY,
        3200,
        'Temporary Application Workflow Test',
        'Test Location',
        'eval01',
        CURRENT_TIMESTAMP,
        CURRENT_DATE + INTERVAL 90 DAY
    );
    SET v_job_id = LAST_INSERT_ID();

    CALL manage_application('emp18', v_job_id, 'i');

    SELECT status, evaluator1_username, evaluator2_username
      INTO v_status, v_evaluator1, v_evaluator2
      FROM promotion_request
     WHERE employee_username = 'emp18'
       AND job_id = v_job_id;

    INSERT INTO verification_results (
        category, test_name, expected_result, actual_result, status, details
    ) VALUES (
        'Stored routines',
        'manage_application creates an active request',
        'active; eval01 and eval02',
        CONCAT(v_status, '; ', v_evaluator1, ' and ', v_evaluator2),
        IF(
            v_status = 'active'
            AND v_evaluator1 = 'eval01'
            AND v_evaluator2 = 'eval02',
            'PASS',
            'FAIL'
        ),
        'The second evaluator is selected from the same company as the job evaluator.'
    );

    CALL manage_application('emp18', v_job_id, 'c');

    SELECT status, cancel_date
      INTO v_status, v_cancel_date
      FROM promotion_request
     WHERE employee_username = 'emp18'
       AND job_id = v_job_id;

    INSERT INTO verification_results (
        category, test_name, expected_result, actual_result, status, details
    ) VALUES (
        'Stored routines',
        'manage_application cancels an existing request',
        'canceled with date',
        CONCAT(v_status, '; ', COALESCE(CAST(v_cancel_date AS CHAR), 'NULL')),
        IF(v_status = 'canceled' AND v_cancel_date IS NOT NULL, 'PASS', 'FAIL'),
        'The cancellation date is assigned automatically.'
    );

    CALL manage_application('emp18', v_job_id, 'a');

    SELECT status, cancel_date
      INTO v_status, v_cancel_date
      FROM promotion_request
     WHERE employee_username = 'emp18'
       AND job_id = v_job_id;

    INSERT INTO verification_results (
        category, test_name, expected_result, actual_result, status, details
    ) VALUES (
        'Stored routines',
        'manage_application reactivates a canceled request',
        'active with NULL cancel_date',
        CONCAT(v_status, '; ', COALESCE(CAST(v_cancel_date AS CHAR), 'NULL')),
        IF(v_status = 'active' AND v_cancel_date IS NULL, 'PASS', 'FAIL'),
        'Reactivation clears the cancellation date.'
    );

    DELETE FROM promotion_request
     WHERE employee_username = 'emp18'
       AND job_id = v_job_id;

    DELETE FROM job
     WHERE id = v_job_id;

    DELETE FROM dba_log
     WHERE table_name = 'job'
       AND record_key = CAST(v_job_id AS CHAR);

    -- EVALUATEPROMOTIONREQUEST: process all rows, calculate winner, and move
    -- canceled requests to history with grade 0.
    INSERT INTO job (
        start_date,
        salary,
        position,
        edra,
        job_evaluator,
        announce_date,
        submission_date
    ) VALUES (
        CURRENT_DATE + INTERVAL 150 DAY,
        3500,
        'Temporary Result Generation Test',
        'Test Location',
        'eval01',
        CURRENT_TIMESTAMP,
        CURRENT_DATE + INTERVAL 120 DAY
    );
    SET v_job_id = LAST_INSERT_ID();

    INSERT INTO promotion_request (
        evaluator1_username, evaluator2_username, employee_username, job_id,
        status, cancel_date, request_date, evaluation_grade1, evaluation_grade2
    ) VALUES
        ('eval01', 'eval02', 'emp14', v_job_id, 'active', NULL, CURRENT_DATE, 10, 10),
        ('eval01', 'eval02', 'emp16', v_job_id, 'active', NULL, CURRENT_DATE, 18, 18),
        ('eval01', 'eval02', 'emp17', v_job_id, 'active', NULL, CURRENT_DATE, 18, 18),
        ('eval01', 'eval02', 'emp18', v_job_id, 'canceled', CURRENT_DATE, CURRENT_DATE, NULL, NULL);

    UPDATE promotion_request
       SET request_date = CASE employee_username
           WHEN 'emp14' THEN CURRENT_DATE - INTERVAL 4 DAY
           WHEN 'emp16' THEN CURRENT_DATE - INTERVAL 3 DAY
           WHEN 'emp17' THEN CURRENT_DATE - INTERVAL 2 DAY
           ELSE CURRENT_DATE - INTERVAL 1 DAY
       END
     WHERE job_id = v_job_id;

    CALL EVALUATEPROMOTIONREQUEST(v_job_id);

    SELECT COUNT(*)
      INTO v_history_count
      FROM request_history
     WHERE job_id = v_job_id;

    SELECT COUNT(*)
      INTO v_winner_count
      FROM request_history
     WHERE job_id = v_job_id
       AND employee_username = 'emp16'
       AND was_winner = TRUE
       AND evaluation_grade = 18;

    SELECT COUNT(*)
      INTO v_canceled_grade_count
      FROM request_history
     WHERE job_id = v_job_id
       AND employee_username = 'emp18'
       AND original_status = 'canceled'
       AND evaluation_grade = 0;

    SELECT COUNT(*)
      INTO v_remaining_count
      FROM promotion_request
     WHERE job_id = v_job_id;

    INSERT INTO verification_results (
        category, test_name, expected_result, actual_result, status, details
    ) VALUES (
        'Stored routines',
        'EVALUATEPROMOTIONREQUEST processes every application',
        '4 history rows; 0 current rows',
        CONCAT(v_history_count, ' history rows; ', v_remaining_count, ' current rows'),
        IF(v_history_count = 4 AND v_remaining_count = 0, 'PASS', 'FAIL'),
        'All requests for the job are transferred from promotion_request to request_history.'
    );

    INSERT INTO verification_results (
        category, test_name, expected_result, actual_result, status, details
    ) VALUES (
        'Stored routines',
        'EVALUATEPROMOTIONREQUEST applies the tie-break rule',
        'emp16 wins with grade 18',
        IF(v_winner_count = 1, 'emp16 wins with grade 18', 'expected winner not found'),
        IF(v_winner_count = 1, 'PASS', 'FAIL'),
        'emp16 and emp17 tie on grade; emp16 wins because the request date is earlier.'
    );

    INSERT INTO verification_results (
        category, test_name, expected_result, actual_result, status, details
    ) VALUES (
        'Stored routines',
        'Canceled request is stored with grade 0',
        'one matching history row',
        CAST(v_canceled_grade_count AS CHAR),
        IF(v_canceled_grade_count = 1, 'PASS', 'FAIL'),
        'Canceled requests do not compete for the position and are archived with grade 0.'
    );

    DELETE FROM request_history
     WHERE job_id = v_job_id;

    DELETE FROM job
     WHERE id = v_job_id;

    DELETE FROM dba_log
     WHERE table_name = 'job'
       AND record_key = CAST(v_job_id AS CHAR);

    SET SESSION SQL_SAFE_UPDATES = v_original_sql_safe_updates;
END$$

DELIMITER ;

CALL RunVerificationWorkflowTests();
DROP PROCEDURE IF EXISTS RunVerificationWorkflowTests;

-- -----------------------------------------------------------------------------
-- 7. Audit-definition safety checks
-- -----------------------------------------------------------------------------
INSERT INTO verification_results (
    category,
    test_name,
    expected_result,
    actual_result,
    status,
    details
)
SELECT
    'Security',
    'User audit triggers do not copy passwords',
    '0 trigger definitions referencing NEW.password or OLD.password',
    CAST(COUNT(*) AS CHAR),
    IF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Passwords are deliberately omitted from JSON audit snapshots.'
FROM information_schema.triggers
WHERE trigger_schema = DATABASE()
  AND event_object_table = 'user'
  AND (
      action_statement LIKE '%NEW.password%'
      OR action_statement LIKE '%OLD.password%'
  );

INSERT INTO verification_results (
    category,
    test_name,
    expected_result,
    actual_result,
    status,
    details
)
SELECT
    'Security',
    'Audit triggers record the database actor',
    '9 audit triggers use CURRENT_USER()',
    CAST(COUNT(*) AS CHAR),
    IF(COUNT(*) = 9, 'PASS', 'FAIL'),
    'The job, user, and degree INSERT/UPDATE/DELETE triggers record the database account that performed the action.'
FROM information_schema.triggers
WHERE trigger_schema = DATABASE()
  AND event_object_table IN ('job', 'user', 'degree')
  AND action_statement LIKE '%CURRENT_USER()%';

-- -----------------------------------------------------------------------------
-- 8. Restore AUTO_INCREMENT counters consumed by temporary tests
-- -----------------------------------------------------------------------------
SET @next_job_id = (SELECT COALESCE(MAX(id), 0) + 1 FROM job);
SET @sql_statement = CONCAT('ALTER TABLE job AUTO_INCREMENT = ', @next_job_id);
PREPARE prepared_statement FROM @sql_statement;
EXECUTE prepared_statement;
DEALLOCATE PREPARE prepared_statement;

SET @next_request_id = (SELECT COALESCE(MAX(id), 0) + 1 FROM promotion_request);
SET @sql_statement = CONCAT(
    'ALTER TABLE promotion_request AUTO_INCREMENT = ',
    @next_request_id
);
PREPARE prepared_statement FROM @sql_statement;
EXECUTE prepared_statement;
DEALLOCATE PREPARE prepared_statement;

SET @next_history_id = (SELECT COALESCE(MAX(id), 0) + 1 FROM request_history);
SET @sql_statement = CONCAT(
    'ALTER TABLE request_history AUTO_INCREMENT = ',
    @next_history_id
);
PREPARE prepared_statement FROM @sql_statement;
EXECUTE prepared_statement;
DEALLOCATE PREPARE prepared_statement;

SET @next_log_id = (SELECT COALESCE(MAX(log_id), 0) + 1 FROM dba_log);
SET @sql_statement = CONCAT('ALTER TABLE dba_log AUTO_INCREMENT = ', @next_log_id);
PREPARE prepared_statement FROM @sql_statement;
EXECUTE prepared_statement;
DEALLOCATE PREPARE prepared_statement;

-- -----------------------------------------------------------------------------
-- 9. Final verification report
-- -----------------------------------------------------------------------------
SELECT
    status,
    COUNT(*) AS tests
FROM verification_results
GROUP BY status
ORDER BY FIELD(status, 'FAIL', 'PASS');

SELECT
    result_id,
    category,
    test_name,
    expected_result,
    actual_result,
    status,
    details
FROM verification_results
ORDER BY
    FIELD(status, 'FAIL', 'PASS'),
    category,
    result_id;

SELECT
    CASE
        WHEN SUM(status = 'FAIL') = 0
            THEN 'ALL VERIFICATION TESTS PASSED'
        ELSE CONCAT(SUM(status = 'FAIL'), ' VERIFICATION TEST(S) FAILED')
    END AS overall_result,
    SUM(status = 'PASS') AS passed_tests,
    SUM(status = 'FAIL') AS failed_tests,
    COUNT(*) AS total_tests
FROM verification_results;

DROP TEMPORARY TABLE IF EXISTS expected_routines;
DROP TEMPORARY TABLE IF EXISTS expected_indexes;
DROP TEMPORARY TABLE IF EXISTS minimum_seed_counts;
DROP TEMPORARY TABLE IF EXISTS verification_results;
