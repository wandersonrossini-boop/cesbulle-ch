package com.tesourariacme.api.presentation;

import com.tesourariacme.api.application.SubmitServiceClosingUseCase;
import com.tesourariacme.api.application.ServiceClosingSessionService;
import com.tesourariacme.api.domain.ServiceClosingSession;
import com.tesourariacme.api.domain.ServiceClosingSessionStatus;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

public class ServiceClosingControllerTest {

    private SubmitServiceClosingUseCase useCase;
    private ServiceClosingSessionService sessionService;
    private com.tesourariacme.api.application.MonthlyPeriodService monthlyPeriodService;
    private ServiceClosingController controller;
    private Authentication authUser1;
    private Authentication authUser2;

    @BeforeEach
    public void setUp() {
        useCase = mock(SubmitServiceClosingUseCase.class);
        sessionService = mock(ServiceClosingSessionService.class);
        monthlyPeriodService = mock(com.tesourariacme.api.application.MonthlyPeriodService.class);
        when(monthlyPeriodService.isPeriodLocked(any(LocalDate.class))).thenReturn(false);
        controller = new ServiceClosingController(useCase, sessionService, new com.fasterxml.jackson.databind.ObjectMapper(), monthlyPeriodService);

        authUser1 = mock(Authentication.class);
        when(authUser1.getName()).thenReturn("user1");

        authUser2 = mock(Authentication.class);
        when(authUser2.getName()).thenReturn("user2");
    }

    @Test
    public void testCreateSessionSuccess() {
        ServiceClosingController.ServiceClosingSessionRequest request = new ServiceClosingController.ServiceClosingSessionRequest();
        request.setServiceDate(LocalDate.of(2026, 8, 19));
        request.setServiceTime(LocalTime.of(19, 0));
        request.setServiceEndTime(LocalTime.of(21, 0));
        request.setServiceType("DOMINGO");

        ServiceClosingSession session = new ServiceClosingSession();
        session.setId(100L);
        session.setServiceDate(request.getServiceDate());
        session.setServiceTime(request.getServiceTime());
        session.setServiceEndTime(request.getServiceEndTime());
        session.setServiceType(request.getServiceType());
        session.setStatus(ServiceClosingSessionStatus.ACTIVE);
        session.setStartedBy("user1");
        session.setStartedAt(LocalDateTime.now());
        session.setExpiresAt(LocalDateTime.now().plusHours(2));

        when(sessionService.getOrCreate(
                request.getServiceDate(),
                request.getServiceTime(),
                request.getServiceEndTime(),
                request.getServiceType(),
                "user1"
        )).thenReturn(session);

        ResponseEntity<?> response = controller.createSession(request, authUser1);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(response.getBody());
        ServiceClosingController.ServiceClosingSessionResponse body = (ServiceClosingController.ServiceClosingSessionResponse) response.getBody();
        assertEquals(100L, body.getId());
        assertEquals("user1", body.getStartedBy());
        assertEquals("ACTIVE", body.getStatus());
    }

    @Test
    public void testSecondUserSameServiceGetsSameID() {
        ServiceClosingController.ServiceClosingSessionRequest request = new ServiceClosingController.ServiceClosingSessionRequest();
        request.setServiceDate(LocalDate.of(2026, 8, 19));
        request.setServiceTime(LocalTime.of(19, 0));
        request.setServiceEndTime(LocalTime.of(21, 0));
        request.setServiceType("DOMINGO");

        ServiceClosingSession existingSession = new ServiceClosingSession();
        existingSession.setId(100L);
        existingSession.setServiceDate(request.getServiceDate());
        existingSession.setServiceTime(request.getServiceTime());
        existingSession.setServiceEndTime(request.getServiceEndTime());
        existingSession.setServiceType(request.getServiceType());
        existingSession.setStatus(ServiceClosingSessionStatus.ACTIVE);
        existingSession.setStartedBy("user1");
        existingSession.setStartedAt(LocalDateTime.now());
        existingSession.setExpiresAt(LocalDateTime.now().plusHours(2));

        when(sessionService.getOrCreate(
                request.getServiceDate(),
                request.getServiceTime(),
                request.getServiceEndTime(),
                request.getServiceType(),
                "user2"
        )).thenReturn(existingSession);

        ResponseEntity<?> response = controller.createSession(request, authUser2);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(response.getBody());
        ServiceClosingController.ServiceClosingSessionResponse body = (ServiceClosingController.ServiceClosingSessionResponse) response.getBody();
        assertEquals(100L, body.getId());
        assertEquals("user1", body.getStartedBy());
    }

    @Test
    public void testFinishedSessionRejectsNewOpening() {
        ServiceClosingController.ServiceClosingSessionRequest request = new ServiceClosingController.ServiceClosingSessionRequest();
        request.setServiceDate(LocalDate.of(2026, 8, 19));
        request.setServiceTime(LocalTime.of(19, 0));
        request.setServiceEndTime(LocalTime.of(21, 0));
        request.setServiceType("DOMINGO");

        when(sessionService.getOrCreate(
                request.getServiceDate(),
                request.getServiceTime(),
                request.getServiceEndTime(),
                request.getServiceType(),
                "user1"
        )).thenThrow(new IllegalArgumentException("O culto para a data e hora informadas já possui um fechamento concluído."));

        ResponseEntity<?> response = controller.createSession(request, authUser1);

        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertEquals("O culto para a data e hora informadas já possui um fechamento concluído.", response.getBody());
    }

    @Test
    public void testGetSessionByIdSuccess() {
        ServiceClosingSession session = new ServiceClosingSession();
        session.setId(100L);
        session.setServiceDate(LocalDate.of(2026, 8, 19));
        session.setServiceTime(LocalTime.of(19, 0));
        session.setServiceEndTime(LocalTime.of(21, 0));
        session.setServiceType("DOMINGO");
        session.setStatus(ServiceClosingSessionStatus.ACTIVE);
        session.setStartedBy("user1");
        session.setStartedAt(LocalDateTime.now());
        session.setExpiresAt(LocalDateTime.now().plusHours(2));

        when(sessionService.findById(100L)).thenReturn(java.util.Optional.of(session));

        ResponseEntity<?> response = controller.getSessionById(100L);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(response.getBody());
        ServiceClosingController.ServiceClosingSessionResponse body = (ServiceClosingController.ServiceClosingSessionResponse) response.getBody();
        assertEquals(100L, body.getId());
    }

    @Test
    public void testGetSessionByIdNotFound() {
        when(sessionService.findById(999L)).thenReturn(java.util.Optional.empty());

        ResponseEntity<?> response = controller.getSessionById(999L);

        assertEquals(HttpStatus.NOT_FOUND, response.getStatusCode());
    }

    @Test
    public void testSessionDraftFlow() {
        Long sessionId = 100L;
        java.util.Map<String, String> draftMap = java.util.Map.of("data", "test-draft-content");
        String draftJson = "{\"data\":\"test-draft-content\"}";

        // 1. Save draft
        doNothing().when(sessionService).saveDraft(eq(sessionId), anyString());
        ResponseEntity<?> postResponse = controller.saveSessionDraft(sessionId, draftMap);
        assertEquals(HttpStatus.OK, postResponse.getStatusCode());
        verify(sessionService, times(1)).saveDraft(eq(sessionId), anyString());

        // 2. Read draft
        when(sessionService.getDraft(sessionId)).thenReturn(java.util.Optional.of(draftJson));
        ResponseEntity<?> getResponse = controller.getSessionDraft(sessionId);
        assertEquals(HttpStatus.OK, getResponse.getStatusCode());
        assertNotNull(getResponse.getBody());

        // 3. Clear draft
        doNothing().when(sessionService).clearDraft(sessionId);
        ResponseEntity<?> deleteResponse = controller.clearSessionDraft(sessionId);
        assertEquals(HttpStatus.OK, deleteResponse.getStatusCode());
        verify(sessionService, times(1)).clearDraft(sessionId);
    }

    @Test
    public void testSessionDraftNotFoundReturns404() {
        Long sessionId = 999L;
        when(sessionService.getDraft(sessionId)).thenReturn(java.util.Optional.empty());

        ResponseEntity<?> getResponse = controller.getSessionDraft(sessionId);
        assertEquals(HttpStatus.NOT_FOUND, getResponse.getStatusCode());
    }

    @Test
    public void testSessionDraftFinishedBlocksChanges() {
        Long sessionId = 100L;
        java.util.Map<String, String> draftMap = java.util.Map.of("data", "test-draft-content");

        // Save blocks
        doThrow(new IllegalStateException("Não é permitido alterar o rascunho de uma sessão finalizada."))
                .when(sessionService).saveDraft(eq(sessionId), anyString());
        ResponseEntity<?> postResponse = controller.saveSessionDraft(sessionId, draftMap);
        assertEquals(HttpStatus.BAD_REQUEST, postResponse.getStatusCode());
        assertEquals("Não é permitido alterar o rascunho de uma sessão finalizada.", postResponse.getBody());

        // Clear blocks
        doThrow(new IllegalStateException("Não é permitido alterar o rascunho de uma sessão finalizada."))
                .when(sessionService).clearDraft(sessionId);
        ResponseEntity<?> deleteResponse = controller.clearSessionDraft(sessionId);
        assertEquals(HttpStatus.BAD_REQUEST, deleteResponse.getStatusCode());
        assertEquals("Não é permitido alterar o rascunho de uma sessão finalizada.", deleteResponse.getBody());
    }
}
