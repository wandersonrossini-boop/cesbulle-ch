package com.tesourariacme.api.presentation;

import com.tesourariacme.api.domain.ServiceSchedule;
import com.tesourariacme.api.infrastructure.ServiceScheduleRepository;
import lombok.Data;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.DayOfWeek;
import java.time.LocalTime;
import java.util.List;

@RestController
@RequestMapping("/api/admin/service-schedules")
public class ServiceScheduleController {

    private final ServiceScheduleRepository repository;

    public ServiceScheduleController(ServiceScheduleRepository repository) {
        this.repository = repository;
    }

    private boolean isAdmin(Authentication authentication) {
        return authentication != null && authentication.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));
    }

    @GetMapping
    public ResponseEntity<?> listAll(Authentication authentication) {
        if (!isAdmin(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Acesso negado. Apenas administradores.");
        }
        List<ServiceSchedule> schedules = repository.findAll();
        return ResponseEntity.ok(schedules);
    }

    @PostMapping
    public ResponseEntity<?> create(@RequestBody ServiceScheduleRequest request, Authentication authentication) {
        if (!isAdmin(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Acesso negado. Apenas administradores.");
        }
        try {
            ServiceSchedule schedule = new ServiceSchedule();
            schedule.setDayOfWeek(DayOfWeek.valueOf(request.getDayOfWeek().toUpperCase()));
            schedule.setStartTime(LocalTime.parse(request.getStartTime()));
            schedule.setEndTime(LocalTime.parse(request.getEndTime()));
            schedule.setServiceType(request.getServiceType());
            schedule.setActive(request.isActive());
            
            ServiceSchedule saved = repository.save(schedule);
            return ResponseEntity.ok(saved);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Erro ao cadastrar agenda: " + e.getMessage());
        }
    }

    @PutMapping("/{id}")
    public ResponseEntity<?> update(@PathVariable Long id, @RequestBody ServiceScheduleRequest request, Authentication authentication) {
        if (!isAdmin(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Acesso negado. Apenas administradores.");
        }
        return repository.findById(id).map(schedule -> {
            try {
                schedule.setDayOfWeek(DayOfWeek.valueOf(request.getDayOfWeek().toUpperCase()));
                schedule.setStartTime(LocalTime.parse(request.getStartTime()));
                schedule.setEndTime(LocalTime.parse(request.getEndTime()));
                schedule.setServiceType(request.getServiceType());
                schedule.setActive(request.isActive());
                ServiceSchedule saved = repository.save(schedule);
                return ResponseEntity.ok(saved);
            } catch (Exception e) {
                return ResponseEntity.badRequest().body("Erro ao atualizar agenda: " + e.getMessage());
            }
        }).orElse(ResponseEntity.notFound().build());
    }

    @PatchMapping("/{id}/toggle-active")
    public ResponseEntity<?> toggleActive(@PathVariable Long id, Authentication authentication) {
        if (!isAdmin(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Acesso negado. Apenas administradores.");
        }
        return repository.findById(id).map(schedule -> {
            schedule.setActive(!schedule.isActive());
            ServiceSchedule saved = repository.save(schedule);
            return ResponseEntity.ok(saved);
        }).orElse(ResponseEntity.notFound().build());
    }

    @Data
    public static class ServiceScheduleRequest {
        private String dayOfWeek;
        private String startTime;
        private String endTime;
        private String serviceType;
        private boolean active = true;
    }
}
