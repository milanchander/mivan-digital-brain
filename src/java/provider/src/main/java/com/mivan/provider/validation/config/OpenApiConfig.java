package com.mivan.provider.validation.config;

import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.info.Contact;
import io.swagger.v3.oas.annotations.info.Info;
import io.swagger.v3.oas.annotations.info.License;
import io.swagger.v3.oas.models.OpenAPI;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * OpenAPI / Swagger configuration for the provider validation service.
 */
@Configuration
@OpenAPIDefinition(
    info = @Info(
        title = "MiCPS Provider Validation API",
        version = "1.0.0",
        description = "Java equivalent of the MPRVVLDR0 COBOL program tree — "
                    + "NPI lookup, credentialing, exclusion screening, network "
                    + "verification, and mandatory sanction logging.",
        contact = @Contact(name = "Mivan Digital Brain",
                           email = "milan.chander@accenture.com"),
        license = @License(name = "Mivan Internal")
    )
)
public class OpenApiConfig {

    @Bean
    public OpenAPI providerValidationOpenAPI() {
        return new OpenAPI();
    }
}
