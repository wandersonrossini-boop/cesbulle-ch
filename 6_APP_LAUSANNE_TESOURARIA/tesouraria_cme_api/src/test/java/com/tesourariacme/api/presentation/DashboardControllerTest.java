package com.tesourariacme.api.presentation;

import com.tesourariacme.api.application.MonthlyPeriodService;
import com.tesourariacme.api.domain.Expense;
import com.tesourariacme.api.domain.ServiceClosing;
import com.tesourariacme.api.infrastructure.ExpenseRepository;
import com.tesourariacme.api.infrastructure.ServiceClosingRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

public class DashboardControllerTest {

    private ServiceClosingRepository serviceClosingRepository;
    private ExpenseRepository expenseRepository;
    private MonthlyPeriodService monthlyPeriodService;
    private DashboardController controller;
    private Authentication treasurerAuth;
    private Authentication readOnlyAuth;

    @BeforeEach
    public void setUp() {
        serviceClosingRepository = mock(ServiceClosingRepository.class);
        expenseRepository = mock(ExpenseRepository.class);
        monthlyPeriodService = mock(MonthlyPeriodService.class);
        controller = new DashboardController(serviceClosingRepository, expenseRepository, monthlyPeriodService);

        treasurerAuth = mock(Authentication.class);
        when(treasurerAuth.getName()).thenReturn("tesoureiro");
        doReturn(List.of(new SimpleGrantedAuthority("ROLE_TREASURER"))).when(treasurerAuth).getAuthorities();

        readOnlyAuth = mock(Authentication.class);
        when(readOnlyAuth.getName()).thenReturn("readOnly");
        doReturn(List.of(new SimpleGrantedAuthority("ROLE_USER"))).when(readOnlyAuth).getAuthorities();
    }

    @Test
    public void testGetDashboardSummaryAuthorized() {
        LocalDate start = LocalDate.now().withDayOfMonth(1);
        LocalDate end = LocalDate.now().withDayOfMonth(LocalDate.now().lengthOfMonth());

        ServiceClosing closing = new ServiceClosing();
        closing.setTotalDizimos(BigDecimal.valueOf(100.0));
        closing.setTotalOfertas(BigDecimal.valueOf(50.0));
        closing.setTotalVotos(BigDecimal.valueOf(20.0));
        when(serviceClosingRepository.findByServiceDateBetween(start, end)).thenReturn(List.of(closing));

        Expense expense = new Expense();
        expense.setAmount(BigDecimal.valueOf(300.0));
        expense.setStatus("PENDING");
        when(expenseRepository.findByStatus("PENDING")).thenReturn(List.of(expense));

        when(monthlyPeriodService.isPeriodLocked(anyInt(), anyInt())).thenReturn(false);

        ResponseEntity<?> response = controller.getDashboardSummary(treasurerAuth);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        
        DashboardSummaryResponse body = (DashboardSummaryResponse) response.getBody();
        assertNotNull(body);
        assertEquals(BigDecimal.valueOf(170.0), body.getCurrentMonthInputs());
        assertEquals(1, body.getPendingExpensesCount());
        assertEquals(BigDecimal.valueOf(300.0), body.getPendingExpensesTotal());
    }

    @Test
    public void testGetDashboardSummaryForbidden() {
        ResponseEntity<?> response = controller.getDashboardSummary(readOnlyAuth);
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
    }
}
