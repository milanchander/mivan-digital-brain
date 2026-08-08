package com.mivan.ma.repository;

import com.mivan.ma.model.HccCrosswalk;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface HccCrosswalkRepository extends JpaRepository<HccCrosswalk, Long> {

    Optional<HccCrosswalk> findByIcd10CodeAndModelYearAndEffDateLessThanEqualAndTermDateGreaterThanEqual(
            String icd10Code, String modelYear, LocalDate effDate, LocalDate termDate);

    List<HccCrosswalk> findByHccCodeAndModelYear(String hccCode, String modelYear);

    List<HccCrosswalk> findByModelYear(String modelYear);
}
