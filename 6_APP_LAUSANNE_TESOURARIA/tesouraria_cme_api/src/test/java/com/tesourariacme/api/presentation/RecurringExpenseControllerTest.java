package com.tesourariacme.api.presentation;

import com.tesourariacme.api.domain.RecurringExpense;
import com.tesourariacme.api.infrastructure.RecurringExpenseRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

public class RecurringExpenseControllerTest {

    private RecurringExpenseRepository repository;
    private RecurringExpenseController controller;
    private Authentication treasurerAuth;
    private Authentication readOnlyAuth;

    @BeforeEach
    public void setUp() {
        repository = mock(RecurringExpenseRepository.class);
        controller = new RecurringExpenseController(repository);

        treasurerAuth = mock(Authentication.class);
        when(treasurerAuth.getName()).thenReturn("tesoureiro");
        doReturn(List.of(new SimpleGrantedAuthority("ROLE_TREASURER"))).when(treasurerAuth).getAuthorities();

        readOnlyAuth = mock(Authentication.class);
        when(readOnlyAuth.getName()).thenReturn("readOnly");
        doReturn(List.of(new SimpleGrantedAuthority("ROLE_USER"))).when(readOnlyAuth).getAuthorities();
    }

    @Test
    public void testGetAllAuthorized() {
        when(repository.findAll()).thenReturn(List.of(new RecurringExpense()));
        ResponseEntity<?> response = controller.getAll(treasurerAuth);
        assertEquals(HttpStatus.OK, response.getStatusCode());
    }

    @Test
    public void testGetAllForbidden() {
        ResponseEntity<?> response = controller.getAll(readOnlyAuth);
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
    }

    @Test
    public void testCreateSuccess() {
        RecurringExpense entity = new RecurringExpense();
        entity.setDescription("Recorrente");
        when(repository.save(any(RecurringExpense.class))).thenAnswer(i -> i.getArgument(0));

        ResponseEntity<?> response = controller.create(entity, treasurerAuth);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        verify(repository, times(1)).save(entity);
    }

    @Test
    public void testUpdateSuccess() {
        RecurringExpense entity = new RecurringExpense();
        entity.setId(1L);
        entity.setDescription("Original");
        when(repository.findById(1L)).thenReturn(Optional.of(entity));
        when(repository.save(any(RecurringExpense.class))).thenAnswer(i -> i.getArgument(0));

        RecurringExpense updated = new RecurringExpense();
        updated.setDescription("Updated");
        updated.setAmount(new BigDecimal("200.00"));
        updated.setCategory("Utilidades");
        updated.setDueDayOfMonth(15);
        updated.setActive(false);

        ResponseEntity<?> response = controller.update(1L, updated, treasurerAuth);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals("Updated", entity.getDescription());
        assertFalse(entity.isActive());
    }

    @Test
    public void testDeleteSuccess() {
        when(repository.existsById(1L)).thenReturn(true);
        ResponseEntity<?> response = controller.delete(1L, treasurerAuth);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        verify(repository, times(1)).deleteById(1L);
    }
}
