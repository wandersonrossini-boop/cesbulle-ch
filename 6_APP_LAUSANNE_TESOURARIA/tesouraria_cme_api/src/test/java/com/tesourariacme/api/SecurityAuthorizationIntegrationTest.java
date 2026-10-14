package com.tesourariacme.api;

import com.tesourariacme.api.config.JwtUtil;
import com.tesourariacme.api.domain.AppUser;
import com.tesourariacme.api.infrastructure.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Optional;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@org.springframework.boot.autoconfigure.EnableAutoConfiguration(
    exclude = {
        org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration.class,
        org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration.class,
        org.springframework.boot.autoconfigure.jdbc.DataSourceTransactionManagerAutoConfiguration.class
    }
)
public class SecurityAuthorizationIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtUtil jwtUtil;

    @MockBean
    private ContributorRepository contributorRepository;

    @MockBean
    private ServiceClosingRepository serviceClosingRepository;

    @MockBean
    private ExpenseRepository expenseRepository;

    @MockBean
    private MonthlyPeriodRepository monthlyPeriodRepository;

    @MockBean
    private AuditLogRepository auditLogRepository;

    @MockBean
    private MemberRepository memberRepository;

    @MockBean
    private EnvelopeRepository envelopeRepository;

    @MockBean
    private ExpenseAttachmentRepository expenseAttachmentRepository;

    @MockBean
    private ServiceClosingAttachmentRepository serviceClosingAttachmentRepository;

    @MockBean
    private StorageService storageService;

    @MockBean
    private RecurringExpenseRepository recurringExpenseRepository;

    @MockBean
    private ServiceClosingSessionRepository serviceClosingSessionRepository;

    @MockBean
    private ServiceScheduleRepository serviceScheduleRepository;

    @MockBean
    private AppUserRepository appUserRepository;

    @MockBean
    private javax.sql.DataSource dataSource;

    private String adminToken;
    private String treasurerToken;
    private String revokedToken;

    @BeforeEach
    public void setUp() {
        AppUser adminUser = new AppUser();
        adminUser.setUsername("pastor");
        adminUser.setRole("ADMIN");
        adminUser.setAuthorized(true);
        adminUser.setPasswordHash("$2a$10$hashedpwd");

        AppUser treasurerUser = new AppUser();
        treasurerUser.setUsername("tesoureiro");
        treasurerUser.setRole("TREASURER");
        treasurerUser.setAuthorized(true);
        treasurerUser.setPasswordHash("$2a$10$hashedpwd");

        AppUser revokedUser = new AppUser();
        revokedUser.setUsername("tesoureiro_revogado");
        revokedUser.setRole("TREASURER");
        revokedUser.setAuthorized(false);
        revokedUser.setPasswordHash("$2a$10$hashedpwd");

        when(appUserRepository.findByUsernameIgnoreCase("pastor")).thenReturn(Optional.of(adminUser));
        when(appUserRepository.findByUsernameIgnoreCase("tesoureiro")).thenReturn(Optional.of(treasurerUser));
        when(appUserRepository.findByUsernameIgnoreCase("tesoureiro_revogado")).thenReturn(Optional.of(revokedUser));

        adminToken = jwtUtil.generateToken("pastor");
        treasurerToken = jwtUtil.generateToken("tesoureiro");
        revokedToken = jwtUtil.generateToken("tesoureiro_revogado");
    }

    @Test
    public void testUnauthenticatedAccessToUsersReturnsUnauthorized() throws Exception {
        mockMvc.perform(get("/api/users"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    public void testRevokedUserGetsCleanForbiddenWithout500() throws Exception {
        mockMvc.perform(get("/api/users")
                .header("Authorization", "Bearer " + revokedToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error").value("Usuário pendente ou acesso revogado pelo administrador."));
    }

    @Test
    public void testTreasurerForbiddenFromUserManagement() throws Exception {
        mockMvc.perform(get("/api/users")
                .header("Authorization", "Bearer " + treasurerToken))
                .andExpect(status().isForbidden());
    }

    @Test
    public void testAdminAllowedAccessToUserManagement() throws Exception {
        mockMvc.perform(get("/api/users")
                .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk());
    }

    @Test
    public void testAdminForbiddenFromSubmittingServiceClosing() throws Exception {
        mockMvc.perform(post("/api/fechamento-culto")
                .header("Authorization", "Bearer " + adminToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
                .andExpect(status().isForbidden());
    }

    @Test
    public void testAdminForbiddenFromCreatingExpense() throws Exception {
        mockMvc.perform(post("/api/despesas")
                .header("Authorization", "Bearer " + adminToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
                .andExpect(status().isForbidden());
    }

    @Test
    public void testTreasurerAllowedPostToServiceClosingSecurityCheck() throws Exception {
        // Must pass security filter (not 401, not 403)
        mockMvc.perform(post("/api/fechamento-culto")
                .header("Authorization", "Bearer " + treasurerToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
                .andExpect(result -> {
                    int status = result.getResponse().getStatus();
                    org.junit.jupiter.api.Assertions.assertNotEquals(401, status);
                    org.junit.jupiter.api.Assertions.assertNotEquals(403, status);
                });
    }

    @Test
    public void testTreasurerAllowedPostToExpensesSecurityCheck() throws Exception {
        // Must pass security filter (not 401, not 403)
        mockMvc.perform(post("/api/despesas")
                .header("Authorization", "Bearer " + treasurerToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
                .andExpect(result -> {
                    int status = result.getResponse().getStatus();
                    org.junit.jupiter.api.Assertions.assertNotEquals(401, status);
                    org.junit.jupiter.api.Assertions.assertNotEquals(403, status);
                });
    }

    @Test
    public void testPublicRegistrationPermitAll() throws Exception {
        mockMvc.perform(post("/api/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
                .andExpect(status().isBadRequest()); // reaches controller validation, not security 401/403
    }
}
