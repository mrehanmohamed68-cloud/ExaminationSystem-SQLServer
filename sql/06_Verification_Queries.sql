-------------------------------------------------------------------
-- ExaminationSystemDB - Verification / Sanity Check Queries
-- Run after 02_ExaminationSystem_Build_Schema_Objects.sql and
-- 03_ExaminationSystem_Security_Setup.sql, to confirm object counts
-- and permission grants look right before moving on to testing.
-------------------------------------------------------------------

use ExaminationSystemDB
go

-------------------------------------------------------------------
-- 1) Object counts (sanity check that everything got created)
-------------------------------------------------------------------
select count(*) as TablesCount from sys.tables
go
select count(*) as ProceduresCount from sys.procedures
go
select count(*) as ViewsCount from sys.views
go

-------------------------------------------------------------------
-- 2) Permission audit: which role/user has which permission on
--    which object (used to confirm the access-control design from
--    03_ExaminationSystem_Security_Setup.sql)
-------------------------------------------------------------------
select dp.name as RoleOrUser, o.name as ObjectName, p.permission_name
from sys.database_permissions p
join sys.database_principals dp on dp.principal_id = p.grantee_principal_id
join sys.objects o on o.object_id = p.major_id
where dp.name in ('ExamAdminRole','TrainingManagerRole','InstructorRole','StudentRole')
order by dp.name, o.name
go
