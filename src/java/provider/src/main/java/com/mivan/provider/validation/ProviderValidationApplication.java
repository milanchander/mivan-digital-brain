package com.mivan.provider.validation;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * MiCPS Provider Data Validation service.
 *
 * <p>Java equivalent of the {@code MPRVVLDR0} COBOL program tree. Exposes the
 * five-step provider validation sequence (NPI lookup, credentialing,
 * exclusion screening, network verification, sanction logging) over REST.</p>
 */
@SpringBootApplication
public class ProviderValidationApplication {

    public static void main(String[] args) {
        SpringApplication.run(ProviderValidationApplication.class, args);
    }
}
