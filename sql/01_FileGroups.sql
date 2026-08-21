-------------------------------------------------------------------
-- ExaminationSystemDB - Files & Filegroups
-- Run this FIRST, before any table creation.
-- Adjust folder paths/sizes to match your machine
-- (the folder C:\SQLData\ must already exist).
-------------------------------------------------------------------

use master
go

if DB_ID('ExaminationSystemDB') is not null
begin
	alter database ExaminationSystemDB set single_user with rollback immediate
	drop database ExaminationSystemDB
end
go

-------------------------------------------------------------------
-- Design:
--   PRIMARY filegroup -> system catalog + low-growth master/reference
--                         data: Admin, TrainingManager, Instructor,
--                         Branch, Intake, Course, Track, Student,
--                         CourseAssignment, Exam, TFQuestion, TextQuestion.
--   FG_Data filegroup  -> high-growth transactional data: Question,
--                         MCQChoice, ExamQuestion, StudentExam,
--                         StudentAnswer. These grow continuously as
--                         instructors add questions and students take
--                         exams, so they're isolated on their own file
--                         for I/O separation and independent growth
--                         management.
--   Log file           -> kept outside any filegroup, as usual.
-------------------------------------------------------------------

create database ExaminationSystemDB
on primary
(
	name = N'ExaminationSystemDB_Primary',
	filename = N'C:\SQLData\ExaminationSystemDB_Primary.mdf',
	size = 64MB,
	filegrowth = 32MB
),
filegroup FG_Data
(
	name = N'ExaminationSystemDB_Data',
	filename = N'C:\SQLData\ExaminationSystemDB_Data.ndf',
	size = 128MB,
	filegrowth = 64MB
)
log on
(
	name = N'ExaminationSystemDB_Log',
	filename = N'C:\SQLData\ExaminationSystemDB_Log.ldf',
	size = 64MB,
	filegrowth = 32MB
)
go

-- Make FG_Data the default filegroup, so any CREATE TABLE with
-- no explicit ON clause (in the next script) lands on FG_Data automatically.
alter database ExaminationSystemDB modify filegroup FG_Data default
go

use ExaminationSystemDB
go

print '=== Database created with PRIMARY + FG_Data filegroups. FG_Data is now the default filegroup. ==='
go

-------------------------------------------------------------------
-- Run order for the whole project:
--   1) THIS FILE
--   2) 02_ExaminationSystem_Build_Schema_Objects.sql
--   3) 03_ExaminationSystem_Security_Setup.sql
--   4) 04_ExaminationSystem_Backup_Job.sql
--   5) 05_ExaminationSystem_Test_Execution.sql   (optional, for testing)
--   6) 06_ExaminationSystem_Verification_Queries.sql (optional, sanity checks)
--
-- Filegroup placement in script 2:
--   - Low-growth tables (Admin, TrainingManager, Instructor, Branch,
--     Intake, Course, Track, Student, CourseAssignment, Exam,
--     TFQuestion, TextQuestion) are explicitly placed "on [PRIMARY]".
--   - High-growth tables (Question, MCQChoice, ExamQuestion,
--     StudentExam, StudentAnswer) have no ON clause, so they land on
--     FG_Data automatically since it's now the default filegroup.
-------------------------------------------------------------------
