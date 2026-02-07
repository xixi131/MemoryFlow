package com.memoryflow.aspect;

import com.memoryflow.annotation.RequiresCaptcha;
import com.memoryflow.exception.BusinessException;
import com.memoryflow.exception.ErrorCode;
import com.memoryflow.service.TurnstileService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.springframework.stereotype.Component;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import jakarta.servlet.http.HttpServletRequest;

/**
 * 人机验证切面
 */
@Slf4j
@Aspect
@Component
@RequiredArgsConstructor
public class TurnstileAspect {

    private final TurnstileService turnstileService;

    @Around("@annotation(requiresCaptcha)")
    public Object checkCaptcha(ProceedingJoinPoint joinPoint, RequiresCaptcha requiresCaptcha) throws Throwable {
        ServletRequestAttributes attributes = (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
        if (attributes == null) {
            return joinPoint.proceed();
        }

        HttpServletRequest request = attributes.getRequest();
        String token = request.getHeader("X-CF-Token");

        // 如果 Header 没有，尝试从参数中获取（可选，根据需求）
        if (token == null || token.isEmpty()) {
            token = request.getParameter("cf-turnstile-response");
        }

        if (token == null || token.isEmpty()) {
            log.warn("Missing Turnstile token for request: {}", request.getRequestURI());
            throw new BusinessException(ErrorCode.AUTH_CAPTCHA_FAILED);
        }

        boolean isValid = turnstileService.verify(token);
        if (!isValid) {
            log.warn("Invalid Turnstile token for request: {}", request.getRequestURI());
            throw new BusinessException(ErrorCode.AUTH_CAPTCHA_FAILED);
        }

        return joinPoint.proceed();
    }
}
