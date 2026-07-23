package gr.upatras.firms;

import java.util.List;
import java.util.Map;

/** A paginated set of raw database rows. */
public record TablePage(
        List<String> columns,
        List<Map<String, Object>> rows,
        long totalRows,
        int offset,
        int limit
) {
}
