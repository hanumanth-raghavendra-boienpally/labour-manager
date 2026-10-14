package com.winfo.labour.web;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import com.winfo.labour.config.AppSettings;

/** Lets the React dev server call the API directly if it is not using the Vite proxy. */
@Configuration
public class WebConfig implements WebMvcConfigurer {

    private final AppSettings settings;

    public WebConfig(AppSettings settings) {
        this.settings = settings;
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOrigins(settings.allowedOrigins())
                .allowedMethods("GET", "POST", "OPTIONS")
                .allowedHeaders("*");
    }
}
