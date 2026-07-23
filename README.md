# Employee Promotion Database System

Complete solution for the 2023-2024 Database Laboratory project. The repository implements both required parts:

- **Part A:** MySQL relational schema, seed data, stored routines, triggers, application-history generation, indexes, benchmarks, and automated verification.
- **Part B:** Java Swing desktop interface connected through JDBC, with generic table browsing and CRUD operations, data-entry validation, pagination, promotion-result processing, and history searches.

The Greek technical report follows the five-chapter structure required by the project specification. It documents the database design, stored procedures, triggers, Java/JDBC application, additional functionality, execution examples, benchmark results, testing evidence, usage scenarios, diagrams, and screenshots. The report references the corresponding SQL and Java files instead of duplicating their complete source code.

## Repository structure

```text
employee-promotion-database-system/
├── application/
│   ├── pom.xml
│   └── src/main/java/gr/upatras/firms/
│       ├── App.java
│       ├── ColumnMeta.java
│       ├── ConnectionConfig.java
│       ├── ConnectionDialog.java
│       ├── DatabaseSession.java
│       ├── DynamicResult.java
│       ├── DynamicResultTableModel.java
│       ├── ForeignKeyMeta.java
│       ├── GenericTableModel.java
│       ├── MainFrame.java
│       ├── MetadataService.java
│       ├── PromotionResultsPanel.java
│       ├── PromotionService.java
│       ├── RecordEditorDialog.java
│       ├── SqlNames.java
│       ├── TableDataService.java
│       ├── TableManagementPanel.java
│       ├── TableMeta.java
│       ├── TablePage.java
│       └── Ui.java
├── database/
│   ├── 01-schema.sql
│   ├── 02-seed-data.sql
│   ├── 03-procedures.sql
│   ├── 04-triggers.sql
│   ├── 05-generate-history.sql
│   ├── 06-indexes-and-benchmarks.sql
│   └── 07-verification-tests.sql
├── docs/
│   └── employee-promotion-database-system-report.pdf
├── .gitignore
└── README.md
```

## Requirements covered

| Project section | Implementation |
|---|---|
| 3.1.1 | Complete relational schema and the required minimum seed records for a three-member team |
| 3.1.2.1 | Promotion-request creation, activation, cancellation, date limits, and three-active-request limit |
| 3.1.2.2 | Two-evaluator grading, qualification-based missing grades, winner selection, tie-breaking, and archival |
| 3.1.2.3 | `request_history` plus a reproducible generator for 60,001 records with integer grades from 1 to 20 |
| 3.1.2.4 | DBA user subtype and action log |
| 3.1.3.1 | `GetEvaluationGrade` |
| 3.1.3.2 | `manage_application` |
| 3.1.3.3 | `EVALUATEPROMOTIONREQUEST` |
| 3.1.3.4 | Grade/evaluator history procedures, supporting indexes, and before/after benchmarks |
| 3.1.4.1 | Audit triggers for INSERT, UPDATE, and DELETE on `job`, `user`, and `degree` |
| 3.1.4.2 | Trigger checks for late applications and the active-request limit |
| 3.1.4.3 | Trigger checks for late cancellation and invalid reactivation |
| 3.2.1 | GUI selection, display, insertion, modification, and deletion for every base table |
| 3.2.2 | Metadata-driven validation, foreign-key lists, ENUM/Boolean controls, and typed input checks |
| 3.2.3 | Promotion preview/processing and request-history search tools |
| 3.1.5 / 3.2.4 | Greek report with Chapters 1-5, design documentation, examples, scenarios, diagrams, results, and screenshots |

## Prerequisites

- MySQL Server 8.0 or newer
- MySQL Workbench or another MySQL client
- JDK 17 or newer
- Apache Maven 3.9 or newer

The application was successfully built with JDK 21 while targeting Java 17 bytecode.

## Recreate the database

Connect to MySQL with an account permitted to create databases, routines, triggers, and indexes. Run the scripts in this exact order:

1. `database/01-schema.sql`
2. `database/02-seed-data.sql`
3. `database/03-procedures.sql`
4. `database/04-triggers.sql`
5. `database/05-generate-history.sql`
6. `database/06-indexes-and-benchmarks.sql`
7. `database/07-verification-tests.sql`

The first script recreates the `firms` database and therefore removes any existing database with that name.

Expected final verification summary:

```text
ALL VERIFICATION TESTS PASSED
passed_tests: 53
failed_tests: 0
total_tests: 53
```

After recreation and verification, the database contains:

- 16 base tables
- 7 installed routines, including the qualification function and history generator
- 12 triggers
- 3 history-search indexes
- 60,001 generated history rows before any later demonstration processing

## Build the Java application

Open a terminal in the `application` directory and run:

```powershell
mvn clean package
```

Maven downloads the MySQL JDBC dependency, compiles the Java source files, and creates:

```text
target/employee-promotion-database-gui.jar
```

Run the application on Windows with:

```powershell
java -jar .\target\employee-promotion-database-gui.jar
```

On Linux or macOS:

```bash
java -jar ./target/employee-promotion-database-gui.jar
```

The generated `target/` directory and JAR file are build outputs and are intentionally excluded from version control.

## Connect the application

Enter the MySQL connection values at runtime. Typical local settings are:

```text
Host: 127.0.0.1
Port: 3306
Database: firms
Username: your MySQL account
Password: your MySQL password
```

The password is kept only in memory for the active session and is not written to a project file.

## Main GUI functions

- Select and display any base table.
- Add, edit, and delete records using prepared statements.
- Generate input forms from database metadata.
- Restrict foreign-key fields to values already stored in the related tables.
- Validate required fields, integers, decimals, dates, datetimes, times, Booleans, and ENUM values.
- Paginate large tables in pages of 500 rows.
- Preview and process promotion results.
- Search completed applications by grade interval or evaluator.

## Verified results

The database implementation was tested on MySQL 8.0 and passed all 53 automated checks. The Java application was also tested manually for:

- database connection;
- table loading;
- 500-row history pagination;
- Add, Edit, and Delete operations;
- history searches;
- application preview;
- promotion processing and winner selection;
- removal of temporary demonstration data.

In the recorded benchmark, the grade-interval search improved from approximately 53.568 ms to 18.695 ms after indexing. The evaluator search was functionally correct but showed no meaningful improvement in that run because it searches two evaluator columns with an `OR` condition.

## Report

The Greek technical report is available at:

[`docs/employee-promotion-database-system-report.pdf`](docs/employee-promotion-database-system-report.pdf)

It documents the relational design, assumptions, table roles, stored-procedure and trigger behavior, benchmark methodology and results, Java/JDBC architecture, validation approach, usage scenarios, test evidence, diagrams, and GUI screenshots. Complete implementation code is kept in the corresponding files under `database/` and `application/`.
