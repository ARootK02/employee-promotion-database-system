package gr.upatras.firms;

import javax.swing.BorderFactory;
import javax.swing.JButton;
import javax.swing.JComboBox;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.JSpinner;
import javax.swing.JTable;
import javax.swing.JTabbedPane;
import javax.swing.JTextField;
import javax.swing.SpinnerNumberModel;
import java.awt.BorderLayout;
import java.awt.FlowLayout;
import java.awt.Font;
import java.awt.GridLayout;
import java.sql.SQLException;

/** Bonus interface: previews/executes results and searches the large history. */
public final class PromotionResultsPanel extends JPanel {
    private final PromotionService service;
    private final JComboBox<PromotionService.JobOption> jobSelector = new JComboBox<>();
    private final DynamicResultTableModel processModel = new DynamicResultTableModel();
    private final JTable processTable = new JTable(processModel);
    private final JLabel winnerLabel = new JLabel("No job processed in this session.");
    private final DynamicResultTableModel historyModel = new DynamicResultTableModel();
    private final JTable historyTable = new JTable(historyModel);

    public PromotionResultsPanel(DatabaseSession session) {
        super(new BorderLayout());
        service = new PromotionService(session.connection());
        setBorder(BorderFactory.createEmptyBorder(10, 10, 10, 10));
        JTabbedPane tabs = new JTabbedPane();
        tabs.addTab("Process promotion results", buildProcessingPanel());
        tabs.addTab("Search request history", buildHistoryPanel());
        add(tabs, BorderLayout.CENTER);
        loadSelections();
    }

    private JPanel buildProcessingPanel() {
        JPanel panel = new JPanel(new BorderLayout(8, 8));
        JPanel controls = new JPanel(new FlowLayout(FlowLayout.LEFT));
        JLabel label = new JLabel("Job:");
        label.setFont(label.getFont().deriveFont(Font.BOLD));
        JButton previewButton = new JButton("Preview applications");
        JButton processButton = new JButton("Process results");
        controls.add(label);
        controls.add(jobSelector);
        controls.add(previewButton);
        controls.add(processButton);
        previewButton.addActionListener(event -> preview());
        processButton.addActionListener(event -> process());

        winnerLabel.setBorder(BorderFactory.createEmptyBorder(5, 5, 5, 5));
        panel.add(controls, BorderLayout.NORTH);
        panel.add(new JScrollPane(processTable), BorderLayout.CENTER);
        panel.add(winnerLabel, BorderLayout.SOUTH);
        return panel;
    }

    private JPanel buildHistoryPanel() {
        JPanel panel = new JPanel(new BorderLayout(8, 8));
        JPanel searches = new JPanel(new GridLayout(2, 1, 4, 4));

        JPanel gradeSearch = new JPanel(new FlowLayout(FlowLayout.LEFT));
        JSpinner firstGrade = new JSpinner(new SpinnerNumberModel(7, 0, 20, 1));
        JSpinner secondGrade = new JSpinner(new SpinnerNumberModel(12, 0, 20, 1));
        JButton gradeButton = new JButton("Search by grade interval");
        gradeSearch.add(new JLabel("Grades:"));
        gradeSearch.add(firstGrade);
        gradeSearch.add(new JLabel("to"));
        gradeSearch.add(secondGrade);
        gradeSearch.add(gradeButton);

        JPanel evaluatorSearch = new JPanel(new FlowLayout(FlowLayout.LEFT));
        JComboBox<String> evaluatorSelector = new JComboBox<>();
        evaluatorSelector.setPrototypeDisplayValue("evaluator_username");
        JButton evaluatorButton = new JButton("Search by evaluator");
        evaluatorSearch.add(new JLabel("Evaluator:"));
        evaluatorSearch.add(evaluatorSelector);
        evaluatorSearch.add(evaluatorButton);

        gradeButton.addActionListener(event -> {
            try {
                int first = (Integer) firstGrade.getValue();
                int second = (Integer) secondGrade.getValue();
                historyModel.setResult(service.searchHistoryByGrade(first, second));
                resize(historyTable);
            } catch (SQLException exception) {
                Ui.showError(this, "History search failed", exception);
            }
        });
        evaluatorButton.addActionListener(event -> {
            String evaluator = (String) evaluatorSelector.getSelectedItem();
            if (evaluator == null) {
                return;
            }
            try {
                historyModel.setResult(service.searchHistoryByEvaluator(evaluator));
                resize(historyTable);
            } catch (SQLException exception) {
                Ui.showError(this, "History search failed", exception);
            }
        });

        try {
            for (String evaluator : service.loadEvaluators()) {
                evaluatorSelector.addItem(evaluator);
            }
        } catch (SQLException exception) {
            Ui.showError(this, "Unable to load evaluators", exception);
        }

        searches.add(gradeSearch);
        searches.add(evaluatorSearch);
        panel.add(searches, BorderLayout.NORTH);
        panel.add(new JScrollPane(historyTable), BorderLayout.CENTER);
        return panel;
    }

    private void loadSelections() {
        try {
            jobSelector.removeAllItems();
            for (PromotionService.JobOption job : service.loadJobs()) {
                jobSelector.addItem(job);
            }
        } catch (SQLException exception) {
            Ui.showError(this, "Unable to load jobs", exception);
        }
    }

    private void preview() {
        PromotionService.JobOption job = selectedJob();
        if (job == null) {
            return;
        }
        try {
            DynamicResult result = service.preview(job.id());
            processModel.setResult(result);
            resize(processTable);
            winnerLabel.setText(result.rows().isEmpty()
                    ? "No current applications exist for the selected job."
                    : result.rows().size() + " application(s) ready for review.");
        } catch (SQLException exception) {
            Ui.showError(this, "Preview failed", exception);
        }
    }

    private void process() {
        PromotionService.JobOption job = selectedJob();
        if (job == null) {
            return;
        }
        int choice = JOptionPane.showConfirmDialog(this,
                "Process all applications for job " + job.id() + "?\n"
                        + "The procedure will move them from promotion_request to request_history.",
                "Confirm result processing", JOptionPane.YES_NO_OPTION,
                JOptionPane.WARNING_MESSAGE);
        if (choice != JOptionPane.YES_OPTION) {
            return;
        }
        try {
            PromotionService.PromotionProcessingResult result = service.process(job.id());
            processModel.setResult(result.applications());
            resize(processTable);
            PromotionService.WinnerSummary winner = result.winner();
            if (winner == null || winner.winnerUsername() == null) {
                winnerLabel.setText("Processed applications: no active winner was available.");
            } else {
                winnerLabel.setText("Winner: " + winner.winnerUsername()
                        + " | grade " + winner.winningGrade()
                        + " | processed applications " + winner.processedApplications());
            }
        } catch (SQLException exception) {
            Ui.showError(this, "Result processing failed", exception);
        }
    }

    private PromotionService.JobOption selectedJob() {
        PromotionService.JobOption job = (PromotionService.JobOption) jobSelector.getSelectedItem();
        if (job == null) {
            Ui.showInfo(this, "Select a job first.");
        }
        return job;
    }

    private static void resize(JTable table) {
        table.setAutoResizeMode(JTable.AUTO_RESIZE_OFF);
        for (int column = 0; column < table.getColumnCount(); column++) {
            table.getColumnModel().getColumn(column).setPreferredWidth(
                    Math.max(110, Math.min(260, table.getColumnName(column).length() * 11 + 25)));
        }
    }
}
