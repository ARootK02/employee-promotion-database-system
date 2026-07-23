-- Employee Promotion Database System
-- File: 01-schema.sql
-- Purpose: Create the complete MySQL 8.0 schema used by Parts A and B.
-- Run this file before all other database scripts.

DROP DATABASE IF EXISTS firms;

CREATE DATABASE firms
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE firms;

CREATE TABLE etairia (
    AFM CHAR(9) NOT NULL,
    DOY VARCHAR(30) NOT NULL,
    name VARCHAR(80) NOT NULL,
    tel VARCHAR(20) NOT NULL,
    street VARCHAR(80) NOT NULL,
    num INT UNSIGNED NOT NULL,
    city VARCHAR(60) NOT NULL,
    country VARCHAR(60) NOT NULL,
    PRIMARY KEY (AFM),
    CONSTRAINT chk_etairia_afm CHECK (AFM REGEXP '^[0-9]{9}$'),
    CONSTRAINT chk_etairia_num CHECK (num > 0)
) ENGINE = InnoDB;

CREATE TABLE `user` (
    username VARCHAR(30) NOT NULL,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(50) NOT NULL,
    lastname VARCHAR(60) NOT NULL,
    reg_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    email VARCHAR(254) NOT NULL,
    PRIMARY KEY (username),
    CONSTRAINT uq_user_email UNIQUE (email)
) ENGINE = InnoDB;

CREATE TABLE employee (
    username VARCHAR(30) NOT NULL,
    bio TEXT NOT NULL,
    sistatikes VARCHAR(255) NULL,
    certificates VARCHAR(255) NULL,
    PRIMARY KEY (username),
    CONSTRAINT fk_employee_user
        FOREIGN KEY (username) REFERENCES `user` (username)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE = InnoDB;

CREATE TABLE languages (
    candid VARCHAR(30) NOT NULL,
    lang ENUM('EN', 'FR', 'SP', 'GE', 'CH', 'GR') NOT NULL,
    PRIMARY KEY (candid, lang),
    CONSTRAINT fk_languages_employee
        FOREIGN KEY (candid) REFERENCES employee (username)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE = InnoDB;

CREATE TABLE project (
    candid VARCHAR(30) NOT NULL,
    num SMALLINT UNSIGNED NOT NULL,
    descr TEXT NOT NULL,
    url VARCHAR(255) NULL,
    PRIMARY KEY (candid, num),
    CONSTRAINT fk_project_employee
        FOREIGN KEY (candid) REFERENCES employee (username)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT chk_project_num CHECK (num > 0)
) ENGINE = InnoDB;

CREATE TABLE evaluator (
    username VARCHAR(30) NOT NULL,
    exp_years TINYINT UNSIGNED NOT NULL,
    firm CHAR(9) NOT NULL,
    PRIMARY KEY (username),
    CONSTRAINT fk_evaluator_company
        FOREIGN KEY (firm) REFERENCES etairia (AFM)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_evaluator_user
        FOREIGN KEY (username) REFERENCES `user` (username)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT chk_evaluator_experience CHECK (exp_years <= 60)
) ENGINE = InnoDB;

CREATE TABLE job (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    start_date DATE NOT NULL,
    salary DECIMAL(10, 2) NOT NULL,
    position VARCHAR(100) NOT NULL,
    edra VARCHAR(100) NOT NULL,
    job_evaluator VARCHAR(30) NOT NULL,
    announce_date DATETIME NOT NULL,
    submission_date DATE NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_job_evaluator
        FOREIGN KEY (job_evaluator) REFERENCES evaluator (username)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT chk_job_salary CHECK (salary > 0),
    CONSTRAINT chk_job_dates CHECK (submission_date < start_date)
) ENGINE = InnoDB;

-- Subjects may optionally reference a broader subject category.
-- The self-reference supports hierarchical subject classification while
-- preserving referential actions for category updates and deletions.
CREATE TABLE subject (
    title VARCHAR(80) NOT NULL,
    descr VARCHAR(500) NOT NULL,
    belongs_to VARCHAR(80) NULL,
    PRIMARY KEY (title),
    CONSTRAINT fk_subject_parent
        FOREIGN KEY (belongs_to) REFERENCES subject (title)
        ON DELETE SET NULL
        ON UPDATE CASCADE
) ENGINE = InnoDB;

CREATE TABLE requires (
    job_id INT UNSIGNED NOT NULL,
    subject_title VARCHAR(80) NOT NULL,
    PRIMARY KEY (job_id, subject_title),
    CONSTRAINT fk_requires_job
        FOREIGN KEY (job_id) REFERENCES job (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_requires_subject
        FOREIGN KEY (subject_title) REFERENCES subject (title)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE = InnoDB;

-- Basic employee-to-job applications are represented by applies.
-- Promotion requests with evaluators, status, and grades are represented by
-- promotion_request below.
CREATE TABLE applies (
    cand_username VARCHAR(30) NOT NULL,
    job_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (cand_username, job_id),
    CONSTRAINT fk_applies_employee
        FOREIGN KEY (cand_username) REFERENCES employee (username)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_applies_job
        FOREIGN KEY (job_id) REFERENCES job (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE = InnoDB;

CREATE TABLE degree (
    titlos VARCHAR(150) NOT NULL,
    idryma VARCHAR(140) NOT NULL,
    bathmida ENUM('BSc', 'MSc', 'PhD') NOT NULL,
    PRIMARY KEY (titlos, idryma)
) ENGINE = InnoDB;

CREATE TABLE has_degree (
    degr_title VARCHAR(150) NOT NULL,
    degr_idryma VARCHAR(140) NOT NULL,
    cand_username VARCHAR(30) NOT NULL,
    etos YEAR NOT NULL,
    grade DECIMAL(4, 2) NOT NULL,
    PRIMARY KEY (degr_title, degr_idryma, cand_username),
    CONSTRAINT fk_has_degree_degree
        FOREIGN KEY (degr_title, degr_idryma)
        REFERENCES degree (titlos, idryma)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_has_degree_employee
        FOREIGN KEY (cand_username) REFERENCES employee (username)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT chk_has_degree_grade CHECK (grade BETWEEN 0 AND 10)
) ENGINE = InnoDB;

-- The distinct-evaluator rule is enforced by 04-triggers.sql because MySQL
-- does not permit that CHECK constraint on columns participating in foreign
-- keys with ON UPDATE CASCADE.
CREATE TABLE promotion_request (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    evaluator1_username VARCHAR(30) NOT NULL,
    evaluator2_username VARCHAR(30) NOT NULL,
    employee_username VARCHAR(30) NOT NULL,
    job_id INT UNSIGNED NOT NULL,
    status ENUM('active', 'completed', 'canceled') NOT NULL DEFAULT 'active',
    cancel_date DATE NULL,
    request_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    evaluation_grade1 TINYINT UNSIGNED NULL,
    evaluation_grade2 TINYINT UNSIGNED NULL,
    PRIMARY KEY (id),
    CONSTRAINT uq_promotion_employee_job UNIQUE (employee_username, job_id),
    CONSTRAINT fk_promotion_evaluator1
        FOREIGN KEY (evaluator1_username) REFERENCES evaluator (username)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_promotion_evaluator2
        FOREIGN KEY (evaluator2_username) REFERENCES evaluator (username)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_promotion_employee
        FOREIGN KEY (employee_username) REFERENCES employee (username)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_promotion_job
        FOREIGN KEY (job_id) REFERENCES job (id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT chk_promotion_grade1 CHECK (
        evaluation_grade1 IS NULL OR evaluation_grade1 BETWEEN 1 AND 20
    ),
    CONSTRAINT chk_promotion_grade2 CHECK (
        evaluation_grade2 IS NULL OR evaluation_grade2 BETWEEN 1 AND 20
    ),
    CONSTRAINT chk_promotion_cancel_state CHECK (
        (status = 'canceled' AND cancel_date IS NOT NULL)
        OR
        (status IN ('active', 'completed') AND cancel_date IS NULL)
    )
) ENGINE = InnoDB;

-- Historical identifiers are stored without foreign keys so completed
-- records remain available independently of later changes to operational data
-- and can support the large history-search workload.
CREATE TABLE request_history (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    evaluator1_username VARCHAR(30) NOT NULL,
    evaluator2_username VARCHAR(30) NOT NULL,
    employee_username VARCHAR(30) NOT NULL,
    job_id INT UNSIGNED NOT NULL,
    status ENUM('completed') NOT NULL DEFAULT 'completed',
    original_status ENUM('active', 'canceled') NOT NULL,
    evaluation_grade DECIMAL(4, 2) NOT NULL,
    request_date DATE NOT NULL,
    completed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    was_winner BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (id),
    CONSTRAINT chk_history_grade CHECK (evaluation_grade BETWEEN 0 AND 20)
) ENGINE = InnoDB;

CREATE TABLE user_dba (
    dba_username VARCHAR(30) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NULL,
    PRIMARY KEY (dba_username),
    CONSTRAINT fk_dba_user
        FOREIGN KEY (dba_username) REFERENCES `user` (username)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT chk_dba_dates CHECK (
        end_date IS NULL OR end_date >= start_date
    )
) ENGINE = InnoDB;

CREATE TABLE dba_log (
    log_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    actor_username VARCHAR(128) NOT NULL,
    table_name ENUM('job', 'user', 'degree') NOT NULL,
    action_type ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    record_key VARCHAR(255) NOT NULL,
    action_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    old_data JSON NULL,
    new_data JSON NULL,
    PRIMARY KEY (log_id)
) ENGINE = InnoDB;
