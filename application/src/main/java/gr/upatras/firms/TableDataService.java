package gr.upatras.firms;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.StringJoiner;

/** Executes generic paginated CRUD operations using prepared statements. */
public final class TableDataService {
    private final Connection connection;

    public TableDataService(Connection connection) {
        this.connection = connection;
    }

    public TablePage loadPage(TableMeta table, int limit, int offset) throws SQLException {
        long total = countRows(table.name());
        List<Map<String, Object>> rows = new ArrayList<>();
        List<String> columns = table.columns().stream().map(ColumnMeta::name).toList();

        String orderBy = table.hasPrimaryKey()
                ? " ORDER BY " + table.primaryKeyColumns().stream()
                    .map(SqlNames::quote)
                    .reduce((left, right) -> left + ", " + right)
                    .orElse("")
                : "";
        String sql = "SELECT * FROM " + SqlNames.quote(table.name()) + orderBy + " LIMIT ? OFFSET ?";

        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setInt(1, limit);
            statement.setInt(2, offset);
            try (ResultSet resultSet = statement.executeQuery()) {
                while (resultSet.next()) {
                    Map<String, Object> row = new LinkedHashMap<>();
                    for (String column : columns) {
                        row.put(column, resultSet.getObject(column));
                    }
                    rows.add(row);
                }
            }
        }
        return new TablePage(columns, rows, total, offset, limit);
    }

    public void insert(TableMeta table, Map<String, Object> values) throws SQLException {
        if (values.isEmpty()) {
            throw new SQLException("No values were supplied for insertion.");
        }
        StringJoiner columns = new StringJoiner(", ");
        StringJoiner placeholders = new StringJoiner(", ");
        values.keySet().forEach(column -> {
            columns.add(SqlNames.quote(column));
            placeholders.add("?");
        });
        String sql = "INSERT INTO " + SqlNames.quote(table.name()) + " (" + columns + ") VALUES ("
                + placeholders + ")";
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            bindValues(statement, new ArrayList<>(values.values()));
            statement.executeUpdate();
        }
    }

    public void update(TableMeta table,
                       Map<String, Object> newValues,
                       Map<String, Object> originalPrimaryKey) throws SQLException {
        requirePrimaryKey(table, originalPrimaryKey);
        StringJoiner assignments = new StringJoiner(", ");
        newValues.keySet().forEach(column -> assignments.add(SqlNames.quote(column) + " = ?"));
        String where = primaryKeyWhere(table);
        String sql = "UPDATE " + SqlNames.quote(table.name()) + " SET " + assignments + " WHERE " + where;

        List<Object> bindings = new ArrayList<>(newValues.values());
        table.primaryKeyColumns().forEach(column -> bindings.add(originalPrimaryKey.get(column)));
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            bindValues(statement, bindings);
            int affected = statement.executeUpdate();
            if (affected != 1) {
                throw new SQLException("Expected to update one row, but " + affected + " rows were changed.");
            }
        }
    }

    public void delete(TableMeta table, Map<String, Object> primaryKey) throws SQLException {
        requirePrimaryKey(table, primaryKey);
        String sql = "DELETE FROM " + SqlNames.quote(table.name()) + " WHERE " + primaryKeyWhere(table);
        List<Object> bindings = table.primaryKeyColumns().stream().map(primaryKey::get).toList();
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            bindValues(statement, bindings);
            int affected = statement.executeUpdate();
            if (affected != 1) {
                throw new SQLException("Expected to delete one row, but " + affected + " rows were changed.");
            }
        }
    }

    private long countRows(String tableName) throws SQLException {
        String sql = "SELECT COUNT(*) FROM " + SqlNames.quote(tableName);
        try (PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            resultSet.next();
            return resultSet.getLong(1);
        }
    }

    private static String primaryKeyWhere(TableMeta table) {
        return table.primaryKeyColumns().stream()
                .map(column -> SqlNames.quote(column) + " <=> ?")
                .reduce((left, right) -> left + " AND " + right)
                .orElseThrow();
    }

    private static void requirePrimaryKey(TableMeta table, Map<String, Object> primaryKey) throws SQLException {
        if (!table.hasPrimaryKey()) {
            throw new SQLException("The selected table does not have a primary key; safe update/delete is unavailable.");
        }
        for (String column : table.primaryKeyColumns()) {
            if (!primaryKey.containsKey(column)) {
                throw new SQLException("Primary-key value is missing for column " + column + ".");
            }
        }
    }

    private static void bindValues(PreparedStatement statement, List<Object> values) throws SQLException {
        for (int index = 0; index < values.size(); index++) {
            Object value = values.get(index);
            if (value == null) {
                statement.setNull(index + 1, Types.NULL);
            } else {
                statement.setObject(index + 1, value);
            }
        }
    }
}
