package com.memoryflow.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Data
@Component
@ConfigurationProperties(prefix = "jwt")
public class JwtConfig {

    /**
     * JWT签名密钥
     */
    private String secret;

    /**
     * Access Token 过期时间(毫秒)
     */
    private long accessTokenExpiration = 1800000; // 30分钟

    /**
     * Refresh Token 过期时间(毫秒)
     */
    private long refreshTokenExpiration = 604800000; // 7天

    /**
     * 签发者
     */
    private String issuer = "MemoryFlow";
}
