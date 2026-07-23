package gr.upatras.firms;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Reads table, column, key, enum, and foreign-key metadata from MySQL. */
public final class MetadataService {
    private static final Pattern ENUM_VALUE = Pattern.compile("'((?:''|[^'])*)'");

    private final Connection connection;

    public MetadataService(Connection connection) {
        this.connection = connection;
    }

    public List<String> loadBaseTables() throws SQLException {
        List<String> tables = new ArrayList<>();
        String sql = """
                SELECT table_name
                FROM information_schema.tables
                WHERE table_schema = DATABASE()
                  AND table_type = 'BASE TABLE'
                ORDER BY table_name
                """;
        try (PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            while (resultSet.next()) {
                tables.add(resultSet.getString(1));
            }
        }
        return tables;
    }

    public TableMeta loadTableMeta(String tableName) throws SQLException {
        Map<String, ForeignKeyMeta> foreignKeys = loadForeignKeys(tableName);
        Set<String> primaryKeys = loadPrimaryKeys(tableName);
        List<ColumnMeta> columns = new ArrayList<>();

        String sql = """
                SELECT column_name,
                       data_type,
                       column_type,
                       is_nullable,
                       column_default,
                       extra,
                       character_maximum_length,
                       numeric_precision,
                       numeric_scale
                FROM information_schema.columns
                WHERE table_schema = DATABASE()
                  AND table_name = ?
                ORDER BY ordinal_position
                """;

        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, tableName);
            try (ResultSet resultSet = statement.executeQuery()) {
                while (resultSet.next()) {
                    String name = resultSet.getString("column_name");
                    String columnType = resultSet.getString("column_type");
                    columns.add(new ColumnMeta(
                            name,
                            resultSet.getString("data_type"),
                            columnType,
                            "YES".equalsIgnoreCase(resultSet.getString("is_nullable")),
                            resultSet.getString("column_default"),
                            resultSet.getString("extra"),
                            nullableLong(resultSet, "character_maximum_length"),
                            nullableInteger(resultSet, "numeric_precision"),
                            nullableInteger(resultSet, "numeric_scale"),
                            primaryKeys.contains(name),
                            foreignKeys.get(name),
                            parseEnumValues(columnType)
                    ));
                }
            }
        }

        return new TableMeta(tableName, List.copyOf(columns), List.copyOf(primaryKeys));
    }

    private Set<String> loadPrimaryKeys(String tableName) throws SQLException {
        Set<String> keys = new LinkedHashSet<>();
        String sql = """
                SELECT kcu.column_name
                FROM information_schema.table_constraints AS tc
                JOIN information_schema.key_column_usage AS kcu
                  ON kcu.constraint_schema = tc.constraint_schema
                 AND kcu.table_name = tc.table_name
                 AND kcu.constraint_name = tc.constraint_name
                WHERE tc.constraint_schema = DATABASE()
                  AND tc.table_name = ?
                  AND tc.constraint_type = 'PRIMARY KEY'
                ORDER BY kcu.ordinal_position
                """;
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, tableName);
            try (ResultSet resultSet = statement.executeQuery()) {
                while (resultSet.next()) {
                    keys.add(resultSet.getString(1));
                }
            }
        }
        return keys;
    }

    private Map<String, ForeignKeyMeta> loadForeignKeys(String tableName) throws SQLException {
        Map<String, ForeignKeyMeta> result = new LinkedHashMap<>();
        String sql = """
                SELECT constraint_name,
                       column_name,
                       referenced_table_name,
                       referenced_column_name
                FROM information_schema.key_column_usage
                WHERE constraint_schema = DATABASE()
                  AND table_name = ?
                  AND referenced_table_name IS NOT NULL
                ORDER BY constraint_name, ordinal_position
                """;
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, tableName);
            try (ResultSet resultSet = statement.executeQuery()) {
                while (resultSet.next()) {
                    result.put(resultSet.getString("column_name"), new ForeignKeyMeta(
                            resultSet.getString("constraint_name"),
                            resultSet.getString("referenced_table_name"),
                            resultSet.getString("referenced_column_name")
                    ));
                }
            }
        }
        return result;
    }

    public List<Object> loadForeignKeyOptions(ForeignKeyMeta foreignKey) throws SQLException {
        String sql = "SELECT DISTINCT " + SqlNames.quote(foreignKey.referencedColumn())
                + " FROM " + SqlNames.quote(foreignKey.referencedTable())
                + " ORDER BY " + SqlNames.quote(foreignKey.referencedColumn())
                + " LIMIT 1000";
        List<Object> values = new ArrayList<>();
        try (PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            while (resultSet.next()) {
                values.add(resultSet.getObject(1));
            }
        }
        return values;
    }

    private static List<String> parseEnumValues(String columnType) {
        if (columnType == null || !columnType.toLowerCase().startsWith("enum(")) {
            return Collections.emptyList();
        }
        List<String> values = new ArrayList<>();
        Matcher matcher = ENUM_VALUE.matcher(columnType);
        while (matcher.find()) {
            values.add(matcher.group(1).replace("''", "'"));
        }
        return List.copyOf(values);
    }

    private static Long nullableLong(ResultSet resultSet, String column) throws SQLException {
        long value = resultSet.getLong(column);
        return resultSet.wasNull() ? null : value;
    }

    private static Integer nullableInteger(ResultSet resultSet, String column) throws SQLException {
        int value = resultSet.getInt(column);
        return resultSet.wasNull() ? null : value;
    }
}
