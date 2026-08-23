package com.tesourariacme.api.application;

import com.tesourariacme.api.domain.Expense;
import com.tesourariacme.api.domain.ServiceClosing;
import com.tesourariacme.api.infrastructure.ExpenseRepository;
import com.tesourariacme.api.infrastructure.ServiceClosingRepository;
import com.tesourariacme.api.presentation.FinancialReportDTO;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class FinancialReportService {

    private final ServiceClosingRepository serviceClosingRepository;
    private final ExpenseRepository expenseRepository;
    private final com.tesourariacme.api.application.MonthlyPeriodService monthlyPeriodService;

    public FinancialReportService(
            ServiceClosingRepository serviceClosingRepository,
            ExpenseRepository expenseRepository,
            com.tesourariacme.api.application.MonthlyPeriodService monthlyPeriodService) {
        this.serviceClosingRepository = serviceClosingRepository;
        this.expenseRepository = expenseRepository;
        this.monthlyPeriodService = monthlyPeriodService;
    }

    public FinancialReportDTO generateMonthlyReport(int month, int year) {
        if (month < 1 || month > 12) {
            throw new IllegalArgumentException("Mês inválido (deve ser entre 1 e 12).");
        }
        if (year < 2000) {
            throw new IllegalArgumentException("Ano inválido.");
        }

        LocalDate startDate = LocalDate.of(year, month, 1);
        LocalDate endDate = startDate.withDayOfMonth(startDate.lengthOfMonth());

        // 1. Incomes from ServiceClosings
        List<ServiceClosing> closings = serviceClosingRepository.findByServiceDateBetween(startDate, endDate);

        BigDecimal sumDizimos = BigDecimal.ZERO;
        long countDizimos = 0;
        BigDecimal sumOfertas = BigDecimal.ZERO;
        long countOfertas = 0;
        BigDecimal sumVotos = BigDecimal.ZERO;
        long countVotos = 0;

        for (ServiceClosing c : closings) {
            BigDecimal diz = c.getTotalDizimos() != null ? c.getTotalDizimos() : BigDecimal.ZERO;
            BigDecimal ofe = c.getTotalOfertas() != null ? c.getTotalOfertas() : BigDecimal.ZERO;
            BigDecimal vot = c.getTotalVotos() != null ? c.getTotalVotos() : BigDecimal.ZERO;

            if (diz.compareTo(BigDecimal.ZERO) > 0) {
                sumDizimos = sumDizimos.add(diz);
                countDizimos++;
            }
            if (ofe.compareTo(BigDecimal.ZERO) > 0) {
                sumOfertas = sumOfertas.add(ofe);
                countOfertas++;
            }
            if (vot.compareTo(BigDecimal.ZERO) > 0) {
                sumVotos = sumVotos.add(vot);
                countVotos++;
            }
        }

        List<FinancialReportDTO.CategorySummary> incomesList = new ArrayList<>();
        incomesList.add(new FinancialReportDTO.CategorySummary("Dízimos Nominais", sumDizimos, countDizimos));
        incomesList.add(new FinancialReportDTO.CategorySummary("Ofertas Gerais", sumOfertas, countOfertas));
        incomesList.add(new FinancialReportDTO.CategorySummary("Votos / Missões", sumVotos, countVotos));

        BigDecimal totalIncomes = sumDizimos.add(sumOfertas).add(sumVotos);

        // 2. Expenses with status APPROVED or PAID
        List<Expense> expenses = expenseRepository.findByExpenseDateBetweenAndStatusIn(
                startDate, endDate, List.of("APPROVED", "PAID"));

        BigDecimal totalExpenses = BigDecimal.ZERO;
        Map<String, List<Expense>> groupedExpenses = expenses.stream()
                .collect(Collectors.groupingBy(e -> e.getCategory() != null ? e.getCategory() : "Outros"));

        List<FinancialReportDTO.CategorySummary> expensesList = new ArrayList<>();
        for (Map.Entry<String, List<Expense>> entry : groupedExpenses.entrySet()) {
            BigDecimal categorySum = entry.getValue().stream()
                    .map(Expense::getAmount)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            totalExpenses = totalExpenses.add(categorySum);
            expensesList.add(new FinancialReportDTO.CategorySummary(entry.getKey(), categorySum, entry.getValue().size()));
        }

        // 3. Totals
        BigDecimal netBalance = totalIncomes.subtract(totalExpenses);

        FinancialReportDTO.Period period = new FinancialReportDTO.Period(month, year);
        FinancialReportDTO.Summary summary = new FinancialReportDTO.Summary(totalIncomes, totalExpenses, netBalance);
        FinancialReportDTO.Metadata metadata = new FinancialReportDTO.Metadata(LocalDateTime.now(), "CHF", "OFFICIAL");

        return new FinancialReportDTO(period, summary, incomesList, expensesList, metadata);
    }

    public String generateMonthlyReportCsv(int month, int year) {
        FinancialReportDTO report = generateMonthlyReport(month, year);
        StringBuilder sb = new StringBuilder();
        
        sb.append("RELATORIO FINANCEIRO MENSAL - CME LAUSANNE\n");
        sb.append("Periodo;").append(String.format("%02d/%d", month, year)).append("\n");
        sb.append("Status;").append(report.getMetadata().getStatus()).append("\n");
        sb.append("Moeda;").append(report.getMetadata().getCurrency()).append("\n");
        sb.append("Gerado em;").append(report.getMetadata().getGeneratedAt().toString()).append("\n\n");

        sb.append("RESUMO\n");
        sb.append("Total de Entradas;Total de Saidas;Saldo Liquido\n");
        sb.append(report.getSummary().getTotalIncomes()).append(";")
          .append(report.getSummary().getTotalExpenses()).append(";")
          .append(report.getSummary().getNetBalance()).append("\n\n");

        sb.append("DETALHAMENTO DE ENTRADAS\n");
        sb.append("Categoria/Tipo;Valor;Quantidade\n");
        for (FinancialReportDTO.CategorySummary inc : report.getIncomesByCategory()) {
            sb.append(inc.getCategory()).append(";")
              .append(inc.getTotal()).append(";")
              .append(inc.getCount()).append("\n");
        }
        sb.append("\n");

        sb.append("DETALHAMENTO DE SAIDAS\n");
        sb.append("Categoria;Valor;Quantidade\n");
        for (FinancialReportDTO.CategorySummary exp : report.getExpensesByCategory()) {
            sb.append(exp.getCategory()).append(";")
              .append(exp.getTotal()).append(";")
              .append(exp.getCount()).append("\n");
        }

        return sb.toString();
    }

    public byte[] generateMonthlyReportPdf(int month, int year) {
        FinancialReportDTO report = generateMonthlyReport(month, year);
        String status = monthlyPeriodService.getPeriodStatus(year, month);

        java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
        com.lowagie.text.Document document = new com.lowagie.text.Document(com.lowagie.text.PageSize.A4, 50, 50, 50, 50);

        try {
            com.lowagie.text.pdf.PdfWriter.getInstance(document, out);
            document.open();

            // Font Styles
            com.lowagie.text.Font titleFont = com.lowagie.text.FontFactory.getFont(com.lowagie.text.FontFactory.HELVETICA_BOLD, 16);
            com.lowagie.text.Font sectionFont = com.lowagie.text.FontFactory.getFont(com.lowagie.text.FontFactory.HELVETICA_BOLD, 12);
            com.lowagie.text.Font bodyFont = com.lowagie.text.FontFactory.getFont(com.lowagie.text.FontFactory.HELVETICA, 10);
            com.lowagie.text.Font boldFont = com.lowagie.text.FontFactory.getFont(com.lowagie.text.FontFactory.HELVETICA_BOLD, 10);

            // 1. Header
            com.lowagie.text.Paragraph header = new com.lowagie.text.Paragraph();
            header.add(new com.lowagie.text.Paragraph("CENTRE MISSIONNAIRE EVANGELIQUE (CME) - LAUSANNE", sectionFont));
            header.add(new com.lowagie.text.Paragraph("Chemin de la Colline 7, 1007 Lausanne\nAssociation religieuse exoneree d'impots", bodyFont));
            header.setSpacingAfter(20);
            document.add(header);

            // 2. Title
            com.lowagie.text.Paragraph title = new com.lowagie.text.Paragraph("RAPPORT FINANCIER MENSUEL - " + String.format("%02d/%d", month, year), titleFont);
            title.setAlignment(com.lowagie.text.Element.ALIGN_CENTER);
            title.setSpacingAfter(15);
            document.add(title);

            // 3. Status block
            String statusLabel = "LOCKED".equals(status) ? "LOCKED / FECHADO PARA AUDITORIA" : "OPEN / ABERTO";
            com.lowagie.text.Paragraph statusParagraph = new com.lowagie.text.Paragraph(
                "Status da Competência: " + statusLabel + "\nData de Emissão: " + LocalDate.now().toString(), bodyFont
            );
            statusParagraph.setSpacingAfter(20);
            document.add(statusParagraph);

            // 4. Balanço Sintético
            com.lowagie.text.pdf.PdfPTable kpiTable = new com.lowagie.text.pdf.PdfPTable(3);
            kpiTable.setWidthPercentage(100);
            kpiTable.setSpacingAfter(20);

            kpiTable.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph("TOTAL ENTRADAS (CHF)", boldFont)));
            kpiTable.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph("TOTAL SAÍDAS (CHF)", boldFont)));
            kpiTable.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph("SALDO LÍQUIDO (CHF)", boldFont)));

            kpiTable.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph(report.getSummary().getTotalIncomes().toString(), bodyFont)));
            kpiTable.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph(report.getSummary().getTotalExpenses().toString(), bodyFont)));
            kpiTable.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph(report.getSummary().getNetBalance().toString(), bodyFont)));

            document.add(kpiTable);

            // 5. Entradas Detalhadas
            com.lowagie.text.Paragraph incomeHeader = new com.lowagie.text.Paragraph("DETALHAMENTO DE ENTRADAS", sectionFont);
            incomeHeader.setSpacingAfter(10);
            document.add(incomeHeader);

            com.lowagie.text.pdf.PdfPTable incomeTable = new com.lowagie.text.pdf.PdfPTable(3);
            incomeTable.setWidthPercentage(100);
            incomeTable.setWidths(new float[]{2.0f, 1.5f, 1.5f});
            incomeTable.setSpacingAfter(20);

            incomeTable.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph("CATEGORIA", boldFont)));
            incomeTable.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph("QUANTIDADE", boldFont)));
            incomeTable.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph("VALOR (CHF)", boldFont)));

            for (FinancialReportDTO.CategorySummary inc : report.getIncomesByCategory()) {
                incomeTable.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph(inc.getCategory(), bodyFont)));
                incomeTable.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph(String.valueOf(inc.getCount()), bodyFont)));
                incomeTable.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph(inc.getTotal().toString(), bodyFont)));
            }
            document.add(incomeTable);

            // 6. Saídas Detalhadas
            com.lowagie.text.Paragraph expenseHeader = new com.lowagie.text.Paragraph("DETALHAMENTO DE SAÍDAS (APROVADAS / PAGAS)", sectionFont);
            expenseHeader.setSpacingAfter(10);
            document.add(expenseHeader);

            com.lowagie.text.pdf.PdfPTable expenseTable = new com.lowagie.text.pdf.PdfPTable(3);
            expenseTable.setWidthPercentage(100);
            expenseTable.setWidths(new float[]{2.0f, 1.5f, 1.5f});
            expenseTable.setSpacingAfter(30);

            expenseTable.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph("CATEGORIA", boldFont)));
            expenseTable.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph("QUANTIDADE", boldFont)));
            expenseTable.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph("VALOR (CHF)", boldFont)));

            for (FinancialReportDTO.CategorySummary exp : report.getExpensesByCategory()) {
                expenseTable.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph(exp.getCategory(), bodyFont)));
                expenseTable.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph(String.valueOf(exp.getCount()), bodyFont)));
                expenseTable.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph(exp.getTotal().toString(), bodyFont)));
            }
            document.add(expenseTable);

            // 7. Signature area
            com.lowagie.text.pdf.PdfPTable signTable = new com.lowagie.text.pdf.PdfPTable(2);
            signTable.setWidthPercentage(100);
            signTable.setWidths(new float[]{1.0f, 1.0f});
            signTable.setSpacingBefore(30);

            com.lowagie.text.pdf.PdfPCell pastorCell = new com.lowagie.text.pdf.PdfPCell();
            pastorCell.setBorder(com.lowagie.text.Rectangle.NO_BORDER);
            pastorCell.addElement(new com.lowagie.text.Paragraph("___________________________________\nPastor Presidente\nVisto", bodyFont));
            signTable.addCell(pastorCell);

            com.lowagie.text.pdf.PdfPCell treasurerCell = new com.lowagie.text.pdf.PdfPCell();
            treasurerCell.setBorder(com.lowagie.text.Rectangle.NO_BORDER);
            treasurerCell.addElement(new com.lowagie.text.Paragraph("___________________________________\n1º Tesoureiro\nAssinatura", bodyFont));
            signTable.addCell(treasurerCell);

            document.add(signTable);

            document.close();
        } catch (Exception e) {
            throw new RuntimeException("Erro ao gerar PDF do relatório contábil: " + e.getMessage(), e);
        }

        return out.toByteArray();
    }
}
