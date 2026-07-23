-- Employee Promotion Database System
-- File: 06-indexes-and-benchmarks.sql
-- Purpose: Add the request-history indexes required by section 3.1.3.4 and
--          compare the two history searches before and after indexing.
-- Run after 05-generate-history.sql.
-- MySQL version: 8.0+
--
-- Index rationale
-- 1. idx_history_grade_employee_job begins with evaluation_grade because the
--    first procedure filters by a grade interval. employee_username and job_id
--    make it a covering index for the values returned by that procedure.
-- 2. idx_history_evaluator1_employee_job and
--    idx_history_evaluator2_employee_job support the two alternatives in the
--    evaluator search. MySQL can combine them with an index-merge union, while
--    the trailing columns cover the result fields.
--
-- The benchmark repeats COUNT(*) versions of the same filters. This avoids
-- measuring Workbench rendering/network time and focuses the comparison on
-- database lookup cost. Results vary by computer, buffer-pool state, and
-- background activity, so screenshots should be captured from the local run.

USE firms;

DELIMITER $$

DROP PROCEDURE IF EXISTS ConfigureHistoryIndexes$$

CREATE PROCEDURE ConfigureHistoryIndexes(
    IN p_enable BOOLEAN
)
BEGIN
    DECLARE v_exists INT DEFAULT 0;

    IF p_enable THEN
        SELECT COUNT(*)
          INTO v_exists
          FROM information_schema.statistics
         WHERE table_schema = DATABASE()
           AND table_name = 'request_history'
           AND index_name = 'idx_history_grade_employee_job';

        IF v_exists = 0 THEN
            SET @ddl_statement =
                'CREATE INDEX idx_history_grade_employee_job '
                'ON request_history (evaluation_grade, employee_username, job_id)';
            PREPARE prepared_ddl FROM @ddl_statement;
            EXECUTE prepared_ddl;
            DEALLOCATE PREPARE prepared_ddl;
        END IF;

        SELECT COUNT(*)
          INTO v_exists
          FROM information_schema.statistics
         WHERE table_schema = DATABASE()
           AND table_name = 'request_history'
           AND index_name = 'idx_history_evaluator1_employee_job';

        IF v_exists = 0 THEN
            SET @ddl_statement =
                'CREATE INDEX idx_history_evaluator1_employee_job '
                'ON request_history (evaluator1_username, employee_username, job_id)';
            PREPARE prepared_ddl FROM @ddl_statement;
            EXECUTE prepared_ddl;
            DEALLOCATE PREPARE prepared_ddl;
        END IF;

        SELECT COUNT(*)
          INTO v_exists
          FROM information_schema.statistics
         WHERE table_schema = DATABASE()
           AND table_name = 'request_history'
           AND index_name = 'idx_history_evaluator2_employee_job';

        IF v_exists = 0 THEN
            SET @ddl_statement =
                'CREATE INDEX idx_history_evaluator2_employee_job '
                'ON request_history (evaluator2_username, employee_username, job_id)';
            PREPARE prepared_ddl FROM @ddl_statement;
            EXECUTE prepared_ddl;
            DEALLOCATE PREPARE prepared_ddl;
        END IF;
    ELSE
        SELECT COUNT(*)
          INTO v_exists
          FROM information_schema.statistics
         WHERE table_schema = DATABASE()
           AND table_name = 'request_history'
           AND index_name = 'idx_history_grade_employee_job';

        IF v_exists > 0 THEN
            SET @ddl_statement =
                'DROP INDEX idx_history_grade_employee_job ON request_history';
            PREPARE prepared_ddl FROM @ddl_statement;
            EXECUTE prepared_ddl;
            DEALLOCATE PREPARE prepared_ddl;
        END IF;

        SELECT COUNT(*)
          INTO v_exists
          FROM information_schema.statistics
         WHERE table_schema = DATABASE()
           AND table_name = 'request_history'
           AND index_name = 'idx_history_evaluator1_employee_job';

        IF v_exists > 0 THEN
            SET @ddl_statement =
                'DROP INDEX idx_history_evaluator1_employee_job ON request_history';
            PREPARE prepared_ddl FROM @ddl_statement;
            EXECUTE prepared_ddl;
            DEALLOCATE PREPARE prepared_ddl;
        END IF;

        SELECT COUNT(*)
          INTO v_exists
          FROM information_schema.statistics
         WHERE table_schema = DATABASE()
           AND table_name = 'request_history'
           AND index_name = 'idx_history_evaluator2_employee_job';

        IF v_exists > 0 THEN
            SET @ddl_statement =
                'DROP INDEX idx_history_evaluator2_employee_job ON request_history';
            PREPARE prepared_ddl FROM @ddl_statement;
            EXECUTE prepared_ddl;
            DEALLOCATE PREPARE prepared_ddl;
        END IF;
    END IF;
END$$

DROP PROCEDURE IF EXISTS RunHistoryIndexBenchmark$$

CREATE PROCEDURE RunHistoryIndexBenchmark(
    IN p_test_stage VARCHAR(30),
    IN p_repetitions INT UNSIGNED,
    IN p_grade1 INT,
    IN p_grade2 INT,
    IN p_evaluator_username VARCHAR(30)
)
BEGIN
    DECLARE v_iteration INT UNSIGNED DEFAULT 0;
    DECLARE v_low_grade INT;
    DECLARE v_high_grade INT;
    DECLARE v_match_count BIGINT UNSIGNED DEFAULT 0;
    DECLARE v_started_at DATETIME(6);
    DECLARE v_grade_microseconds BIGINT UNSIGNED DEFAULT 0;
    DECLARE v_evaluator_microseconds BIGINT UNSIGNED DEFAULT 0;

    IF p_test_stage IS NULL OR CHAR_LENGTH(TRIM(p_test_stage)) = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A benchmark stage label is required.';
    END IF;

    IF p_repetitions IS NULL OR p_repetitions = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Benchmark repetitions must be greater than zero.';
    END IF;

    IF p_grade1 IS NULL OR p_grade2 IS NULL
       OR p_grade1 NOT BETWEEN 0 AND 20
       OR p_grade2 NOT BETWEEN 0 AND 20
       OR p_grade1 = p_grade2 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Provide two different grade limits from 0 to 20.';
    END IF;

    IF p_evaluator_username IS NULL
       OR CHAR_LENGTH(TRIM(p_evaluator_username)) = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'An evaluator username is required.';
    END IF;

    SET v_low_grade = LEAST(p_grade1, p_grade2);
    SET v_high_grade = GREATEST(p_grade1, p_grade2);

    SET v_iteration = 0;
    SET v_started_at = NOW(6);

    WHILE v_iteration < p_repetitions DO
        SELECT COUNT(*)
          INTO v_match_count
          FROM request_history AS rh
         WHERE rh.evaluation_grade BETWEEN v_low_grade AND v_high_grade;

        SET v_iteration = v_iteration + 1;
    END WHILE;

    SET v_grade_microseconds =
        TIMESTAMPDIFF(MICROSECOND, v_started_at, NOW(6));

    SET v_iteration = 0;
    SET v_started_at = NOW(6);

    WHILE v_iteration < p_repetitions DO
        SELECT COUNT(*)
          INTO v_match_count
          FROM request_history AS rh
         WHERE rh.evaluator1_username = p_evaluator_username
            OR rh.evaluator2_username = p_evaluator_username;

        SET v_iteration = v_iteration + 1;
    END WHILE;

    SET v_evaluator_microseconds =
        TIMESTAMPDIFF(MICROSECOND, v_started_at, NOW(6));

    INSERT INTO tmp_index_benchmark_results (
        test_stage,
        query_name,
        repetitions,
        total_microseconds,
        average_microseconds
    ) VALUES
        (
            p_test_stage,
            'grade interval search',
            p_repetitions,
            v_grade_microseconds,
            ROUND(v_grade_microseconds / p_repetitions, 2)
        ),
        (
            p_test_stage,
            'evaluator search',
            p_repetitions,
            v_evaluator_microseconds,
            ROUND(v_evaluator_microseconds / p_repetitions, 2)
        );
END$$

DELIMITER ;

DROP TEMPORARY TABLE IF EXISTS tmp_index_benchmark_results;

CREATE TEMPORARY TABLE tmp_index_benchmark_results (
    benchmark_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    test_stage VARCHAR(30) NOT NULL,
    query_name VARCHAR(60) NOT NULL,
    repetitions INT UNSIGNED NOT NULL,
    total_microseconds BIGINT UNSIGNED NOT NULL,
    average_microseconds DECIMAL(14, 2) NOT NULL,
    PRIMARY KEY (benchmark_id)
) ENGINE = MEMORY;

-- -----------------------------------------------------------------------------
-- Benchmark without the additional history indexes.
-- -----------------------------------------------------------------------------
CALL ConfigureHistoryIndexes(FALSE);
ANALYZE TABLE request_history;

-- Capture these plans if the report needs evidence of the full scans.
EXPLAIN ANALYZE
SELECT
    rh.employee_username,
    rh.job_id
FROM request_history AS rh
WHERE rh.evaluation_grade BETWEEN 7 AND 12;

EXPLAIN ANALYZE
SELECT
    rh.employee_username,
    rh.job_id
FROM request_history AS rh
WHERE rh.evaluator1_username = 'eval01'
   OR rh.evaluator2_username = 'eval01';

CALL RunHistoryIndexBenchmark(
    'without indexes',
    200,
    7,
    12,
    'eval01'
);

-- -----------------------------------------------------------------------------
-- Install the final indexes and repeat the same benchmark.
-- -----------------------------------------------------------------------------
CALL ConfigureHistoryIndexes(TRUE);
ANALYZE TABLE request_history;

-- Capture these plans if the report needs evidence of index range/index-merge
-- access. The indexes remain installed after this script finishes.
EXPLAIN ANALYZE
SELECT
    rh.employee_username,
    rh.job_id
FROM request_history AS rh
WHERE rh.evaluation_grade BETWEEN 7 AND 12;

EXPLAIN ANALYZE
SELECT
    rh.employee_username,
    rh.job_id
FROM request_history AS rh
WHERE rh.evaluator1_username = 'eval01'
   OR rh.evaluator2_username = 'eval01';

CALL RunHistoryIndexBenchmark(
    'with indexes',
    200,
    7,
    12,
    'eval01'
);

-- Main before/after timing table for the report screenshot.
SELECT
    test_stage,
    query_name,
    repetitions,
    total_microseconds,
    average_microseconds,
    ROUND(average_microseconds / 1000, 3) AS average_milliseconds
FROM tmp_index_benchmark_results
ORDER BY query_name, benchmark_id;

-- Percentage improvement. MySQL temporary tables cannot be opened twice in
-- one statement, so pivot the rows with conditional aggregation instead of a
-- self-join. Negative values can occur on very fast systems or warm caches.
SELECT
    result_by_query.query_name,
    result_by_query.without_index_microseconds,
    result_by_query.with_index_microseconds,
    ROUND(
        100 * (
            result_by_query.without_index_microseconds
            - result_by_query.with_index_microseconds
        ) / NULLIF(result_by_query.without_index_microseconds, 0),
        2
    ) AS improvement_percent
FROM (
    SELECT
        query_name,
        MAX(
            CASE
                WHEN test_stage = 'without indexes'
                    THEN average_microseconds
            END
        ) AS without_index_microseconds,
        MAX(
            CASE
                WHEN test_stage = 'with indexes'
                    THEN average_microseconds
            END
        ) AS with_index_microseconds
    FROM tmp_index_benchmark_results
    GROUP BY query_name
) AS result_by_query
ORDER BY result_by_query.query_name;

-- Final index verification.
SELECT
    index_name,
    seq_in_index,
    column_name,
    cardinality
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name = 'request_history'
  AND index_name IN (
      'idx_history_grade_employee_job',
      'idx_history_evaluator1_employee_job',
      'idx_history_evaluator2_employee_job'
  )
ORDER BY index_name, seq_in_index;

DROP PROCEDURE IF EXISTS RunHistoryIndexBenchmark;
DROP PROCEDURE IF EXISTS ConfigureHistoryIndexes;
