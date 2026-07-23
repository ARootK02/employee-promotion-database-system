package gr.upatras.firms;

import javax.swing.JOptionPane;
import java.awt.Component;
import java.sql.SQLException;

/** Common user-facing dialog helpers. */
public final class Ui {
    private Ui() {
    }

    public static void showError(Component parent, String heading, Throwable throwable) {
        String message = throwable.getMessage();
        if (throwable instanceof SQLException sqlException) {
            message = "SQLState: " + sqlException.getSQLState()
                    + "\nError code: " + sqlException.getErrorCode()
                    + "\n\n" + sqlException.getMessage();
        }
        JOptionPane.showMessageDialog(parent, message, heading, JOptionPane.ERROR_MESSAGE);
    }

    public static void showInfo(Component parent, String message) {
        JOptionPane.showMessageDialog(parent, message, "Information", JOptionPane.INFORMATION_MESSAGE);
    }
}
