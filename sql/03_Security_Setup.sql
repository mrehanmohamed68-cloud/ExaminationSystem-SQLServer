-------------------------------------------------------------------
-- ExaminationSystemDB - Security: Logins, Users, Roles, Permissions
--
-- >>> PREREQUISITE: 01_ExaminationSystem_FileGroups.sql and
-- >>> 02_ExaminationSystem_Build_Schema_Objects.sql (tables, triggers,
-- >>> indexes, functions, procedures, and views) must have already
-- >>> been run successfully against ExaminationSystemDB before this
-- >>> script. If you get "Cannot find the object ... because it does
-- >>> not exist", it means step 2 was skipped or failed - go run
-- >>> that first, then come back to this file.
--
-- This implements exactly what is documented in "Examination System
-- - Security & Access Control Guide".
-------------------------------------------------------------------

use master
go

-- 1) Server-level logins (placeholder passwords - CHANGE before any
--    real deployment; see Accounts_and_Passwords.txt)
-- Idempotent: safe to re-run even if these logins already exist from
-- a previous attempt.
if not exists (select 1 from sys.server_principals where name = N'ExamSystem_Admin')
	create login ExamSystem_Admin      with password = 'ChangeMe_Admin@12345',      check_policy = off
if not exists (select 1 from sys.server_principals where name = N'ExamSystem_Manager')
	create login ExamSystem_Manager    with password = 'ChangeMe_Manager@12345',    check_policy = off
if not exists (select 1 from sys.server_principals where name = N'ExamSystem_Instructor')
	create login ExamSystem_Instructor with password = 'ChangeMe_Instructor@12345', check_policy = off
if not exists (select 1 from sys.server_principals where name = N'ExamSystem_Student')
	create login ExamSystem_Student    with password = 'ChangeMe_Student@12345',    check_policy = off
go

use ExaminationSystemDB
go

-- 2) Database users mapped 1:1 to the logins above (idempotent)
if not exists (select 1 from sys.database_principals where name = N'ExamSystem_Admin')
	create user ExamSystem_Admin      for login ExamSystem_Admin
if not exists (select 1 from sys.database_principals where name = N'ExamSystem_Manager')
	create user ExamSystem_Manager    for login ExamSystem_Manager
if not exists (select 1 from sys.database_principals where name = N'ExamSystem_Instructor')
	create user ExamSystem_Instructor for login ExamSystem_Instructor
if not exists (select 1 from sys.database_principals where name = N'ExamSystem_Student')
	create user ExamSystem_Student    for login ExamSystem_Student
go

-- 3) Database roles (idempotent)
if not exists (select 1 from sys.database_principals where name = N'ExamAdminRole')
	create role ExamAdminRole
if not exists (select 1 from sys.database_principals where name = N'TrainingManagerRole')
	create role TrainingManagerRole
if not exists (select 1 from sys.database_principals where name = N'InstructorRole')
	create role InstructorRole
if not exists (select 1 from sys.database_principals where name = N'StudentRole')
	create role StudentRole
go

alter role ExamAdminRole       add member ExamSystem_Admin
alter role TrainingManagerRole add member ExamSystem_Manager
alter role InstructorRole      add member ExamSystem_Instructor
alter role StudentRole         add member ExamSystem_Student
go

-------------------------------------------------------------------
-- 4) ExamAdminRole - full direct table access, every table in dbo
-------------------------------------------------------------------
grant select, insert, update, delete on schema :: dbo to ExamAdminRole
go

-------------------------------------------------------------------
-- 5) TrainingManagerRole - EXECUTE on its procedures + SELECT on
--    QuestionPool. No direct table grants are given anywhere below,
--    so table access stays denied by default for this role.
-------------------------------------------------------------------
grant execute on SP_CreateQuestion  to TrainingManagerRole
grant execute on SP_AddBranch       to TrainingManagerRole
grant execute on SP_UpdateBranch    to TrainingManagerRole
grant execute on SP_AddTrack        to TrainingManagerRole
grant execute on SP_UpdateTrack     to TrainingManagerRole
grant execute on SP_AddIntake       to TrainingManagerRole
grant execute on SP_AddStudent      to TrainingManagerRole
grant execute on SP_UpdateStudent   to TrainingManagerRole
grant execute on SP_SearchStudents  to TrainingManagerRole
grant select  on QuestionPool       to TrainingManagerRole
go

-------------------------------------------------------------------
-- 6) InstructorRole - EXECUTE on its procedures + SELECT on 4 views
-------------------------------------------------------------------
grant execute on SP_CreateQuestion      to InstructorRole
grant execute on SP_GenerateRandomExam  to InstructorRole
grant execute on SP_CreateManualExam    to InstructorRole
grant execute on SP_AssignStudentToExam to InstructorRole
grant execute on SP_GradeStudentExam    to InstructorRole
grant execute on SP_MarkTextAnswer      to InstructorRole
grant execute on SP_SearchExams         to InstructorRole
grant execute on SP_SearchQuestions     to InstructorRole
grant select  on QuestionPool           to InstructorRole
grant select  on ExamDetails            to InstructorRole
grant select  on ExamQuestions          to InstructorRole
grant select  on TextAnswersForReview   to InstructorRole
go

-------------------------------------------------------------------
-- 7) StudentRole - EXECUTE on SP_SaveStudentAnswer/SP_SearchExams
--    + SELECT on 3 views
-------------------------------------------------------------------
grant execute on SP_SaveStudentAnswer to StudentRole
grant execute on SP_SearchExams       to StudentRole
grant select  on ExamDetails          to StudentRole
grant select  on ExamQuestions        to StudentRole
grant select  on StudentResults       to StudentRole
go

-------------------------------------------------------------------
-- NOTE on "deny by default":
-- TrainingManagerRole / InstructorRole / StudentRole never receive a
-- GRANT on any table, so SQL Server's default-deny already blocks
-- direct table access for them - this is why the procedures above
-- are all created "with execute as owner" (ownership chaining lets
-- them touch the tables on the role's behalf). Do NOT add any
-- table-level GRANT to these three roles later; that would silently
-- reopen the direct-access hole the whole design is built to close.
-------------------------------------------------------------------

print '=== Security setup complete: 4 logins, 4 users, 4 roles, permissions granted per the Security & Access Control Guide. ==='
go
