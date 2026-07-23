package gr.upatras.firms;

import javax.swing.BorderFactory;
import javax.swing.JButton;
import javax.swing.JComboBox;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.JTable;
import javax.swing.ListSelectionModel;
import javax.swing.SwingUtilities;
import java.awt.BorderLayout;
import java.awt.FlowLayout;
import java.awt.Font;
import java.awt.event.MouseAdapter;
import java.awt.event.MouseEvent;
import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Main Part B requirement: select any table and perform CRUD operations. */
public final class TableManagementPanel extends JPanel {
    private static final int PAGE_SIZE = 500;

    private final MetadataService metadataService;
    private final TableDataService dataService;
    private final JComboBox<String> tableSelector = new JComboBox<>();
    private final GenericTableModel tableModel = new GenericTableModel();
    private final JTable table = new JTable(tableModel);
    private final JLabel pageLabel = new JLabel("No table selected");
    private final JButton previousButton = new JButton("Previous");
    private final JButton nextButton = new JButton("Next");
    private final JButton addButton = new JButton("Add");
    private final JButton editButton = new JButton("Edit");
    private final JButton deleteButton = new JButton("Delete");
    private TableMeta currentTable;
    private TablePage currentPage;
    private int offset;

    public TableManagementPanel(DatabaseSession session) {
        super(new BorderLayout(8, 8));
        metadataService = new MetadataService(session.connection());
        dataService = new TableDataService(session.connection());
        setBorder(BorderFactory.createEmptyBorder(10, 10, 10, 10));
        buildUi();
        loadTableNames();
    }

    private void buildUi() {
        JPanel top = new JPanel(new FlowLayout(FlowLayout.LEFT));
        JLabel label = new JLabel("Database table:");
        label.setFont(label.getFont().deriveFont(Font.BOLD));
        top.add(label);
        top.add(tableSelector);
        JButton refreshButton = new JButton("Refresh");
        top.add(refreshButton);
        top.add(addButton);
        top.add(editButton);
        top.add(deleteButton);

        table.setAutoResizeMode(JTable.AUTO_RESIZE_OFF);
        table.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);
        table.setFillsViewportHeight(true);
        table.addMouseListener(new MouseAdapter() {
            @Override
            public void mouseClicked(MouseEvent event) {
                if (event.getClickCount() == 2 && SwingUtilities.isLeftMouseButton(event)) {
                    editSelected();
                }
            }
        });

        JPanel paging = new JPanel(new FlowLayout(FlowLayout.RIGHT));
        paging.add(previousButton);
        paging.add(pageLabel);
        paging.add(nextButton);

        tableSelector.addActionListener(event -> tableChanged());
        refreshButton.addActionListener(event -> refresh());
        addButton.addActionListener(event -> insertRow());
        editButton.addActionListener(event -> editSelected());
        deleteButton.addActionListener(event -> deleteSelected());
        previousButton.addActionListener(event -> {
            offset = Math.max(0, offset - PAGE_SIZE);
            refresh();
        });
        nextButton.addActionListener(event -> {
            offset += PAGE_SIZE;
            refresh();
        });

        add(top, BorderLayout.NORTH);
        add(new JScrollPane(table), BorderLayout.CENTER);
        add(paging, BorderLayout.SOUTH);
        updateButtons();
    }

    private void loadTableNames() {
        try {
            List<String> tables = metadataService.loadBaseTables();
            for (String name : tables) {
                tableSelector.addItem(name);
            }
            if (!tables.isEmpty()) {
                tableSelector.setSelectedIndex(0);
            }
        } catch (SQLException exception) {
            Ui.showError(this, "Unable to load tables", exception);
        }
    }

    private void tableChanged() {
        String name = (String) tableSelector.getSelectedItem();
        if (name == null) {
            return;
        }
        try {
            currentTable = metadataService.loadTableMeta(name);
            offset = 0;
            refresh();
        } catch (SQLException exception) {
            Ui.showError(this, "Unable to read table metadata", exception);
        }
    }

    private void refresh() {
        if (currentTable == null) {
            return;
        }
        try {
            currentPage = dataService.loadPage(currentTable, PAGE_SIZE, offset);
            if (offset >= currentPage.totalRows() && offset > 0) {
                offset = Math.max(0, offset - PAGE_SIZE);
                currentPage = dataService.loadPage(currentTable, PAGE_SIZE, offset);
            }
            tableModel.setPage(currentPage);
            resizeColumns();
            updateButtons();
        } catch (SQLException exception) {
            Ui.showError(this, "Unable to load table data", exception);
        }
    }

    private void insertRow() {
        if (currentTable == null) {
            return;
        }
        RecordEditorDialog dialog = new RecordEditorDialog(
                SwingUtilities.getWindowAncestor(this), currentTable, metadataService, null);
        Map<String, Object> values = dialog.showDialog();
        if (values == null) {
            return;
        }
        try {
            dataService.insert(currentTable, values);
            refresh();
        } catch (SQLException exception) {
            Ui.showError(this, "Insert failed", exception);
        }
    }

    private void editSelected() {
        Map<String, Object> row = selectedRow();
        if (row == null) {
            return;
        }
        if (!currentTable.hasPrimaryKey()) {
            Ui.showInfo(this, "This table has no primary key, so safe editing is unavailable.");
            return;
        }
        RecordEditorDialog dialog = new RecordEditorDialog(
                SwingUtilities.getWindowAncestor(this), currentTable, metadataService, row);
        Map<String, Object> values = dialog.showDialog();
        if (values == null) {
            return;
        }
        Map<String, Object> originalKey = primaryKeyFrom(row);
        try {
            dataService.update(currentTable, values, originalKey);
            refresh();
        } catch (SQLException exception) {
            Ui.showError(this, "Update failed", exception);
        }
    }

    private void deleteSelected() {
        Map<String, Object> row = selectedRow();
        if (row == null) {
            return;
        }
        if (!currentTable.hasPrimaryKey()) {
            Ui.showInfo(this, "This table has no primary key, so safe deletion is unavailable.");
            return;
        }
        Map<String, Object> key = primaryKeyFrom(row);
        int choice = JOptionPane.showConfirmDialog(this,
                "Delete the selected row from " + currentTable.name() + "?\nPrimary key: " + key,
                "Confirm deletion", JOptionPane.YES_NO_OPTION, JOptionPane.WARNING_MESSAGE);
        if (choice != JOptionPane.YES_OPTION) {
            return;
        }
        try {
            dataService.delete(currentTable, key);
            refresh();
        } catch (SQLException exception) {
            Ui.showError(this, "Delete failed", exception);
        }
    }

    private Map<String, Object> selectedRow() {
        int viewRow = table.getSelectedRow();
        if (viewRow < 0) {
            Ui.showInfo(this, "Select a row first.");
            return null;
        }
        int modelRow = table.convertRowIndexToModel(viewRow);
        return tableModel.rowAt(modelRow);
    }

    private Map<String, Object> primaryKeyFrom(Map<String, Object> row) {
        Map<String, Object> key = new LinkedHashMap<>();
        currentTable.primaryKeyColumns().forEach(column -> key.put(column, row.get(column)));
        return key;
    }

    private void updateButtons() {
        boolean selected = currentTable != null;
        addButton.setEnabled(selected);
        editButton.setEnabled(selected && currentTable.hasPrimaryKey());
        deleteButton.setEnabled(selected && currentTable.hasPrimaryKey());
        if (currentPage == null) {
            previousButton.setEnabled(false);
            nextButton.setEnabled(false);
            pageLabel.setText("No data");
            return;
        }
        long start = currentPage.totalRows() == 0 ? 0 : currentPage.offset() + 1L;
        long end = Math.min(currentPage.offset() + currentPage.rows().size(), currentPage.totalRows());
        pageLabel.setText(start + "-" + end + " of " + currentPage.totalRows());
        previousButton.setEnabled(currentPage.offset() > 0);
        nextButton.setEnabled(currentPage.offset() + currentPage.limit() < currentPage.totalRows());
    }

    private void resizeColumns() {
        for (int column = 0; column < table.getColumnCount(); column++) {
            int width = Math.max(90, Math.min(280, table.getColumnName(column).length() * 10 + 30));
            table.getColumnModel().getColumn(column).setPreferredWidth(width);
        }
    }
}
