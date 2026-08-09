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
                .title("Medicaid State Reporting API")
                .description("Post-adjudication state reporting for Medicaid claims "
                        + "adjudicated by MiFCT (TriZetto Facets). Handles TPL identification, "
                        + "payer of last resort calculation (42 CFR 433.139), Medicaid liability, "
                        + "and state MMIS encounter submission. This is not a claim adjudication driver.")
                .version("1.0.0")
                .contact(new Contact()
                        .name("Mivan Health Plan — Medicaid Operations")
                        .email("medicaid-ops@mivanhealth.example.com")));
    }
}
