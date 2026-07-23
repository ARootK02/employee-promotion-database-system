package gr.upatras.firms;

import javax.swing.BorderFactory;
import javax.swing.JButton;
import javax.swing.JDialog;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JPasswordField;
import javax.swing.JTextField;
import java.awt.BorderLayout;
import java.awt.Dialog;
import java.awt.Dimension;
import java.awt.FlowLayout;
import java.awt.Frame;
import java.awt.GridBagConstraints;
import java.awt.GridBagLayout;
import java.awt.Insets;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.Arrays;

/** Modal startup dialog. Passwords are used in memory and are never saved. */
public final class ConnectionDialog extends JDialog {
    private final JTextField hostField = new JTextField(env("FIRMS_DB_HOST", "127.0.0.1"), 20);
    private final JTextField portField = new JTextField(env("FIRMS_DB_PORT", "3306"), 8);
    private final JTextField databaseField = new JTextField(env("FIRMS_DB_NAME", "firms"), 20);
    private final JTextField usernameField = new JTextField(env("FIRMS_DB_USER", "root"), 20);
    private final JPasswordField passwordField = new JPasswordField(20);
    private ConnectionConfig result;

    public ConnectionDialog(Frame owner) {
        super(owner, "Connect to MySQL", Dialog.ModalityType.APPLICATION_MODAL);
        setDefaultCloseOperation(DISPOSE_ON_CLOSE);
        buildUi();
        pack();
        setMinimumSize(new Dimension(470, 330));
        setLocationRelativeTo(owner);
    }

    public ConnectionConfig showDialog() {
        setVisible(true);
        return result;
    }

    private void buildUi() {
        JPanel form = new JPanel(new GridBagLayout());
        form.setBorder(BorderFactory.createEmptyBorder(16, 16, 8, 16));
        GridBagConstraints gbc = new GridBagConstraints();
        gbc.insets = new Insets(5, 5, 5, 5);
        gbc.anchor = GridBagConstraints.WEST;
        gbc.fill = GridBagConstraints.HORIZONTAL;

        addRow(form, gbc, 0, "Host", hostField);
        addRow(form, gbc, 1, "Port", portField);
        addRow(form, gbc, 2, "Database", databaseField);
        addRow(form, gbc, 3, "Username", usernameField);
        addRow(form, gbc, 4, "Password", passwordField);

        JLabel note = new JLabel("The password is not written to a file or stored by the application.");
        gbc.gridx = 0;
        gbc.gridy = 5;
        gbc.gridwidth = 2;
        form.add(note, gbc);

        JButton testButton = new JButton("Test connection");
        JButton connectButton = new JButton("Connect");
        JButton cancelButton = new JButton("Cancel");
        testButton.addActionListener(event -> testConnection());
        connectButton.addActionListener(event -> accept());
        cancelButton.addActionListener(event -> dispose());
        getRootPane().setDefaultButton(connectButton);

        JPanel buttons = new JPanel(new FlowLayout(FlowLayout.RIGHT));
        buttons.add(testButton);
        buttons.add(connectButton);
        buttons.add(cancelButton);

        add(form, BorderLayout.CENTER);
        add(buttons, BorderLayout.SOUTH);
    }

    private static void addRow(JPanel panel, GridBagConstraints gbc, int row, String label, java.awt.Component field) {
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.gridwidth = 1;
        gbc.weightx = 0;
        panel.add(new JLabel(label + ":"), gbc);
        gbc.gridx = 1;
        gbc.weightx = 1;
        panel.add(field, gbc);
    }

    private void testConnection() {
        ConnectionConfig config;
        try {
            config = readConfig();
        } catch (IllegalArgumentException exception) {
            Ui.showError(this, "Invalid connection settings", exception);
            return;
        }
        char[] passwordCopy = Arrays.copyOf(config.password(), config.password().length);
        try (Connection ignored = DriverManager.getConnection(
                config.jdbcUrl(), config.username(), new String(passwordCopy))) {
            Ui.showInfo(this, "Connection succeeded.");
        } catch (SQLException exception) {
            Ui.showError(this, "Connection failed", exception);
        } finally {
            Arrays.fill(passwordCopy, '\0');
            Arrays.fill(config.password(), '\0');
        }
    }

    private void accept() {
        try {
            result = readConfig();
            dispose();
        } catch (IllegalArgumentException exception) {
            Ui.showError(this, "Invalid connection settings", exception);
        }
    }

    private ConnectionConfig readConfig() {
        String host = required(hostField.getText(), "Host");
        String database = required(databaseField.getText(), "Database");
        String username = required(usernameField.getText(), "Username");
        int port;
        try {
            port = Integer.parseInt(portField.getText().trim());
        } catch (NumberFormatException exception) {
            throw new IllegalArgumentException("Port must be a whole number.");
        }
        if (port < 1 || port > 65535) {
            throw new IllegalArgumentException("Port must be between 1 and 65535.");
        }
        return new ConnectionConfig(host, port, database, username, passwordField.getPassword());
    }

    private static String required(String value, String label) {
        String trimmed = value == null ? "" : value.trim();
        if (trimmed.isEmpty()) {
            throw new IllegalArgumentException(label + " is required.");
        }
        return trimmed;
    }

    private static String env(String name, String fallback) {
        String value = System.getenv(name);
        return value == null || value.isBlank() ? fallback : value;
    }
}
