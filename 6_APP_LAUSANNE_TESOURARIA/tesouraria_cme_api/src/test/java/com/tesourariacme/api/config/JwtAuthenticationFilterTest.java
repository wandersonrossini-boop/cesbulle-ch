package com.tesourariacme.api.config;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UsernameNotFoundException;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

public class JwtAuthenticationFilterTest {

    private JwtUtil jwtUtil;
    private CustomUserDetailsService customUserDetailsService;
    private JwtAuthenticationFilter filter;

    @BeforeEach
    public void setUp() {
        SecurityContextHolder.clearContext();
        jwtUtil = mock(JwtUtil.class);
        customUserDetailsService = mock(CustomUserDetailsService.class);
        filter = new JwtAuthenticationFilter(jwtUtil, customUserDetailsService);
    }

    @AfterEach
    public void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    public void testFilterHandlesDisabledExceptionCleanlyAs403Without500() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader("Authorization", "Bearer valid.token.here");
        MockHttpServletResponse response = new MockHttpServletResponse();
        MockFilterChain filterChain = new MockFilterChain();

        when(jwtUtil.validateToken("valid.token.here")).thenReturn(true);
        when(jwtUtil.getUsernameFromToken("valid.token.here")).thenReturn("tesoureiro_revogado");
        when(customUserDetailsService.loadUserByUsername("tesoureiro_revogado"))
                .thenThrow(new DisabledException("Usuário pendente ou revogado."));

        filter.doFilter(request, response, filterChain);

        assertEquals(403, response.getStatus());
        assertTrue(response.getContentAsString().contains("Usuário pendente ou acesso revogado"));
        assertNull(SecurityContextHolder.getContext().getAuthentication());
    }

    @Test
    public void testFilterHandlesUsernameNotFoundExceptionCleanlyAs401Without500() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader("Authorization", "Bearer valid.token.here");
        MockHttpServletResponse response = new MockHttpServletResponse();
        MockFilterChain filterChain = new MockFilterChain();

        when(jwtUtil.validateToken("valid.token.here")).thenReturn(true);
        when(jwtUtil.getUsernameFromToken("valid.token.here")).thenReturn("usuario_inexistente");
        when(customUserDetailsService.loadUserByUsername("usuario_inexistente"))
                .thenThrow(new UsernameNotFoundException("Usuário não encontrado."));

        filter.doFilter(request, response, filterChain);

        assertEquals(401, response.getStatus());
        assertTrue(response.getContentAsString().contains("Usuário não encontrado"));
        assertNull(SecurityContextHolder.getContext().getAuthentication());
    }

    @Test
    public void testFilterAuthenticatesAuthorizedUserSuccessfully() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader("Authorization", "Bearer valid.token.here");
        MockHttpServletResponse response = new MockHttpServletResponse();
        MockFilterChain filterChain = new MockFilterChain();

        when(jwtUtil.validateToken("valid.token.here")).thenReturn(true);
        when(jwtUtil.getUsernameFromToken("valid.token.here")).thenReturn("pastor");

        UserDetails userDetails = new User("pastor", "hash", List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
        when(customUserDetailsService.loadUserByUsername("pastor")).thenReturn(userDetails);

        filter.doFilter(request, response, filterChain);

        assertEquals(200, response.getStatus());
        assertNotNull(SecurityContextHolder.getContext().getAuthentication());
        assertEquals("pastor", SecurityContextHolder.getContext().getAuthentication().getName());
    }
}
