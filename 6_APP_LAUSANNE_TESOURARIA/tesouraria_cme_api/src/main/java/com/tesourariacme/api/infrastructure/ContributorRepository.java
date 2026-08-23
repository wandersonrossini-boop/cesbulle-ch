package com.tesourariacme.api.infrastructure;

import com.tesourariacme.api.domain.Contributor;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface ContributorRepository extends JpaRepository<Contributor, Long> {

    Optional<Contributor> findByContributorNumber(String contributorNumber);

    List<Contributor> findAllByActiveTrue();

    @Query("SELECT c FROM Contributor c WHERE c.active = true AND " +
           "(LOWER(c.fullName) LIKE LOWER(CONCAT('%', :search, '%')) OR " +
           "LOWER(c.contributorNumber) LIKE LOWER(CONCAT('%', :search, '%')))")
    List<Contributor> searchActive(@Param("search") String search);
}
