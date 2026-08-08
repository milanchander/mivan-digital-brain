package com.mivan.ma.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI maEncounterOpenApi() {
        return new OpenAPI().info(new Info()
                .title("MA Encounter Processing API")
                .description("Medicare Advantage encounter data pipeline. "
                        + "Java implementation of the MAENCDR0 COBOL driver — "
                        + "eligibility check (MAELGCK0), HCC validation (MAHCCVL0), "
                        + "RAF calculation (MARAFCL0), encounter build (MAENCBL0), "
                        + "and EDPS submission (MAEDPSUB0).")
                .version("1.0.0")
                .contact(new Contact()
                        .name("Mivan Health Plan — MA Operations")
                        .email("ma-ops@mivanhealth.example.com")));
    }
}
