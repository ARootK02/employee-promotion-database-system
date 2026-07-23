package gr.upatras.firms;

import javax.swing.BorderFactory;
import javax.swing.JComboBox;
import javax.swing.JComponent;
import javax.swing.JDialog;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JPasswordField;
import javax.swing.JScrollPane;
import javax.swing.JTextArea;
import javax.swing.JTextField;
import javax.swing.JButton;
import javax.swing.JOptionPane;
import java.awt.BorderLayout;
import java.awt.Component;
import java.awt.Dialog;
import java.awt.Dimension;
import java.awt.FlowLayout;
import java.awt.GridBagConstraints;
import java.awt.GridBagLayout;
import java.awt.Insets;
import java.awt.Window;
import java.math.BigDecimal;
import java.sql.Date;
import java.sql.SQLException;
import java.sql.Time;
import java.sql.Timestamp;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Metadata-driven insert/edit form with enum, boolean, and foreign-key selectors. */
public final class RecordEditorDialog extends JDialog {
    private static final Object NULL_OPTION = new Object() {
        @Override
        public String toString() {
            return "<NULL>";
        }
    };

    private final TableMeta table;
    private final MetadataService metadataService;
    private final Map<String, Object> originalRow;
    private final Map<String, JComponent> editors = new LinkedHashMap<>();
    private Map<String, Object> result;

    public RecordEditorDialog(Window owner,
                              TableMeta table,
                              MetadataService metadataService,
                              Map<String, Object> originalRow) {
        super(owner,
                (originalRow == null ? "Insert into " : "Edit ") + table.name(),
                Dialog.ModalityType.APPLICATION_MODAL);
        this.table = table;
        this.metadataService = metadataService;
        this.originalRow = originalRow;
        setDefaultCloseOperation(DISPOSE_ON_CLOSE);
        buildUi();
        pack();
        setMinimumSize(new Dimension(600, Math.min(760, Math.max(360, getHeight()))));
        setLocationRelativeTo(owner);
    }

    public Map<String, Object> showDialog() {
        setVisible(true);
        return result;
    }

    private void buildUi() {
        JPanel form = new JPanel(new GridBagLayout());
        form.setBorder(BorderFactory.createEmptyBorder(12, 12, 12, 12));
        GridBagConstraints gbc = new GridBagConstraints();
        gbc.insets = new Insets(4, 4, 4, 4);
        gbc.anchor = GridBagConstraints.NORTHWEST;
        gbc.fill = GridBagConstraints.HORIZONTAL;

        int row = 0;
        for (ColumnMeta column : table.columns()) {
            if (column.autoIncrement() || column.generated()) {
                if (originalRow == null) {
                    continue;
                }
            }
            gbc.gridx = 0;
            gbc.gridy = row;
            gbc.weightx = 0;
            String suffix = column.primaryKey() ? " (PK)" : "";
            if (column.requiredOnInsert()) {
                suffix += " *";
            }
            form.add(new JLabel(column.name() + suffix + ":"), gbc);

            JComponent editor;
            try {
                editor = createEditor(column);
            } catch (SQLException exception) {
                editor = new JTextField(28);
                editor.setToolTipText("Could not load selection values: " + exception.getMessage());
            }
            editors.put(column.name(), editor);
            gbc.gridx = 1;
            gbc.weightx = 1;
            if (editor instanceof JTextArea textArea) {
                form.add(new JScrollPane(textArea), gbc);
            } else {
                form.add(editor, gbc);
            }
            row++;
        }

        JLabel hint = new JLabel("Date: YYYY-MM-DD; datetime: YYYY-MM-DD HH:MM:SS; * required");
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.gridwidth = 2;
        form.add(hint, gbc);

        JButton save = new JButton(originalRow == null ? "Insert" : "Save changes");
        JButton cancel = new JButton("Cancel");
        save.addActionListener(event -> save());
        cancel.addActionListener(event -> dispose());
        getRootPane().setDefaultButton(save);

        JPanel buttons = new JPanel(new FlowLayout(FlowLayout.RIGHT));
        buttons.add(save);
        buttons.add(cancel);

        JScrollPane scrollPane = new JScrollPane(form);
        scrollPane.setBorder(BorderFactory.createEmptyBorder());
        add(scrollPane, BorderLayout.CENTER);
        add(buttons, BorderLayout.SOUTH);
    }

    private JComponent createEditor(ColumnMeta column) throws SQLException {
        Object current = originalRow == null ? null : originalRow.get(column.name());
        if (column.autoIncrement() || column.generated()) {
            JTextField field = new JTextField(current == null ? "" : current.toString(), 28);
            field.setEditable(false);
            return field;
        }
        if (!column.enumValues().isEmpty()) {
            JComboBox<Object> box = new JComboBox<>();
            if (column.nullable()) {
                box.addItem(NULL_OPTION);
            }
            column.enumValues().forEach(box::addItem);
            selectValue(box, current);
            return box;
        }
        if (column.foreignKey() != null) {
            JComboBox<Object> box = new JComboBox<>();
            if (column.nullable()) {
                box.addItem(NULL_OPTION);
            }
            for (Object value : metadataService.loadForeignKeyOptions(column.foreignKey())) {
                box.addItem(value);
            }
            selectValue(box, current);
            return box;
        }
        if (column.isBoolean()) {
            JComboBox<Object> box = new JComboBox<>();
            if (column.nullable()) {
                box.addItem(NULL_OPTION);
            }
            box.addItem(Boolean.FALSE);
            box.addItem(Boolean.TRUE);
            if (current != null) {
                boolean booleanValue = current instanceof Boolean b
                        ? b
                        : ((Number) current).intValue() != 0;
                box.setSelectedItem(booleanValue);
            }
            return box;
        }
        if (column.isLongText()) {
            JTextArea area = new JTextArea(4, 34);
            area.setLineWrap(true);
            area.setWrapStyleWord(true);
            area.setText(current == null ? "" : current.toString());
            return area;
        }
        JTextField field = "password".equalsIgnoreCase(column.name())
                ? new JPasswordField(28)
                : new JTextField(28);
        field.setText(current == null ? "" : current.toString());
        field.setToolTipText(typeHint(column));
        return field;
    }

    private static void selectValue(JComboBox<Object> box, Object current) {
        if (current == null) {
            if (box.getItemCount() > 0 && box.getItemAt(0) == NULL_OPTION) {
                box.setSelectedIndex(0);
            }
            return;
        }
        for (int index = 0; index < box.getItemCount(); index++) {
            Object item = box.getItemAt(index);
            if (current.toString().equals(String.valueOf(item))) {
                box.setSelectedIndex(index);
                return;
            }
        }
    }

    private void save() {
        try {
            Map<String, Object> values = new LinkedHashMap<>();
            for (ColumnMeta column : table.columns()) {
                JComponent editor = editors.get(column.name());
                if (editor == null || column.autoIncrement() || column.generated()) {
                    continue;
                }
                FormInput input = readInput(column, editor);
                if (originalRow == null && input.omitOnInsert()) {
                    continue;
                }
                values.put(column.name(), input.value());
            }
            result = values;
            dispose();
        } catch (IllegalArgumentException exception) {
            JOptionPane.showMessageDialog(this, exception.getMessage(),
                    "Invalid value", JOptionPane.WARNING_MESSAGE);
        }
    }

    private FormInput readInput(ColumnMeta column, JComponent component) {
        if (component instanceof JComboBox<?> box) {
            Object value = box.getSelectedItem();
            if (value == NULL_OPTION) {
                return new FormInput(null, false);
            }
            return new FormInput(value, false);
        }

        String text;
        if (component instanceof JPasswordField passwordField) {
            text = new String(passwordField.getPassword());
        } else if (component instanceof JTextArea textArea) {
            text = textArea.getText();
        } else {
            text = ((JTextField) component).getText();
        }
        String trimmed = text == null ? "" : text.trim();
        if (trimmed.isEmpty()) {
            if (originalRow == null && column.defaultValue() != null) {
                return new FormInput(null, true);
            }
            if (column.nullable()) {
                return new FormInput(null, false);
            }
            throw new IllegalArgumentException(column.name() + " is required.");
        }

        try {
            if (column.isBoolean()) {
                if (trimmed.equals("1") || trimmed.equalsIgnoreCase("true")) {
                    return new FormInput(true, false);
                }
                if (trimmed.equals("0") || trimmed.equalsIgnoreCase("false")) {
                    return new FormInput(false, false);
                }
                throw new IllegalArgumentException(column.name() + " must be true/false or 1/0.");
            }
            if (column.isInteger()) {
                return new FormInput(Long.valueOf(trimmed), false);
            }
            if (column.isDecimal()) {
                return new FormInput(new BigDecimal(trimmed), false);
            }
            if (column.isDate()) {
                return new FormInput(Date.valueOf(LocalDate.parse(trimmed)), false);
            }
            if (column.isDateTime()) {
                String normalized = trimmed.replace('T', ' ');
                if (normalized.length() == 16) {
                    normalized += ":00";
                }
                return new FormInput(Timestamp.valueOf(LocalDateTime.parse(
                        normalized.replace(' ', 'T'))), false);
            }
            if (column.isTime()) {
                return new FormInput(Time.valueOf(LocalTime.parse(trimmed)), false);
            }
        } catch (IllegalArgumentException exception) {
            throw new IllegalArgumentException(
                    "Invalid value for " + column.name() + " (" + typeHint(column) + ").");
        }
        return new FormInput(trimmed, false);
    }

    private static String typeHint(ColumnMeta column) {
        if (column.isDate()) {
            return "date YYYY-MM-DD";
        }
        if (column.isDateTime()) {
            return "datetime YYYY-MM-DD HH:MM:SS";
        }
        if (column.isTime()) {
            return "time HH:MM:SS";
        }
        return column.columnType();
    }

    private record FormInput(Object value, boolean omitOnInsert) {
    }
}
