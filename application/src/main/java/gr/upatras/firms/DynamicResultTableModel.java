package gr.upatras.firms;

import javax.swing.table.AbstractTableModel;
import java.util.List;

/** Read-only model for stored-procedure and bonus-interface results. */
public final class DynamicResultTableModel extends AbstractTableModel {
    private List<String> columns = List.of();
    private List<List<Object>> rows = List.of();

    public void setResult(DynamicResult result) {
        columns = result.columns();
        rows = result.rows();
        fireTableStructureChanged();
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
        return rows.get(rowIndex).get(columnIndex);
    }
}
