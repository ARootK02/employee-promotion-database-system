package gr.upatras.firms;

import javax.swing.BorderFactory;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JMenu;
import javax.swing.JMenuBar;
import javax.swing.JMenuItem;
import javax.swing.JOptionPane;
import javax.swing.JTabbedPane;
import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;

/** Top-level window containing the required CRUD interface and bonus tools. */
public final class MainFrame extends JFrame {
    private final DatabaseSession session;

    public MainFrame(DatabaseSession session) {
        super("Employee Promotion Database System");
        this.session = session;
        setDefaultCloseOperation(DO_NOTHING_ON_CLOSE);
        setMinimumSize(new Dimension(1100, 720));
        setSize(1280, 800);
        setLocationRelativeTo(null);
        buildUi();
        addWindowListener(new WindowAdapter() {
            @Override
            public void windowClosing(WindowEvent event) {
                closeApplication();
            }
        });
    }

    private void buildUi() {
        setJMenuBar(buildMenu());
        JTabbedPane tabs = new JTabbedPane();
        tabs.addTab("Table management", new TableManagementPanel(session));
        tabs.addTab("Promotion tools", new PromotionResultsPanel(session));
        JLabel status = new JLabel(" Connected: " + session.description());
        status.setBorder(BorderFactory.createEmptyBorder(4, 4, 4, 4));
        add(tabs, BorderLayout.CENTER);
        add(status, BorderLayout.SOUTH);
    }

    private JMenuBar buildMenu() {
        JMenuBar menuBar = new JMenuBar();
        JMenu file = new JMenu("File");
        JMenuItem exit = new JMenuItem("Exit");
        exit.addActionListener(event -> closeApplication());
        file.add(exit);

        JMenu help = new JMenu("Help");
        JMenuItem about = new JMenuItem("About");
        about.addActionListener(event -> JOptionPane.showMessageDialog(this,
                "Employee Promotion Database System\n"
                        + "Java Swing + JDBC administration interface\n"
                        + "University database laboratory portfolio project",
                "About", JOptionPane.INFORMATION_MESSAGE));
        help.add(about);
        menuBar.add(file);
        menuBar.add(help);
        return menuBar;
    }

    private void closeApplication() {
        session.close();
        dispose();
        System.exit(0);
    }
}
