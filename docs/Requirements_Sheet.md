# Examination System Database — Requirements Sheet

**Project Title:** Examination System Database

## System Requirements

- The system should provide a question pool, so an instructor can pick exam questions from it.
- Question types may be Multiple Choice, True & False, or Text questions.
- For Multiple Choice and True & False questions, the system should store the correct answer, check the student's answer, and store the result.
- For Text questions, the system should store the best accepted answer and use text functions / regular expressions to check the student's answer — displaying valid and invalid answers to the instructor for manual review and marking (bonus).
- The system should store course information (name, description, Max Degree, Min Degree), instructor information, and student information. Each instructor can teach one or more courses, and each course may be taught by one instructor per class (the instructor may change for other classes/years).
- The Training Manager can add and edit Branches, Tracks within each department, and add new Intakes.
- The Training Manager can add students and define their personal data, intake, branch, and track.
- Training Managers, Instructors, and Students each need a login account to access the system.
- An instructor can create an exam (for their own course only) by selecting a number of questions of each type — either randomly selected by the system, or manually selected from the question pool. A degree must be assigned to each question, and the total must not exceed the course's Max Degree. A course may have more than one exam.
- Each exam records: type (Exam or Corrective), intake, branch, track, course, start time, end time, total time, and allowance options.
- Each exam is associated with a year, course, and instructor.
- An instructor selects which students can take a specific exam, and defines the exam date, start time, and end time. Students can view and take the exam only within the specified time window.
- The system stores each student's answers, automatically calculates correct answers, and computes the student's final result for that course.
- Test data must be inserted into all tables and the system tested end-to-end.

## Technical Requirements

- Implement the database using files and filegroups, sized according to estimated data volume.
- Choose the appropriate data type for every column, and follow consistent naming conventions for all objects.
- Implement indexes for optimal query performance.
- Use constraints and triggers to enforce data integrity and access rules.
- Use procedures and functions for all system operations, and views for all reporting — end users should never need to write raw queries.
- Provide multiple search/filter options across different criteria.
- Implement four account types: Admin, Training Manager, Instructor, and Student — each restricted to their own tasks and objects only (via SQL users and permissions).
- The system must perform an automatic daily backup.

## Project Deliverables

- System Requirement sheet (this document)
- System ERD (image or Word format)
- Database files
- SQL Server solution: one script per contributor plus a single consolidated script for the full database structure, objects, and data
- Text file listing and briefly describing every database object (Views, Procedures, Functions, Triggers, etc.)
- Test sheets containing test queries, results, and comments
- Text file listing all database accounts and passwords
