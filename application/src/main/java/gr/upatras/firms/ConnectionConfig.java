package gr.upatras.firms;

/** Database connection values entered at application startup. */
public record ConnectionConfig(
        String host,
        int port,
        String database,
        String username,
        char[] password
) {
    public String jdbcUrl() {
        return "jdbc:mysql://" + host + ":" + port + "/" + database
                + "?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC"
                + "&useUnicode=true&characterEncoding=UTF-8";
    }
}
