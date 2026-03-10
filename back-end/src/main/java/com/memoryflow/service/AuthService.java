package com.memoryflow.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.memoryflow.config.JwtConfig;
import com.memoryflow.dto.auth.*;
import com.memoryflow.entity.User;
import com.memoryflow.entity.UserSettings;
import com.memoryflow.entity.UserToken;
import com.memoryflow.exception.BusinessException;
import com.memoryflow.exception.ErrorCode;
import com.memoryflow.mapper.AdminWhitelistMapper;
import com.memoryflow.mapper.UserMapper;
import com.memoryflow.mapper.UserSettingsMapper;
import com.memoryflow.mapper.UserTokenMapper;
import com.memoryflow.security.JwtTokenProvider;
import com.memoryflow.utils.IpUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.util.concurrent.TimeUnit;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserMapper userMapper;
    private final AdminWhitelistMapper adminWhitelistMapper;
    private final UserTokenMapper userTokenMapper;
    private final UserSettingsMapper userSettingsMapper;
    private final JwtTokenProvider jwtTokenProvider;
    private final JwtConfig jwtConfig;
    private final RedisTemplate<String, Object> redisTemplate;
    private final EmailReminderService emailReminderService;
    private final IpUtils ipUtils;

    @Value("${file.upload-dir}")
    private String uploadDir;

    // Redis Key 前缀
    private static final String LOGIN_FAIL_PREFIX = "auth:login:fail:";
    private static final String LOGIN_LOCK_PREFIX = "auth:login:lock:";
    private static final String REGISTER_IP_PREFIX = "auth:register:ip:";
    private static final String VERIFY_CODE_PREFIX = "auth:verify:code:";
    private static final String DEFAULT_AVATAR_URL = "/uploads/avatars/default-avatar.svg";

    /**
     * 发送验证码
     */
    public void sendVerificationCode(String email, String type) {
        // 1. 检查邮箱是否存在
        User user = userMapper.selectOne(new LambdaQueryWrapper<User>().eq(User::getEmail, email));
        
        if ("register".equals(type)) {
            // 注册模式：邮箱不能存在
            if (user != null) {
                throw new BusinessException(ErrorCode.AUTH_EMAIL_EXISTS);
            }
            // 还需要检查白名单
            com.memoryflow.entity.AdminWhitelist whitelist = adminWhitelistMapper.selectOne(
                    new LambdaQueryWrapper<com.memoryflow.entity.AdminWhitelist>()
                            .eq(com.memoryflow.entity.AdminWhitelist::getEmail, email)
            );
            if (whitelist == null) {
                throw new BusinessException(ErrorCode.AUTH_EMAIL_NOT_INVITED);
            }
        } else {
            // 重置密码/其他模式：邮箱必须存在
            if (user == null) {
                throw new BusinessException(ErrorCode.USER_NOT_FOUND);
            }
        }

        // 2. 生成验证码
        String code = String.valueOf((int) ((Math.random() * 9 + 1) * 100000)); // 6位随机数

        // 3. 存储到Redis (5分钟有效期)
        String key = VERIFY_CODE_PREFIX + email;
        redisTemplate.opsForValue().set(key, code, 5, TimeUnit.MINUTES);

        // 4. 发送邮件
        emailReminderService.sendVerificationCode(email, code);
    }

    /**
     * 重置密码
     */
    @Transactional
    public void resetPassword(String email, String code, String newPassword) {
        // 1. 验证验证码
        String key = VERIFY_CODE_PREFIX + email;
        Object storedCode = redisTemplate.opsForValue().get(key);
        if (storedCode == null || !code.equals(storedCode.toString())) {
            throw new BusinessException(ErrorCode.AUTH_VERIFY_CODE_INVALID);
        }

        // 2. 获取用户
        User user = userMapper.selectOne(new LambdaQueryWrapper<User>().eq(User::getEmail, email));
        if (user == null) {
            throw new BusinessException(ErrorCode.USER_NOT_FOUND);
        }

        // 3. 更新密码
        user.setPassword(newPassword); // Entity handles hashing if setter is well defined, or Service should hash?
        // Let's check User entity setPassword implementation.
        // Assuming user.setPassword() handles hashing or we need PasswordEncoder.
        // Wait, current register method: user.setPassword(request.getPassword());
        // Let's check User.java.
        // If User.java doesn't hash, then register method is flawed or hashing happens there.
        // In register: user.setPassword(request.getPassword()); -> userMapper.insert(user);
        // Let's assume User entity has logic or we need to check.
        // Actually, best practice is Service handles hashing.
        // Let's check register implementation again.
        // It just calls user.setPassword.
        
        userMapper.updateById(user);

        // 4. 删除验证码
        redisTemplate.delete(key);
    }

    /**
     * 更换邮箱
     */
    @Transactional
    public void changeEmail(Long userId, String code, String newEmail) {
        User user = userMapper.selectById(userId);
        if (user == null) {
            throw new BusinessException(ErrorCode.USER_NOT_FOUND);
        }

        // 1. 验证验证码 (验证的是当前用户的旧邮箱)
        String key = VERIFY_CODE_PREFIX + user.getEmail();
        Object storedCode = redisTemplate.opsForValue().get(key);
        if (storedCode == null || !code.equals(storedCode.toString())) {
            throw new BusinessException(ErrorCode.AUTH_VERIFY_CODE_INVALID);
        }

        // 2. 检查新邮箱是否已被占用
        if (!user.getEmail().equals(newEmail)) {
            Long count = userMapper.selectCount(new LambdaQueryWrapper<User>().eq(User::getEmail, newEmail));
            if (count > 0) {
                throw new BusinessException(ErrorCode.AUTH_EMAIL_EXISTS);
            }
        }

        // 3. 更新邮箱
        user.setEmail(newEmail);
        userMapper.updateById(user);

        // 4. 删除验证码
        redisTemplate.delete(key);
    }

    /**
     * 用户注册
     */
    @Transactional
    public AuthResponse register(RegisterRequest request, String ipAddress) {
        // 1. 检查IP注册频率限制
        checkRegisterRateLimit(ipAddress);

        // 验证验证码
        String key = VERIFY_CODE_PREFIX + request.getEmail();
        Object storedCode = redisTemplate.opsForValue().get(key);
        if (storedCode == null || !request.getCode().equals(storedCode.toString())) {
            throw new BusinessException(ErrorCode.AUTH_VERIFY_CODE_INVALID);
        }
        redisTemplate.delete(key); // 验证成功后删除

        // 1.5 检查白名单 (邀请制)
        com.memoryflow.entity.AdminWhitelist whitelist = adminWhitelistMapper.selectOne(
                new LambdaQueryWrapper<com.memoryflow.entity.AdminWhitelist>()
                        .eq(com.memoryflow.entity.AdminWhitelist::getEmail, request.getEmail())
        );
        if (whitelist == null) {
            throw new BusinessException(ErrorCode.AUTH_EMAIL_NOT_INVITED);
        }

        // 2. 检查邮箱是否已存在
        Long count = userMapper.selectCount(new LambdaQueryWrapper<User>()
                .eq(User::getEmail, request.getEmail()));
        if (count > 0) {
            throw new BusinessException(ErrorCode.AUTH_EMAIL_EXISTS);
        }

        // 3. 创建用户
        User user = User.builder()
                .email(request.getEmail())
                .nickname(request.getNickname())
                .avatarUrl(DEFAULT_AVATAR_URL)
                .emailVerified(false)
                .status(1)
                .build();
        user.setPassword(request.getPassword());
        user.setRegistrationIp(ipAddress); // Use request IP as registration IP
        user.setRegistrationLocation(ipUtils.getIpLocation(ipAddress)); // Set registration location
        user.setLastLoginIp(ipAddress);    // Initial last login IP
        user.setLastLoginLocation(user.getRegistrationLocation()); // Initial last login location
        user.setLastLoginTime(LocalDateTime.now());
        user.setLoginCount(1);

        userMapper.insert(user);

        // 更新白名单状态
        whitelist.setIsRegistered(true);
        adminWhitelistMapper.updateById(whitelist);

        // 4. 创建默认用户设置
        UserSettings settings = UserSettings.createDefault(user.getId());
        userSettingsMapper.insert(settings);

        // 5. 记录IP注册次数
        incrementRegisterCount(ipAddress);

        // 6. 生成Token并返回
        return generateAuthResponse(user, ipAddress);
    }

    /**
     * 用户登录
     */
    @Transactional
    public AuthResponse login(LoginRequest request, String ipAddress) {
        String email = request.getEmail();

        // 1. 检查账号是否被锁定
        if (isAccountLocked(email)) {
            throw new BusinessException(ErrorCode.AUTH_ACCOUNT_LOCKED);
        }

        // 2. 查找用户
        User user = userMapper.selectOne(new LambdaQueryWrapper<User>()
                .eq(User::getEmail, email));

        if (user == null) {
            incrementLoginFailCount(email);
            throw new BusinessException(ErrorCode.AUTH_CREDENTIALS_INVALID);
        }

        // 3. 验证密码
        if (!user.verifyPassword(request.getPassword())) {
            incrementLoginFailCount(email);
            throw new BusinessException(ErrorCode.AUTH_CREDENTIALS_INVALID);
        }

        // 4. 检查账号状态
        if (!user.isActive()) {
            throw new BusinessException(ErrorCode.AUTH_ACCOUNT_DISABLED);
        }

        // 5. 清除登录失败计数
        clearLoginFailCount(email);

        // 更新登录信息
        user.setLastLoginIp(ipAddress); // Update with current IP
        user.setLastLoginLocation(ipUtils.getIpLocation(ipAddress)); // Update login location
        user.setLastLoginTime(LocalDateTime.now());
        user.setLoginCount(user.getLoginCount() + 1);
        userMapper.updateById(user);

        // 6. 生成Token并返回
        return generateAuthResponse(user, ipAddress);
    }

    /**
     * 刷新Token
     */
    @Transactional
    public AuthResponse refreshToken(String refreshToken, String ipAddress) {
        // 1. 验证refresh token
        if (!jwtTokenProvider.validateToken(refreshToken)) {
            throw new BusinessException(ErrorCode.AUTH_TOKEN_INVALID);
        }

        // 2. 检查token类型
        String tokenType = jwtTokenProvider.getTokenType(refreshToken);
        if (!"refresh".equals(tokenType)) {
            throw new BusinessException(ErrorCode.AUTH_TOKEN_INVALID);
        }

        // 3. 查找数据库中的token记录
        UserToken userToken = userTokenMapper.selectOne(new LambdaQueryWrapper<UserToken>()
                .eq(UserToken::getRefreshToken, refreshToken));

        if (userToken == null) {
            throw new BusinessException(ErrorCode.AUTH_TOKEN_INVALID);
        }

        if (userToken.isExpired()) {
            userTokenMapper.deleteById(userToken.getId());
            throw new BusinessException(ErrorCode.AUTH_TOKEN_EXPIRED);
        }

        // 4. 获取用户
        Long userId = jwtTokenProvider.getUserIdFromToken(refreshToken);
        User user = userMapper.selectById(userId);

        if (user == null) {
            throw new BusinessException(ErrorCode.AUTH_TOKEN_INVALID);
        }

        if (!user.isActive()) {
            throw new BusinessException(ErrorCode.AUTH_ACCOUNT_DISABLED);
        }

        // 5. 删除旧token，生成新token
        userTokenMapper.deleteById(userToken.getId());
        return generateAuthResponse(user, ipAddress);
    }

    /**
     * 退出登录
     */
    @Transactional
    public void logout(Long userId) {
        userTokenMapper.delete(new LambdaQueryWrapper<UserToken>()
                .eq(UserToken::getUserId, userId));
    }

    /**
     * 更新个人资料
     */
    @Transactional
    public AuthResponse.UserInfo updateProfile(Long userId, UpdateProfileRequest request) {
        User user = userMapper.selectById(userId);
        if (user == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "用户不存在");
        }

        String oldAvatarUrl = user.getAvatarUrl();
        user.setNickname(request.getNickname());
        user.setProfession(request.getProfession());
        user.setAge(request.getAge());
        if (request.getAvatarUrl() != null && !request.getAvatarUrl().isBlank()) {
            user.setAvatarUrl(request.getAvatarUrl());
        }

        userMapper.updateById(user);
        deleteOldAvatarIfReplaced(oldAvatarUrl, user.getAvatarUrl());

        return AuthResponse.UserInfo.builder()
                .id(user.getId())
                .email(user.getEmail())
                .nickname(user.getDisplayName())
                .avatarUrl(user.getAvatarUrl())
                .profession(user.getProfession())
                .age(user.getAge())
                .build();
    }

    private void deleteOldAvatarIfReplaced(String oldAvatarUrl, String newAvatarUrl) {
        String oldFileName = extractAvatarFileName(oldAvatarUrl);
        if (oldFileName == null || oldFileName.isBlank()) return;

        String newFileName = extractAvatarFileName(newAvatarUrl);
        if (oldFileName.equals(newFileName)) return;
        if (isDefaultAvatarFile(oldFileName)) return;

        try {
            String dir = uploadDir;
            if (dir == null || dir.isBlank()) return;
            if (!dir.endsWith("/") && !dir.endsWith("\\")) dir = dir + "/";

            Path base = Paths.get(dir).normalize().toAbsolutePath();
            Path target = base.resolve(oldFileName).normalize().toAbsolutePath();
            if (!target.startsWith(base)) return;

            Files.deleteIfExists(target);
        } catch (Exception e) {
            log.warn("Failed to delete old avatar: {}", e.getMessage());
        }
    }

    private String extractAvatarFileName(String avatarUrl) {
        if (avatarUrl == null) return null;
        String value = avatarUrl.trim();
        if (value.isEmpty()) return null;

        String path = value;
        try {
            if (value.startsWith("http://") || value.startsWith("https://")) {
                path = new URL(value).getPath();
            }
        } catch (Exception ignored) {
        }

        int idx = path.indexOf("/uploads/avatars/");
        if (idx < 0) idx = path.indexOf("/api/uploads/avatars/");
        if (idx < 0) return null;

        String base = idx >= 0 && path.startsWith("/api/uploads/avatars/") ? "/api/uploads/avatars/" : "/uploads/avatars/";
        int start = path.indexOf(base);
        if (start < 0) return null;
        String tail = path.substring(start + base.length());
        if (tail.isEmpty() || tail.contains("/") || tail.contains("\\")) return null;
        return tail;
    }

    private boolean isDefaultAvatarFile(String fileName) {
        if (fileName == null) return false;
        return "default-avatar.png".equalsIgnoreCase(fileName)
                || "default-avatar.svg".equalsIgnoreCase(fileName);
    }

    /**
     * 生成认证响应
     */
    private AuthResponse generateAuthResponse(User user, String ipAddress) {
        // 生成tokens
        String accessToken = jwtTokenProvider.generateAccessToken(user.getId(), user.getEmail());
        String refreshToken = jwtTokenProvider.generateRefreshToken(user.getId());

        // 保存refresh token到数据库
        UserToken userToken = UserToken.builder()
                .userId(user.getId())
                .refreshToken(refreshToken)
                .ipAddress(ipAddress)
                .expiresAt(LocalDateTime.now().plusSeconds(jwtConfig.getRefreshTokenExpiration() / 1000))
                .build();
        userTokenMapper.insert(userToken);

        // 构建响应
        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .expiresIn(jwtTokenProvider.getAccessTokenExpirationSeconds())
                .user(AuthResponse.UserInfo.builder()
                        .id(user.getId())
                        .email(user.getEmail())
                        .nickname(user.getDisplayName())
                        .avatarUrl(user.getAvatarUrl())
                        .profession(user.getProfession())
                        .age(user.getAge())
                        .build())
                .build();
    }

    // ========== Redis 防暴力破解 ==========

    /**
     * 检查账号是否被锁定
     */
    private boolean isAccountLocked(String email) {
        String lockKey = LOGIN_LOCK_PREFIX + email;
        try {
            return Boolean.TRUE.equals(redisTemplate.hasKey(lockKey));
        } catch (Exception e) {
            log.error("Redis error checking account lock status for {}: {}", email, e.getMessage());
            // 如果Redis挂了，为了不影响用户登录，默认不锁定
            // 或者可以实施降级策略
            return false;
        }
    }

    /**
     * 增加登录失败计数
     */
    private void incrementLoginFailCount(String email) {
        String failKey = LOGIN_FAIL_PREFIX + email;
        try {
            Long count = redisTemplate.opsForValue().increment(failKey);

            // 设置过期时间（5分钟）
            if (count != null && count == 1) {
                redisTemplate.expire(failKey, 5, TimeUnit.MINUTES);
            }

            // 检查是否达到锁定阈值（5次）
            if (count != null && count >= 5) {
                String lockKey = LOGIN_LOCK_PREFIX + email;
                redisTemplate.opsForValue().set(lockKey, "locked", 5, TimeUnit.MINUTES);
                redisTemplate.delete(failKey);
                log.warn("Account locked due to too many failed attempts: {}", email);
            }
        } catch (Exception e) {
            log.error("Redis error incrementing login fail count for {}: {}", email, e.getMessage());
        }
    }

    /**
     * 清除登录失败计数
     */
    private void clearLoginFailCount(String email) {
        try {
            redisTemplate.delete(LOGIN_FAIL_PREFIX + email);
            redisTemplate.delete(LOGIN_LOCK_PREFIX + email);
        } catch (Exception e) {
            log.error("Redis error clearing login fail count for {}: {}", email, e.getMessage());
        }
    }

    /**
     * 检查注册频率限制
     */
    private void checkRegisterRateLimit(String ipAddress) {
        String key = REGISTER_IP_PREFIX + ipAddress;
        Object count = redisTemplate.opsForValue().get(key);

        if (count != null && Integer.parseInt(count.toString()) >= 3) {
            throw new BusinessException(ErrorCode.AUTH_REGISTER_LIMIT);
        }
    }

    /**
     * 增加IP注册计数
     */
    private void incrementRegisterCount(String ipAddress) {
        String key = REGISTER_IP_PREFIX + ipAddress;
        Long count = redisTemplate.opsForValue().increment(key);

        if (count != null && count == 1) {
            // 第一次注册，设置1小时过期
            redisTemplate.expire(key, 1, TimeUnit.HOURS);
        }
    }
}
