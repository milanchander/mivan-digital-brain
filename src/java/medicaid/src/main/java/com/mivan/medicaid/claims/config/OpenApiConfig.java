package com.mivan.medicaid.claims.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI medicaidClaimOpenApi() {
        return new OpenAPI().info(new Info()
                .title("Medicaid Claim Processing API")
                .description("Medicaid claim processing pipeline. "
                        + "Java implementation of the MMCOCLDR0 COBOL driver — "
                        + "eligibility verification (MMCOELV0), "
                        + "TPL identification (MMCOTPL0), "
                        + "payer of last resort calculation (MMCOLRP0, 42 CFR 433.139), "
                        + "encounter build (MMCOENC0), "
                        + "and state MMIS submission (MMCOSSUB0).")
                .version("1.0.0")
                .contact(new Contact()
                        .name("Mivan Health Plan — Medicaid Operations")
                        .email("medicaid-ops@mivanhealth.example.com")));
    }
}
