-------------------------------------------------------------------
-- ExaminationSystemDB - Build Schema, Objects & Seed Data
-- NO CREATE DATABASE / DROP DATABASE here on purpose - this runs
-- directly against the ExaminationSystemDB you already created
-- with the filegroups script. Run order:
--   1) 01_ExaminationSystem_FileGroups.sql
--   2) THIS FILE
--   3) 03_ExaminationSystem_Security_Setup.sql
--   4) 04_ExaminationSystem_Backup_Job.sql
-------------------------------------------------------------------

use ExaminationSystemDB
go

-------------------------------------------------------------------
-- 2. Tables
-------------------------------------------------------------------

create table Admin
(
	Adm_Id		int primary key identity,
	Adm_User	varchar(50) not null unique,
	Adm_Pass	varchar(255) not null,
	Adm_Name	nvarchar(100) not null
) on [PRIMARY]
go

create table TrainingManager
(
	Mgr_Id		int primary key identity,
	Mgr_User	varchar(50) not null unique,
	Mgr_Pass	varchar(255) not null,
	Mgr_Name	nvarchar(100) not null
) on [PRIMARY]
go

create table Instructor
(
	Ins_Id		int primary key identity,
	Ins_User	varchar(50) not null unique,
	Ins_Pass	varchar(255) not null,
	Ins_Name	nvarchar(100) not null,
	Ins_Email	varchar(100) not null unique,
	Ins_Phone	varchar(20) null
) on [PRIMARY]
go

create table Branch
(
	Br_Id		int primary key identity,
	Br_Name		nvarchar(100) not null unique,
	Br_Location	nvarchar(200) null
) on [PRIMARY]
go

create table Intake
(
	Int_Id			int primary key identity,
	Int_Name		nvarchar(50) not null unique,
	Int_StartDate	date not null
) on [PRIMARY]
go

create table Course
(
	Crs_Id		int primary key identity,
	Crs_Name	nvarchar(100) not null unique,
	Crs_Desc	nvarchar(max) null,
	Crs_MaxDeg	decimal(5,2) not null,
	Crs_MinDeg	decimal(5,2) not null,

	check (Crs_MinDeg >= 0 and Crs_MinDeg <= Crs_MaxDeg)
) on [PRIMARY]
go

create table Track
(
	Trk_Id		int primary key identity,
	Trk_Name	nvarchar(100) not null,
	Trk_BrId	int not null references Branch(Br_Id),

	unique (Trk_Name, Trk_BrId)
) on [PRIMARY]
go

create table Student
(
	St_Id		int primary key identity,
	St_User		varchar(50) not null unique,
	St_Pass		varchar(255) not null,
	St_Name		nvarchar(100) not null,
	St_Email	varchar(100) not null unique,
	St_Phone	varchar(20) null,

	St_BrId		int not null references Branch(Br_Id),
	St_TrkId	int not null references Track(Trk_Id),
	St_IntId	int not null references Intake(Int_Id)
) on [PRIMARY]
go

create table CourseAssignment
(
	Asg_Id		int primary key identity,
	Asg_CrsId	int not null references Course(Crs_Id),
	Asg_InsId	int not null references Instructor(Ins_Id),
	Asg_Year	smallint not null,

	unique (Asg_CrsId, Asg_Year)
) on [PRIMARY]
go

-- Question pool (high-growth -> FG_Data, default filegroup, no ON clause)
create table Question
(
	Q_Id		int primary key identity,
	Q_CrsId		int not null references Course(Crs_Id),
	Q_Type		varchar(10) not null,		-- MCQ , TF , Text
	Q_Text		nvarchar(max) not null,
	Q_CreatedBy	int not null references Instructor(Ins_Id),

	check (Q_Type in ('MCQ','TF','Text'))
)
go

create table MCQChoice
(
	Ch_Id		int primary key identity,
	Ch_QId		int not null references Question(Q_Id),
	Ch_Text		nvarchar(500) not null,
	Ch_Correct	bit not null default 0
)
go

create unique index UX_Choice_OneCorrect
on MCQChoice(Ch_QId)
where Ch_Correct = 1
go

create table TFQuestion
(
	TF_QId		int primary key references Question(Q_Id),
	TF_Correct	bit not null
) on [PRIMARY]
go

create table TextQuestion
(
	Txt_QId			int primary key references Question(Q_Id),
	Txt_BestAnswer	nvarchar(max) not null
) on [PRIMARY]
go

create table Exam
(
	Exm_Id			int primary key identity,

	Exm_AsgId		int not null references CourseAssignment(Asg_Id),
	Exm_Type		varchar(20) not null,		-- Exam , Corrective

	Exm_IntId		int not null references Intake(Int_Id),
	Exm_BrId		int not null references Branch(Br_Id),
	Exm_TrkId		int not null references Track(Trk_Id),

	Exm_Start		datetime not null,
	Exm_End			datetime not null,

	Exm_TotalTime	int not null,
	Exm_Allowance	nvarchar(500) null,

	check (Exm_Type in ('Exam','Corrective')),
	check (Exm_End > Exm_Start),
	check (Exm_TotalTime > 0)
) on [PRIMARY]
go

-- ExamQuestion / StudentExam / StudentAnswer (high-growth -> FG_Data)
create table ExamQuestion
(
	EQ_Id		int primary key identity,
	EQ_ExmId	int not null references Exam(Exm_Id),
	EQ_QId		int not null references Question(Q_Id),
	EQ_Degree	decimal(5,2) not null,

	unique (EQ_ExmId, EQ_QId),
	check (EQ_Degree > 0)
)
go

create table StudentExam
(
	SE_Id		int primary key identity,

	SE_ExmId	int not null references Exam(Exm_Id),
	SE_StId		int not null references Student(St_Id),

	SE_Date		date not null,
	SE_Start	time not null,
	SE_End		time not null,

	SE_Result	decimal(5,2) null,

	unique (SE_ExmId, SE_StId),
	check (SE_End > SE_Start),
	check (SE_Result is null or SE_Result >= 0)
)
go

create table StudentAnswer
(
	Ans_Id			int primary key identity,

	Ans_SEId		int not null references StudentExam(SE_Id),
	Ans_QId			int not null references Question(Q_Id),

	Ans_ChoiceId	int null references MCQChoice(Ch_Id),
	Ans_BoolAns		bit null,
	Ans_TextAns		nvarchar(max) null,

	Ans_Correct		bit null,
	Ans_Degree		decimal(5,2) null,
	Ans_Comment		nvarchar(500) null,

	unique (Ans_SEId, Ans_QId),
	check (Ans_Degree is null or Ans_Degree >= 0)
)
go

-------------------------------------------------------------------
-- 3. Triggers (Data Integrity)
-------------------------------------------------------------------

create or alter trigger TR_Student_TrackBranchMatch
on Student
after insert, update
as
begin
	set nocount on
	if exists
	(
		select 1
		from inserted i
		join Track t on t.Trk_Id = i.St_TrkId
		where t.Trk_BrId <> i.St_BrId
	)
	begin
		raiserror('Student Track does not belong to Student Branch.',16,1)
		rollback tran
		return
	end
end
go

create or alter trigger TR_Exam_TrackBranchMatch
on Exam
after insert, update
as
begin
	set nocount on
	if exists
	(
		select 1
		from inserted i
		join Track t on t.Trk_Id = i.Exm_TrkId
		where t.Trk_BrId <> i.Exm_BrId
	)
	begin
		raiserror('Exam Track does not belong to Exam Branch.',16,1)
		rollback tran
		return
	end
end
go

create or alter trigger TR_StudentExam_ValidateStudent
on StudentExam
after insert, update
as
begin
	set nocount on
	if exists
	(
		select 1
		from inserted i
		join Exam e on e.Exm_Id = i.SE_ExmId
		join Student s on s.St_Id = i.SE_StId
		where s.St_IntId <> e.Exm_IntId
		   or s.St_BrId  <> e.Exm_BrId
		   or s.St_TrkId <> e.Exm_TrkId
	)
	begin
		raiserror('Student does not belong to the exam Intake, Branch, or Track.',16,1)
		rollback tran
		return
	end
end
go

create or alter trigger TR_ExamQuestion_ValidateCourse
on ExamQuestion
after insert, update
as
begin
	set nocount on
	if exists
	(
		select 1
		from inserted i
		join Exam e on e.Exm_Id = i.EQ_ExmId
		join CourseAssignment ca on ca.Asg_Id = e.Exm_AsgId
		join Question q on q.Q_Id = i.EQ_QId
		where q.Q_CrsId <> ca.Asg_CrsId
	)
	begin
		raiserror('Exam questions must belong to the same course as the exam.',16,1)
		rollback tran
		return
	end
end
go

create or alter trigger TR_ExamQuestion_CheckMaxDegree
on ExamQuestion
after insert, update, delete
as
begin
	set nocount on
	declare @Exams table (ExmId int primary key)
	insert into @Exams(ExmId)
	select EQ_ExmId from inserted
	union
	select EQ_ExmId from deleted

	if exists
	(
		select 1
		from @Exams x
		join Exam e on e.Exm_Id = x.ExmId
		join CourseAssignment ca on ca.Asg_Id = e.Exm_AsgId
		join Course c on c.Crs_Id = ca.Asg_CrsId
		cross apply
		(
			select isnull(sum(eq.EQ_Degree),0) as TotalDeg
			from ExamQuestion eq
			where eq.EQ_ExmId = e.Exm_Id
		) d
		where d.TotalDeg > c.Crs_MaxDeg
	)
	begin
		raiserror('Total exam question degrees cannot exceed Course MaxDegree.',16,1)
		rollback tran
		return
	end
end
go

create or alter trigger TR_Question_InstructorCourseCheck
on Question
after insert, update
as
begin
	set nocount on
	if exists
	(
		select 1
		from inserted i
		left join CourseAssignment ca
			on ca.Asg_CrsId = i.Q_CrsId
		   and ca.Asg_InsId = i.Q_CreatedBy
		where ca.Asg_Id is null
	)
	begin
		raiserror('Instructor can only create questions for an assigned course.',16,1)
		rollback tran
		return
	end
end
go

create or alter trigger TR_TFQuestion_TypeCheck
on TFQuestion
after insert, update
as
begin
	set nocount on
	if exists
	(
		select 1
		from inserted i
		join Question q on q.Q_Id = i.TF_QId
		where q.Q_Type <> 'TF'
	)
	begin
		raiserror('TFQuestion must reference a TF question.',16,1)
		rollback tran
	end
end
go

create or alter trigger TR_TextQuestion_TypeCheck
on TextQuestion
after insert, update
as
begin
	set nocount on
	if exists
	(
		select 1
		from inserted i
		join Question q on q.Q_Id = i.Txt_QId
		where q.Q_Type <> 'Text'
	)
	begin
		raiserror('TextQuestion must reference a Text question.',16,1)
		rollback tran
	end
end
go

create or alter trigger TR_MCQChoice_TypeCheck
on MCQChoice
after insert, update
as
begin
	set nocount on
	if exists
	(
		select 1
		from inserted i
		join Question q on q.Q_Id = i.Ch_QId
		where q.Q_Type <> 'MCQ'
	)
	begin
		raiserror('MCQChoice must reference an MCQ question.',16,1)
		rollback tran
	end
end
go

create or alter trigger TR_StudentAnswer_Validate
on StudentAnswer
after insert, update
as
begin
	set nocount on

	if exists
	(
		select 1
		from inserted i
		join StudentExam se on se.SE_Id = i.Ans_SEId
		left join ExamQuestion eq
			on eq.EQ_ExmId = se.SE_ExmId
		   and eq.EQ_QId = i.Ans_QId
		where eq.EQ_Id is null
	)
	begin
		raiserror('Student answer question is not part of the assigned exam.',16,1)
		rollback tran
		return
	end

	if exists
	(
		select 1
		from inserted i
		join Question q on q.Q_Id = i.Ans_QId
		left join MCQChoice c
			on c.Ch_Id = i.Ans_ChoiceId
		   and c.Ch_QId = i.Ans_QId
		where q.Q_Type = 'MCQ'
		  and i.Ans_ChoiceId is not null
		  and c.Ch_Id is null
	)
	begin
		raiserror('Selected MCQ choice does not belong to the question.',16,1)
		rollback tran
		return
	end

	if exists
	(
		select 1
		from inserted i
		join Question q on q.Q_Id = i.Ans_QId
		where
			(q.Q_Type = 'MCQ'  and (i.Ans_BoolAns is not null or i.Ans_TextAns is not null))
		 or (q.Q_Type = 'TF'   and (i.Ans_ChoiceId is not null or i.Ans_TextAns is not null))
		 or (q.Q_Type = 'Text' and (i.Ans_ChoiceId is not null or i.Ans_BoolAns is not null))
	)
	begin
		raiserror('Student answer fields do not match the question type.',16,1)
		rollback tran
		return
	end
end
go

-------------------------------------------------------------------
-- 4. Indexes (Performance)
-------------------------------------------------------------------

create nonclustered index IX_Question_Course_Type on Question(Q_CrsId, Q_Type)
go
create nonclustered index IX_Exam_Assignment_Times on Exam(Exm_AsgId, Exm_Start, Exm_End)
go
create nonclustered index IX_ExamQuestion_Exam on ExamQuestion(EQ_ExmId)
go
create nonclustered index IX_StudentExam_Student on StudentExam(SE_StId, SE_Date)
go
create nonclustered index IX_StudentAnswer_StudentExam on StudentAnswer(Ans_SEId)
go
create nonclustered index IX_CourseAssignment_Instructor on CourseAssignment(Asg_InsId, Asg_Year)
go
create nonclustered index IX_Question_CreatedBy on Question(Q_CreatedBy)
go

-------------------------------------------------------------------
-- 5. Table Type
-------------------------------------------------------------------

if exists (select * from sys.types where name = N'QuestionListType')
	drop type QuestionListType
go

create type QuestionListType as table
(
	QId		int not null,
	Degree	decimal(5,2) not null
)
go

-------------------------------------------------------------------
-- 6. Functions
-------------------------------------------------------------------

create or alter function GetExamTotalDegree (@ExmId int)
returns decimal(10,2)
begin
	declare @Total decimal(10,2)
	select @Total = isnull(sum(EQ_Degree),0)
	from ExamQuestion
	where EQ_ExmId = @ExmId
	return @Total
end
go

create or alter function NormalizeAnswer (@Answer nvarchar(max))
returns nvarchar(max)
begin
	declare @Result nvarchar(max)
	if @Answer is null
		return null
	set @Result = lower(ltrim(rtrim(@Answer)))
	set @Result = replace(replace(replace(@Result, char(9),' '), char(10),' '), char(13),' ')
	while charindex('  ', @Result) > 0
		set @Result = replace(@Result,'  ',' ')
	return @Result
end
go

create or alter function IsAnswerValid (@StudentAns nvarchar(max), @BestAns nvarchar(max))
returns bit
begin
	declare @Result bit = 0
	if @StudentAns is null or @BestAns is null
		return 0
	if dbo.NormalizeAnswer(@StudentAns) = dbo.NormalizeAnswer(@BestAns)
		set @Result = 1
	return @Result
end
go

-------------------------------------------------------------------
-- 7. Procedures
-------------------------------------------------------------------

create or alter proc SP_CreateQuestion
	@CrsId int, @QType varchar(10), @QText nvarchar(max), @CreatedBy int
with execute as owner
as
begin
	set nocount on
	begin try
		begin tran
		if not exists (select 1 from CourseAssignment where Asg_CrsId = @CrsId and Asg_InsId = @CreatedBy)
			throw 50001, 'Instructor is not assigned to this course.', 1
		if @QType not in ('MCQ','TF','Text')
			throw 50002, 'Invalid question type.', 1

		insert into Question (Q_CrsId, Q_Type, Q_Text, Q_CreatedBy)
		values (@CrsId, @QType, @QText, @CreatedBy)

		declare @QId int = scope_identity()

		if @QType = 'TF'
			insert into TFQuestion (TF_QId, TF_Correct) values (@QId, 0)
		if @QType = 'Text'
			insert into TextQuestion (Txt_QId, Txt_BestAnswer) values (@QId, '')

		commit tran
		select @QId as QId
	end try
	begin catch
		if @@trancount > 0 rollback tran;
		throw;
	end catch
end
go

create or alter proc SP_GenerateRandomExam
	@AsgId int, @ExmType varchar(20), @IntId int, @BrId int, @TrkId int,
	@Start datetime, @End datetime, @TotalTime int, @Allowance nvarchar(500) = null,
	@NumMCQ int = 0, @NumTF int = 0, @NumText int = 0, @DegreePerQ decimal(5,2) = 1
with execute as owner
as
begin
	set nocount on
	begin try
		begin tran
		declare @CrsId int, @ExmId int, @MaxDeg decimal(10,2)
		select @CrsId = Asg_CrsId from CourseAssignment where Asg_Id = @AsgId
		if @CrsId is null throw 50010, 'Invalid course assignment.', 1
		if @NumMCQ < 0 or @NumTF < 0 or @NumText < 0
			throw 50011, 'Number of questions cannot be negative.', 1
		if @DegreePerQ <= 0 throw 50012, 'Degree per question must be greater than zero.', 1
		if @Start >= @End throw 50013, 'End time must be after start time.', 1
		if @TotalTime <= 0 throw 50014, 'Total time must be greater than zero.', 1

		declare @QCount int = @NumMCQ + @NumTF + @NumText
		if @QCount = 0 throw 50015, 'At least one question is required.', 1

		select @MaxDeg = Crs_MaxDeg from Course where Crs_Id = @CrsId
		if @QCount * @DegreePerQ > @MaxDeg
			throw 50016, 'Exam total degree exceeds Course MaxDegree.', 1
		if (select count(*) from Question where Q_CrsId = @CrsId and Q_Type = 'MCQ') < @NumMCQ
			throw 50017, 'Not enough MCQ questions in question pool.', 1
		if (select count(*) from Question where Q_CrsId = @CrsId and Q_Type = 'TF') < @NumTF
			throw 50018, 'Not enough True/False questions in question pool.', 1
		if (select count(*) from Question where Q_CrsId = @CrsId and Q_Type = 'Text') < @NumText
			throw 50019, 'Not enough Text questions in question pool.', 1

		insert into Exam (Exm_AsgId, Exm_Type, Exm_IntId, Exm_BrId, Exm_TrkId, Exm_Start, Exm_End, Exm_TotalTime, Exm_Allowance)
		values (@AsgId, @ExmType, @IntId, @BrId, @TrkId, @Start, @End, @TotalTime, @Allowance)

		set @ExmId = scope_identity()

		insert into ExamQuestion (EQ_ExmId, EQ_QId, EQ_Degree)
		select top (@NumMCQ) @ExmId, Q_Id, @DegreePerQ
		from Question where Q_CrsId = @CrsId and Q_Type = 'MCQ'
		order by newid()

		insert into ExamQuestion (EQ_ExmId, EQ_QId, EQ_Degree)
		select top (@NumTF) @ExmId, Q_Id, @DegreePerQ
		from Question where Q_CrsId = @CrsId and Q_Type = 'TF'
		order by newid()

		insert into ExamQuestion (EQ_ExmId, EQ_QId, EQ_Degree)
		select top (@NumText) @ExmId, Q_Id, @DegreePerQ
		from Question where Q_CrsId = @CrsId and Q_Type = 'Text'
		order by newid()

		commit tran
		select @ExmId as ExmId
	end try
	begin catch
		if @@trancount > 0 rollback tran;
		throw;
	end catch
end
go

create or alter proc SP_CreateManualExam
	@AsgId int, @ExmType varchar(20), @IntId int, @BrId int, @TrkId int,
	@Start datetime, @End datetime, @TotalTime int, @Allowance nvarchar(500),
	@Questions QuestionListType readonly
with execute as owner
as
begin
	set nocount on
	begin try
		begin tran
		declare @CrsId int, @ExmId int, @MaxDeg decimal(10,2), @TotalDeg decimal(10,2)

		select @CrsId = Asg_CrsId from CourseAssignment where Asg_Id = @AsgId
		if @CrsId is null throw 50100, 'Invalid course assignment.', 1

		select @MaxDeg = Crs_MaxDeg from Course where Crs_Id = @CrsId
		select @TotalDeg = isnull(sum(Degree),0) from @Questions

		if @TotalDeg > @MaxDeg throw 50101, 'Exam degree exceeds Course MaxDegree.', 1

		if exists
		(
			select 1 from @Questions q
			left join Question dbq on dbq.Q_Id = q.QId
			where dbq.Q_Id is null or dbq.Q_CrsId <> @CrsId
		)
			throw 50102, 'All selected questions must belong to the exam course.', 1

		insert into Exam (Exm_AsgId, Exm_Type, Exm_IntId, Exm_BrId, Exm_TrkId, Exm_Start, Exm_End, Exm_TotalTime, Exm_Allowance)
		values (@AsgId, @ExmType, @IntId, @BrId, @TrkId, @Start, @End, @TotalTime, @Allowance)

		set @ExmId = scope_identity()

		insert into ExamQuestion (EQ_ExmId, EQ_QId, EQ_Degree)
		select @ExmId, QId, Degree from @Questions

		commit tran
		select @ExmId as ExmId
	end try
	begin catch
		if @@trancount > 0 rollback tran;
		throw;
	end catch
end
go

create or alter proc SP_AssignStudentToExam
	@ExmId int, @StId int, @ExamDate date, @Start time, @End time
with execute as owner
as
begin
	set nocount on
	declare @IntId int, @BrId int, @TrkId int, @ExmStart datetime, @ExmEnd datetime

	select @IntId = Exm_IntId, @BrId = Exm_BrId, @TrkId = Exm_TrkId,
		   @ExmStart = Exm_Start, @ExmEnd = Exm_End
	from Exam where Exm_Id = @ExmId

	if @ExmStart is null throw 50200, 'Exam not found.', 1

	if not exists (select 1 from Student where St_Id = @StId and St_IntId = @IntId and St_BrId = @BrId and St_TrkId = @TrkId)
		throw 50201, 'Student does not belong to exam Intake, Branch, or Track.', 1

	if @End <= @Start throw 50202, 'Student exam EndTime must be after StartTime.', 1

	if cast(@ExmStart as date) <> @ExamDate
	   or @Start < cast(@ExmStart as time)
	   or @End   > cast(@ExmEnd as time)
		throw 50203, 'Student exam schedule must be inside exam schedule.', 1

	insert into StudentExam (SE_ExmId, SE_StId, SE_Date, SE_Start, SE_End)
	values (@ExmId, @StId, @ExamDate, @Start, @End)
end
go

create or alter proc SP_SaveStudentAnswer
	@SEId int, @QId int, @ChoiceId int = null, @BoolAns bit = null, @TextAns nvarchar(max) = null
with execute as owner
as
begin
	set nocount on
	declare @ExamDate date, @Start time, @End time

	select @ExamDate = SE_Date, @Start = SE_Start, @End = SE_End
	from StudentExam where SE_Id = @SEId

	if @ExamDate is null throw 50500, 'Student exam not found.', 1

	if cast(getdate() as date) <> @ExamDate
	   or cast(getdate() as time) not between @Start and @End
		throw 50501, 'You can only answer during the scheduled exam time.', 1

	if exists (select 1 from StudentAnswer where Ans_SEId = @SEId and Ans_QId = @QId)
		update StudentAnswer
		set Ans_ChoiceId = @ChoiceId, Ans_BoolAns = @BoolAns, Ans_TextAns = @TextAns
		where Ans_SEId = @SEId and Ans_QId = @QId
	else
		insert into StudentAnswer (Ans_SEId, Ans_QId, Ans_ChoiceId, Ans_BoolAns, Ans_TextAns)
		values (@SEId, @QId, @ChoiceId, @BoolAns, @TextAns)
end
go

create or alter proc SP_GradeStudentExam
	@SEId int
with execute as owner
as
begin
	set nocount on
	declare @ExmId int
	select @ExmId = SE_ExmId from StudentExam where SE_Id = @SEId
	if @ExmId is null throw 50300, 'Student exam not found.', 1

	update sa
	set Ans_Correct = case when c.Ch_Correct = 1 then 1 else 0 end,
		Ans_Degree  = case when c.Ch_Correct = 1 then eq.EQ_Degree else 0 end
	from StudentAnswer sa
	join ExamQuestion eq on eq.EQ_ExmId = @ExmId and eq.EQ_QId = sa.Ans_QId
	join MCQChoice c on c.Ch_Id = sa.Ans_ChoiceId
	where sa.Ans_SEId = @SEId

	update sa
	set Ans_Correct = case when tf.TF_Correct = sa.Ans_BoolAns then 1 else 0 end,
		Ans_Degree  = case when tf.TF_Correct = sa.Ans_BoolAns then eq.EQ_Degree else 0 end
	from StudentAnswer sa
	join ExamQuestion eq on eq.EQ_ExmId = @ExmId and eq.EQ_QId = sa.Ans_QId
	join TFQuestion tf on tf.TF_QId = sa.Ans_QId
	where sa.Ans_SEId = @SEId

	update sa
	set Ans_Correct = dbo.IsAnswerValid(sa.Ans_TextAns, tq.Txt_BestAnswer),
		Ans_Degree  = case when dbo.IsAnswerValid(sa.Ans_TextAns, tq.Txt_BestAnswer) = 1 then eq.EQ_Degree else 0 end
	from StudentAnswer sa
	join ExamQuestion eq on eq.EQ_ExmId = @ExmId and eq.EQ_QId = sa.Ans_QId
	join TextQuestion tq on tq.Txt_QId = sa.Ans_QId
	where sa.Ans_SEId = @SEId

	declare @Final decimal(5,2)
	select @Final = isnull(sum(Ans_Degree),0) from StudentAnswer where Ans_SEId = @SEId
	update StudentExam set SE_Result = @Final where SE_Id = @SEId

	select @SEId as SEId, @Final as FinalResult
end
go

create or alter proc SP_MarkTextAnswer
	@AnsId int, @Degree decimal(5,2), @Comment nvarchar(500) = null
with execute as owner
as
begin
	set nocount on
	declare @SEId int, @QId int, @MaxDeg decimal(5,2)

	select @SEId = sa.Ans_SEId, @QId = sa.Ans_QId, @MaxDeg = eq.EQ_Degree
	from StudentAnswer sa
	join StudentExam se on se.SE_Id = sa.Ans_SEId
	join ExamQuestion eq on eq.EQ_ExmId = se.SE_ExmId and eq.EQ_QId = sa.Ans_QId
	where sa.Ans_Id = @AnsId

	if @SEId is null throw 50400, 'Answer not found.', 1
	if @Degree < 0 or @Degree > @MaxDeg throw 50401, 'Awarded degree is outside allowed range.', 1

	update StudentAnswer
	set Ans_Degree = @Degree,
		Ans_Correct = case when @Degree = @MaxDeg then 1 when @Degree = 0 then 0 else null end,
		Ans_Comment = @Comment
	where Ans_Id = @AnsId

	update se
	set SE_Result = (select isnull(sum(Ans_Degree),0) from StudentAnswer where Ans_SEId = se.SE_Id)
	from StudentExam se
	where se.SE_Id = @SEId
end
go

create or alter proc SP_AddBranch @Name nvarchar(100), @Location nvarchar(200) = null
with execute as owner
as
begin
	set nocount on
	insert into Branch (Br_Name, Br_Location) values (@Name, @Location)
	select scope_identity() as BrId
end
go

create or alter proc SP_UpdateBranch @BrId int, @Name nvarchar(100), @Location nvarchar(200) = null
with execute as owner
as
begin
	set nocount on
	update Branch set Br_Name = @Name, Br_Location = @Location where Br_Id = @BrId
end
go

create or alter proc SP_AddTrack @Name nvarchar(100), @BrId int
with execute as owner
as
begin
	set nocount on
	if not exists (select 1 from Branch where Br_Id = @BrId)
		throw 50600, 'Branch not found.', 1
	insert into Track (Trk_Name, Trk_BrId) values (@Name, @BrId)
	select scope_identity() as TrkId
end
go

create or alter proc SP_UpdateTrack @TrkId int, @Name nvarchar(100), @BrId int
with execute as owner
as
begin
	set nocount on
	update Track set Trk_Name = @Name, Trk_BrId = @BrId where Trk_Id = @TrkId
end
go

create or alter proc SP_AddIntake @Name nvarchar(50), @StartDate date
with execute as owner
as
begin
	set nocount on
	insert into Intake (Int_Name, Int_StartDate) values (@Name, @StartDate)
	select scope_identity() as IntId
end
go

create or alter proc SP_AddStudent
	@User varchar(50), @Pass varchar(255), @Name nvarchar(100), @Email varchar(100),
	@Phone varchar(20) = null, @BrId int, @TrkId int, @IntId int
with execute as owner
as
begin
	set nocount on
	insert into Student (St_User, St_Pass, St_Name, St_Email, St_Phone, St_BrId, St_TrkId, St_IntId)
	values (@User, @Pass, @Name, @Email, @Phone, @BrId, @TrkId, @IntId)
	select scope_identity() as StId
end
go

create or alter proc SP_UpdateStudent
	@StId int, @Name nvarchar(100), @Email varchar(100), @Phone varchar(20) = null,
	@BrId int, @TrkId int, @IntId int
with execute as owner
as
begin
	set nocount on
	update Student
	set St_Name = @Name, St_Email = @Email, St_Phone = @Phone,
		St_BrId = @BrId, St_TrkId = @TrkId, St_IntId = @IntId
	where St_Id = @StId
end
go

create or alter proc SP_SearchStudents
	@Name nvarchar(100) = null, @BrId int = null, @TrkId int = null, @IntId int = null
as
begin
	set nocount on
	select s.St_Id, s.St_Name, s.St_Email, s.St_Phone, b.Br_Name, t.Trk_Name, i.Int_Name
	from Student s
	join Branch b on b.Br_Id = s.St_BrId
	join Track t on t.Trk_Id = s.St_TrkId
	join Intake i on i.Int_Id = s.St_IntId
	where (@Name is null or s.St_Name like '%' + @Name + '%')
	  and (@BrId is null or s.St_BrId = @BrId)
	  and (@TrkId is null or s.St_TrkId = @TrkId)
	  and (@IntId is null or s.St_IntId = @IntId)
end
go

create or alter proc SP_SearchExams
	@CrsId int = null, @BrId int = null, @TrkId int = null, @ExmType varchar(20) = null,
	@FromDate date = null, @ToDate date = null
as
begin
	set nocount on
	select e.Exm_Id, c.Crs_Name, e.Exm_Type, b.Br_Name, t.Trk_Name, e.Exm_Start, e.Exm_End, e.Exm_TotalTime
	from Exam e
	join CourseAssignment ca on ca.Asg_Id = e.Exm_AsgId
	join Course c on c.Crs_Id = ca.Asg_CrsId
	join Branch b on b.Br_Id = e.Exm_BrId
	join Track t on t.Trk_Id = e.Exm_TrkId
	where (@CrsId is null or c.Crs_Id = @CrsId)
	  and (@BrId is null or e.Exm_BrId = @BrId)
	  and (@TrkId is null or e.Exm_TrkId = @TrkId)
	  and (@ExmType is null or e.Exm_Type = @ExmType)
	  and (@FromDate is null or cast(e.Exm_Start as date) >= @FromDate)
	  and (@ToDate is null or cast(e.Exm_Start as date) <= @ToDate)
end
go

create or alter proc SP_SearchQuestions
	@CrsId int = null, @QType varchar(10) = null, @CreatedBy int = null
as
begin
	set nocount on
	select q.Q_Id, c.Crs_Name, q.Q_Type, q.Q_Text, i.Ins_Name
	from Question q
	join Course c on c.Crs_Id = q.Q_CrsId
	join Instructor i on i.Ins_Id = q.Q_CreatedBy
	where (@CrsId is null or q.Q_CrsId = @CrsId)
	  and (@QType is null or q.Q_Type = @QType)
	  and (@CreatedBy is null or q.Q_CreatedBy = @CreatedBy)
end
go

-------------------------------------------------------------------
-- 8. Views
-------------------------------------------------------------------

create or alter view QuestionPool
as
	select q.Q_Id, q.Q_CrsId, c.Crs_Name, q.Q_Type, q.Q_Text, q.Q_CreatedBy, i.Ins_Name
	from Question q
	join Course c on c.Crs_Id = q.Q_CrsId
	join Instructor i on i.Ins_Id = q.Q_CreatedBy
go

create or alter view ExamDetails
as
	select
		e.Exm_Id, e.Exm_Type, c.Crs_Name, i.Ins_Name,
		e.Exm_IntId, it.Int_Name, e.Exm_BrId, b.Br_Name, e.Exm_TrkId, t.Trk_Name,
		e.Exm_Start, e.Exm_End, e.Exm_TotalTime, e.Exm_Allowance,
		dbo.GetExamTotalDegree(e.Exm_Id) as TotalDegree
	from Exam e
	join CourseAssignment ca on ca.Asg_Id = e.Exm_AsgId
	join Course c on c.Crs_Id = ca.Asg_CrsId
	join Instructor i on i.Ins_Id = ca.Asg_InsId
	join Intake it on it.Int_Id = e.Exm_IntId
	join Branch b on b.Br_Id = e.Exm_BrId
	join Track t on t.Trk_Id = e.Exm_TrkId
go

create or alter view StudentResults
as
	select se.SE_Id, s.St_Id, s.St_Name, e.Exm_Id, c.Crs_Name, e.Exm_Type,
		   se.SE_Date, se.SE_Start, se.SE_End, se.SE_Result
	from StudentExam se
	join Student s on s.St_Id = se.SE_StId
	join Exam e on e.Exm_Id = se.SE_ExmId
	join CourseAssignment ca on ca.Asg_Id = e.Exm_AsgId
	join Course c on c.Crs_Id = ca.Asg_CrsId
go

create or alter view TextAnswersForReview
as
	select
		sa.Ans_Id, se.SE_Id, s.St_Id, s.St_Name,
		q.Q_Id, q.Q_Text, sa.Ans_TextAns, tq.Txt_BestAnswer,
		sa.Ans_Correct, sa.Ans_Degree, eq.EQ_Degree, sa.Ans_Comment
	from StudentAnswer sa
	join StudentExam se on se.SE_Id = sa.Ans_SEId
	join Student s on s.St_Id = se.SE_StId
	join Question q on q.Q_Id = sa.Ans_QId
	join TextQuestion tq on tq.Txt_QId = q.Q_Id
	join ExamQuestion eq on eq.EQ_ExmId = se.SE_ExmId and eq.EQ_QId = q.Q_Id
go

create or alter view ExamQuestions
as
	select eq.EQ_Id, eq.EQ_ExmId, eq.EQ_QId, q.Q_Type, q.Q_Text, eq.EQ_Degree
	from ExamQuestion eq
	join Question q on q.Q_Id = eq.EQ_QId
go

-------------------------------------------------------------------
-- 9. Test Data
-------------------------------------------------------------------

insert into Admin (Adm_User, Adm_Pass, Adm_Name)
values ('admin1', 'Admin@123', 'System Administrator')

insert into TrainingManager (Mgr_User, Mgr_Pass, Mgr_Name)
values ('manager1', 'Manager@123', 'Training Manager')

insert into Branch (Br_Name, Br_Location)
values ('Main Campus', 'Cairo')

insert into Intake (Int_Name, Int_StartDate)
values ('Intake 44', '2026-01-01')

insert into Track (Trk_Name, Trk_BrId)
values ('Application Development', 1)

insert into Instructor (Ins_User, Ins_Pass, Ins_Name, Ins_Email, Ins_Phone)
values ('inst_john', 'Instructor@123', 'John Doe', 'john@test.com', '01000000000')

insert into Student (St_User, St_Pass, St_Name, St_Email, St_Phone, St_BrId, St_TrkId, St_IntId)
values ('student1', 'Student@123', 'Ahmed Ali', 'ahmed@test.com', '01111111111', 1, 1, 1)

insert into Course (Crs_Name, Crs_Desc, Crs_MaxDeg, Crs_MinDeg)
values ('SQL Server', 'Database Fundamentals and SQL Server', 100.00, 50.00)

insert into CourseAssignment (Asg_CrsId, Asg_InsId, Asg_Year)
values (1, 1, 2026)

insert into Question (Q_CrsId, Q_Type, Q_Text, Q_CreatedBy)
values (1, 'MCQ', 'What does DML stand for?', 1)

insert into MCQChoice (Ch_QId, Ch_Text, Ch_Correct)
values
	(1, 'Data Manipulation Language', 1),
	(1, 'Data Mode Language', 0),
	(1, 'Database Management Logic', 0),
	(1, 'Data Mapping Language', 0)

insert into Question (Q_CrsId, Q_Type, Q_Text, Q_CreatedBy)
values (1, 'TF', 'PRIMARY KEY allows NULL values.', 1)

insert into TFQuestion (TF_QId, TF_Correct)
values (2, 0)

insert into Question (Q_CrsId, Q_Type, Q_Text, Q_CreatedBy)
values (1, 'Text', 'What is the purpose of a PRIMARY KEY?', 1)

insert into TextQuestion (Txt_QId, Txt_BestAnswer)
values (3, 'It uniquely identifies each row in a table.')
go

-------------------------------------------------------------------
-- 10. Baseline Demo "Test Run" (Exm_Id = 1, SE_Id = 1)
-- This is required seed state: 05_ExaminationSystem_Test_Execution.sql
-- assumes a first demo exam (Exm_Id = 1) and a first student exam
-- registration (SE_Id = 1) already exist before its own Section 0
-- setup runs (which then creates Exm_Id = 2, SE_Id = 2, ...). Without
-- this block, the test script's hardcoded "Id = 2" assumptions shift
-- by one and every later test built on top of them fails with FK
-- violations.
--
-- Exam window is built dynamically around "now" so the demo works
-- correctly on whatever day/time you run this script.
-------------------------------------------------------------------

declare @ExmStart datetime = dateadd(minute, -5, getdate())	-- started 5 min ago
declare @ExmEnd   datetime = dateadd(hour, 2, getdate())		-- ends in 2 hours

exec SP_GenerateRandomExam
	@AsgId = 1, @ExmType = 'Exam', @IntId = 1, @BrId = 1, @TrkId = 1,
	@Start = @ExmStart, @End = @ExmEnd, @TotalTime = 120,
	@Allowance = N'Calculator allowed', @NumMCQ = 1, @NumTF = 1, @NumText = 1, @DegreePerQ = 20
go

-- student's personal window : derived from the ACTUAL stored exam times
-- (recomputing GETDATE() again here would drift past Exm_End)
declare @StoredStart datetime, @StoredEnd datetime

select @StoredStart = Exm_Start, @StoredEnd = Exm_End
from Exam where Exm_Id = 1

declare @ExamDate date = cast(@StoredStart as date)
declare @StuStart time = cast(@StoredStart as time)
declare @StuEnd   time = cast(@StoredEnd as time)

exec SP_AssignStudentToExam
	@ExmId = 1, @StId = 1,
	@ExamDate = @ExamDate, @Start = @StuStart, @End = @StuEnd
go

exec SP_SaveStudentAnswer @SEId = 1, @QId = 1, @ChoiceId = 1
exec SP_SaveStudentAnswer @SEId = 1, @QId = 2, @BoolAns = 0
exec SP_SaveStudentAnswer @SEId = 1, @QId = 3, @TextAns = N'It uniquely identifies each row in a table.'
go

exec SP_GradeStudentExam @SEId = 1
go

print '=== Schema, objects, and seed data (including the baseline Exm_Id=1 / SE_Id=1 demo run) built successfully on ExaminationSystemDB. ==='
go
