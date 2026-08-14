package com.tesourariacme.api.presentation;

import com.tesourariacme.api.domain.Member;
import com.tesourariacme.api.infrastructure.MemberRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.data.domain.Sort;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/membros")
@CrossOrigin(origins = "*")
public class MemberController {

    private final MemberRepository memberRepository;

    public MemberController(MemberRepository memberRepository) {
        this.memberRepository = memberRepository;
    }

    // GET /api/membros — returns plain list of names (used by counting wizard)
    @GetMapping
    public ResponseEntity<List<String>> listMembers() {
        List<String> names = memberRepository.findAll(Sort.by(Sort.Direction.ASC, "name"))
                .stream()
                .map(Member::getName)
                .collect(Collectors.toList());
        return ResponseEntity.ok(names);
    }

    // GET /api/membros/detalhado — returns id + name (used by members management page)
    @GetMapping("/detalhado")
    public ResponseEntity<List<Map<String, Object>>> listMembersDetailed() {
        List<Map<String, Object>> result = memberRepository
                .findAll(Sort.by(Sort.Direction.ASC, "name"))
                .stream()
                .map(m -> Map.<String, Object>of("id", m.getId(), "name", m.getName()))
                .collect(Collectors.toList());
        return ResponseEntity.ok(result);
    }

    // POST /api/membros — create a new member explicitly
    @PostMapping
    public ResponseEntity<?> createMember(@RequestBody Map<String, String> body) {
        String name = body.getOrDefault("name", "").trim();
        if (name.isEmpty()) {
            return ResponseEntity.badRequest().body("O nome não pode ser vazio.");
        }
        if (memberRepository.findByNameIgnoreCase(name).isPresent()) {
            return ResponseEntity.badRequest().body("Já existe um contribuinte com este nome.");
        }
        Member newMember = new Member();
        newMember.setName(name);
        memberRepository.save(newMember);
        return ResponseEntity.ok(Map.of("id", newMember.getId(), "name", newMember.getName()));
    }

    // PUT /api/membros/{id} — rename a member
    @PutMapping("/{id}")
    public ResponseEntity<?> renameMember(@PathVariable Long id, @RequestBody Map<String, String> body) {
        String newName = body.getOrDefault("name", "").trim();
        if (newName.isEmpty()) {
            return ResponseEntity.badRequest().body("O nome não pode ser vazio.");
        }
        return memberRepository.findById(id).map(member -> {
            // Check for duplicates (case-insensitive), excluding itself
            boolean duplicateExists = memberRepository.findByNameIgnoreCase(newName)
                    .filter(m -> !m.getId().equals(id))
                    .isPresent();
            if (duplicateExists) {
                return ResponseEntity.badRequest().body("Já existe um contribuinte com este nome.");
            }
            member.setName(newName);
            return ResponseEntity.ok(memberRepository.save(member));
        }).orElse(ResponseEntity.notFound().build());
    }

    // DELETE /api/membros/{id} — remove a member
    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteMember(@PathVariable Long id) {
        if (!memberRepository.existsById(id)) {
            return ResponseEntity.notFound().build();
        }
        memberRepository.deleteById(id);
        return ResponseEntity.noContent().build();
    }
}
