package com.tesourariacme.api.presentation;

import com.tesourariacme.api.config.JwtUtil;
import com.tesourariacme.api.domain.AppUser;
import com.tesourariacme.api.infrastructure.AppUserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

public class AuthControllerTest {

    private JwtUtil jwtUtil;
    private AuthenticationManager authenticationManager;
    private AppUserRepository userRepository;
    private PasswordEncoder passwordEncoder;
    private AuthController authController;

    @BeforeEach
    public void setUp() {
        jwtUtil = mock(JwtUtil.class);
        authenticationManager = mock(AuthenticationManager.class);
        userRepository = mock(AppUserRepository.class);
        passwordEncoder = mock(PasswordEncoder.class);

        when(passwordEncoder.encode(any())).thenAnswer(invocation -> "hash_" + invocation.getArgument(0));

        authController = new AuthController(jwtUtil, authenticationManager, userRepository, passwordEncoder);
    }

    @Test
    public void testRegisterValidDataCreatesPendingTreasurer() {
        when(userRepository.findByUsernameIgnoreCase("novo_tesoureiro")).thenReturn(Optional.empty());

        RegisterRequest request = new RegisterRequest(" Novo_Tesoureiro ", "segredo123", " João da Silva ", "avatar_data");
        ResponseEntity<?> response = authController.register(request);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertTrue(response.getBody().toString().contains("Aguardando aprovação"));

        ArgumentCaptor<AppUser> userCaptor = ArgumentCaptor.forClass(AppUser.class);
        verify(userRepository).save(userCaptor.capture());
        AppUser savedUser = userCaptor.getValue();

        assertEquals("novo_tesoureiro", savedUser.getUsername(), "Username must be normalized to lowercase and trimmed");
        assertEquals("João da Silva", savedUser.getName(), "Name must be trimmed");
        assertEquals("TREASURER", savedUser.getRole(), "Role must strictly be TREASURER for public registration");
        assertFalse(savedUser.isAuthorized(), "Newly registered user must be unauthorized (pending)");
        assertEquals("hash_segredo123", savedUser.getPasswordHash());
        assertEquals("avatar_data", savedUser.getAvatarBase64());
    }

    @Test
    public void testRegisterBlankUsernameReturnsBadRequest() {
        RegisterRequest request = new RegisterRequest("   ", "segredo123", "João", null);
        ResponseEntity<?> response = authController.register(request);

        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertTrue(response.getBody().toString().contains("Nome de usuário é obrigatório"));
        verify(userRepository, never()).save(any());
    }

    @Test
    public void testRegisterBlankNameReturnsBadRequest() {
        RegisterRequest request = new RegisterRequest("usuario", "segredo123", "   ", null);
        ResponseEntity<?> response = authController.register(request);

        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertTrue(response.getBody().toString().contains("Nome completo é obrigatório"));
        verify(userRepository, never()).save(any());
    }

    @Test
    public void testRegisterShortPasswordReturnsBadRequest() {
        RegisterRequest request = new RegisterRequest("usuario", "12345", "João", null);
        ResponseEntity<?> response = authController.register(request);

        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertTrue(response.getBody().toString().contains("no mínimo 6 caracteres"));
        verify(userRepository, never()).save(any());
    }

    @Test
    public void testRegisterDuplicateUsernameCaseInsensitiveReturnsBadRequest() {
        when(userRepository.findByUsernameIgnoreCase("pastor")).thenReturn(Optional.of(new AppUser()));

        RegisterRequest request = new RegisterRequest("Pastor", "segredo123", "Pastor Fake", null);
        ResponseEntity<?> response = authController.register(request);

        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertTrue(response.getBody().toString().contains("Usuário já existe"));
        verify(userRepository, never()).save(any());
    }

    @Test
    public void testLoginDisabledUserReturnsForbiddenWithout500() {
        when(authenticationManager.authenticate(any(UsernamePasswordAuthenticationToken.class)))
                .thenThrow(new DisabledException("Usuário pendente de autorização."));

        LoginRequest request = new LoginRequest("tesoureiro_pendente", "senha123");
        ResponseEntity<?> response = authController.login(request);

        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        assertTrue(response.getBody().toString().contains("Usuário aguardando aprovação"));
    }

    @Test
    public void testLoginInvalidCredentialsReturnsUnauthorized() {
        when(authenticationManager.authenticate(any(UsernamePasswordAuthenticationToken.class)))
                .thenThrow(new BadCredentialsException("Credenciais inválidas"));

        LoginRequest request = new LoginRequest("pastor", "senha_errada");
        ResponseEntity<?> response = authController.login(request);

        assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
    }

    @Test
    public void testLoginSuccessReturnsToken() {
        Authentication auth = mock(Authentication.class);
        when(authenticationManager.authenticate(any(UsernamePasswordAuthenticationToken.class)))
                .thenReturn(auth);
        when(jwtUtil.generateToken("pastor")).thenReturn("jwt.token.mock");

        LoginRequest request = new LoginRequest(" Pastor ", "senha_certa");
        ResponseEntity<?> response = authController.login(request);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        LoginResponse loginResp = (LoginResponse) response.getBody();
        assertNotNull(loginResp);
        assertEquals("jwt.token.mock", loginResp.getToken());
    }
}
