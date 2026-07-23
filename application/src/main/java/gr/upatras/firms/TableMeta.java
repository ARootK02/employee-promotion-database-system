package gr.upatras.firms;

import java.util.List;

/** Complete editable metadata for one base table. */
public record TableMeta(
        String name,
        List<ColumnMeta> columns,
        List<String> primaryKeyColumns
) {
    public ColumnMeta column(String columnName) {
        return columns.stream()
                .filter(column -> column.name().equals(columnName))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Unknown column: " + columnName));
    }

    public boolean hasPrimaryKey() {
        return !primaryKeyColumns.isEmpty();
    }
}
