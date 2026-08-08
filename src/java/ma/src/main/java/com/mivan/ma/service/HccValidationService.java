package com.mivan.ma.service;

import com.mivan.ma.model.HccCrosswalk;
import com.mivan.ma.model.MaHccRecord;
import com.mivan.ma.repository.HccCrosswalkRepository;
import com.mivan.ma.repository.MaHccRecordRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

/**
 * Validates ICD-10 diagnosis codes against the CMS HCC crosswalk and applies hierarchy rules.
 * Java equivalent of COBOL subprogram MAHCCVL0.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class HccValidationService {

    private final HccCrosswalkRepository crosswalkRepository;
    private final MaHccRecordRepository hccRecordRepository;

    /**
     * Validates and enriches a list of HCC records for the given member.
     * Sets validationStatus to "VA" or "IN" on each record and persists results.
     * Mirrors MAHCCVL0 DB2 SELECT + hierarchy flag logic.
     */
    public List<MaHccRecord> validateHccCodes(String mbi, String modelYear,
                                               List<MaHccRecord> records) {
        for (MaHccRecord rec : records) {
            Optional<HccCrosswalk> xwalk = crosswalkRepository
                    .findByIcd10CodeAndModelYearAndEffDateLessThanEqualAndTermDateGreaterThanEqual(
                            rec.getIcd10Code(), modelYear,
                            rec.getDosFrom(), rec.getDosThru());

            if (xwalk.isPresent()) {
                HccCrosswalk cw = xwalk.get();
                rec.setHccCode(cw.getHccCode());
                rec.setHccLabel(cw.getHccLabel());
                rec.setRafCoefficient(cw.getRafCoefficient());
                rec.setHierarchicalHcc(cw.getHierarchicalHcc());
                rec.setHierarchyInd(cw.getHierarchicalHcc() != null ? "Y" : "N");
                rec.setValidationStatus("VA");
                log.debug("HCC validated mbi={} icd10={} hcc={}", mbi,
                        rec.getIcd10Code(), rec.getHccCode());
            } else {
                rec.setValidationStatus("IN");
                rec.setRejectReason("NOXW");
                log.debug("HCC invalid mbi={} icd10={}", mbi, rec.getIcd10Code());
            }
        }
        return hccRecordRepository.saveAll(records);
    }

    /**
     * Returns only validated HCC records for downstream RAF calculation.
     */
    public List<MaHccRecord> getValidatedRecords(String mbi, String paymentYear) {
        return hccRecordRepository.findByMbiAndValidationStatus(mbi, "VA");
    }
}
