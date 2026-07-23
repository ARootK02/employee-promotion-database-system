package gr.upatras.firms;

import java.util.regex.Pattern;

/** Restricts dynamically quoted identifiers to names returned by JDBC metadata. */
public final class SqlNames {
    private static final Pattern SAFE_IDENTIFIER = Pattern.compile("[A-Za-z0-9_]+(?: [A-Za-z0-9_]+)*");

    private SqlNames() {
    }

    public static String quote(String identifier) {
        if (identifier == null || !SAFE_IDENTIFIER.matcher(identifier).matches()) {
            throw new IllegalArgumentException("Unsafe SQL identifier: " + identifier);
        }
        return "`" + identifier.replace("`", "``") + "`";
    }
}
