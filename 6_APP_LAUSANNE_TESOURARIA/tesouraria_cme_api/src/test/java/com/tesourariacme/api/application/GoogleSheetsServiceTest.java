package com.tesourariacme.api.application;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertThrows;

public class GoogleSheetsServiceTest {

    @Test
    public void testThrowsExceptionWhenCredentialsMissing() {
        GoogleSheetsService service = new GoogleSheetsService("", "secretaria@cme.com");
        assertThrows(RuntimeException.class, () -> {
            service.createFinancialReportSheet(null, 8, 2026);
        });
    }
}
