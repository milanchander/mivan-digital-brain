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
                .title("MA Post-Adjudication Reporting API")
                .description("Post-adjudication CMS reporting for Medicare Advantage claims "
                        + "adjudicated by MiFCT (TriZetto Facets). Handles HCC diagnosis "
                        + "validation, RAF score calculation, encounter staging, and CMS "
                        + "EDPS submission. This is not a claim adjudication driver.")
                .version("1.0.0")
                .contact(new Contact()
                        .name("Mivan Health Plan — MA Operations")
                        .email("ma-ops@mivanhealth.example.com")));
    }
}
