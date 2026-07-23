package gr.upatras.firms;

/** Referenced table and column for a foreign-key column. */
public record ForeignKeyMeta(
        String constraintName,
        String referencedTable,
        String referencedColumn
) {
}
