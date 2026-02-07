package com.memoryflow.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/**
 * Cloudflare Turnstile 配置类
 */
@Data
@Configuration
@ConfigurationProperties(prefix = "cloudflare.turnstile")
public class TurnstileProperties {
    /**
     * Turnstile Secret Key
     */
    private String secretKey;

    /**
     * Turnstile Verify URL
     */
    private String siteVerifyUrl;
}
