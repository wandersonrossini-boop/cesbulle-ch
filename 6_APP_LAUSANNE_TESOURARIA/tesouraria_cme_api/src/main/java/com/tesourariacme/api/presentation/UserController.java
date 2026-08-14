package com.tesourariacme.api.presentation;

import com.tesourariacme.api.domain.AppUser;
import com.tesourariacme.api.infrastructure.AppUserRepository;
import lombok.Data;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/users")
@CrossOrigin(origins = "*")
public class UserController {

    private final AppUserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public UserController(AppUserRepository userRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    // ----------------------------------------------------
    // ADMIN ENDPOINTS
    // ----------------------------------------------------

    @GetMapping
    public ResponseEntity<List<AppUser>> getAllUsers(Authentication authentication) {
        if (!isAdmin(authentication)) return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        return ResponseEntity.ok(userRepository.findAll());
    }

    @PutMapping("/{id}/approve")
    public ResponseEntity<?> approveUser(@PathVariable Long id, Authentication authentication) {
        if (!isAdmin(authentication)) return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        
        return userRepository.findById(id).map(user -> {
            user.setAuthorized(true);
            userRepository.save(user);
            return ResponseEntity.ok("Usuário aprovado com sucesso.");
        }).orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/{id}/revoke")
    public ResponseEntity<?> revokeUser(@PathVariable Long id, Authentication authentication) {
        if (!isAdmin(authentication)) return ResponseEntity.status(HttpStatus.FORBIDDEN).build();

        return userRepository.findById(id).map(user -> {
            user.setAuthorized(false);
            userRepository.save(user);
            return ResponseEntity.ok("Acesso revogado.");
        }).orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteUser(@PathVariable Long id, Authentication authentication) {
        if (!isAdmin(authentication)) return ResponseEntity.status(HttpStatus.FORBIDDEN).build();

        if (userRepository.existsById(id)) {
            userRepository.deleteById(id);
            return ResponseEntity.ok("Usuário removido.");
        }
        return ResponseEntity.notFound().build();
    }

    @PutMapping("/{id}/reset-password")
    public ResponseEntity<?> adminResetPassword(@PathVariable Long id, @RequestBody PasswordUpdateRequest request, Authentication authentication) {
        if (!isAdmin(authentication)) return ResponseEntity.status(HttpStatus.FORBIDDEN).build();

        return userRepository.findById(id).map(user -> {
            user.setPasswordHash(passwordEncoder.encode(request.getNewPassword()));
            userRepository.save(user);
            return ResponseEntity.ok("Senha redefinida pelo administrador.");
        }).orElse(ResponseEntity.notFound().build());
    }

    // ----------------------------------------------------
    // PROFILE ENDPOINTS (FOR THE LOGGED IN USER)
    // ----------------------------------------------------

    @GetMapping("/me")
    public ResponseEntity<AppUser> getMyProfile(Authentication authentication) {
        return userRepository.findByUsername(authentication.getName())
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/me")
    public ResponseEntity<?> updateMyProfile(@RequestBody ProfileUpdateRequest request, Authentication authentication) {
        return userRepository.findByUsername(authentication.getName()).map(user -> {
            if (request.getName() != null) user.setName(request.getName());
            if (request.getAvatarBase64() != null) user.setAvatarBase64(request.getAvatarBase64());
            if (request.getNewPassword() != null && !request.getNewPassword().isEmpty()) {
                user.setPasswordHash(passwordEncoder.encode(request.getNewPassword()));
            }
            userRepository.save(user);
            return ResponseEntity.ok(user);
        }).orElse(ResponseEntity.notFound().build());
    }

    private boolean isAdmin(Authentication authentication) {
        return authentication.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));
    }
}

@Data
class PasswordUpdateRequest {
    private String newPassword;
}

@Data
class ProfileUpdateRequest {
    private String name;
    private String newPassword;
    private String avatarBase64;
}
