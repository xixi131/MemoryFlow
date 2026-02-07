package com.memoryflow.annotation;

import java.lang.annotation.*;

/**
 * 标记需要进行人机验证的方法
 */
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface RequiresCaptcha {
}
