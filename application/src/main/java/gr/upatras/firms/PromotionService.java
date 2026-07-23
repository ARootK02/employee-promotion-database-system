package gr.upatras.firms;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

/** Queries active applications and executes the promotion-result procedure. */
public final class PromotionService {
    private final Connection connection;

    public PromotionService(Connection connection) {
        this.connection = connection;
    }

    public List<JobOption> loadJobs() throws SQLException {
        List<JobOption> jobs = new ArrayList<>();
        String sql = "SELECT id, position FROM job ORDER BY id";
        try (PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            while (resultSet.next()) {
                jobs.add(new JobOption(resultSet.getInt("id"), resultSet.getString("position")));
            }
        }
        return jobs;
    }

    public DynamicResult preview(int jobId) throws SQLException {
        String sql = """
                SELECT pr.id AS request_id,
                       pr.employee_username,
                       CONCAT(u.name, ' ', u.lastname) AS employee_name,
                       pr.status,
                       pr.request_date,
                       pr.evaluator1_username,
                       pr.evaluation_grade1,
                       pr.evaluator2_username,
                       pr.evaluation_grade2,
                       CalculateQualificationScore(pr.employee_username) AS qualification_score,
                       CASE
                           WHEN pr.status = 'canceled' THEN 0
                           ELSE ROUND((
                               COALESCE(pr.evaluation_grade1, CalculateQualificationScore(pr.employee_username))
                               + COALESCE(pr.evaluation_grade2, CalculateQualificationScore(pr.employee_username))
                           ) / 2, 2)
                       END AS projected_final_grade
                FROM promotion_request AS pr
                JOIN `user` AS u ON u.username = pr.employee_username
                WHERE pr.job_id = ?
                ORDER BY pr.status = 'canceled', projected_final_grade DESC, pr.request_date ASC
                """;
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setInt(1, jobId);
            try (ResultSet resultSet = statement.executeQuery()) {
                return readResult(resultSet);
            }
        }
    }

    public PromotionProcessingResult process(int jobId) throws SQLException {
        DynamicResult applications = new DynamicResult(List.of(), List.of());
        WinnerSummary winner = null;
        try (CallableStatement statement = connection.prepareCall("{CALL EVALUATEPROMOTIONREQUEST(?)}")) {
            statement.setInt(1, jobId);
            boolean hasResult = statement.execute();
            int resultNumber = 0;
            while (true) {
                if (hasResult) {
                    try (ResultSet resultSet = statement.getResultSet()) {
                        if (resultNumber == 0) {
                            applications = readResult(resultSet);
                        } else if (resultNumber == 1 && resultSet.next()) {
                            winner = new WinnerSummary(
                                    resultSet.getInt("job_id"),
                                    resultSet.getString("winner_username"),
                                    resultSet.getBigDecimal("winning_grade"),
                                    resultSet.getInt("processed_applications")
                            );
                        }
                    }
                    resultNumber++;
                } else if (statement.getUpdateCount() == -1) {
                    break;
                }
                hasResult = statement.getMoreResults(Statement.CLOSE_CURRENT_RESULT);
            }
        }
        return new PromotionProcessingResult(applications, winner);
    }

    public DynamicResult searchHistoryByGrade(int firstGrade, int secondGrade) throws SQLException {
        try (CallableStatement statement = connection.prepareCall("{CALL findApplicationsByGrade(?, ?)}")) {
            statement.setInt(1, firstGrade);
            statement.setInt(2, secondGrade);
            boolean result = statement.execute();
            if (!result) {
                return new DynamicResult(List.of(), List.of());
            }
            try (ResultSet resultSet = statement.getResultSet()) {
                return readResult(resultSet);
            }
        }
    }

    public DynamicResult searchHistoryByEvaluator(String evaluator) throws SQLException {
        try (CallableStatement statement = connection.prepareCall("{CALL findApplicationsByEvaluator(?)}")) {
            statement.setString(1, evaluator);
            boolean result = statement.execute();
            if (!result) {
                return new DynamicResult(List.of(), List.of());
            }
            try (ResultSet resultSet = statement.getResultSet()) {
                return readResult(resultSet);
            }
        }
    }

    public List<String> loadEvaluators() throws SQLException {
        List<String> evaluators = new ArrayList<>();
        try (PreparedStatement statement = connection.prepareStatement(
                "SELECT username FROM evaluator ORDER BY username");
             ResultSet resultSet = statement.executeQuery()) {
            while (resultSet.next()) {
                evaluators.add(resultSet.getString(1));
            }
        }
        return evaluators;
    }

    private static DynamicResult readResult(ResultSet resultSet) throws SQLException {
        ResultSetMetaData metadata = resultSet.getMetaData();
        int columnCount = metadata.getColumnCount();
        List<String> columns = new ArrayList<>(columnCount);
        for (int index = 1; index <= columnCount; index++) {
            columns.add(metadata.getColumnLabel(index));
        }
        List<List<Object>> rows = new ArrayList<>();
        while (resultSet.next()) {
            List<Object> row = new ArrayList<>(columnCount);
            for (int index = 1; index <= columnCount; index++) {
                row.add(resultSet.getObject(index));
            }
            rows.add(row);
        }
        return new DynamicResult(List.copyOf(columns), List.copyOf(rows));
    }

    public record JobOption(int id, String position) {
        @Override
        public String toString() {
            return id + " - " + position;
        }
    }

    public record WinnerSummary(
            int jobId,
            String winnerUsername,
            java.math.BigDecimal winningGrade,
            int processedApplications
    ) {
    }

    public record PromotionProcessingResult(
            DynamicResult applications,
            WinnerSummary winner
    ) {
    }
}
