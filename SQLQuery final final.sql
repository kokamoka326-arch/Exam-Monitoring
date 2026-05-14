IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'iam_security')
    CREATE DATABASE iam_security;
GO
USE iam_security;
GO
 
PRINT '================================================';
PRINT ' IAM Security — Full Schema Setup';
PRINT '================================================';
GO
 
-- ================================================================
--  SECTION 1 — CORE IAM TABLES
-- ================================================================
 
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='users' AND xtype='U')
BEGIN
    CREATE TABLE users (
        id            UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        username      NVARCHAR(50)     NOT NULL UNIQUE,
        email         NVARCHAR(100)    NOT NULL UNIQUE,
        password_hash NVARCHAR(255)    NOT NULL,
        full_name     NVARCHAR(150)    NULL,
        is_active     BIT              NOT NULL DEFAULT 1,
        created_at    DATETIME2        NOT NULL DEFAULT GETDATE(),
        last_login    DATETIME2        NULL
    );
    PRINT '✅ users';
END
ELSE PRINT '⏭  users';
GO
 
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='roles' AND xtype='U')
BEGIN
    CREATE TABLE roles (
        id          UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        name        NVARCHAR(50)     NOT NULL UNIQUE,
        description NVARCHAR(255)    NULL,
        created_at  DATETIME2        NOT NULL DEFAULT GETDATE()
    );
    PRINT '✅ roles';
END
ELSE PRINT '⏭  roles';
GO
 
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='permissions' AND xtype='U')
BEGIN
    CREATE TABLE permissions (
        id          UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        resource    NVARCHAR(100)    NOT NULL,
        action      NVARCHAR(50)     NOT NULL,
        description NVARCHAR(255)    NULL,
        CONSTRAINT uq_resource_action UNIQUE (resource, action)
    );
    PRINT '✅ permissions';
END
ELSE PRINT '⏭  permissions';
GO
 
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='user_roles' AND xtype='U')
BEGIN
    CREATE TABLE user_roles (
        id          UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        user_id     UNIQUEIDENTIFIER NOT NULL REFERENCES users(id)       ON DELETE CASCADE,
        role_id     UNIQUEIDENTIFIER NOT NULL REFERENCES roles(id)       ON DELETE CASCADE,
        assigned_at DATETIME2        NOT NULL DEFAULT GETDATE(),
        CONSTRAINT uq_user_role UNIQUE (user_id, role_id)
    );
    PRINT '✅ user_roles';
END
ELSE PRINT '⏭  user_roles';
GO
 
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='role_permissions' AND xtype='U')
BEGIN
    CREATE TABLE role_permissions (
        id            UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        role_id       UNIQUEIDENTIFIER NOT NULL REFERENCES roles(id)       ON DELETE CASCADE,
        permission_id UNIQUEIDENTIFIER NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
        CONSTRAINT uq_role_permission UNIQUE (role_id, permission_id)
    );
    PRINT '✅ role_permissions';
END
ELSE PRINT '⏭  role_permissions';
GO
 
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='login_attempts' AND xtype='U')
BEGIN
    CREATE TABLE login_attempts (
        id             UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        user_id        UNIQUEIDENTIFIER NULL REFERENCES users(id) ON DELETE SET NULL,
        ip_address     NVARCHAR(45)     NOT NULL,
        success        BIT              NOT NULL DEFAULT 0,
        failure_reason NVARCHAR(255)    NULL,
        attempted_at   DATETIME2        NOT NULL DEFAULT GETDATE()
    );
    PRINT '✅ login_attempts';
END
ELSE PRINT '⏭  login_attempts';
GO
 
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='activity_logs' AND xtype='U')
BEGIN
    CREATE TABLE activity_logs (
        id         UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        user_id    UNIQUEIDENTIFIER NULL REFERENCES users(id) ON DELETE SET NULL,
        action     NVARCHAR(100)    NOT NULL,
        resource   NVARCHAR(100)    NOT NULL,
        ip_address NVARCHAR(45)     NULL,
        metadata   NVARCHAR(MAX)    NULL,
        created_at DATETIME2        NOT NULL DEFAULT GETDATE()
    );
    PRINT '✅ activity_logs';
END
ELSE PRINT '⏭  activity_logs';
GO
 
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='anomaly_flags' AND xtype='U')
BEGIN
    CREATE TABLE anomaly_flags (
        id              UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        activity_log_id UNIQUEIDENTIFIER NOT NULL REFERENCES activity_logs(id) ON DELETE CASCADE,
        severity        NVARCHAR(20)     NOT NULL CHECK (severity IN ('low','medium','high','critical')),
        type            NVARCHAR(100)    NOT NULL,
        is_resolved     BIT              NOT NULL DEFAULT 0,
        flagged_at      DATETIME2        NOT NULL DEFAULT GETDATE()
    );
    PRINT '✅ anomaly_flags';
END
ELSE PRINT '⏭  anomaly_flags';
GO
 
-- Core indexes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='ix_login_attempts_user_id')
    CREATE INDEX ix_login_attempts_user_id ON login_attempts (user_id);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='ix_login_attempts_ip')
    CREATE INDEX ix_login_attempts_ip      ON login_attempts (ip_address);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='ix_login_attempts_time')
    CREATE INDEX ix_login_attempts_time    ON login_attempts (attempted_at);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='ix_activity_logs_user_id')
    CREATE INDEX ix_activity_logs_user_id  ON activity_logs  (user_id);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='ix_activity_logs_time')
    CREATE INDEX ix_activity_logs_time     ON activity_logs  (created_at);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='ix_anomaly_flags_log')
    CREATE INDEX ix_anomaly_flags_log      ON anomaly_flags  (activity_log_id);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='ix_anomaly_flags_resolved')
    CREATE INDEX ix_anomaly_flags_resolved ON anomaly_flags  (is_resolved);
GO
PRINT '✅ Core indexes';
GO
 
-- ================================================================
--  SECTION 2 — EXAM SYSTEM TABLES
-- ================================================================
 
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='exams' AND xtype='U')
BEGIN
    CREATE TABLE exams (
        id               UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        name             NVARCHAR(200)    NOT NULL,
        description      NVARCHAR(500)    NULL,
        subject          NVARCHAR(150)    NULL,
        start_time       DATETIME2        NOT NULL,
        end_time         DATETIME2        NOT NULL,
        duration_minutes INT              NOT NULL DEFAULT 60,
        created_by       UNIQUEIDENTIFIER NULL REFERENCES users(id) ON DELETE SET NULL,
        is_active        BIT              NOT NULL DEFAULT 1,
        created_at       DATETIME2        NOT NULL DEFAULT GETDATE()
    );
    PRINT '✅ exams';
END
ELSE PRINT '⏭  exams';
GO
 
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='exam_sessions' AND xtype='U')
BEGIN
    CREATE TABLE exam_sessions (
        id             UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        user_id        UNIQUEIDENTIFIER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        exam_id        UNIQUEIDENTIFIER NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
        ip_address     NVARCHAR(45)     NOT NULL,
        device_id      NVARCHAR(255)    NOT NULL DEFAULT 'unknown',
        user_agent     NVARCHAR(500)    NULL,
        start_time     DATETIME2        NOT NULL DEFAULT GETDATE(),
        end_time       DATETIME2        NULL,
        status         NVARCHAR(20)     NOT NULL DEFAULT 'active'
            CHECK (status IN ('active','completed','blocked','terminated')),
        behavior_score INT              NOT NULL DEFAULT 0,
        created_at     DATETIME2        NOT NULL DEFAULT GETDATE()
    );
    PRINT '✅ exam_sessions';
END
ELSE PRINT '⏭  exam_sessions';
GO
 
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='student_events' AND xtype='U')
BEGIN
    CREATE TABLE student_events (
        id         UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        session_id UNIQUEIDENTIFIER NOT NULL REFERENCES exam_sessions(id) ON DELETE CASCADE,
        event_type NVARCHAR(50)     NOT NULL,
        details    NVARCHAR(MAX)    NULL,
        timestamp  DATETIME2        NOT NULL DEFAULT GETDATE()
    );
    PRINT '✅ student_events';
END
ELSE PRINT '⏭  student_events';
GO
 
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='face_analysis' AND xtype='U')
BEGIN
    CREATE TABLE face_analysis (
        id               UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        session_id       UNIQUEIDENTIFIER NOT NULL REFERENCES exam_sessions(id) ON DELETE CASCADE,
        faces_count      INT              NOT NULL,
        eyes_open_ratio  FLOAT            NOT NULL DEFAULT 0,
        head_tilt_angle  FLOAT            NULL,
        mouth_open_ratio FLOAT            NULL,
        ai_risk_score    FLOAT            NULL,
        is_anomalous     BIT              NOT NULL DEFAULT 0,
        analyzed_at      DATETIME2        NOT NULL DEFAULT GETDATE()
    );
    PRINT '✅ face_analysis';
END
ELSE PRINT '⏭  face_analysis';
GO
 
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='exam_access_control' AND xtype='U')
BEGIN
    CREATE TABLE exam_access_control (
        id             UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        exam_id        UNIQUEIDENTIFIER NOT NULL REFERENCES exams(id)  ON DELETE CASCADE,
        user_id        UNIQUEIDENTIFIER NULL REFERENCES users(id)      ON DELETE NO ACTION,
        allowed_ip     NVARCHAR(45)     NULL,
        allowed_device NVARCHAR(255)    NULL,
        action         NVARCHAR(5)      NOT NULL DEFAULT 'ALLOW'
            CHECK (action IN ('ALLOW','DENY')),
        created_at     DATETIME2        NOT NULL DEFAULT GETDATE()
    );
    PRINT '✅ exam_access_control';
END
ELSE PRINT '⏭  exam_access_control';
GO
 
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='cheat_incidents' AND xtype='U')
BEGIN
    CREATE TABLE cheat_incidents (
        id             UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        session_id     UNIQUEIDENTIFIER NOT NULL REFERENCES exam_sessions(id) ON DELETE CASCADE,
        user_id        UNIQUEIDENTIFIER NOT NULL REFERENCES users(id)         ON DELETE NO ACTION,
        exam_id        UNIQUEIDENTIFIER NOT NULL REFERENCES exams(id)         ON DELETE NO ACTION,
        incident_type  NVARCHAR(60)     NOT NULL
            CHECK (incident_type IN (
                'shared_ip','tab_switch','multiple_faces',
                'copy_attempt','devtools_open','window_blur',
                'screenshot_attempt','keyboard_shortcut','new_tab_opened'
            )),
        severity       NVARCHAR(10)     NOT NULL DEFAULT 'medium'
            CHECK (severity IN ('low','medium','high','critical')),
        details        NVARCHAR(MAX)    NULL,
        ip_address     NVARCHAR(45)     NULL,
        alert_number   INT              NOT NULL DEFAULT 1,
        is_reviewed    BIT              NOT NULL DEFAULT 0,
        reviewer_id    UNIQUEIDENTIFIER NULL REFERENCES users(id) ON DELETE NO ACTION,
        reviewed_at    DATETIME2        NULL,
        reviewer_notes NVARCHAR(500)    NULL,
        detected_at    DATETIME2        NOT NULL DEFAULT GETDATE()
    );
    PRINT '✅ cheat_incidents';
END
ELSE PRINT '⏭  cheat_incidents';
GO
 
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='face_analysis_v2' AND xtype='U')
BEGIN
    CREATE TABLE face_analysis_v2 (
        id                UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        session_id        UNIQUEIDENTIFIER NOT NULL REFERENCES exam_sessions(id) ON DELETE CASCADE,
        faces_count       INT              NOT NULL,
        confidence_score  FLOAT            NOT NULL DEFAULT 0,
        head_tilt_angle   FLOAT            NULL,
        mouth_open_ratio  FLOAT            NULL,
        -- 0 faces = NOT a cheat | >1 faces = cheat
        is_multiple_faces BIT              NOT NULL DEFAULT 0,
        incident_id       UNIQUEIDENTIFIER NULL REFERENCES cheat_incidents(id) ON DELETE NO ACTION,
        analyzed_at       DATETIME2        NOT NULL DEFAULT GETDATE()
    );
    PRINT '✅ face_analysis_v2';
END
ELSE PRINT '⏭  face_analysis_v2';
GO
 
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='tab_sessions' AND xtype='U')
BEGIN
    CREATE TABLE tab_sessions (
        id                 UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        session_id         UNIQUEIDENTIFIER NOT NULL REFERENCES exam_sessions(id) ON DELETE CASCADE,
        tab_id             NVARCHAR(100)    NOT NULL,
        device_fingerprint NVARCHAR(255)    NOT NULL,
        opened_at          DATETIME2        NOT NULL DEFAULT GETDATE(),
        closed_at          DATETIME2        NULL,
        is_exam_tab        BIT              NOT NULL DEFAULT 1,
        was_flagged        BIT              NOT NULL DEFAULT 0
    );
    PRINT '✅ tab_sessions';
END
ELSE PRINT '⏭  tab_sessions';
GO
 
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='ip_device_registry' AND xtype='U')
BEGIN
    CREATE TABLE ip_device_registry (
        id                 UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        session_id         UNIQUEIDENTIFIER NOT NULL REFERENCES exam_sessions(id) ON DELETE CASCADE,
        user_id            UNIQUEIDENTIFIER NOT NULL REFERENCES users(id)         ON DELETE NO ACTION,
        exam_id            UNIQUEIDENTIFIER NOT NULL REFERENCES exams(id)         ON DELETE NO ACTION,
        ip_address         NVARCHAR(45)     NOT NULL,
        device_fingerprint NVARCHAR(255)    NOT NULL,
        user_agent         NVARCHAR(500)    NULL,
        first_seen         DATETIME2        NOT NULL DEFAULT GETDATE(),
        last_seen          DATETIME2        NOT NULL DEFAULT GETDATE(),
        is_flagged         BIT              NOT NULL DEFAULT 0
    );
    PRINT '✅ ip_device_registry';
END
ELSE PRINT '⏭  ip_device_registry';
GO
 
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='ip_shared_alerts' AND xtype='U')
BEGIN
    CREATE TABLE ip_shared_alerts (
        id            UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        exam_id       UNIQUEIDENTIFIER NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
        ip_address    NVARCHAR(45)     NOT NULL,
        student_count INT              NOT NULL,
        student_ids   NVARCHAR(MAX)    NOT NULL,
        session_ids   NVARCHAR(MAX)    NOT NULL,
        detected_at   DATETIME2        NOT NULL DEFAULT GETDATE(),
        is_reviewed   BIT              NOT NULL DEFAULT 0
    );
    PRINT '✅ ip_shared_alerts';
END
ELSE PRINT '⏭  ip_shared_alerts';
GO
 
-- Exam system indexes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='IX_exam_sessions_user')
    CREATE INDEX IX_exam_sessions_user      ON exam_sessions      (user_id);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='IX_exam_sessions_exam')
    CREATE INDEX IX_exam_sessions_exam      ON exam_sessions      (exam_id);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='IX_exam_sessions_status')
    CREATE INDEX IX_exam_sessions_status    ON exam_sessions      (status);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='IX_exam_sessions_ip')
    CREATE INDEX IX_exam_sessions_ip        ON exam_sessions      (ip_address);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='IX_cheat_session')
    CREATE INDEX IX_cheat_session           ON cheat_incidents    (session_id);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='IX_cheat_user')
    CREATE INDEX IX_cheat_user              ON cheat_incidents    (user_id);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='IX_cheat_type')
    CREATE INDEX IX_cheat_type              ON cheat_incidents    (incident_type);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='IX_cheat_reviewed')
    CREATE INDEX IX_cheat_reviewed          ON cheat_incidents    (is_reviewed);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='IX_face_v2_session')
    CREATE INDEX IX_face_v2_session         ON face_analysis_v2   (session_id);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='IX_face_v2_multi')
    CREATE INDEX IX_face_v2_multi           ON face_analysis_v2   (is_multiple_faces);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='IX_tab_session')
    CREATE INDEX IX_tab_session             ON tab_sessions        (session_id);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='IX_ip_reg_ip')
    CREATE INDEX IX_ip_reg_ip               ON ip_device_registry  (ip_address);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='IX_ip_reg_exam')
    CREATE INDEX IX_ip_reg_exam             ON ip_device_registry  (exam_id);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='IX_ip_shared_exam')
    CREATE INDEX IX_ip_shared_exam          ON ip_shared_alerts    (exam_id);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='IX_student_events_session')
    CREATE INDEX IX_student_events_session  ON student_events      (session_id);
GO
PRINT '✅ Exam system indexes';
GO
 
-- ================================================================
--  SECTION 3 — STORED PROCEDURES
-- ================================================================
 
IF OBJECT_ID('usp_DetectSharedIP','P') IS NOT NULL DROP PROCEDURE usp_DetectSharedIP;
GO
CREATE PROCEDURE usp_DetectSharedIP
    @exam_id    UNIQUEIDENTIFIER,
    @ip_address NVARCHAR(45)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @student_count INT;
    SELECT @student_count = COUNT(DISTINCT user_id)
    FROM   exam_sessions
    WHERE  exam_id = @exam_id AND ip_address = @ip_address AND status = 'active';
 
    IF @student_count < 2 RETURN;
 
    DECLARE @student_ids NVARCHAR(MAX), @session_ids NVARCHAR(MAX);
    SELECT @student_ids = '[' + STRING_AGG('"' + CAST(user_id AS NVARCHAR(36)) + '"', ',') + ']'
    FROM exam_sessions WHERE exam_id=@exam_id AND ip_address=@ip_address AND status='active';
    SELECT @session_ids = '[' + STRING_AGG('"' + CAST(id AS NVARCHAR(36)) + '"', ',') + ']'
    FROM exam_sessions WHERE exam_id=@exam_id AND ip_address=@ip_address AND status='active';
 
    IF EXISTS (SELECT 1 FROM ip_shared_alerts WHERE exam_id=@exam_id AND ip_address=@ip_address AND is_reviewed=0)
        UPDATE ip_shared_alerts
        SET student_count=@student_count, student_ids=@student_ids, session_ids=@session_ids, detected_at=GETDATE()
        WHERE exam_id=@exam_id AND ip_address=@ip_address AND is_reviewed=0;
    ELSE
        INSERT INTO ip_shared_alerts (exam_id,ip_address,student_count,student_ids,session_ids)
        VALUES (@exam_id,@ip_address,@student_count,@student_ids,@session_ids);
 
    UPDATE ip_device_registry SET is_flagged=1
    WHERE exam_id=@exam_id AND ip_address=@ip_address;
 
    INSERT INTO cheat_incidents (session_id,user_id,exam_id,incident_type,severity,details,ip_address,alert_number)
    SELECT es.id, es.user_id, es.exam_id, 'shared_ip', 'critical',
        N'{"shared_with_count":' + CAST(@student_count AS NVARCHAR(5)) + N',"ip":"' + @ip_address + N'"}',
        @ip_address,
        ISNULL((SELECT MAX(alert_number) FROM cheat_incidents WHERE user_id=es.user_id AND exam_id=es.exam_id),0)+1
    FROM exam_sessions es
    WHERE es.exam_id=@exam_id AND es.ip_address=@ip_address AND es.status='active'
    AND NOT EXISTS (SELECT 1 FROM cheat_incidents ci WHERE ci.session_id=es.id AND ci.incident_type='shared_ip');
END;
GO
PRINT '✅ usp_DetectSharedIP';
GO
 
IF OBJECT_ID('usp_LogCheatIncident','P') IS NOT NULL DROP PROCEDURE usp_LogCheatIncident;
GO
CREATE PROCEDURE usp_LogCheatIncident
    @session_id    UNIQUEIDENTIFIER,
    @incident_type NVARCHAR(60),
    @details       NVARCHAR(MAX) = NULL,
    @ip_address    NVARCHAR(45)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @user_id UNIQUEIDENTIFIER, @exam_id UNIQUEIDENTIFIER;
    SELECT @user_id=user_id, @exam_id=exam_id FROM exam_sessions WHERE id=@session_id;
    IF @user_id IS NULL RETURN;
 
    DECLARE @alert_number INT;
    SELECT @alert_number = ISNULL(MAX(alert_number),0)+1
    FROM cheat_incidents WHERE user_id=@user_id AND exam_id=@exam_id;
 
    DECLARE @severity NVARCHAR(10) = 'medium';
    IF @incident_type IN ('shared_ip','multiple_faces')              SET @severity = 'critical';
    ELSE IF @incident_type IN ('tab_switch','new_tab_opened')        SET @severity = 'high';
    ELSE IF @incident_type IN ('copy_attempt','screenshot_attempt','devtools_open') SET @severity = 'medium';
    ELSE IF @incident_type IN ('window_blur','keyboard_shortcut')    SET @severity = 'low';
    IF @alert_number >= 5 SET @severity = 'critical';
 
    INSERT INTO cheat_incidents
        (session_id,user_id,exam_id,incident_type,severity,details,ip_address,alert_number)
    VALUES (@session_id,@user_id,@exam_id,@incident_type,@severity,@details,@ip_address,@alert_number);
 
    DECLARE @delta INT = 0;
    IF @severity='low'      SET @delta=5;
    IF @severity='medium'   SET @delta=15;
    IF @severity='high'     SET @delta=25;
    IF @severity='critical' SET @delta=50;
    UPDATE exam_sessions SET behavior_score=behavior_score+@delta WHERE id=@session_id;
 
    SELECT ci.id AS incident_id, ci.severity, ci.alert_number, es.behavior_score
    FROM cheat_incidents ci
    JOIN exam_sessions es ON es.id=ci.session_id
    WHERE ci.session_id=@session_id AND ci.incident_type=@incident_type AND ci.alert_number=@alert_number;
END;
GO
PRINT '✅ usp_LogCheatIncident';
GO
 
-- ================================================================
--  SECTION 4 — VIEWS
-- ================================================================
 
IF OBJECT_ID('v_live_exam_dashboard','V') IS NOT NULL DROP VIEW v_live_exam_dashboard;
GO
CREATE VIEW v_live_exam_dashboard AS
SELECT
    es.id AS session_id, u.username, u.full_name, u.email,
    ex.name AS exam_name, ex.subject AS exam_subject,
    es.ip_address, es.device_id, es.status, es.behavior_score, es.start_time,
    SUM(CASE WHEN ci.incident_type='shared_ip'      THEN 1 ELSE 0 END) AS shared_ip_count,
    SUM(CASE WHEN ci.incident_type='tab_switch'     THEN 1 ELSE 0 END) AS tab_switch_count,
    SUM(CASE WHEN ci.incident_type='multiple_faces' THEN 1 ELSE 0 END) AS multiple_faces_count,
    SUM(CASE WHEN ci.incident_type='copy_attempt'   THEN 1 ELSE 0 END) AS copy_attempt_count,
    SUM(CASE WHEN ci.incident_type='new_tab_opened' THEN 1 ELSE 0 END) AS new_tab_count,
    SUM(CASE WHEN ci.incident_type='devtools_open'  THEN 1 ELSE 0 END) AS devtools_count,
    COUNT(ci.id) AS total_incidents,
    (SELECT TOP 1 fv.faces_count FROM face_analysis_v2 fv
     WHERE fv.session_id=es.id ORDER BY fv.analyzed_at DESC) AS last_faces_count,
    CASE WHEN EXISTS (
        SELECT 1 FROM ip_shared_alerts isa
        WHERE isa.exam_id=es.exam_id AND isa.ip_address=es.ip_address AND isa.is_reviewed=0
    ) THEN 1 ELSE 0 END AS shared_ip_flagged
FROM exam_sessions es
JOIN users u  ON u.id=es.user_id
JOIN exams ex ON ex.id=es.exam_id
LEFT JOIN cheat_incidents ci ON ci.session_id=es.id
GROUP BY
    es.id, u.username, u.full_name, u.email,
    ex.name, ex.subject, es.ip_address, es.device_id,
    es.status, es.behavior_score, es.start_time, es.exam_id;
GO
PRINT '✅ v_live_exam_dashboard';
GO
 
IF OBJECT_ID('v_shared_ip_report','V') IS NOT NULL DROP VIEW v_shared_ip_report;
GO
CREATE VIEW v_shared_ip_report AS
SELECT
    ex.name AS exam_name, es.ip_address,
    COUNT(DISTINCT es.user_id) AS student_count,
    STRING_AGG(u.username, ', ') AS student_usernames,
    MIN(es.start_time) AS first_seen, MAX(es.start_time) AS last_seen
FROM exam_sessions es
JOIN exams ex ON ex.id=es.exam_id
JOIN users u  ON u.id=es.user_id
GROUP BY ex.name, es.ip_address
HAVING COUNT(DISTINCT es.user_id) > 1;
GO
PRINT '✅ v_shared_ip_report';
GO
 
IF OBJECT_ID('v_proctor_summary','V') IS NOT NULL DROP VIEW v_proctor_summary;
GO
CREATE VIEW v_proctor_summary AS
SELECT
    COUNT(DISTINCT es.id)                                      AS total_sessions,
    SUM(CASE WHEN es.status='active'    THEN 1 ELSE 0 END)    AS active_sessions,
    SUM(CASE WHEN es.status='completed' THEN 1 ELSE 0 END)    AS completed_sessions,
    COUNT(DISTINCT ci.id)                                      AS total_incidents,
    SUM(CASE WHEN ci.severity='critical' THEN 1 ELSE 0 END)   AS critical_incidents,
    SUM(CASE WHEN ci.is_reviewed=0       THEN 1 ELSE 0 END)   AS unreviewed_incidents,
    COUNT(DISTINCT isa.id)                                     AS shared_ip_alerts
FROM exam_sessions es
LEFT JOIN cheat_incidents  ci  ON ci.session_id=es.id
LEFT JOIN ip_shared_alerts isa ON isa.exam_id=es.exam_id;
GO
PRINT '✅ v_proctor_summary';
GO
 
-- ================================================================
--  SECTION 5 — SEED DATA
-- ================================================================
 
-- Roles
MERGE INTO roles AS t
USING (VALUES
    ('admin',   'Full system access'),
    ('analyst', 'Read logs and anomaly data'),
    ('viewer',  'Read-only access to reports'),
    ('proctor', 'Monitor live exams and review incidents'),
    ('student', 'Take exams — limited to own sessions only')
) AS s(name, description) ON t.name = s.name
WHEN NOT MATCHED THEN INSERT (name, description) VALUES (s.name, s.description);
GO
PRINT '✅ Roles';
 
-- Permissions
MERGE INTO permissions AS t
USING (VALUES
    ('users',       'create',  'Create new users'),
    ('users',       'read',    'View user profiles'),
    ('users',       'update',  'Edit user data'),
    ('users',       'delete',  'Delete users'),
    ('logs',        'read',    'View activity logs'),
    ('anomalies',   'read',    'View anomaly flags'),
    ('anomalies',   'resolve', 'Mark anomalies resolved'),
    ('roles',       'manage',  'Assign and manage roles'),
    ('exams',       'create',  'Create exams'),
    ('exams',       'read',    'View exam details'),
    ('exams',       'manage',  'Edit/delete exams'),
    ('sessions',    'read',    'View exam sessions'),
    ('sessions',    'monitor', 'Live-monitor exam sessions'),
    ('incidents',   'read',    'View cheat incidents'),
    ('incidents',   'review',  'Mark incidents as reviewed'),
    ('face_data',   'read',    'View face analysis records'),
    ('ip_registry', 'read',    'View IP/device registry'),
    ('own_session', 'write',   'Student: submit own exam data')
) AS s(resource, action, description) ON t.resource=s.resource AND t.action=s.action
WHEN NOT MATCHED THEN INSERT (resource, action, description) VALUES (s.resource, s.action, s.description);
GO
PRINT '✅ Permissions';
GO
 
-- Role-Permission wiring
-- admin → all permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.name='admin'
AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.role_id=r.id AND rp.permission_id=p.id);
GO
 
-- proctor → monitor + review
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r
JOIN permissions p ON p.resource IN ('sessions','incidents','face_data','ip_registry','exams','logs')
                  AND p.action   IN ('read','monitor','review')
WHERE r.name='proctor'
AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.role_id=r.id AND rp.permission_id=p.id);
GO
 
-- analyst → read
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r
JOIN permissions p ON p.resource IN ('logs','anomalies','incidents','sessions') AND p.action='read'
WHERE r.name='analyst'
AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.role_id=r.id AND rp.permission_id=p.id);
GO
 
-- viewer → read all
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r
JOIN permissions p ON p.action='read'
WHERE r.name='viewer'
AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.role_id=r.id AND rp.permission_id=p.id);
GO
 
-- student → own_session write
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r
JOIN permissions p ON p.resource='own_session' AND p.action='write'
WHERE r.name='student'
AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.role_id=r.id AND rp.permission_id=p.id);
GO
PRINT '✅ Role-Permission assignments';
GO
 
-- ── ✅ SEED ACCOUNTS ─────────────────────────────────────────────
-- Passwords verified with bcrypt (saltRounds=10):
--   admin123   → $2b$10$VyykDk7pUqNBZw2ChYBiVemVbjAA08ZQZbpg5.dqVlb5OF4w5lH1K
--   proctor123 → $2b$10$XTcUJkgEDZ.xPcJSOJLSMOBTyVEhUkPOq5dsp9IfS9R8N3tqMDf16
--   student123 → $2b$10$GSvV.VSy7ZbLkW7BFeH3T.9MkVRCZEXoXh5ik2wLii9li4I01xsOC
--   analyst123 → $2b$10$b/0zoiCH3KindOwmGGba6O/q0jXnczen8TYHYX1tn0Vs.d6BnZLGe
-- ─────────────────────────────────────────────────────────────────
 
INSERT INTO users (username, email, password_hash, full_name, is_active)
SELECT s.username, s.email, s.password_hash, s.full_name, 1
FROM (VALUES
    ('admin',     'admin@iam.io',      '$2b$10$VyykDk7pUqNBZw2ChYBiVemVbjAA08ZQZbpg5.dqVlb5OF4w5lH1K', 'System Administrator'),
    ('proctor01', 'proctor01@iam.io',  '$2b$10$XTcUJkgEDZ.xPcJSOJLSMOBTyVEhUkPOq5dsp9IfS9R8N3tqMDf16','Dr. Sarah Williams'),
    ('proctor02', 'proctor02@iam.io',  '$2b$10$XTcUJkgEDZ.xPcJSOJLSMOBTyVEhUkPOq5dsp9IfS9R8N3tqMDf16','Prof. James Carter'),
    ('2024001',   's2024001@uni.edu',  '$2b$10$GSvV.VSy7ZbLkW7BFeH3T.9MkVRCZEXoXh5ik2wLii9li4I01xsOC','Ahmed Mohamed Ali'),
    ('2024002',   's2024002@uni.edu',  '$2b$10$GSvV.VSy7ZbLkW7BFeH3T.9MkVRCZEXoXh5ik2wLii9li4I01xsOC','Sara Hassan Ibrahim'),
    ('2024003',   's2024003@uni.edu',  '$2b$10$GSvV.VSy7ZbLkW7BFeH3T.9MkVRCZEXoXh5ik2wLii9li4I01xsOC','Omar Khaled Nasser'),
    ('analyst01', 'analyst01@iam.io',  '$2b$10$b/0zoiCH3KindOwmGGba6O/q0jXnczen8TYHYX1tn0Vs.d6BnZLGe', 'Laila Mostafa')
) AS s(username, email, password_hash, full_name)
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.username = s.username);
GO
PRINT '✅ Users inserted';
GO
 
-- Assign roles to users
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM (VALUES
    ('admin',     'admin'),
    ('admin',     'proctor'),    -- admin can also act as proctor
    ('proctor01', 'proctor'),
    ('proctor02', 'proctor'),
    ('2024001',   'student'),
    ('2024002',   'student'),
    ('2024003',   'student'),
    ('analyst01', 'analyst')
) AS m(uname, rname)
JOIN users u ON u.username = m.uname
JOIN roles r ON r.name     = m.rname
WHERE NOT EXISTS (
    SELECT 1 FROM user_roles ur WHERE ur.user_id=u.id AND ur.role_id=r.id
);
GO
PRINT '✅ User roles assigned';
GO
 
-- Seed Exams
INSERT INTO exams (name, description, subject, start_time, end_time, duration_minutes, created_by, is_active)
SELECT s.name, s.description, s.subject, s.start_time, s.end_time, s.dur, u.id, 1
FROM (VALUES
    ('Information Security 101',
     'Midterm: network security, encryption, IAM fundamentals',
     'Information Security',
     DATEADD(HOUR, 1, GETDATE()), DATEADD(HOUR, 3, GETDATE()), 60),
    ('Advanced Programming',
     'Final: data structures, algorithms, system design',
     'Computer Science',
     DATEADD(HOUR, 2, GETDATE()), DATEADD(HOUR, 5, GETDATE()), 120),
    ('Network Architecture',
     'VPN, routing protocols, access control lists',
     'Networking',
     DATEADD(HOUR, 24, GETDATE()), DATEADD(HOUR, 26, GETDATE()), 90)
) AS s(name, description, subject, start_time, end_time, dur)
CROSS JOIN (SELECT id FROM users WHERE username='admin') u
WHERE NOT EXISTS (SELECT 1 FROM exams e WHERE e.name=s.name);
GO
 
-- ACL rules for all exams
INSERT INTO exam_access_control (exam_id, allowed_ip, action)
SELECT e.id, v.ip, v.act
FROM exams e
CROSS JOIN (VALUES
    ('192.168.1.0', 'ALLOW'),
    ('192.168.2.0', 'ALLOW'),
    ('10.0.0.0',    'ALLOW')
) AS v(ip, act)
WHERE NOT EXISTS (
    SELECT 1 FROM exam_access_control ac WHERE ac.exam_id=e.id AND ac.allowed_ip=v.ip
);
GO
PRINT '✅ Exams + ACL seeded';
GO
 
-- ================================================================
--  SECTION 6 — QUICK REFERENCE
-- ================================================================
PRINT '';
PRINT '================================================================';
PRINT ' ✅ SETUP COMPLETE';
PRINT '================================================================';
PRINT ' ACCOUNTS (username / password):';
PRINT '   admin      / admin123    → roles: admin + proctor';
PRINT '   proctor01  / proctor123  → role: proctor';
PRINT '   proctor02  / proctor123  → role: proctor';
PRINT '   2024001    / student123  → role: student';
PRINT '   2024002    / student123  → role: student';
PRINT '   2024003    / student123  → role: student';
PRINT '   analyst01  / analyst123  → role: analyst';
PRINT '';
PRINT ' QUICK QUERIES:';
PRINT '   SELECT * FROM v_live_exam_dashboard WHERE status=''active'';';
PRINT '   SELECT * FROM v_shared_ip_report;';
PRINT '   SELECT * FROM v_proctor_summary;';
PRINT '================================================================';
GO


UPDATE users SET password_hash = 'student123' WHERE username = '2024001';


UPDATE users 
SET password_hash = 'proctor123' 
WHERE username = 'proctor01';

UPDATE users SET password_hash = 'student123' WHERE username = '2024002';

