-------------------------------------------------------------------
-- Examination System Database - TEST EXECUTION SCRIPT
-- Covers 72 test cases across constraints, triggers, procedures,
-- and functions.
--
-- How to use:
--   1) Run 01_ExaminationSystem_FileGroups.sql (drops and recreates
--      the database from scratch)
--   2) Run 02_ExaminationSystem_Build_Schema_Objects.sql
--      (creates tables, triggers, procs, views + seed data, ending
--      with its own baseline "Test Run" - REQUIRED before this
--      script: Br_Id=1, Trk_Id=1, Int_Id=1, Crs_Id=1, Ins_Id=1,
--      St_Id=1, Asg_Id=1, Q_Id 1-3, Exm_Id=1, SE_Id=1)
--   3) (optional) Run 07_ExaminationSystem_BugFix_Patch.sql only if
--      you're testing against an older copy of the database built
--      before that patch - 02 already includes the fix.
--   4) Run this script (F5) in SQL Server Management Studio.
--   5) Open the "Messages" tab (not "Results") to read the verdicts.
--   6) Each block prints one of:
--        '... PASSED (failed as expected)'      -> correct
--        '... PASSED (succeeded as expected)'    -> correct
--        '... FAILED - UNEXPECTED SUCCESS'        -> bug!
--        '... FAILED - UNEXPECTED ERROR'          -> bug!
--
-- NOTE: TC-20 and TC-53..TC-56 look up IDs by their distinguishing
-- values (St_User / Exam start-end-branch-track) instead of hardcoding
-- them, since earlier failed inserts (TC-15, TC-17) still consume
-- IDENTITY values and would shift a hardcoded Id.
-------------------------------------------------------------------

use ExaminationSystemDB
go

set nocount on
go

-------------------------------------------------------------------
-- SECTION 0 : Extra seed data needed for cross-entity test cases
-- (kept separate from the original seed so IDs 1 are undisturbed)
-------------------------------------------------------------------

insert into Branch (Br_Name, Br_Location) values (N'Second Campus', N'Alexandria')            -- Br_Id = 2
insert into Intake (Int_Name, Int_StartDate) values (N'Intake 45', '2026-06-01')               -- Int_Id = 2
insert into Track (Trk_Name, Trk_BrId) values (N'Other Track', 2)                              -- Trk_Id = 2 (Branch 2)

insert into Course (Crs_Name, Crs_Desc, Crs_MaxDeg, Crs_MinDeg)
values (N'Web Development', N'HTML/CSS/JS', 50.00, 25.00)                                      -- Crs_Id = 2

insert into Instructor (Ins_User, Ins_Pass, Ins_Name, Ins_Email, Ins_Phone)
values ('inst_sara', 'Instructor@123', N'Sara Adel', 'sara@test.com', '01022222222')            -- Ins_Id = 2

insert into CourseAssignment (Asg_CrsId, Asg_InsId, Asg_Year) values (2, 2, 2026)               -- Asg_Id = 2

insert into Question (Q_CrsId, Q_Type, Q_Text, Q_CreatedBy)
values (2, 'MCQ', N'What does HTML stand for?', 2)                                             -- Q_Id = 4 (Course 2)
insert into MCQChoice (Ch_QId, Ch_Text, Ch_Correct)
values (4, N'Hyper Text Markup Language', 1)                                                    -- Ch_Id = 5

insert into Question (Q_CrsId, Q_Type, Q_Text, Q_CreatedBy)
values (1, 'Text', N'Explain a Foreign Key.', 1)                                               -- Q_Id = 5 (Course 1, not in any exam)
insert into TextQuestion (Txt_QId, Txt_BestAnswer)
values (5, N'A column that references the primary key of another table.')

insert into Question (Q_CrsId, Q_Type, Q_Text, Q_CreatedBy)
values (1, 'MCQ', N'What does DDL stand for?', 1)                                              -- Q_Id = 6 (Course 1, no choices yet)

insert into Student (St_User, St_Pass, St_Name, St_Email, St_Phone, St_BrId, St_TrkId, St_IntId)
values ('student2', 'Student@123', N'Sara Mostafa', 'sara2@test.com', '01033333333', 2, 2, 2)   -- St_Id = 2 (Branch 2)

insert into Student (St_User, St_Pass, St_Name, St_Email, St_Phone, St_BrId, St_TrkId, St_IntId)
values ('student3', 'Student@123', N'Omar Khaled', 'omar@test.com', '01044444444', 1, 1, 1)     -- St_Id = 3 (matches Exam 1's Br/Trk/Int)

-- a second, independent exam (Course 1 / Asg 1) to run Student/Answer level tests on
-- without touching the seed data created by the original script's Test Run section
declare @Exm2Start datetime = dateadd(minute, -5, getdate())
declare @Exm2End   datetime = dateadd(hour, 3, getdate())

insert into Exam (Exm_AsgId, Exm_Type, Exm_IntId, Exm_BrId, Exm_TrkId, Exm_Start, Exm_End, Exm_TotalTime, Exm_Allowance)
values (1, 'Exam', 1, 1, 1, @Exm2Start, @Exm2End, 180, N'None')                                  -- Exm_Id = 2

insert into ExamQuestion (EQ_ExmId, EQ_QId, EQ_Degree) values (2, 1, 10)   -- MCQ
insert into ExamQuestion (EQ_ExmId, EQ_QId, EQ_Degree) values (2, 2, 10)   -- TF
insert into ExamQuestion (EQ_ExmId, EQ_QId, EQ_Degree) values (2, 3, 10)   -- Text

declare @StoredStart2 datetime, @StoredEnd2 datetime
select @StoredStart2 = Exm_Start, @StoredEnd2 = Exm_End from Exam where Exm_Id = 2

insert into StudentExam (SE_ExmId, SE_StId, SE_Date, SE_Start, SE_End)
values (2, 1, cast(@StoredStart2 as date), cast(@StoredStart2 as time), cast(@StoredEnd2 as time)) -- SE_Id = 2

-- a duplicate answer used only as setup so TC-12 has something to collide with
insert into StudentAnswer (Ans_SEId, Ans_QId, Ans_BoolAns) values (2, 2, 1)

print '=== Setup complete. Starting test cases. ==='
go

-------------------------------------------------------------------
-- SECTION 1 : TABLE CONSTRAINT TEST CASES  (TC-01 .. TC-14)
-------------------------------------------------------------------

-- TC-01 : Course, MinDeg > MaxDeg -> expect FAIL
begin try
    insert into Course (Crs_Name, Crs_Desc, Crs_MaxDeg, Crs_MinDeg) values (N'TC01 Bad Course', null, 50, 80)
    print 'TC-01 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-01 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-02 : Course, valid MinDeg/MaxDeg -> expect PASS
begin try
    insert into Course (Crs_Name, Crs_Desc, Crs_MaxDeg, Crs_MinDeg) values (N'TC02 Good Course', null, 100, 50)
    print 'TC-02 PASSED (succeeded as expected)'
end try
begin catch
    print 'TC-02 FAILED - UNEXPECTED ERROR -> ' + error_message()
end catch
go

-- TC-03 : Exam, End <= Start -> expect FAIL
begin try
    insert into Exam (Exm_AsgId, Exm_Type, Exm_IntId, Exm_BrId, Exm_TrkId, Exm_Start, Exm_End, Exm_TotalTime, Exm_Allowance)
    values (1, 'Exam', 1, 1, 1, '2026-09-01 09:00', '2026-09-01 08:00', 60, null)
    print 'TC-03 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-03 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-04 : Exam, TotalTime = 0 -> expect FAIL
begin try
    insert into Exam (Exm_AsgId, Exm_Type, Exm_IntId, Exm_BrId, Exm_TrkId, Exm_Start, Exm_End, Exm_TotalTime, Exm_Allowance)
    values (1, 'Exam', 1, 1, 1, '2026-09-01 09:00', '2026-09-01 11:00', 0, null)
    print 'TC-04 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-04 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-05 : Exam, invalid Exm_Type -> expect FAIL
begin try
    insert into Exam (Exm_AsgId, Exm_Type, Exm_IntId, Exm_BrId, Exm_TrkId, Exm_Start, Exm_End, Exm_TotalTime, Exm_Allowance)
    values (1, 'Quiz', 1, 1, 1, '2026-09-01 09:00', '2026-09-01 11:00', 60, null)
    print 'TC-05 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-05 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-06 : Question, invalid Q_Type -> expect FAIL
begin try
    insert into Question (Q_CrsId, Q_Type, Q_Text, Q_CreatedBy) values (1, 'Essay', N'bad type test', 1)
    print 'TC-06 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-06 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-07 : ExamQuestion, Degree = 0 -> expect FAIL
begin try
    insert into ExamQuestion (EQ_ExmId, EQ_QId, EQ_Degree) values (1, 5, 0)
    print 'TC-07 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-07 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-08 : ExamQuestion, duplicate (EQ_ExmId, EQ_QId) -> expect FAIL
begin try
    insert into ExamQuestion (EQ_ExmId, EQ_QId, EQ_Degree) values (1, 1, 10)  -- Q_Id 1 already on Exam 1
    print 'TC-08 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-08 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-09 : StudentExam, End <= Start -> expect FAIL
begin try
    insert into StudentExam (SE_ExmId, SE_StId, SE_Date, SE_Start, SE_End)
    values (2, 3, cast(getdate() as date), '10:00', '09:00')
    print 'TC-09 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-09 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-10 : StudentExam, duplicate (SE_ExmId, SE_StId) -> expect FAIL
begin try
    insert into StudentExam (SE_ExmId, SE_StId, SE_Date, SE_Start, SE_End)
    values (2, 1, cast(getdate() as date), '09:00', '10:00')  -- St_Id 1 already on Exam 2
    print 'TC-10 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-10 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-11 : StudentAnswer, Degree < 0 -> expect FAIL
begin try
    insert into StudentAnswer (Ans_SEId, Ans_QId, Ans_TextAns, Ans_Degree) values (2, 3, N'test answer', -5)
    print 'TC-11 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-11 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-12 : StudentAnswer, duplicate (Ans_SEId, Ans_QId) -> expect FAIL
begin try
    insert into StudentAnswer (Ans_SEId, Ans_QId, Ans_BoolAns) values (2, 2, 0)  -- (2,2) already exists from setup
    print 'TC-12 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-12 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-13 : MCQChoice, second correct choice for the same question -> expect FAIL
begin try
    insert into MCQChoice (Ch_QId, Ch_Text, Ch_Correct) values (1, N'Another correct?', 1)  -- Q_Id 1 already has a correct choice
    print 'TC-13 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-13 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-14 : MCQChoice, one correct choice for a fresh question -> expect PASS
begin try
    insert into MCQChoice (Ch_QId, Ch_Text, Ch_Correct) values (6, N'Data Definition Language', 1)  -- Q_Id 6, no choices yet
    print 'TC-14 PASSED (succeeded as expected)'
end try
begin catch
    print 'TC-14 FAILED - UNEXPECTED ERROR -> ' + error_message()
end catch
go

-------------------------------------------------------------------
-- SECTION 2 : TRIGGER TEST CASES  (TC-15 .. TC-33)
-------------------------------------------------------------------

-- TC-15 : TR_Student_TrackBranchMatch -> expect FAIL (Track 2 belongs to Branch 2, not Branch 1)
begin try
    insert into Student (St_User, St_Pass, St_Name, St_Email, St_Phone, St_BrId, St_TrkId, St_IntId)
    values ('tc15_student', 'Pass@123', N'TC15 Student', 'tc15@test.com', null, 1, 2, 1)
    print 'TC-15 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-15 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-16 : TR_Student_TrackBranchMatch -> expect PASS (matching Branch/Track)
-- NOTE: the actual St_Id is NOT guaranteed to be 4, because TC-15's failed
-- insert still consumes an IDENTITY value. TC-20 looks this student up by
-- St_User instead of assuming a fixed Id.
begin try
    insert into Student (St_User, St_Pass, St_Name, St_Email, St_Phone, St_BrId, St_TrkId, St_IntId)
    values ('tc16_student', 'Pass@123', N'TC16 Student', 'tc16@test.com', null, 1, 1, 1)
    print 'TC-16 PASSED (succeeded as expected)'
end try
begin catch
    print 'TC-16 FAILED - UNEXPECTED ERROR -> ' + error_message()
end catch
go

-- TC-17 : TR_Exam_TrackBranchMatch -> expect FAIL (Track 2 belongs to Branch 2, not Branch 1)
begin try
    insert into Exam (Exm_AsgId, Exm_Type, Exm_IntId, Exm_BrId, Exm_TrkId, Exm_Start, Exm_End, Exm_TotalTime, Exm_Allowance)
    values (1, 'Exam', 1, 1, 2, '2026-09-05 09:00', '2026-09-05 11:00', 60, null)
    print 'TC-17 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-17 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-18 : TR_Exam_TrackBranchMatch -> expect PASS (matching Branch/Track)
-- NOTE: the actual Exm_Id is NOT guaranteed to be 3, for the same reason as
-- above. TC-53..TC-56 look this exam up by its distinguishing values instead
-- of assuming a fixed Id.
begin try
    insert into Exam (Exm_AsgId, Exm_Type, Exm_IntId, Exm_BrId, Exm_TrkId, Exm_Start, Exm_End, Exm_TotalTime, Exm_Allowance)
    values (1, 'Exam', 1, 1, 1, '2026-09-05 09:00', '2026-09-05 11:00', 60, null)
    print 'TC-18 PASSED (succeeded as expected)'
end try
begin catch
    print 'TC-18 FAILED - UNEXPECTED ERROR -> ' + error_message()
end catch
go

-- TC-19 : TR_StudentExam_ValidateStudent -> expect FAIL (Student 2 belongs to Branch 2/Track 2/Intake 2)
begin try
    insert into StudentExam (SE_ExmId, SE_StId, SE_Date, SE_Start, SE_End)
    values (1, 2, cast(getdate() as date), '09:00', '10:00')
    print 'TC-19 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-19 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-20 : TR_StudentExam_ValidateStudent -> expect PASS
-- (student created in TC-16, matches Exam 2's Br/Trk/Int) - looked up by St_User, not a hardcoded Id
begin try
    declare @tc20_stid int
    select @tc20_stid = St_Id from Student where St_User = 'tc16_student'

    insert into StudentExam (SE_ExmId, SE_StId, SE_Date, SE_Start, SE_End)
    values (2, @tc20_stid, cast(getdate() as date), '09:00', '10:00')
    print 'TC-20 PASSED (succeeded as expected)'
end try
begin catch
    print 'TC-20 FAILED - UNEXPECTED ERROR -> ' + error_message()
end catch
go

-- TC-21 : TR_ExamQuestion_ValidateCourse -> expect FAIL (Q_Id 4 belongs to Course 2, Exam 2 is Course 1)
begin try
    insert into ExamQuestion (EQ_ExmId, EQ_QId, EQ_Degree) values (2, 4, 5)
    print 'TC-21 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-21 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-22 : TR_ExamQuestion_ValidateCourse -> expect PASS (Q_Id 6 belongs to Course 1, same as Exam 2)
begin try
    insert into ExamQuestion (EQ_ExmId, EQ_QId, EQ_Degree) values (2, 6, 10)
    print 'TC-22 PASSED (succeeded as expected)'
end try
begin catch
    print 'TC-22 FAILED - UNEXPECTED ERROR -> ' + error_message()
end catch
go

-- TC-23 : TR_ExamQuestion_CheckMaxDegree -> expect FAIL (Exam 2 total is now 40; Course 1 max is 100)
begin try
    insert into ExamQuestion (EQ_ExmId, EQ_QId, EQ_Degree) values (2, 5, 100)
    print 'TC-23 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-23 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-24 : TR_ExamQuestion_CheckMaxDegree -> expect PASS (deleting a row keeps the total within range)
begin try
    delete from ExamQuestion where EQ_ExmId = 2 and EQ_QId = 6
    print 'TC-24 PASSED (succeeded as expected)'
end try
begin catch
    print 'TC-24 FAILED - UNEXPECTED ERROR -> ' + error_message()
end catch
go

-- TC-25 : TR_Question_InstructorCourseCheck -> expect FAIL (Instructor 2 is not assigned to Course 1)
begin try
    insert into Question (Q_CrsId, Q_Type, Q_Text, Q_CreatedBy) values (1, 'MCQ', N'TC25 question', 2)
    print 'TC-25 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-25 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-26 : TR_Question_InstructorCourseCheck -> expect PASS (Instructor 2 IS assigned to Course 2)
begin try
    insert into Question (Q_CrsId, Q_Type, Q_Text, Q_CreatedBy) values (2, 'MCQ', N'TC26 question', 2)
    print 'TC-26 PASSED (succeeded as expected)'
end try
begin catch
    print 'TC-26 FAILED - UNEXPECTED ERROR -> ' + error_message()
end catch
go

-- TC-27 : TR_TFQuestion_TypeCheck -> expect FAIL (Q_Id 1 is an MCQ question)
begin try
    insert into TFQuestion (TF_QId, TF_Correct) values (1, 1)
    print 'TC-27 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-27 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-28 : TR_TextQuestion_TypeCheck -> expect FAIL (Q_Id 1 is an MCQ question)
begin try
    insert into TextQuestion (Txt_QId, Txt_BestAnswer) values (1, N'wrong sub type')
    print 'TC-28 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-28 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-29 : TR_MCQChoice_TypeCheck -> expect FAIL (Q_Id 2 is a TF question)
begin try
    insert into MCQChoice (Ch_QId, Ch_Text, Ch_Correct) values (2, N'wrong sub type', 0)
    print 'TC-29 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-29 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-30 : TR_StudentAnswer_Validate (question not in exam) -> expect FAIL (Q_Id 5 is not part of Exam 2)
begin try
    insert into StudentAnswer (Ans_SEId, Ans_QId, Ans_TextAns) values (2, 5, N'answer to a question not on my exam')
    print 'TC-30 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-30 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-31 : TR_StudentAnswer_Validate (choice belongs to a different question) -> expect FAIL
begin try
    insert into StudentAnswer (Ans_SEId, Ans_QId, Ans_ChoiceId) values (2, 1, 5)   -- Ch_Id 5 belongs to Q_Id 4, not Q_Id 1
    print 'TC-31 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-31 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-32 : TR_StudentAnswer_Validate (fields do not match question type) -> expect FAIL
begin try
    insert into StudentAnswer (Ans_SEId, Ans_QId, Ans_ChoiceId, Ans_TextAns) values (2, 1, 1, N'should not be set for MCQ')
    print 'TC-32 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-32 PASSED (failed as expected) -> ' + error_message()
end catch
go

-- TC-33 : TR_StudentAnswer_Validate (fully valid answer) -> expect PASS
begin try
    insert into StudentAnswer (Ans_SEId, Ans_QId, Ans_ChoiceId) values (2, 1, 1)
    print 'TC-33 PASSED (succeeded as expected)'
end try
begin catch
    print 'TC-33 FAILED - UNEXPECTED ERROR -> ' + error_message()
end catch
go

-------------------------------------------------------------------
-- SECTION 3 : STORED PROCEDURE TEST CASES  (TC-34 .. TC-67)
-------------------------------------------------------------------

-- TC-34 : SP_CreateQuestion, instructor not assigned to course -> expect THROW 50001
begin try
    exec SP_CreateQuestion @CrsId = 1, @QType = 'MCQ', @QText = N'tc34', @CreatedBy = 2
    print 'TC-34 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-34 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-35 : SP_CreateQuestion, invalid type -> expect THROW 50002
begin try
    exec SP_CreateQuestion @CrsId = 1, @QType = 'Essay', @QText = N'tc35', @CreatedBy = 1
    print 'TC-35 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-35 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-36 : SP_CreateQuestion, valid -> expect PASS
begin try
    exec SP_CreateQuestion @CrsId = 1, @QType = 'TF', @QText = N'tc36 new tf question', @CreatedBy = 1
    print 'TC-36 PASSED (succeeded as expected)'
end try
begin catch
    print 'TC-36 FAILED - UNEXPECTED ERROR -> ' + error_message()
end catch
go

-- TC-37 : SP_GenerateRandomExam, invalid AsgId -> expect THROW 50010
begin try
    exec SP_GenerateRandomExam @AsgId = 9999, @ExmType = 'Exam', @IntId = 1, @BrId = 1, @TrkId = 1,
         @Start = '2026-10-01 09:00', @End = '2026-10-01 11:00', @TotalTime = 60,
         @NumMCQ = 1, @NumTF = 0, @NumText = 0, @DegreePerQ = 5
    print 'TC-37 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-37 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-38 : SP_GenerateRandomExam, negative count -> expect THROW 50011
begin try
    exec SP_GenerateRandomExam @AsgId = 1, @ExmType = 'Exam', @IntId = 1, @BrId = 1, @TrkId = 1,
         @Start = '2026-10-01 09:00', @End = '2026-10-01 11:00', @TotalTime = 60,
         @NumMCQ = -1, @NumTF = 0, @NumText = 0, @DegreePerQ = 5
    print 'TC-38 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-38 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-39 : SP_GenerateRandomExam, DegreePerQ = 0 -> expect THROW 50012
begin try
    exec SP_GenerateRandomExam @AsgId = 1, @ExmType = 'Exam', @IntId = 1, @BrId = 1, @TrkId = 1,
         @Start = '2026-10-01 09:00', @End = '2026-10-01 11:00', @TotalTime = 60,
         @NumMCQ = 1, @NumTF = 0, @NumText = 0, @DegreePerQ = 0
    print 'TC-39 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-39 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-40 : SP_GenerateRandomExam, Start >= End -> expect THROW 50013
begin try
    exec SP_GenerateRandomExam @AsgId = 1, @ExmType = 'Exam', @IntId = 1, @BrId = 1, @TrkId = 1,
         @Start = '2026-10-01 11:00', @End = '2026-10-01 09:00', @TotalTime = 60,
         @NumMCQ = 1, @NumTF = 0, @NumText = 0, @DegreePerQ = 5
    print 'TC-40 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-40 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-41 : SP_GenerateRandomExam, TotalTime = 0 -> expect THROW 50014
begin try
    exec SP_GenerateRandomExam @AsgId = 1, @ExmType = 'Exam', @IntId = 1, @BrId = 1, @TrkId = 1,
         @Start = '2026-10-01 09:00', @End = '2026-10-01 11:00', @TotalTime = 0,
         @NumMCQ = 1, @NumTF = 0, @NumText = 0, @DegreePerQ = 5
    print 'TC-41 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-41 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-42 : SP_GenerateRandomExam, zero questions requested -> expect THROW 50015
begin try
    exec SP_GenerateRandomExam @AsgId = 1, @ExmType = 'Exam', @IntId = 1, @BrId = 1, @TrkId = 1,
         @Start = '2026-10-01 09:00', @End = '2026-10-01 11:00', @TotalTime = 60,
         @NumMCQ = 0, @NumTF = 0, @NumText = 0, @DegreePerQ = 5
    print 'TC-42 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-42 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-43 : SP_GenerateRandomExam, total degree exceeds Course max (100) -> expect THROW 50016
begin try
    exec SP_GenerateRandomExam @AsgId = 1, @ExmType = 'Exam', @IntId = 1, @BrId = 1, @TrkId = 1,
         @Start = '2026-10-01 09:00', @End = '2026-10-01 11:00', @TotalTime = 60,
         @NumMCQ = 1, @NumTF = 1, @NumText = 1, @DegreePerQ = 40
    print 'TC-43 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-43 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-44 : SP_GenerateRandomExam, not enough MCQ in pool -> expect THROW 50017
begin try
    exec SP_GenerateRandomExam @AsgId = 1, @ExmType = 'Exam', @IntId = 1, @BrId = 1, @TrkId = 1,
         @Start = '2026-10-01 09:00', @End = '2026-10-01 11:00', @TotalTime = 60,
         @NumMCQ = 50, @NumTF = 0, @NumText = 0, @DegreePerQ = 1
    print 'TC-44 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-44 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-45 : SP_GenerateRandomExam, not enough TF in pool -> expect THROW 50018
begin try
    exec SP_GenerateRandomExam @AsgId = 1, @ExmType = 'Exam', @IntId = 1, @BrId = 1, @TrkId = 1,
         @Start = '2026-10-01 09:00', @End = '2026-10-01 11:00', @TotalTime = 60,
         @NumMCQ = 0, @NumTF = 50, @NumText = 0, @DegreePerQ = 1
    print 'TC-45 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-45 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-46 : SP_GenerateRandomExam, not enough Text in pool -> expect THROW 50019
begin try
    exec SP_GenerateRandomExam @AsgId = 1, @ExmType = 'Exam', @IntId = 1, @BrId = 1, @TrkId = 1,
         @Start = '2026-10-01 09:00', @End = '2026-10-01 11:00', @TotalTime = 60,
         @NumMCQ = 0, @NumTF = 0, @NumText = 50, @DegreePerQ = 1
    print 'TC-46 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-46 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-47 : SP_GenerateRandomExam, valid parameters -> expect PASS
begin try
    exec SP_GenerateRandomExam @AsgId = 1, @ExmType = 'Exam', @IntId = 1, @BrId = 1, @TrkId = 1,
         @Start = '2026-10-01 09:00', @End = '2026-10-01 11:00', @TotalTime = 60,
         @NumMCQ = 1, @NumTF = 0, @NumText = 0, @DegreePerQ = 5
    print 'TC-47 PASSED (succeeded as expected)'
end try
begin catch
    print 'TC-47 FAILED - UNEXPECTED ERROR -> ' + error_message()
end catch
go

-- TC-48 : SP_CreateManualExam, invalid AsgId -> expect THROW 50100
begin try
    declare @q1 QuestionListType
    insert into @q1 values (1, 10)
    exec SP_CreateManualExam @AsgId = 9999, @ExmType = 'Exam', @IntId = 1, @BrId = 1, @TrkId = 1,
         @Start = '2026-10-02 09:00', @End = '2026-10-02 11:00', @TotalTime = 60, @Allowance = null, @Questions = @q1
    print 'TC-48 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-48 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-49 : SP_CreateManualExam, total degree exceeds Course max -> expect THROW 50101
begin try
    declare @q2 QuestionListType
    insert into @q2 values (1, 60), (2, 60)
    exec SP_CreateManualExam @AsgId = 1, @ExmType = 'Exam', @IntId = 1, @BrId = 1, @TrkId = 1,
         @Start = '2026-10-02 09:00', @End = '2026-10-02 11:00', @TotalTime = 60, @Allowance = null, @Questions = @q2
    print 'TC-49 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-49 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-50 : SP_CreateManualExam, question from a different course -> expect THROW 50102
begin try
    declare @q3 QuestionListType
    insert into @q3 values (4, 10)   -- Q_Id 4 belongs to Course 2
    exec SP_CreateManualExam @AsgId = 1, @ExmType = 'Exam', @IntId = 1, @BrId = 1, @TrkId = 1,
         @Start = '2026-10-02 09:00', @End = '2026-10-02 11:00', @TotalTime = 60, @Allowance = null, @Questions = @q3
    print 'TC-50 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-50 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-51 : SP_CreateManualExam, valid -> expect PASS
begin try
    declare @q4 QuestionListType
    insert into @q4 values (1, 10), (2, 10)
    exec SP_CreateManualExam @AsgId = 1, @ExmType = 'Exam', @IntId = 1, @BrId = 1, @TrkId = 1,
         @Start = '2026-10-02 09:00', @End = '2026-10-02 11:00', @TotalTime = 60, @Allowance = null, @Questions = @q4
    print 'TC-51 PASSED (succeeded as expected)'
end try
begin catch
    print 'TC-51 FAILED - UNEXPECTED ERROR -> ' + error_message()
end catch
go

-- TC-52 : SP_AssignStudentToExam, exam not found -> expect THROW 50200
begin try
    exec SP_AssignStudentToExam @ExmId = 9999, @StId = 1, @ExamDate = '2026-09-05', @Start = '09:00', @End = '10:00'
    print 'TC-52 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-52 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-53 : SP_AssignStudentToExam, student does not match exam's Intake/Branch/Track -> expect THROW 50201
-- (exam looked up by its distinguishing values from TC-18, not a hardcoded Id)
begin try
    declare @tc53_examid int
    select @tc53_examid = Exm_Id from Exam
    where Exm_AsgId = 1 and Exm_TrkId = 1 and Exm_BrId = 1 and Exm_IntId = 1
      and Exm_Start = '2026-09-05T09:00:00' and Exm_End = '2026-09-05T11:00:00'

    exec SP_AssignStudentToExam @ExmId = @tc53_examid, @StId = 2, @ExamDate = '2026-09-05', @Start = '09:00', @End = '10:00'
    print 'TC-53 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-53 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-54 : SP_AssignStudentToExam, End <= Start -> expect THROW 50202
begin try
    declare @tc54_examid int
    select @tc54_examid = Exm_Id from Exam
    where Exm_AsgId = 1 and Exm_TrkId = 1 and Exm_BrId = 1 and Exm_IntId = 1
      and Exm_Start = '2026-09-05T09:00:00' and Exm_End = '2026-09-05T11:00:00'

    exec SP_AssignStudentToExam @ExmId = @tc54_examid, @StId = 3, @ExamDate = '2026-09-05', @Start = '10:00', @End = '09:00'
    print 'TC-54 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-54 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-55 : SP_AssignStudentToExam, schedule outside exam window -> expect THROW 50203
begin try
    declare @tc55_examid int
    select @tc55_examid = Exm_Id from Exam
    where Exm_AsgId = 1 and Exm_TrkId = 1 and Exm_BrId = 1 and Exm_IntId = 1
      and Exm_Start = '2026-09-05T09:00:00' and Exm_End = '2026-09-05T11:00:00'

    exec SP_AssignStudentToExam @ExmId = @tc55_examid, @StId = 3, @ExamDate = '2026-09-05', @Start = '07:00', @End = '08:00'  -- exam runs 09:00-11:00
    print 'TC-55 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-55 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-56 : SP_AssignStudentToExam, valid -> expect PASS
begin try
    declare @tc56_examid int
    select @tc56_examid = Exm_Id from Exam
    where Exm_AsgId = 1 and Exm_TrkId = 1 and Exm_BrId = 1 and Exm_IntId = 1
      and Exm_Start = '2026-09-05T09:00:00' and Exm_End = '2026-09-05T11:00:00'

    exec SP_AssignStudentToExam @ExmId = @tc56_examid, @StId = 3, @ExamDate = '2026-09-05', @Start = '09:00', @End = '10:00'
    print 'TC-56 PASSED (succeeded as expected)'
end try
begin catch
    print 'TC-56 FAILED - UNEXPECTED ERROR -> ' + error_message()
end catch
go

-- TC-57 : SP_SaveStudentAnswer, StudentExam not found -> expect THROW 50500
begin try
    exec SP_SaveStudentAnswer @SEId = 9999, @QId = 1, @ChoiceId = 1
    print 'TC-57 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-57 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-58 : SP_SaveStudentAnswer, outside the scheduled time window -> expect THROW 50501
-- (the StudentExam row is looked up dynamically instead of hardcoding an Id: it's
--  the row TC-56 created for student 3 on the exam scheduled 2026-09-05, which is
--  not "today" - a hardcoded Id here breaks the same way TC-20/53-56 did, since
--  earlier failed inserts in this script consume IDENTITY values on StudentExam)
begin try
    declare @tc58_seid int
    select @tc58_seid = se.SE_Id
    from StudentExam se
    join Exam e on e.Exm_Id = se.SE_ExmId
    where se.SE_StId = 3
      and e.Exm_AsgId = 1 and e.Exm_TrkId = 1 and e.Exm_BrId = 1 and e.Exm_IntId = 1
      and e.Exm_Start = '2026-09-05T09:00:00' and e.Exm_End = '2026-09-05T11:00:00'

    exec SP_SaveStudentAnswer @SEId = @tc58_seid, @QId = 1, @ChoiceId = 1
    print 'TC-58 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-58 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-59 : SP_SaveStudentAnswer, new answer, inside the active window -> expect PASS
--         (SE_Id = 2 window is "now -5min" to "now +3h", so it is currently active)
begin try
    exec SP_SaveStudentAnswer @SEId = 2, @QId = 3, @TextAns = N'A row that references a primary key.'
    print 'TC-59 PASSED (succeeded as expected)'
end try
begin catch
    print 'TC-59 FAILED - UNEXPECTED ERROR -> ' + error_message()
end catch
go

-- TC-60 : SP_SaveStudentAnswer, updating an existing answer -> expect PASS
begin try
    exec SP_SaveStudentAnswer @SEId = 2, @QId = 2, @BoolAns = 0   -- (2,2) already exists from setup, this updates it
    print 'TC-60 PASSED (succeeded as expected)'
end try
begin catch
    print 'TC-60 FAILED - UNEXPECTED ERROR -> ' + error_message()
end catch
go

-- TC-61 : SP_GradeStudentExam, StudentExam not found -> expect THROW 50300
begin try
    exec SP_GradeStudentExam @SEId = 9999
    print 'TC-61 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-61 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-62 : SP_GradeStudentExam, valid -> expect PASS (grades SE_Id = 2 and prints its final result)
begin try
    exec SP_GradeStudentExam @SEId = 2
    print 'TC-62 PASSED (succeeded as expected) -> see FinalResult column above'
end try
begin catch
    print 'TC-62 FAILED - UNEXPECTED ERROR -> ' + error_message()
end catch
go

-- TC-63 : SP_MarkTextAnswer, answer not found -> expect THROW 50400
begin try
    exec SP_MarkTextAnswer @AnsId = 9999, @Degree = 5
    print 'TC-63 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-63 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-64 : SP_MarkTextAnswer, Degree outside allowed range -> expect THROW 50401
begin try
    declare @tc64_ansid int
    select @tc64_ansid = Ans_Id from StudentAnswer where Ans_SEId = 2 and Ans_QId = 3
    exec SP_MarkTextAnswer @AnsId = @tc64_ansid, @Degree = 999   -- EQ_Degree for Q3 on Exam 2 is 10
    print 'TC-64 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-64 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-65 : SP_MarkTextAnswer, valid Degree -> expect PASS
begin try
    declare @tc65_ansid int
    select @tc65_ansid = Ans_Id from StudentAnswer where Ans_SEId = 2 and Ans_QId = 3
    exec SP_MarkTextAnswer @AnsId = @tc65_ansid, @Degree = 8, @Comment = N'Mostly correct'
    print 'TC-65 PASSED (succeeded as expected)'
end try
begin catch
    print 'TC-65 FAILED - UNEXPECTED ERROR -> ' + error_message()
end catch
go

-- TC-66 : SP_AddTrack, branch not found -> expect THROW 50600
begin try
    exec SP_AddTrack @Name = N'TC66 Track', @BrId = 9999
    print 'TC-66 FAILED - UNEXPECTED SUCCESS'
end try
begin catch
    print 'TC-66 PASSED (error ' + cast(error_number() as varchar) + ' as expected) -> ' + error_message()
end catch
go

-- TC-67 : SP_AddTrack, valid -> expect PASS
begin try
    exec SP_AddTrack @Name = N'TC67 Track', @BrId = 1
    print 'TC-67 PASSED (succeeded as expected)'
end try
begin catch
    print 'TC-67 FAILED - UNEXPECTED ERROR -> ' + error_message()
end catch
go

-------------------------------------------------------------------
-- SECTION 4 : FUNCTION TEST CASES  (TC-68 .. TC-72)
-------------------------------------------------------------------

-- TC-68 : GetExamTotalDegree, exam with no questions -> expect 0
declare @tc68 decimal(10,2) = dbo.GetExamTotalDegree(9999)
print 'TC-68 ' + case when @tc68 = 0 then 'PASSED' else 'FAILED - expected 0, got ' + cast(@tc68 as varchar) end
go

-- TC-69 : GetExamTotalDegree, exam with questions -> expect it to match SUM(EQ_Degree)
declare @tc69_actual decimal(10,2) = dbo.GetExamTotalDegree(2)
declare @tc69_expected decimal(10,2)
select @tc69_expected = isnull(sum(EQ_Degree), 0) from ExamQuestion where EQ_ExmId = 2
print 'TC-69 ' + case when @tc69_actual = @tc69_expected
    then 'PASSED (returned ' + cast(@tc69_actual as varchar) + ', matches SUM)'
    else 'FAILED - expected ' + cast(@tc69_expected as varchar) + ', got ' + cast(@tc69_actual as varchar) end
go

-- TC-70 : NormalizeAnswer -> expect 'primary key'
declare @tc70 nvarchar(max) = dbo.NormalizeAnswer(N'  Primary   Key  ')
print 'TC-70 ' + case when @tc70 = N'primary key' then 'PASSED' else 'FAILED - got [' + @tc70 + ']' end
go

-- TC-71 : IsAnswerValid, equal after normalization -> expect 1
declare @tc71 bit = dbo.IsAnswerValid(N'  IT UNIQUELY identifies EACH row in a table.  ', N'It uniquely identifies each row in a table.')
print 'TC-71 ' + case when @tc71 = 1 then 'PASSED' else 'FAILED - expected 1, got ' + cast(@tc71 as varchar) end
go

-- TC-72 : IsAnswerValid, different answers -> expect 0
declare @tc72 bit = dbo.IsAnswerValid(N'a completely different answer', N'It uniquely identifies each row in a table.')
print 'TC-72 ' + case when @tc72 = 0 then 'PASSED' else 'FAILED - expected 0, got ' + cast(@tc72 as varchar) end
go

print '=== All 72 test cases executed. Scroll up through the Messages tab and check for any FAILED line. ==='
go
