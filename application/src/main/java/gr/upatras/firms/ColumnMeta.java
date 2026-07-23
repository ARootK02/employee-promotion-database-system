package gr.upatras.firms;

import java.util.List;

/** Metadata required to display and validate one database column. */
public record ColumnMeta(
        String name,
        String dataType,
        String columnType,
        boolean nullable,
        String defaultValue,
        String extra,
        Long characterLength,
        Integer numericPrecision,
        Integer numericScale,
        boolean primaryKey,
        ForeignKeyMeta foreignKey,
        List<String> enumValues
) {
    public boolean autoIncrement() {
        return extra != null && extra.toLowerCase().contains("auto_increment");
    }

    public boolean generated() {
        if (extra == null) {
            return false;
        }
        String lower = extra.toLowerCase();
        return lower.contains("virtual generated") || lower.contains("stored generated");
    }

    public boolean requiredOnInsert() {
        return !nullable && defaultValue == null && !autoIncrement() && !generated();
    }

    public boolean isTextLike() {
        return switch (dataType.toLowerCase()) {
            case "char", "varchar", "text", "tinytext", "mediumtext", "longtext", "json" -> true;
            default -> false;
        };
    }

    public boolean isLongText() {
        return dataType.toLowerCase().contains("text") || "json".equalsIgnoreCase(dataType)
                || (characterLength != null && characterLength > 180);
    }

    public boolean isInteger() {
        return switch (dataType.toLowerCase()) {
            case "tinyint", "smallint", "mediumint", "int", "integer", "bigint", "year" -> true;
            default -> false;
        };
    }

    public boolean isDecimal() {
        return switch (dataType.toLowerCase()) {
            case "decimal", "numeric", "float", "double", "real" -> true;
            default -> false;
        };
    }

    public boolean isBoolean() {
        return "tinyint(1)".equalsIgnoreCase(columnType) || "boolean".equalsIgnoreCase(dataType);
    }

    public boolean isDate() {
        return "date".equalsIgnoreCase(dataType);
    }

    public boolean isDateTime() {
        return switch (dataType.toLowerCase()) {
            case "datetime", "timestamp" -> true;
            default -> false;
        };
    }

    public boolean isTime() {
        return "time".equalsIgnoreCase(dataType);
    }
}
