package gr.upatras.firms;

import javax.swing.table.AbstractTableModel;
import java.util.Collections;
import java.util.List;
import java.util.Map;

/** Read-only Swing model backed by raw row maps. */
public final class GenericTableModel extends AbstractTableModel {
    private List<String> columns = Collections.emptyList();
    private List<Map<String, Object>> rows = Collections.emptyList();

    public void setPage(TablePage page) {
        columns = page.columns();
        rows = page.rows();
        fireTableStructureChanged();
    }

    public Map<String, Object> rowAt(int modelRow) {
        return rows.get(modelRow);
    }

    @Override
    public int getRowCount() {
        return rows.size();
    }

    @Override
    public int getColumnCount() {
        return columns.size();
    }

    @Override
    public String getColumnName(int column) {
        return columns.get(column);
    }

    @Override
    public Object getValueAt(int rowIndex, int columnIndex) {
        String column = columns.get(columnIndex);
        Object value = rows.get(rowIndex).get(column);
        if ("password".equalsIgnoreCase(column) && value != null) {
            return "********";
        }
        return value;
    }

    @Override
    public boolean isCellEditable(int rowIndex, int columnIndex) {
        return false;
    }
}
