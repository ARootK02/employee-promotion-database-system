package gr.upatras.firms;

import javax.swing.JOptionPane;
import javax.swing.SwingUtilities;
import javax.swing.UIManager;
import java.sql.SQLException;

/** Application entry point. */
public final class App {
    private App() {
    }

    public static void main(String[] args) {
        SwingUtilities.invokeLater(App::start);
    }

    private static void start() {
        try {
            UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName());
        } catch (Exception ignored) {
            // Swing's cross-platform look and feel remains available.
        }

        while (true) {
            ConnectionDialog dialog = new ConnectionDialog(null);
            ConnectionConfig config = dialog.showDialog();
            if (config == null) {
                return;
            }
            try {
                DatabaseSession session = DatabaseSession.connect(config);
                new MainFrame(session).setVisible(true);
                return;
            } catch (SQLException exception) {
                Ui.showError(null, "Unable to connect", exception);
                int retry = JOptionPane.showConfirmDialog(null,
                        "Try different connection settings?", "Connection failed",
                        JOptionPane.YES_NO_OPTION);
                if (retry != JOptionPane.YES_OPTION) {
                    return;
                }
            }
        }
    }
}
