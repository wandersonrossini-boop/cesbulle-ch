package com.tesourariacme.api.presentation;

public class GoogleSheetsResponseDTO {
    private String spreadsheetId;
    private String spreadsheetUrl;

    public GoogleSheetsResponseDTO() {
    }

    public GoogleSheetsResponseDTO(String spreadsheetId, String spreadsheetUrl) {
        this.spreadsheetId = spreadsheetId;
        this.spreadsheetUrl = spreadsheetUrl;
    }

    public String getSpreadsheetId() {
        return spreadsheetId;
    }

    public void setSpreadsheetId(String spreadsheetId) {
        this.spreadsheetId = spreadsheetId;
    }

    public String getSpreadsheetUrl() {
        return spreadsheetUrl;
    }

    public void setSpreadsheetUrl(String spreadsheetUrl) {
        this.spreadsheetUrl = spreadsheetUrl;
    }
}
