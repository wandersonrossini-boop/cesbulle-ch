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

    @Test
    public void testRevokeUserBlockedForPastorAccount() {
        AppUser pastor = new AppUser();
        pastor.setId(1L);
        pastor.setUsername("pastor");
        pastor.setRole("ADMIN");
        pastor.setAuthorized(true);

        when(userRepository.findById(1L)).thenReturn(Optional.of(pastor));

        ResponseEntity<?> response = userController.revokeUser(1L, adminAuth);
        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertTrue(response.getBody().toString().contains("não pode ser revogada"));
        verify(userRepository, never()).save(any());
    }

    @Test
    public void testRevokeUserBlockedForAdminRole() {
        AppUser adminUser = new AppUser();
        adminUser.setId(2L);
        adminUser.setUsername("outro_admin");
        adminUser.setRole("ADMIN");
        adminUser.setAuthorized(true);

        when(userRepository.findById(2L)).thenReturn(Optional.of(adminUser));

        ResponseEntity<?> response = userController.revokeUser(2L, adminAuth);
        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertTrue(response.getBody().toString().contains("não pode ser revogada"));
        verify(userRepository, never()).save(any());
    }

    @Test
    public void testDeleteUserBlockedForPastorAccount() {
        AppUser pastor = new AppUser();
        pastor.setId(1L);
        pastor.setUsername("pastor");
        pastor.setRole("ADMIN");

        when(userRepository.findById(1L)).thenReturn(Optional.of(pastor));

        ResponseEntity<?> response = userController.deleteUser(1L, adminAuth);
        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertTrue(response.getBody().toString().contains("não pode ser excluída"));
        verify(userRepository, never()).delete(any());
    }

    @Test
    public void testDeleteUserBlockedForAdminRole() {
        AppUser adminUser = new AppUser();
        adminUser.setId(2L);
        adminUser.setUsername("outro_admin");
        adminUser.setRole("ADMIN");

        when(userRepository.findById(2L)).thenReturn(Optional.of(adminUser));

        ResponseEntity<?> response = userController.deleteUser(2L, adminAuth);
        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertTrue(response.getBody().toString().contains("não pode ser excluída"));
        verify(userRepository, never()).delete(any());
    }

    @Test
    public void testRevokeUserSuccessForTreasurer() {
        AppUser treasurer = new AppUser();
        treasurer.setId(3L);
        treasurer.setUsername("tesoureiro_joao");
        treasurer.setRole("TREASURER");
        treasurer.setAuthorized(true);

        when(userRepository.findById(3L)).thenReturn(Optional.of(treasurer));

        ResponseEntity<?> response = userController.revokeUser(3L, adminAuth);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertFalse(treasurer.isAuthorized());
        verify(userRepository).save(treasurer);
    }

    @Test
    public void testDeleteUserSuccessForTreasurer() {
        AppUser treasurer = new AppUser();
        treasurer.setId(3L);
        treasurer.setUsername("tesoureiro_joao");
        treasurer.setRole("TREASURER");

        when(userRepository.findById(3L)).thenReturn(Optional.of(treasurer));

        ResponseEntity<?> response = userController.deleteUser(3L, adminAuth);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        verify(userRepository).delete(treasurer);
    }

    @Test
    public void testRevokeUserForbiddenForTreasurerAuth() {
        ResponseEntity<?> response = userController.revokeUser(3L, treasurerAuth);
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        verify(userRepository, never()).findById(any());
    }

    @Test
    public void testDeleteUserForbiddenForTreasurerAuth() {
        ResponseEntity<?> response = userController.deleteUser(3L, treasurerAuth);
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        verify(userRepository, never()).findById(any());
    }
}
