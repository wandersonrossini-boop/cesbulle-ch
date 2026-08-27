package com.tesourariacme.api.application;

import com.google.api.client.googleapis.javanet.GoogleNetHttpTransport;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import com.google.api.services.drive.Drive;
import com.google.api.services.drive.model.Permission;
import com.google.api.services.sheets.v4.Sheets;
import com.google.api.services.sheets.v4.model.*;
import com.google.auth.http.HttpCredentialsAdapter;
import com.google.auth.oauth2.GoogleCredentials;
import com.tesourariacme.api.presentation.FinancialReportDTO;
import com.tesourariacme.api.presentation.GoogleSheetsResponseDTO;
import org.springframework.stereotype.Service;

import java.io.ByteArrayInputStream;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

@Service
public class GoogleSheetsService {

    private final String credentialsJson;
    private final String institutionalEmail;

    public GoogleSheetsService() {
        this.credentialsJson = System.getenv("GOOGLE_CREDENTIALS_JSON");
        this.institutionalEmail = System.getenv("INSTITUTIONAL_EMAIL");
    }

    // Constructor for testing
    public GoogleSheetsService(String credentialsJson, String institutionalEmail) {
        this.credentialsJson = credentialsJson;
        this.institutionalEmail = institutionalEmail;
    }

    private GoogleCredentials getCredentials() throws Exception {
        if (credentialsJson == null || credentialsJson.trim().isEmpty()) {
            throw new IllegalStateException("Variável de ambiente GOOGLE_CREDENTIALS_JSON não está configurada.");
        }
        return GoogleCredentials.fromStream(new ByteArrayInputStream(credentialsJson.getBytes(StandardCharsets.UTF_8)))
                .createScoped(Arrays.asList(
                        "https://www.googleapis.com/auth/spreadsheets",
                        "https://www.googleapis.com/auth/drive"
                ));
    }

    public GoogleSheetsResponseDTO createFinancialReportSheet(FinancialReportDTO report, int month, int year) {
        try {
            NetHttpTransport httpTransport = GoogleNetHttpTransport.newTrustedTransport();
            GsonFactory jsonFactory = GsonFactory.getDefaultInstance();
            GoogleCredentials credentials = getCredentials();
            HttpCredentialsAdapter credentialsAdapter = new HttpCredentialsAdapter(credentials);

            Sheets sheetsService = new Sheets.Builder(httpTransport, jsonFactory, credentialsAdapter)
                    .setApplicationName("TesourariaCME")
                    .build();

            Drive driveService = new Drive.Builder(httpTransport, jsonFactory, credentialsAdapter)
                    .setApplicationName("TesourariaCME")
                    .build();

            // 1. Create new spreadsheet
            String title = String.format("CME Lausanne - Relatório Financeiro - %02d-%d", month, year);
            Spreadsheet spreadsheet = new Spreadsheet()
                    .setProperties(new SpreadsheetProperties().setTitle(title));

            Spreadsheet created = sheetsService.spreadsheets().create(spreadsheet).execute();
            String spreadsheetId = created.getSpreadsheetId();
            String spreadsheetUrl = created.getSpreadsheetUrl();

            // 2. Share with Institutional Email as EDITOR
            if (institutionalEmail != null && !institutionalEmail.trim().isEmpty()) {
                Permission permission = new Permission()
                        .setType("user")
                        .setRole("writer")
                        .setEmailAddress(institutionalEmail.trim());

                driveService.permissions().create(spreadsheetId, permission)
                        .setSendNotificationEmail(false)
                        .execute();
            }

            // 3. Populate Data
            List<List<Object>> values = new ArrayList<>();
            values.add(Arrays.asList("RELATÓRIO FINANCEIRO MENSAL - CME LAUSANNE"));
            values.add(Arrays.asList("Período:", String.format("%02d/%d", month, year)));
            values.add(Arrays.asList("Status:", report.getMetadata().getStatus()));
            values.add(Arrays.asList("Moeda:", "CHF"));
            values.add(Arrays.asList("Gerado em:", LocalDateTime.now().format(DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm:ss"))));
            values.add(Arrays.asList(""));

            values.add(Arrays.asList("RESUMO"));
            values.add(Arrays.asList("Total de Entradas", report.getSummary().getTotalIncomes().doubleValue()));
            values.add(Arrays.asList("Saídas Pagas", report.getSummary().getTotalExpenses().doubleValue()));
            values.add(Arrays.asList("Despesas Aprovadas a Pagar", report.getSummary().getTotalCommitted().doubleValue()));
            values.add(Arrays.asList("Saldo Líquido Realizado", report.getSummary().getNetBalance().doubleValue()));
            values.add(Arrays.asList(""));

            values.add(Arrays.asList("DETALHAMENTO DE ENTRADAS"));
            values.add(Arrays.asList("Categoria", "Valor", "Quantidade"));
            for (FinancialReportDTO.CategorySummary income : report.getIncomesByCategory()) {
                values.add(Arrays.asList(income.getCategory(), income.getTotal().doubleValue(), income.getCount()));
            }
            values.add(Arrays.asList(""));

            values.add(Arrays.asList("DETALHAMENTO DE SAÍDAS PAGAS"));
            values.add(Arrays.asList("Categoria", "Valor", "Quantidade"));
            for (FinancialReportDTO.CategorySummary expense : report.getExpensesByCategory()) {
                values.add(Arrays.asList(expense.getCategory(), expense.getTotal().doubleValue(), expense.getCount()));
            }

            ValueRange body = new ValueRange().setValues(values);
            sheetsService.spreadsheets().values()
                    .update(spreadsheetId, "A1", body)
                    .setValueInputOption("USER_ENTERED")
                    .execute();

            // 4. Formatting requests (Bold headers, borders, Currency formats, Autofit)
            List<Request> requests = new ArrayList<>();

            // Bold styling helper
            TextFormat boldStyle = new TextFormat().setBold(true);

            // Bold "RELATÓRIO FINANCEIRO MENSAL"
            requests.add(new Request().setUpdateCells(new UpdateCellsRequest()
                    .setRange(new GridRange().setSheetId(0).setStartRowIndex(0).setEndRowIndex(1).setStartColumnIndex(0).setEndColumnIndex(1))
                    .setRows(Collections.singletonList(new RowData().setValues(Collections.singletonList(new CellData()
                            .setUserEnteredFormat(new CellFormat().setTextFormat(boldStyle))))))
                    .setFields("userEnteredFormat.textFormat")));

            // Bold "RESUMO", "DETALHAMENTO DE ENTRADAS", "DETALHAMENTO DE SAÍDAS PAGAS"
            List<Integer> sectionHeaderRows = Arrays.asList(6, 12, 14 + report.getIncomesByCategory().size());
            for (int r : sectionHeaderRows) {
                requests.add(new Request().setUpdateCells(new UpdateCellsRequest()
                        .setRange(new GridRange().setSheetId(0).setStartRowIndex(r).setEndRowIndex(r + 1).setStartColumnIndex(0).setEndColumnIndex(1))
                        .setRows(Collections.singletonList(new RowData().setValues(Collections.singletonList(new CellData()
                                .setUserEnteredFormat(new CellFormat().setTextFormat(new TextFormat().setBold(true).setFontSize(11)))))))
                        .setFields("userEnteredFormat.textFormat")));
            }

            // Bold headers Categoria/Valor/Quantidade
            int incomeHeaderRow = 13;
            int expenseHeaderRow = 15 + report.getIncomesByCategory().size();
            for (int r : Arrays.asList(incomeHeaderRow, expenseHeaderRow)) {
                requests.add(new Request().setUpdateCells(new UpdateCellsRequest()
                        .setRange(new GridRange().setSheetId(0).setStartRowIndex(r).setEndRowIndex(r + 1).setStartColumnIndex(0).setEndColumnIndex(3))
                        .setRows(Collections.singletonList(new RowData().setValues(Arrays.asList(
                                new CellData().setUserEnteredFormat(new CellFormat().setTextFormat(boldStyle)),
                                new CellData().setUserEnteredFormat(new CellFormat().setTextFormat(boldStyle)),
                                new CellData().setUserEnteredFormat(new CellFormat().setTextFormat(boldStyle))
                        ))))
                        .setFields("userEnteredFormat.textFormat")));
            }

            // Currency formatting (CHF #,##0.00)
            NumberFormat currencyFormat = new NumberFormat().setType("CURRENCY").setPattern("\"CHF\" #,##0.00");
            CellFormat currencyCellFormat = new CellFormat().setNumberFormat(currencyFormat);

            // Format Resumo Values
            requests.add(new Request().setRepeatCell(new RepeatCellRequest()
                    .setRange(new GridRange().setSheetId(0).setStartRowIndex(7).setEndRowIndex(11).setStartColumnIndex(1).setEndColumnIndex(2))
                    .setCell(new CellData().setUserEnteredFormat(currencyCellFormat))
                    .setFields("userEnteredFormat.numberFormat")));

            // Format Incomes Values
            int startIncomes = 14;
            int endIncomes = 14 + report.getIncomesByCategory().size();
            requests.add(new Request().setRepeatCell(new RepeatCellRequest()
                    .setRange(new GridRange().setSheetId(0).setStartRowIndex(startIncomes).setEndRowIndex(endIncomes).setStartColumnIndex(1).setEndColumnIndex(2))
                    .setCell(new CellData().setUserEnteredFormat(currencyCellFormat))
                    .setFields("userEnteredFormat.numberFormat")));

            // Format Expenses Values
            int startExpenses = 16 + report.getIncomesByCategory().size();
            int endExpenses = startExpenses + report.getExpensesByCategory().size();
            requests.add(new Request().setRepeatCell(new RepeatCellRequest()
                    .setRange(new GridRange().setSheetId(0).setStartRowIndex(startExpenses).setEndRowIndex(endExpenses).setStartColumnIndex(1).setEndColumnIndex(2))
                    .setCell(new CellData().setUserEnteredFormat(currencyCellFormat))
                    .setFields("userEnteredFormat.numberFormat")));

            // Autofit columns A, B, C
            requests.add(new Request().setAutoResizeDimensions(new AutoResizeDimensionsRequest()
                    .setDimensions(new DimensionRange().setSheetId(0).setDimension("COLUMNS").setStartIndex(0).setEndIndex(3))));

            BatchUpdateSpreadsheetRequest batchRequest = new BatchUpdateSpreadsheetRequest().setRequests(requests);
            sheetsService.spreadsheets().batchUpdate(spreadsheetId, batchRequest).execute();

            return new GoogleSheetsResponseDTO(spreadsheetId, spreadsheetUrl);

        } catch (Exception e) {
            throw new RuntimeException("Falha ao exportar relatório para o Google Planilhas: " + e.getMessage(), e);
        }
    }
}
