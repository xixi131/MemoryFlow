package com.memoryflow.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.memoryflow.entity.EmailReminderLog;
import com.memoryflow.entity.Point;
import com.memoryflow.entity.User;
import com.memoryflow.entity.UserSettings;
import com.memoryflow.mapper.EmailReminderLogMapper;
import com.memoryflow.mapper.PointMapper;
import com.memoryflow.mapper.UserMapper;
import com.memoryflow.mapper.UserSettingsMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class EmailReminderService {

    private final JavaMailSender mailSender;
    private final UserMapper userMapper;
    private final PointMapper pointMapper;
    private final UserSettingsMapper userSettingsMapper;
    private final EmailReminderLogMapper emailReminderLogMapper;

    @Value("${spring.mail.username:noreply@memoryflow.com}")
    private String fromEmail;

    @Value("${app.name:MemoryFlow}")
    private String appName;

    @Value("${app.frontend-url:http://localhost:3000}")
    private String frontendUrl;

    @Async
    public void sendInvitationEmail(String to) {
        String subject = String.format("邀请您加入 %s", appName);
        String inviteLink = String.format("%s/#/register?email=%s", frontendUrl, to);
        
        String content = String.format("""
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="UTF-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <style>
                        body {
                            margin: 0;
                            padding: 0;
                            font-family: 'Google Sans', Roboto, RobotoDraft, Helvetica, Arial, sans-serif;
                            background-color: #f5f5f5;
                            color: #202124;
                        }
                        .container {
                            width: 100%%;
                            max-width: 580px;
                            margin: 0 auto;
                            padding: 20px;
                        }
                        .card {
                            background-color: #ffffff;
                            border-radius: 8px;
                            padding: 40px 40px;
                            border: 1px solid #dadce0;
                            text-align: center;
                        }
                        .logo {
                            font-size: 24px;
                            font-weight: 500;
                            color: #5f6368;
                            margin-bottom: 24px;
                            display: inline-block;
                        }
                        .logo span {
                            color: #1a73e8;
                            font-weight: bold;
                        }
                        h1 {
                            font-size: 22px;
                            font-weight: 400;
                            margin: 0 0 24px 0;
                            color: #202124;
                        }
                        p {
                            font-size: 14px;
                            line-height: 1.5;
                            color: #3c4043;
                            margin: 0 0 24px 0;
                        }
                        .btn {
                            display: inline-block;
                            background-color: #1a73e8;
                            color: #ffffff;
                            padding: 10px 24px;
                            text-decoration: none;
                            border-radius: 4px;
                            font-weight: 500;
                            font-size: 14px;
                            letter-spacing: 0.25px;
                            line-height: 20px;
                            transition: background-color 0.2s;
                        }
                        .btn:hover {
                            background-color: #1765cc;
                            box-shadow: 0 1px 2px 0 rgba(60,64,67,0.3), 0 1px 3px 1px rgba(60,64,67,0.15);
                        }
                        .footer {
                            margin-top: 24px;
                            font-size: 12px;
                            color: #5f6368;
                            text-align: center;
                        }
                        .divider {
                            height: 1px;
                            background-color: #dadce0;
                            margin: 24px 0;
                        }
                        .user-email {
                            font-weight: 500;
                            color: #202124;
                            border: 1px solid #dadce0;
                            border-radius: 16px;
                            padding: 4px 12px;
                            display: inline-block;
                            margin-bottom: 24px;
                            font-size: 13px;
                        }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <div class="card">
                            <div class="logo">Memory<span>Flow</span></div>
                            
                            <h1>Ready to start learning?</h1>
                            
                            <p>您好！管理员已邀请您加入 <strong>%s</strong>。</p>
                            
                            <div class="user-email">%s</div>
                            
                            <p>我们为您准备了科学的记忆算法和舒适的学习体验。<br>点击下方按钮即可完成注册。</p>
                            
                            <a href="%s" class="btn">接受邀请</a>
                            
                            <div class="divider"></div>
                            
                            <p style="font-size: 12px; color: #5f6368; margin-bottom: 0;">
                                如果按钮无法点击，请复制以下链接到浏览器打开：<br>
                                <a href="%s" style="color: #1a73e8; text-decoration: none;">%s</a>
                            </p>
                        </div>
                        
                        <div class="footer">
                            <p>&copy; %d %s. All rights reserved.</p>
                        </div>
                    </div>
                </body>
                </html>
                """, appName, to, inviteLink, inviteLink, inviteLink, java.time.Year.now().getValue(), appName);

        try {
            sendHtmlEmail(to, subject, content);
            log.info("成功发送邀请邮件给 {}", to);
        } catch (Exception e) {
            log.error("发送邀请邮件失败: {}", e.getMessage());
        }
    }

    /**
     * 检查并发送逾期提醒邮件
     * 规则：超过1天、7天、30天各发送一次提醒
     */
    @Transactional
    public void checkAndSendOverdueReminders() {
        log.info("开始检查逾期复习提醒...");

        List<User> users = userMapper.selectList(null);

        for (User user : users) {
            try {
                processUserReminders(user);
            } catch (Exception e) {
                log.error("处理用户 {} 的提醒时发生错误: {}", user.getId(), e.getMessage());
            }
        }

        log.info("逾期复习提醒检查完成");
    }

    private void processUserReminders(User user) {
        // 检查用户是否开启了邮件提醒
        UserSettings settings = userSettingsMapper.selectOne(new LambdaQueryWrapper<UserSettings>()
                .eq(UserSettings::getUserId, user.getId()));

        if (settings != null && !settings.getEmailReminderEnabled()) {
            return;
        }

        // 获取用户所有逾期的复习点
        List<Point> overduePoints = pointMapper.findOverdueReviewsByUserId(user.getId(), LocalDate.now());

        if (overduePoints.isEmpty()) {
            return;
        }

        // 按逾期天数分组
        Map<String, List<Point>> groupedByOverdue = groupByOverdueDays(overduePoints);

        // 检查并发送不同级别的提醒
        checkAndSendReminder(user, groupedByOverdue, "overdue_1day", 1);
        checkAndSendReminder(user, groupedByOverdue, "overdue_7days", 7);
        checkAndSendReminder(user, groupedByOverdue, "overdue_30days", 30);
    }

    private Map<String, List<Point>> groupByOverdueDays(List<Point> points) {
        LocalDate today = LocalDate.now();

        return points.stream().collect(Collectors.groupingBy(point -> {
            if (point.getNextReviewDate() == null) {
                return "unknown";
            }
            long days = ChronoUnit.DAYS.between(point.getNextReviewDate(), today);
            if (days >= 30) {
                return "30days";
            } else if (days >= 7) {
                return "7days";
            } else if (days >= 1) {
                return "1day";
            }
            return "today";
        }));
    }

    private void checkAndSendReminder(User user, Map<String, List<Point>> groupedPoints,
                                       String reminderType, int minDays) {
        // 检查是否已经发送过该类型的提醒（每种类型只发一次）
        if (hasAlreadySentReminder(user.getId(), reminderType)) {
            return;
        }

        // 统计符合条件的逾期点数量
        int count = 0;
        if (minDays == 1) {
            count = groupedPoints.getOrDefault("1day", List.of()).size()
                    + groupedPoints.getOrDefault("7days", List.of()).size()
                    + groupedPoints.getOrDefault("30days", List.of()).size();
        } else if (minDays == 7) {
            count = groupedPoints.getOrDefault("7days", List.of()).size()
                    + groupedPoints.getOrDefault("30days", List.of()).size();
        } else if (minDays == 30) {
            count = groupedPoints.getOrDefault("30days", List.of()).size();
        }

        if (count == 0) {
            return;
        }

        // 发送提醒邮件
        sendReminderEmail(user, reminderType, count, minDays);
    }

    private boolean hasAlreadySentReminder(Long userId, String reminderType) {
        EmailReminderLog lastReminder = emailReminderLogMapper.selectOne(new LambdaQueryWrapper<EmailReminderLog>()
                .eq(EmailReminderLog::getUserId, userId)
                .eq(EmailReminderLog::getReminderType, reminderType)
                .orderByDesc(EmailReminderLog::getCreatedAt)
                .last("LIMIT 1"));

        if (lastReminder == null) {
            return false;
        }

        // 检查是否是成功发送的
        return "sent".equals(lastReminder.getStatus());
    }

    @Async
    public void sendVerificationCode(String to, String code) {
        String subject = String.format("【%s】验证您的身份", appName);
        String content = String.format("""
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="UTF-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <style>
                        body {
                            margin: 0;
                            padding: 0;
                            font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
                            background-color: #f3f4f6;
                            color: #1f2937;
                        }
                        .container {
                            width: 100%%;
                            max-width: 600px;
                            margin: 0 auto;
                            padding: 40px 20px;
                        }
                        .card {
                            background-color: #ffffff;
                            border-radius: 16px;
                            overflow: hidden;
                            box-shadow: 0 4px 24px rgba(0,0,0,0.08);
                        }
                        .header {
                            padding: 32px 0;
                            text-align: center;
                            border-bottom: 1px solid #f3f4f6;
                        }
                        .logo-text {
                            font-size: 24px;
                            font-weight: 800;
                            color: #111827;
                            letter-spacing: -0.5px;
                            text-decoration: none;
                        }
                        .logo-accent {
                            color: #6366f1;
                        }
                        .content {
                            padding: 40px;
                        }
                        .title {
                            font-size: 20px;
                            font-weight: 600;
                            color: #111827;
                            margin-bottom: 16px;
                            text-align: center;
                        }
                        .text {
                            font-size: 16px;
                            line-height: 1.6;
                            color: #4b5563;
                            text-align: center;
                            margin-bottom: 32px;
                        }
                        .code-box {
                            background-color: #eff6ff;
                            border-radius: 12px;
                            padding: 24px;
                            text-align: center;
                            margin: 32px 0;
                            border: 1px solid #dbeafe;
                        }
                        .code {
                            font-family: monospace;
                            font-size: 36px;
                            font-weight: 700;
                            color: #4f46e5;
                            letter-spacing: 8px;
                        }
                        .footer {
                            padding: 24px;
                            text-align: center;
                            background-color: #f9fafb;
                            border-top: 1px solid #f3f4f6;
                        }
                        .footer-text {
                            font-size: 12px;
                            color: #9ca3af;
                            line-height: 1.5;
                        }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <div class="card">
                            <div class="header">
                                <span class="logo-text">Memory<span class="logo-accent">Flow</span></span>
                            </div>
                            <div class="content">
                                <div class="title">验证您的身份</div>
                                <p class="text">
                                    您好，我们收到了重置密码的请求。<br>
                                    请使用下方的验证码完成操作。
                                </p>
                                
                                <div class="code-box">
                                    <div class="code">%s</div>
                                </div>
                                
                                <p class="text" style="font-size: 14px; margin-bottom: 0;">
                                    验证码有效期为 5 分钟。<br>
                                    如果这不是您本人的操作，请忽略此邮件。
                                </p>
                            </div>
                            <div class="footer">
                                <p class="footer-text">
                                    此邮件由 MemoryFlow 系统自动发送<br>
                                    &copy; %d MemoryFlow. All rights reserved.
                                </p>
                            </div>
                        </div>
                    </div>
                </body>
                </html>
                """, code, java.time.Year.now().getValue());

        try {
            sendHtmlEmail(to, subject, content);
            log.info("成功发送验证码邮件给 {}", to);
        } catch (Exception e) {
            log.error("发送验证码邮件失败: {}", e.getMessage());
        }
    }

    @Async
    public void sendReminderEmail(User user, String reminderType, int overdueCount, int overdueDays) {
        String subject = buildEmailSubject(reminderType, overdueCount);
        String content = buildEmailContent(user, reminderType, overdueCount, overdueDays);

        EmailReminderLog logEntry = EmailReminderLog.builder()
                .userId(user.getId())
                .reminderType(reminderType)
                .email(user.getEmail())
                .subject(subject)
                .content(content)
                .status("pending")
                .build();

        try {
            sendHtmlEmail(user.getEmail(), subject, content);
            logEntry.markAsSent();
            log.info("成功发送 {} 提醒邮件给用户 {}", reminderType, user.getEmail());
        } catch (Exception e) {
            logEntry.markAsFailed(e.getMessage());
            log.error("发送邮件失败: {}", e.getMessage());
        }

        emailReminderLogMapper.insert(logEntry);
    }

    private void sendHtmlEmail(String to, String subject, String htmlContent) throws MessagingException {
        MimeMessage message = mailSender.createMimeMessage();
        MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");

        helper.setFrom(fromEmail);
        helper.setTo(to);
        helper.setSubject(subject);
        helper.setText(htmlContent, true);

        mailSender.send(message);
    }

    private void sendSimpleEmail(String to, String subject, String content) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(fromEmail);
        message.setTo(to);
        message.setSubject(subject);
        message.setText(content);

        mailSender.send(message);
    }

    private String buildEmailSubject(String reminderType, int count) {
        return switch (reminderType) {
            case "overdue_1day" -> String.format("【%s】您有 %d 个知识点逾期未复习", appName, count);
            case "overdue_7days" -> String.format("【%s】重要提醒：%d 个知识点已逾期超过7天", appName, count);
            case "overdue_30days" -> String.format("【%s】紧急：%d 个知识点已逾期超过30天，记忆可能已大幅衰退", appName, count);
            default -> String.format("【%s】复习提醒", appName);
        };
    }

    private String buildEmailContent(User user, String reminderType, int count, int overdueDays) {
        String greeting = user.getNickname() != null ? user.getNickname() : user.getEmail();
        String urgencyMessage = getUrgencyMessage(reminderType);
        String color = getUrgencyColor(reminderType);

        return String.format("""
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="UTF-8">
                    <style>
                        body { font-family: 'Microsoft YaHei', Arial, sans-serif; line-height: 1.6; color: #333; }
                        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                        .header { background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
                        .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
                        .alert-box { background: %s; color: white; padding: 15px; border-radius: 8px; margin: 20px 0; text-align: center; }
                        .stats { background: white; padding: 20px; border-radius: 8px; margin: 20px 0; }
                        .btn { display: inline-block; background: #667eea; color: white; padding: 12px 30px; text-decoration: none; border-radius: 25px; margin-top: 20px; }
                        .footer { text-align: center; color: #888; font-size: 12px; margin-top: 30px; }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <div class="header">
                            <h1>📚 %s</h1>
                            <p>学习复习提醒</p>
                        </div>
                        <div class="content">
                            <p>亲爱的 <strong>%s</strong>，</p>

                            <div class="alert-box">
                                <h2>⚠️ %s</h2>
                                <p>您有 <strong>%d</strong> 个知识点已逾期超过 <strong>%d</strong> 天未复习</p>
                            </div>

                            <div class="stats">
                                <h3>📊 艾宾浩斯遗忘曲线提示</h3>
                                <p>根据艾宾浩斯遗忘曲线，知识点在学习后：</p>
                                <ul>
                                    <li>1天后，记忆保留约 33%%</li>
                                    <li>7天后，记忆保留约 25%%</li>
                                    <li>30天后，记忆保留约 21%%</li>
                                </ul>
                                <p><strong>及时复习可以显著提高记忆保持率！</strong></p>
                            </div>

                            <p style="text-align: center;">
                                <a href="#" class="btn">立即开始复习</a>
                            </p>

                            <p>坚持就是胜利，加油！💪</p>
                        </div>
                        <div class="footer">
                            <p>此邮件由 %s 系统自动发送，请勿直接回复。</p>
                            <p>如不想接收此类邮件，请在应用设置中关闭邮件提醒。</p>
                        </div>
                    </div>
                </body>
                </html>
                """, color, appName, greeting, urgencyMessage, count, overdueDays, appName);
    }

    private String getUrgencyMessage(String reminderType) {
        return switch (reminderType) {
            case "overdue_1day" -> "温馨提醒";
            case "overdue_7days" -> "重要提醒";
            case "overdue_30days" -> "紧急提醒";
            default -> "复习提醒";
        };
    }

    private String getUrgencyColor(String reminderType) {
        return switch (reminderType) {
            case "overdue_1day" -> "#f39c12";  // 黄色
            case "overdue_7days" -> "#e67e22"; // 橙色
            case "overdue_30days" -> "#e74c3c"; // 红色
            default -> "#3498db";
        };
    }

    /**
     * 重置用户的提醒状态（当用户完成所有逾期复习后）
     */
    @Transactional
    public void resetReminderStatus(Long userId) {
        // 当用户没有逾期任务时，可以重置提醒状态
        // 这样下次再逾期时可以重新发送提醒
        List<Point> overduePoints = pointMapper.findOverdueReviewsByUserId(userId, LocalDate.now());

        if (overduePoints.isEmpty()) {
            log.info("用户 {} 没有逾期复习，提醒状态可以重置", userId);
        }
    }
}
