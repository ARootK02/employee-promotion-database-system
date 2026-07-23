package gr.upatras.firms;

import java.util.List;

/** Generic result-set data for the bonus interfaces. */
public record DynamicResult(List<String> columns, List<List<Object>> rows) {
}
