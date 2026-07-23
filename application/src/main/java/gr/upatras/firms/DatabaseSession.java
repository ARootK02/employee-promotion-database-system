package gr.upatras.firms;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.Arrays;

/** Owns the active JDBC connection and closes it when the application exits. */
public final class DatabaseSession implements AutoCloseable {
    private final Connection connection;
    private final ConnectionConfig config;

    private DatabaseSession(Connection connection, ConnectionConfig config) {
        this.connection = connection;
        this.config = config;
    }

    public static DatabaseSession connect(ConnectionConfig config) throws SQLException {
        String password = new String(config.password());
        try {
            Connection connection = DriverManager.getConnection(
                    config.jdbcUrl(), config.username(), password);
            connection.setAutoCommit(true);
            return new DatabaseSession(connection, config);
        } finally {
            Arrays.fill(config.password(), '\0');
        }
    }

    public Connection connection() {
        return connection;
    }

    public String description() {
        return config.username() + "@" + config.host() + ":" + config.port()
                + "/" + config.database();
    }

    @Override
    public void close() {
        try {
            connection.close();
        } catch (SQLException ignored) {
            // The application is already closing; there is no useful recovery action.
        }
    }
}
