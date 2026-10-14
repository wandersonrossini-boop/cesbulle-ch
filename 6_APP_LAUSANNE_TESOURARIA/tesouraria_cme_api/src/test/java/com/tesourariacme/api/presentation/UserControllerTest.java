package com.tesourariacme.api.presentation;

import com.tesourariacme.api.domain.AppUser;
import com.tesourariacme.api.infrastructure.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

public class UserControllerTest {

    private AppUserRepository userRepository;
    private PasswordEncoder passwordEncoder;
    private ExpenseRepository expenseRepository;
    private ExpenseAttachmentRepository expenseAttachmentRepository;
    private ServiceClosingRepository serviceClosingRepository;
    private MemberRepository memberRepository;
    private UserController userController;

    private Authentication adminAuth;
    private Authentication treasurerAuth;

    @BeforeEach
    public void setUp() {
        userRepository = mock(AppUserRepository.class);
        passwordEncoder = mock(PasswordEncoder.class);
        expenseRepository = mock(ExpenseRepository.class);
        expenseAttachmentRepository = mock(ExpenseAttachmentRepository.class);
        serviceClosingRepository = mock(ServiceClosingRepository.class);
        memberRepository = mock(MemberRepository.class);

        userController = new UserController(
                userRepository,
                passwordEncoder,
                expenseRepository,
                expenseAttachmentRepository,
                serviceClosingRepository,
                memberRepository
        );

        adminAuth = mock(Authentication.class);
        when(adminAuth.getName()).thenReturn("pastor");
        doReturn(List.of(new SimpleGrantedAuthority("ROLE_ADMIN"))).when(adminAuth).getAuthorities();

        treasurerAuth = mock(Authentication.class);
        when(treasurerAuth.getName()).thenReturn("tesoureiro");
        doReturn(List.of(new SimpleGrantedAuthority("ROLE_TREASURER"))).when(treasurerAuth).getAuthorities();
    }

    @Test
    public void testResetDatabaseForbiddenForNonAdmin() {
        ResponseEntity<?> response = userController.resetDatabase(Map.of("confirmToken", "CONFIRMAR_RESET_TOTAL"), treasurerAuth);
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        verifyNoInteractions(expenseRepository);
        verifyNoInteractions(serviceClosingRepository);
    }

    @Test
    public void testResetDatabaseBlockedByDefaultEvenForAdmin() {
        // By default allowDatabaseReset is false
        ResponseEntity<?> response = userController.resetDatabase(Map.of("confirmToken", "CONFIRMAR_RESET_TOTAL"), adminAuth);
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        assertTrue(response.getBody().toString().contains("desativado"));
        verifyNoInteractions(expenseRepository);
        verifyNoInteractions(serviceClosingRepository);
    }

    @Test
    public void testGetAllUsersForbiddenForTreasurer() {
        ResponseEntity<?> response = userController.getAllUsers(treasurerAuth);
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
    }

    @Test
    public void testGetAllUsersAllowedForAdmin() {
        when(userRepository.findAll()).thenReturn(List.of(new AppUser()));
        ResponseEntity<?> response = userController.getAllUsers(adminAuth);
        assertEquals(HttpStatus.OK, response.getStatusCode());
    }
}
