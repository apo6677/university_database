--
-- PostgreSQL database dump
--

-- Dumped from database version 13.6
-- Dumped by pg_dump version 13.6

-- Started on 2025-12-19 16:57:59

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 676 (class 1247 OID 18716)
-- Name: DiplomaType; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public."DiplomaType" AS ENUM (
    'certificate',
    'degree',
    'diploma'
);


ALTER TYPE public."DiplomaType" OWNER TO postgres;

--
-- TOC entry 679 (class 1247 OID 18724)
-- Name: course_dependency_mode_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.course_dependency_mode_type AS ENUM (
    'required',
    'recommended'
);


ALTER TYPE public.course_dependency_mode_type OWNER TO postgres;

--
-- TOC entry 682 (class 1247 OID 18730)
-- Name: diploma_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.diploma_type AS ENUM (
    'degree',
    'diploma',
    'certificate'
);


ALTER TYPE public.diploma_type OWNER TO postgres;

--
-- TOC entry 685 (class 1247 OID 18738)
-- Name: level_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.level_type AS ENUM (
    'A',
    'B',
    'C',
    'D'
);


ALTER TYPE public.level_type OWNER TO postgres;

--
-- TOC entry 688 (class 1247 OID 18748)
-- Name: rank_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.rank_type AS ENUM (
    'full',
    'associate',
    'assistant',
    'lecturer'
);


ALTER TYPE public.rank_type OWNER TO postgres;

--
-- TOC entry 691 (class 1247 OID 18758)
-- Name: register_status_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.register_status_type AS ENUM (
    'proposed',
    'requested',
    'approved',
    'rejected',
    'pass',
    'fail'
);


ALTER TYPE public.register_status_type OWNER TO postgres;

--
-- TOC entry 694 (class 1247 OID 18772)
-- Name: semester_season_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.semester_season_type AS ENUM (
    'winter',
    'spring'
);


ALTER TYPE public.semester_season_type OWNER TO postgres;

--
-- TOC entry 697 (class 1247 OID 18778)
-- Name: semester_status_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.semester_status_type AS ENUM (
    'past',
    'present',
    'future'
);


ALTER TYPE public.semester_status_type OWNER TO postgres;

--
-- TOC entry 232 (class 1255 OID 18785)
-- Name: assign_grades_for_semester(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.assign_grades_for_semester(semester_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    lab_grade_var float;
    exam_grade_var float;
    exam_percentage_var float;
    final_grade_var float;
    register_status_var register_status_type;
BEGIN
    -- Assign random values to lab_grade and exam_grade for approved registers in the specified semester
    UPDATE public."Register" AS r
    SET lab_grade = CASE
            WHEN cr.labuses IS NOT NULL THEN (random() * 5 + 5)
            ELSE NULL
        END,
        exam_grade = random() * 10
    FROM public."CourseRun" AS cr
    WHERE r.serial_number = cr.serial_number
        AND cr.semesterrunsin = semester_id
        AND cr.labuses IS NOT NULL
        AND r.register_status = 'approved';

    -- Calculate final_grade and update register status for approved registers
    UPDATE public."Register" AS r
    SET final_grade = CASE
            WHEN r.lab_grade >= 5 AND r.exam_grade >= 5 THEN (r.lab_grade * (1 - cr.exam_percentage / 100)) + (r.exam_grade * cr.exam_percentage / 100)
            ELSE 0
        END,
        register_status = CASE
            WHEN (r.lab_grade >= 5 AND r.exam_grade >= 5) AND ((r.lab_grade * (1 - cr.exam_percentage / 100)) + (r.exam_grade * cr.exam_percentage / 100)) >= 5 THEN 'pass'::register_status_type
            ELSE 'fail'::register_status_type
        END
    FROM public."CourseRun" AS cr
    WHERE r.serial_number = cr.serial_number
        AND cr.semesterrunsin = semester_id
        AND r.register_status = 'approved';

    RETURN;
END;
$$;


ALTER FUNCTION public.assign_grades_for_semester(semester_id integer) OWNER TO postgres;

--
-- TOC entry 236 (class 1255 OID 18786)
-- Name: check_committee_constraint(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_committee_constraint() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    committee_count INTEGER;
    program_committeenum INTEGER;
BEGIN
    -- Get the CommitteeNum of the corresponding program
    SELECT "CommitteeNum" INTO program_committeenum
    FROM "Program"
    WHERE "ProgramID" = (SELECT "ProgramID" FROM "Thesis" WHERE "ThesisID" = NEW."ThesisID");

    -- Count the number of existing entries in the Committee table for the same ThesisID
    SELECT COUNT(*) INTO committee_count
    FROM "Committee"
    WHERE "ThesisID" = NEW."ThesisID";

    -- Check if the number of entries in Committee exceeds the CommitteeNum of the program
    IF committee_count >= program_committeenum THEN
        RAISE EXCEPTION 'Cannot insert more professors for the thesis. Maximum committee size reached.';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_committee_constraint() OWNER TO postgres;

--
-- TOC entry 237 (class 1255 OID 18787)
-- Name: check_foreignlanguageprogram_year_constraint(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_foreignlanguageprogram_year_constraint() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM "ForeignLanguageProgram"
        WHERE program_year > NEW.program_year
		AND NEW."new_program_type" = 'ForeignLanguageProgram'
    ) THEN
        RAISE EXCEPTION 'Cannot insert ForeignLanguageProgram with a year older than the most recent program year.';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_foreignlanguageprogram_year_constraint() OWNER TO postgres;

--
-- TOC entry 238 (class 1255 OID 18788)
-- Name: check_register_status_change(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_register_status_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if the register status is changing from proposed or requested to approved
    IF NEW.register_status = 'approved' AND (OLD.register_status = 'proposed' OR OLD.register_status = 'requested') THEN
        -- Calculate the total units of all courses with register status proposed or requested for the same AMKA
        DECLARE
            total_units integer;
        BEGIN
            SELECT COALESCE(SUM(c.units), 0) INTO total_units
            FROM public."Register" AS r
            JOIN public."Course" AS c ON r."course_code" = c."course_code"
            WHERE r."amka" = NEW."amka"
                AND (r.register_status = 'proposed' OR r.register_status = 'requested');

            -- Check if the total units exceed the limit of 50
            IF total_units > 50 THEN
                -- Raise an exception and rollback the transaction
                RAISE EXCEPTION 'Total units for proposed or requested courses exceed the limit of 50.';
                RETURN NULL;
            END IF;
        END;
    END IF;

    -- Check if the course being changed has dependencies
    IF EXISTS (
        SELECT 1
        FROM public."Course_depends" AS cd
        WHERE cd.dependent = NEW.course_code
    ) THEN
        -- Check if the dependent course is required and if the main course has register status pass
        DECLARE
            main_course_code public."Course".course_code%TYPE;
            main_course_status public."Register".register_status%TYPE;
        BEGIN
            SELECT cd.main, r.register_status
            INTO main_course_code, main_course_status
            FROM public."Course_depends" AS cd
            JOIN public."Register" AS r ON cd.main = r.course_code AND r.amka = NEW.amka
            WHERE cd.dependent = NEW.course_code;

            IF main_course_status IS NULL OR main_course_status <> 'pass' THEN
                -- Change the register status to rejected
                NEW.register_status = 'rejected';
                RAISE NOTICE 'Course "%", which is dependent on "%", has been rejected due to missing required course.', NEW.course_code, main_course_code;
            END IF;
        END;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_register_status_change() OWNER TO postgres;

--
-- TOC entry 250 (class 1255 OID 18789)
-- Name: check_seasonalprogram_year_constraint(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_seasonalprogram_year_constraint() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM "SeasonalProgram"
        WHERE program_year > NEW.program_year
		AND NEW."new_program_type" = 'SeasonalProgram'
    ) THEN
        RAISE EXCEPTION 'Cannot insert SeasonalProgram with a year older than the most recent program year.';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_seasonalprogram_year_constraint() OWNER TO postgres;

--
-- TOC entry 251 (class 1255 OID 18790)
-- Name: check_semester_overlap(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_semester_overlap() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.semester_status = 'future' THEN
        -- Check if there are any overlapping semesters
        IF EXISTS (
            SELECT 1
            FROM public."Semester"
            WHERE (NEW.start_date, NEW.end_date) OVERLAPS (start_date, end_date)
        ) THEN
            RAISE EXCEPTION 'The new semester overlaps with an existing semester.';
        END IF;

        -- Check if the new semester follows the chronological order
        IF EXISTS (
            SELECT 1
            FROM public."Semester"
            WHERE end_date >= NEW.start_date
        ) THEN
            RAISE EXCEPTION 'The new semester does not follow the chronological order.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_semester_overlap() OWNER TO postgres;

--
-- TOC entry 252 (class 1255 OID 18791)
-- Name: find_most_common_sector(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.find_most_common_sector() RETURNS TABLE(sector_code integer, sector_title character)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT l.sector_code, s.sector_title
    FROM (
        SELECT lab.sector_code, COUNT(*) AS count
        FROM public."Lab" AS lab
        GROUP BY lab.sector_code
        ORDER BY COUNT(*) DESC
        LIMIT 1
    ) AS l
    JOIN public."Sector" AS s ON l.sector_code = s.sector_code;
END;
$$;


ALTER FUNCTION public.find_most_common_sector() OWNER TO postgres;

--
-- TOC entry 253 (class 1255 OID 18792)
-- Name: get_all_graduate_students(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_all_graduate_students(program_id integer) RETURNS TABLE(am character)
    LANGUAGE plpgsql ROWS 200
    AS $$
BEGIN
    RETURN QUERY
    SELECT student.am FROM "Student" student
    WHERE student.amka 
    IN(SELECT register.amka FROM "Register" register WHERE register.amka = student.amka 
      AND register.register_status = 'pass'
      AND register.course_code 
      IN(SELECT cr.course_code FROM "CourseRun" cr WHERE cr.course_code
        IN(SELECT refersTo."CourseRunCode" FROM "RefersTo" refersTo WHERE refersTo."SeasonalProgramID" = 7)));

END;
$$;


ALTER FUNCTION public.get_all_graduate_students(program_id integer) OWNER TO postgres;

--
-- TOC entry 254 (class 1255 OID 18793)
-- Name: get_all_professors_names(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_all_professors_names() RETURNS TABLE(name character varying, surname character varying)
    LANGUAGE plpgsql ROWS 200
    AS $$
BEGIN
    RETURN QUERY
    SELECT person.name,person.surname FROM "Person" person 
    WHERE person.amka 

    IN(SELECT prof.amka FROM "Professor" prof WHERE prof.amka
      IN (SELECT teaches.amka FROM "Teaches" teaches WHERE teaches.course_code 
         IN(SELECT courseRun.course_code FROM "CourseRun" courseRun WHERE courseRun.course_code
           IN(SELECT refTo."CourseRunCode" FROM "RefersTo" refTo WHERE refTo."SeasonalProgramID"
             IN(SELECT prog."ProgramID" FROM "Program" prog )))));
END;
$$;


ALTER FUNCTION public.get_all_professors_names() OWNER TO postgres;

--
-- TOC entry 255 (class 1255 OID 18794)
-- Name: get_incomplete_obligatory_courses(integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_incomplete_obligatory_courses(program_id integer, student_amka character varying) RETURNS TABLE(course_code character, course_title character)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT c.course_code, c.course_title
    FROM public."Course" c
    JOIN public."ProgramOffersCourse" poc ON c.course_code = poc."CourseCode"
    LEFT JOIN (
        SELECT rc.course_code
        FROM public."Register" r
        JOIN public."CourseRun" rc ON r.course_code = rc.course_code AND r.serial_number = rc.serial_number
        WHERE r.amka = student_amka
          AND r.passed = TRUE
    ) pc ON c.course_code = pc.course_code
    WHERE poc."ProgramID" = program_id
      AND pc.course_code IS NULL
      AND c.obligatory = TRUE;

END;
$$;


ALTER FUNCTION public.get_incomplete_obligatory_courses(program_id integer, student_amka character varying) OWNER TO postgres;

--
-- TOC entry 230 (class 1255 OID 18795)
-- Name: get_labteachers_workload(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_labteachers_workload() RETURNS TABLE(amka character varying, surname character varying, name character varying, sum bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT person.amka,person.surname,person.name,SUM(course.lab_hours) FROM "Person" person,"Course" course
    WHERE person.amka IN(SELECT lt.amka FROM "LabTeacher" lt)
          AND person.amka IN(SELECT sp.amka FROM "Supports" sp WHERE sp.course_code IN(course.course_code))
          AND course.typical_season IN(SELECT semester.academic_season FROM "Semester" semester WHERE semester.semester_status = 'present')      
    GROUP BY person.amka;

END;
$$;


ALTER FUNCTION public.get_labteachers_workload() OWNER TO postgres;

--
-- TOC entry 231 (class 1255 OID 18796)
-- Name: get_persons(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_persons() RETURNS TABLE(fullname text, person_type text)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
    SELECT p.surname || ', ' || p.name AS fullname, 'Student' AS person_type
    FROM public."Student" s
    JOIN public."Person" p ON s.amka = p.amka
    UNION ALL
    SELECT p.surname || ', ' || p.name AS fullname, 'Professor' AS person_type
    FROM public."Professor" pr
    JOIN public."Person" p ON pr.amka = p.amka
    UNION ALL
    SELECT p.surname || ', ' || p.name AS fullname, 'LabTeacher' AS person_type
    FROM public."LabTeacher" lt
    JOIN public."Person" p ON lt.amka = p.amka;
END;
$$;


ALTER FUNCTION public.get_persons() OWNER TO postgres;

--
-- TOC entry 233 (class 1255 OID 18797)
-- Name: get_prerequisites(character); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_prerequisites(code character) RETURNS TABLE(c_code character, title character)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY

    SELECT cdp.main,c.course_title FROM public."Course_depends" cdp ,public."Course" c 
    WHERE cdp.dependent = code AND cdp.main = c.course_code;
END;
$$;


ALTER FUNCTION public.get_prerequisites(code character) OWNER TO postgres;

--
-- TOC entry 234 (class 1255 OID 18798)
-- Name: get_student_by_am(character); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_student_by_am(s_am character) RETURNS TABLE(amka character varying, student_am character, entry_date date)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT s.amka, s.am, s.entry_date
  FROM public."Student" s
  WHERE s.am = s_am;
END;
$$;


ALTER FUNCTION public.get_student_by_am(s_am character) OWNER TO postgres;

--
-- TOC entry 235 (class 1255 OID 18799)
-- Name: get_students_by_course(character); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_students_by_course(course_code character) RETURNS TABLE(name character varying, surname character varying, am character)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT p.name, p.surname, s.am
  FROM public."Person" p
  JOIN public."Student" s ON p.amka = s.amka
  JOIN public."Register" r ON s.amka = r.amka
  WHERE r.course_code = get_students_by_course.course_code;
END;
$$;


ALTER FUNCTION public.get_students_by_course(course_code character) OWNER TO postgres;

--
-- TOC entry 256 (class 1255 OID 18800)
-- Name: insert_random_labteacher_data(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_random_labteacher_data(num_insertions integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
	level_enum TEXT[] := ARRAY['A', 'B', 'C', 'D'];
    name_var varchar(30);
    surname_var varchar(30);
    amka_var varchar(11);
    father_name_var varchar(30);
    email_var varchar(30);
    labworks_var integer;
    random_level level_type;
BEGIN
    FOR i IN 1..num_insertions LOOP
        SELECT name INTO name_var FROM public."Name" ORDER BY random() LIMIT 1;
        SELECT surname INTO surname_var FROM public."Surname" ORDER BY random() LIMIT 1;
        SELECT name INTO father_name_var FROM public."Name" ORDER BY random() LIMIT 1;
        
        amka_var := FLOOR(RANDOM() * 90000000000 + 10000000000)::varchar(11);
        
        email_var := translate(surname_var, 'ΑΆΒΒΓΔΕΈΖΗΉΘΙΊΚΛΜΝΞΟΌΠΡΣΤΥΎΦΧΨΩΏαάβγδεέζηήθιίκλμνξοόπρστυύφχψωώ', 'AABBGDEEZHHTIIKLMNXOOPRSTYUPHFCCWAOaaaabgdeeezhhtiiiklmnxoooprstyuuphfccwao') || substring(amka_var, 8, 4) || '@tuc.gr';
        
        labworks_var := (SELECT lab_code FROM public."Lab" ORDER BY random() LIMIT 1);
        
        random_level := level_enum[1 + floor(random() * 4)]::level_type;
        
        INSERT INTO public."Person" (amka, name, surname, father_name, email)
        VALUES (amka_var, name_var, surname_var, father_name_var, email_var);
        
        INSERT INTO public."LabTeacher" (amka, labworks, level)
        VALUES (amka_var, labworks_var, random_level);
    END LOOP;
END;
$$;


ALTER FUNCTION public.insert_random_labteacher_data(num_insertions integer) OWNER TO postgres;

--
-- TOC entry 257 (class 1255 OID 18801)
-- Name: insert_random_professor_data(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_random_professor_data(num_insertions integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
	rank_enum TEXT[] := ARRAY['full', 'associate', 'assistant', 'lecturer'];
    name_var varchar(30);
    surname_var varchar(30);
    amka_var varchar(11);
    father_name_var varchar(30);
    email_var varchar(30);
    random_rank rank_type;
    labjoins_var integer;
BEGIN
    FOR i IN 1..num_insertions LOOP
        SELECT name INTO name_var FROM public."Name" ORDER BY random() LIMIT 1;
        SELECT surname INTO surname_var FROM public."Surname" ORDER BY random() LIMIT 1;
        SELECT name INTO father_name_var FROM public."Name" ORDER BY random() LIMIT 1;
        
        amka_var := FLOOR(RANDOM() * 90000000000 + 10000000000)::varchar(11);
        
        email_var := translate(surname_var, 'ΑΆΒΒΓΔΕΈΖΗΉΘΙΊΚΛΜΝΞΟΌΠΡΣΤΥΎΦΧΨΩΏαάβγδεέζηήθιίκλμνξοόπρστυύφχψωώ', 'AABBGDEEZHHTIIKLMNXOOPRSTYUPHFCCWAOaaaabgdeeezhhtiiiklmnxoooprstyuuphfccwao') || substring(amka_var, 8, 4) || '@tuc.gr';
        
        random_rank := rank_enum[1 + floor(random() * 4)]::rank_type;
        
        labjoins_var := (SELECT lab_code FROM public."Lab" ORDER BY random() LIMIT 1);
        
        INSERT INTO public."Person" (amka, name, surname, father_name, email)
        VALUES (amka_var, name_var, surname_var, father_name_var, email_var);
        
        INSERT INTO public."Professor" (amka, rank, labjoins)
        VALUES (amka_var, random_rank, labjoins_var);
    END LOOP;
END;
$$;


ALTER FUNCTION public.insert_random_professor_data(num_insertions integer) OWNER TO postgres;

--
-- TOC entry 258 (class 1255 OID 18802)
-- Name: insert_random_student_data(date, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_random_student_data(entry_date date, num_insertions integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    name_var varchar(30);
    surname_var varchar(30);
    am_var varchar(10);
    amka_var varchar(11);
    father_name_var varchar(30);
    email_var varchar(30);
    is_foreign boolean;
BEGIN
    FOR i IN 1..num_insertions LOOP
        SELECT name INTO name_var FROM public."Name" ORDER BY random() LIMIT 1;
        SELECT surname INTO surname_var FROM public."Surname" ORDER BY random() LIMIT 1;
        SELECT name INTO father_name_var FROM public."Name" ORDER BY random() LIMIT 1;
        
        is_foreign := (random() < 0.2); -- 20% chance of foreign student
        
        IF is_foreign THEN
            am_var := CONCAT(EXTRACT(YEAR FROM entry_date)::character(4), '1', LPAD(i::text, 5, '0'));
        ELSE
            am_var := CONCAT(EXTRACT(YEAR FROM entry_date)::character(4), '0', LPAD(i::text, 5, '0'));
        END IF;
        
        SELECT FLOOR(RANDOM() * 90000000000 + 10000000000)::varchar(11) INTO amka_var;
        
        email_var := translate(surname_var, 'ΑΆΒΒΓΔΕΈΖΗΉΘΙΊΚΛΜΝΞΟΌΠΡΣΤΥΎΦΧΨΩΏαάβγδεέζηήθιίκλμνξοόπρστυύφχψωώ', 'AABBGDEEZHHTIIKLMNXOOPRSTYUPHFCCWAOaaaabgdeeezhhtiiiklmnxoooprstyuuphfccwao') || substring(amka_var, 8, 4) || '@tuc.gr';
        
        INSERT INTO public."Person" (amka, name, surname, father_name, email)
        VALUES (amka_var, name_var, surname_var, father_name_var, email_var);
        
        INSERT INTO public."Student" (am, entry_date, amka)
        VALUES (am_var, entry_date, amka_var);
    END LOOP;
END;
$$;


ALTER FUNCTION public.insert_random_student_data(entry_date date, num_insertions integer) OWNER TO postgres;

--
-- TOC entry 259 (class 1255 OID 18803)
-- Name: insert_refersto(integer, integer, text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_refersto(program_id integer, custom_unit_id integer, course_codes text[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    program_exists boolean;
    course_serials integer[];
BEGIN
    -- Check if the program with the given ProgramID exists in SeasonalProgram table
    SELECT EXISTS(
        SELECT 1
        FROM public."SeasonalProgram"
        WHERE "ProgramID" = program_id
    ) INTO program_exists;

    IF NOT program_exists THEN
        RAISE EXCEPTION 'Program with ProgramID % does not exist in SeasonalProgram table.', program_id;
    END IF;

    -- Fill the CustomUnits table with missing values
    INSERT INTO public."CustomUnits" ("CustomUnitID", "SeasonalProgramID", "Credits")
    SELECT custom_unit_id, program_id, floor(random() * (35 - 25 + 1) + 25)::integer
    FROM unnest(course_codes)
    ON CONFLICT ("CustomUnitID", "SeasonalProgramID") DO NOTHING;

    -- Retrieve the serial numbers of the course runs for the given course codes
    SELECT ARRAY_AGG("serial_number")
    INTO course_serials
    FROM public."CourseRun"
    WHERE "course_code" = ANY(course_codes);

    -- Insert the records into the RefersTo table
    INSERT INTO public."RefersTo" ("CustomUnitID", "SeasonalProgramID", "CourseRunCode", "CourseRunSerial")
    SELECT custom_unit_id, program_id, course_code, course_serial
    FROM unnest(course_codes) AS course_code
    CROSS JOIN unnest(course_serials) AS course_serial
    ON CONFLICT DO NOTHING;

END;
$$;


ALTER FUNCTION public.insert_refersto(program_id integer, custom_unit_id integer, course_codes text[]) OWNER TO postgres;

--
-- TOC entry 260 (class 1255 OID 18804)
-- Name: insert_study_program(character varying, integer, integer, integer, boolean, integer, public.diploma_type, integer, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_study_program(new_program_type character varying, new_duration integer, new_min_courses integer, new_min_credits integer, new_obligatory boolean, new_committee_num integer, new_diploma_type public.diploma_type, new_num_of_participants integer, new_year character varying, new_season character varying DEFAULT NULL::character varying, new_language character varying DEFAULT NULL::character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
    new_program_id integer;
    existing_program_year character varying;
	limit_foreign_participants integer := new_num_of_participants*2/3;
	limit_diploma_participants integer := new_num_of_participants*1/3;
BEGIN
    -- Generate a unique program ID
    SELECT COALESCE(MAX("ProgramID"), 0) + 1 INTO new_program_id FROM public."Program";

-- Delete corresponding rows from "ProgramOffersCourse" table
DELETE FROM public."ProgramOffersCourse"
WHERE "ProgramID" IN (
    SELECT "ProgramID"
    FROM public."Program"
    WHERE "Year" = new_year
);

-- Delete corresponding rows from "Joins" table
DELETE FROM public."Joins"
WHERE "ProgramID" IN (
    SELECT "ProgramID"
    FROM public."Program"
    WHERE "Year" = new_year
);

-- Delete existing programs with the same year
DELETE FROM public."Program"
WHERE "Year" = new_year;

-- Insert the new program into the "Program" table
INSERT INTO public."Program" (
    "ProgramID",
    "Duration",
    "MinCourses",
    "MinCredits",
    "Obligatory",
    "CommitteeNum",
    "DiplomaType",
    "NumOfParticipants",
    "Year"
)
VALUES (
    new_program_id,
    new_duration,
    new_min_courses,
    new_min_credits,
    new_obligatory,
    new_committee_num,
    new_diploma_type,
    new_num_of_participants,
    new_year
);


    -- Check if there is an existing program of a later year
  --  IF new_program_type = 'StandardProgram' AND existing_program_year IS NOT NULL THEN
    --  RAISE EXCEPTION 'Cannot insert program with a year older than the existing program.';
   -- END IF;

    -- Check if there is already an existing program of a later year based on the program type
    IF new_program_type = 'SeasonalProgram' THEN
        EXECUTE format('SELECT "Year" FROM public."Program" WHERE "Year" > $1 ORDER BY "Year" ASC LIMIT 1')
            INTO existing_program_year
            USING new_year;
    ELSIF new_program_type = 'ForeignLanguageProgram' THEN
        EXECUTE format('SELECT "Year" FROM public."Program" WHERE "Year" > $1 ORDER BY "Year" ASC LIMIT 1')
            INTO existing_program_year
            USING new_year;
    ELSE
        EXECUTE format('SELECT "Year" FROM public."Program" WHERE "Year" > $1 AND "ProgramID" IN (SELECT "ProgramID" FROM public."Joins") ORDER BY "Year" ASC LIMIT 1')
            INTO existing_program_year
            USING new_year;
    END IF;

    -- Check if there is an existing program of a later year
    IF existing_program_year IS NOT NULL THEN
        RAISE EXCEPTION 'Cannot insert program with a year older than the existing program.';
    END IF;

    -- Insert into the appropriate additional table based on program type
    IF new_program_type = 'SeasonalProgram' THEN
        -- Insert into SeasonalProgram table
        INSERT INTO public."SeasonalProgram" (
            "ProgramID",
            "Season"
        )
        VALUES (
            new_program_id,
            new_season
        );
    ELSIF new_program_type = 'ForeignLanguageProgram' THEN
        -- Insert into ForeignLanguageProgram table
        INSERT INTO public."ForeignLanguageProgram" (
            "ProgramID",
            "Language"
        )
        VALUES (
            new_program_id,
            new_language
        );
    END IF; 

        -- Connect the program with all courses through ProgramOffersCourse
    INSERT INTO public."ProgramOffersCourse" ("ProgramID", "CourseCode")
    SELECT new_program_id, "course_code" FROM public."Course"; 

IF new_program_type = 'StandardProgram' THEN
    INSERT INTO public."Joins" ("StudentAMKA", "ProgramID")
    SELECT s."amka", new_program_id
    FROM public."Student" st
    JOIN public."Person" s ON s."amka" = st."amka"
    WHERE substring(st."am", 5, 1) = '0'
        AND substring(st."am", 1, 4) = new_year
	ORDER BY random()
    LIMIT new_num_of_participants;
END IF;

IF new_program_type = 'SeasonalProgram' THEN
    INSERT INTO public."Joins" ("StudentAMKA", "ProgramID")
    SELECT s."amka", new_program_id
    FROM public."Student" st
    JOIN public."Person" s ON s."amka" = st."amka"
    WHERE substring(st."am", 5, 1) = '0'
        AND substring(st."am", 1, 4) = new_year
	ORDER BY random()
    LIMIT new_num_of_participants;
END IF;

-- Connect the program with students from Diploma for ForeignLanguageProgram
IF new_program_type = 'ForeignLanguageProgram' THEN
    INSERT INTO public."Joins" ("StudentAMKA", "ProgramID")
    SELECT s."amka", new_program_id
    FROM public."Student" st
    JOIN public."Person" s ON s."amka" = st."amka"
    WHERE substring(st."am", 5, 1) = '1'
        AND substring(st."am", 1, 4) = new_year
	    ORDER BY random()
    LIMIT limit_foreign_participants;

    INSERT INTO public."Joins" ("StudentAMKA", "ProgramID")
    SELECT d."StudentAMKA", new_program_id
    FROM public."Diploma" d
    JOIN public."Person" s ON s."amka" = d."StudentAMKA"
    ORDER BY random()
    LIMIT limit_diploma_participants;
END IF;

    -- Return the newly generated program ID
    RETURN new_program_id;
END;
$_$;


ALTER FUNCTION public.insert_study_program(new_program_type character varying, new_duration integer, new_min_courses integer, new_min_credits integer, new_obligatory boolean, new_committee_num integer, new_diploma_type public.diploma_type, new_num_of_participants integer, new_year character varying, new_season character varying, new_language character varying) OWNER TO postgres;

--
-- TOC entry 261 (class 1255 OID 18805)
-- Name: insert_thesis(character varying, character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_thesis(student_am character varying, thesis_title character varying, program_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    student_amka_var character varying;
    thesis_id_var INTEGER;
    committee_size_var INTEGER;
    program_committeenum INTEGER;
    student_units INTEGER;

    min_courses_var integer;
    min_credits_var integer;
    obligatory_thesis_var boolean;
    student_units_var integer;
    thesis_exists_var boolean;
    diploma_num_var INTEGER;
    thesis_grade_var numeric;
    diploma_grade_var numeric;
    student_avg_grade_var numeric; -- Declare the variable here
BEGIN
    -- Get the StudentAMKA from the Student table based on the student_am value
    SELECT amka INTO student_amka_var
    FROM public."Student"
    WHERE am = student_am;

    -- Check if the student_am exists in the Student table
    IF student_amka_var IS NULL THEN
        RAISE EXCEPTION 'Student with the given AM does not exist.';
    END IF;

    -- Generate a unique ThesisID
    SELECT MAX("ThesisID") + 1 INTO thesis_id_var
    FROM public."Thesis";

    -- If no records exist in the Thesis table, set the initial ThesisID to 1
    IF thesis_id_var IS NULL THEN
        thesis_id_var := 1;
    END IF;

    -- Get the minimum course requirement, minimum credit requirement, and obligatory thesis flag from the program
    SELECT "MinCourses", "MinCredits", "Obligatory" INTO min_courses_var, min_credits_var, obligatory_thesis_var
    FROM public."Program"
    WHERE "ProgramID" = program_id;

    -- Check if the student has passed at least the minimum number of courses required
    SELECT COUNT(*) INTO student_units_var
    FROM public."Register"
    WHERE "amka" = student_amka_var
        AND register_status = 'pass';

    IF student_units_var < min_courses_var THEN
        RAISE EXCEPTION 'Student has not passed the minimum number of courses required.';
    END IF;

    -- Calculate the number of units earned by the student
    SELECT COALESCE(SUM(c.units), 0) INTO student_units_var
    FROM public."Register" AS r
    JOIN public."Course" AS c ON r."course_code" = c."course_code"
    WHERE r."amka" = student_amka_var
        AND r.register_status = 'pass';

    -- Check if the student has earned at least the minimum number of credits required
    IF student_units_var < min_credits_var THEN
        RAISE EXCEPTION 'Student has not earned the minimum number of credits required.';
    END IF;

    -- Check if the obligatory thesis condition is met
    IF obligatory_thesis_var THEN
        SELECT EXISTS (
            SELECT 1
            FROM public."Thesis"
            WHERE "StudentAMKA" = student_amka_var
        ) INTO thesis_exists_var;

        IF NOT thesis_exists_var THEN
            RAISE EXCEPTION 'Student has not submitted a thesis for the obligatory requirement.';
        END IF;
    END IF;

    -- Generate a unique DiplomaNum
    SELECT COALESCE(MAX("DiplomaNum"), 0) + 1 INTO diploma_num_var
    FROM public."Diploma";

    -- If no records exist in the Diploma table, set the initial DiplomaNum to 1
    IF diploma_num_var IS NULL THEN
        diploma_num_var := 1;
    END IF;

    -- Insert the new thesis record
    INSERT INTO public."Thesis" ("ThesisID", "Title", "StudentAMKA", "ProgramID", "Grade")
    VALUES (thesis_id_var, thesis_title, student_amka_var, program_id, FLOOR(RANDOM() * 6 + 5)::numeric);

    -- Get the CommitteeNum from the Program table based on the program_id
    SELECT "CommitteeNum" INTO program_committeenum
    FROM public."Program"
    WHERE "ProgramID" = program_id;

    -- Fetch random teachers for the committee
    SELECT COUNT(*) INTO committee_size_var
    FROM public."Teaches";

    -- Insert random teachers into the Committee table
    INSERT INTO public."Committee" ("ProfessorAMKA", "ThesisID", "Supervisor")
    SELECT "amka", thesis_id_var, FALSE
    FROM public."Teaches"
    OFFSET floor(random() * committee_size_var)
    LIMIT program_committeenum;

	-- Calculate the weighted average of all courses the student has passed
	SELECT COALESCE(
    	SUM(CASE
        	WHEN c.units IN (1, 2) THEN r.final_grade * 1
        	WHEN c.units IN (3, 4) THEN r.final_grade * 1.5
        	ELSE r.final_grade * 2
    	END) / NULLIF(SUM(
        	CASE
            	WHEN c.units IN (1, 2) THEN 1
            	WHEN c.units IN (3, 4) THEN 1.5
            	ELSE 2
        	END), 0), 0)
	INTO student_avg_grade_var
	FROM public."Register" AS r
	JOIN public."Course" AS c ON r."course_code" = c."course_code"
	JOIN public."ProgramOffersCourse" AS poc ON c."course_code" = poc."CourseCode"
	WHERE r."amka" = student_amka_var
    	AND r.register_status = 'pass'
    	AND poc."ProgramID" = program_id;

    SELECT "Grade" INTO thesis_grade_var
    FROM public."Thesis"
    WHERE "ThesisID" = thesis_id_var;

    diploma_grade_var := thesis_grade_var * 0.2 + student_avg_grade_var * 0.8;

    -- Insert a new entry in the Diploma table
    INSERT INTO public."Diploma" ("DiplomaNum", "DiplomaTitle", "StudentAMKA", "ProgramID", "DiplomaGrade")
    VALUES (diploma_num_var, thesis_title, student_amka_var, program_id, diploma_grade_var);
END;
$$;


ALTER FUNCTION public.insert_thesis(student_am character varying, thesis_title character varying, program_id integer) OWNER TO postgres;

--
-- TOC entry 262 (class 1255 OID 18806)
-- Name: update_previous_semester(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_previous_semester() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if the updated semester status is 'present'
    IF NEW.semester_status = 'present' THEN
        -- Check if any previous semester has its status as 'past'
        IF EXISTS (
            SELECT 1
            FROM public."Semester"
            WHERE semester_status = 'past'
              AND academic_season = NEW.academic_season
              AND academic_year = NEW.academic_year
        ) THEN
            RAISE EXCEPTION 'Cannot update to "present" status. Previous semester is still "past".';
        END IF;
        
        -- Check if there is a previous semester with a status other than 'past'
        IF EXISTS (
            SELECT 1
            FROM public."Semester"
            WHERE semester_id <> NEW.semester_id
              AND semester_status <> 'past'
              AND academic_season = NEW.academic_season
              AND academic_year = NEW.academic_year
              AND start_date >= NEW.start_date
        ) THEN
            RAISE EXCEPTION 'Cannot update to "present" status. Previous semester exists with a status other than "past" and a start date after the current semester.';
        END IF;
        
        -- Update the previous semester with status 'present' to 'past'
        UPDATE public."Semester"
        SET semester_status = 'past'
        WHERE semester_id <> NEW.semester_id
          AND semester_status = 'present';
    	END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_previous_semester() OWNER TO postgres;

--
-- TOC entry 263 (class 1255 OID 18807)
-- Name: update_previous_semester_future_to_present(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_previous_semester_future_to_present() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if the updated semester status is 'present'
    IF NEW.semester_status = 'present' AND OLD.semester_status = 'future' THEN
	
		-- Cancel the trigger function if check_semester_overlap or update_previous_semester is triggered
        IF TG_OP = 'INSERT' AND EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'check_semester_overlap') THEN
            RETURN NULL;
        ELSIF TG_OP = 'UPDATE' AND EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_previous_semester') THEN
            RETURN NULL;
        END IF;
	
        -- Generate unique serial numbers using a CTE
        WITH generated_serials AS (
            SELECT (FLOOR(s.semester_id / 2) + s.semester_id % 2) AS serial_number
            FROM public."Register" r
            JOIN public."CourseRun" cr ON cr.serial_number = r.serial_number AND cr.course_code = r.course_code
            JOIN public."Semester" s ON r.semester_id = s.semester_id - 2
            WHERE s.semester_status = 'present' AND r.semester_id = NEW.semester_id - 2
        ),
        
        -- Fetch required course codes using a CTE
        course_codes AS (
            SELECT course_code
            FROM public."Course"
            WHERE typical_season = (
                SELECT academic_season
                FROM public."Semester"
                WHERE semester_status = 'present'
            )
        )
        
        -- Insert rows into the Register table
        INSERT INTO public."Register" (serial_number, amka, course_code, register_status, exam_grade, final_grade, lab_grade)
        SELECT gs.serial_number, r.student_amka, c.course_code, 'proposed', NULL, NULL, NULL
        FROM generated_serials gs
        CROSS JOIN course_codes c
        JOIN public."CourseRun" cr ON cr.course_code = c.course_code
        JOIN public."Register" r ON cr.serial_number = r.serial_number AND cr.course_code = r.course_code
        JOIN public."Semester" s ON r.semester_id = s.semester_id - 2
        WHERE s.semester_status = 'present' AND r.semester_id = NEW.semester_id - 2;

        -- Insert rows into the CourseRun table
        INSERT INTO public."CourseRun" (serial_number, course_code, exam_min, lab_min, exam_percentage, labuses, semesterrunsin)
        SELECT gs.serial_number, c.course_code, cr.exam_min, cr.lab_min, cr.exam_percentage, cr.labuses, (
            SELECT semester_id
            FROM public."Semester"
            WHERE semester_status = 'present'
        )
        FROM generated_serials gs
        CROSS JOIN course_codes c
        JOIN public."CourseRun" cr ON cr.course_code = c.course_code
        JOIN public."Register" r ON cr.serial_number = r.serial_number AND cr.course_code = r.course_code
        JOIN public."Semester" s ON r.semester_id = s.semester_id - 2
        WHERE s.semester_status = 'present' AND r.semester_id = NEW.semester_id - 2;

        -- Insert rows into the teaches table
        INSERT INTO public."Teaches" (course_code, serial_number, amka)
        SELECT c.course_code, gs.serial_number, t.amka
        FROM generated_serials gs
        CROSS JOIN course_codes c
        JOIN public."CourseRun" cr ON cr.course_code = c.course_code
        JOIN public."Register" r ON cr.serial_number = r.serial_number AND cr.course_code = r.course_code
        JOIN public."Semester" s ON r.semester_id = s.semester_id - 2
        JOIN public."Teaches" t ON t.course_code = c.course_code
        WHERE s.semester_status = 'present' AND r.semester_id = NEW.semester_id - 2;

        -- Insert rows into the supports table
        INSERT INTO public."Supports" (course_code, serial_number, amka)
        SELECT c.course_code, gs.serial_number, s.amka
        FROM generated_serials gs
        CROSS JOIN course_codes c
        JOIN public."CourseRun" cr ON cr.course_code = c.course_code
        JOIN public."Register" r ON cr.serial_number = r.serial_number AND cr.course_code = r.course_code
        JOIN public."Semester" s ON r.semester_id = s.semester_id - 2
        JOIN public."Supports" s ON s.course_code = c.course_code
        WHERE s.semester_status = 'present' AND r.semester_id = NEW.semester_id - 2;

        -- Update the previous semester with status 'present' to 'past'
        UPDATE public."Semester"
        SET semester_status = 'past'
        WHERE semester_id <> NEW.semester_id
            AND semester_status = 'present';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_previous_semester_future_to_present() OWNER TO postgres;

--
-- TOC entry 264 (class 1255 OID 18808)
-- Name: update_semester_status(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_semester_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if the semester status is updated from 'present' to 'past'
    IF NEW.semester_status = 'past' AND OLD.semester_status = 'present' THEN
        -- Assign grades for the semester
        PERFORM public.assign_grades_for_semester(NEW.semester_id);
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_semester_status() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 200 (class 1259 OID 18809)
-- Name: Committee; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Committee" (
    "ProfessorAMKA" character varying NOT NULL,
    "ThesisID" integer NOT NULL,
    "Supervisor" boolean
);


ALTER TABLE public."Committee" OWNER TO postgres;

--
-- TOC entry 201 (class 1259 OID 18815)
-- Name: Course; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Course" (
    course_code character(7) NOT NULL,
    course_title character(100) NOT NULL,
    units smallint NOT NULL,
    lecture_hours smallint NOT NULL,
    tutorial_hours smallint NOT NULL,
    lab_hours smallint NOT NULL,
    typical_year smallint NOT NULL,
    typical_season public.semester_season_type NOT NULL,
    obligatory boolean NOT NULL,
    course_description character varying
);


ALTER TABLE public."Course" OWNER TO postgres;

--
-- TOC entry 202 (class 1259 OID 18821)
-- Name: CourseRun; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."CourseRun" (
    course_code character(7) NOT NULL,
    serial_number integer NOT NULL,
    exam_min numeric,
    lab_min numeric,
    exam_percentage numeric,
    labuses integer,
    semesterrunsin integer NOT NULL
);


ALTER TABLE public."CourseRun" OWNER TO postgres;

--
-- TOC entry 203 (class 1259 OID 18827)
-- Name: Course_depends; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Course_depends" (
    dependent character(7) NOT NULL,
    main character(7) NOT NULL,
    mode public.course_dependency_mode_type
);


ALTER TABLE public."Course_depends" OWNER TO postgres;

--
-- TOC entry 204 (class 1259 OID 18830)
-- Name: Covers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Covers" (
    lab_code integer NOT NULL,
    field_code character(3) NOT NULL
);


ALTER TABLE public."Covers" OWNER TO postgres;

--
-- TOC entry 205 (class 1259 OID 18833)
-- Name: CustomUnits; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."CustomUnits" (
    "CustomUnitID" integer NOT NULL,
    "SeasonalProgramID" integer NOT NULL,
    "Credits" integer
);


ALTER TABLE public."CustomUnits" OWNER TO postgres;

--
-- TOC entry 206 (class 1259 OID 18836)
-- Name: Diploma; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Diploma" (
    "DiplomaNum" integer NOT NULL,
    "DiplomaGrade" numeric,
    "DiplomaTitle" character varying,
    "StudentAMKA" character varying NOT NULL,
    "ProgramID" integer NOT NULL
);


ALTER TABLE public."Diploma" OWNER TO postgres;

--
-- TOC entry 207 (class 1259 OID 18842)
-- Name: Field; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Field" (
    code character(3) NOT NULL,
    title character(100) NOT NULL
);


ALTER TABLE public."Field" OWNER TO postgres;

--
-- TOC entry 208 (class 1259 OID 18845)
-- Name: ForeignLanguageProgram; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ForeignLanguageProgram" (
    "ProgramID" integer NOT NULL,
    "Language" character varying
);


ALTER TABLE public."ForeignLanguageProgram" OWNER TO postgres;

--
-- TOC entry 209 (class 1259 OID 18851)
-- Name: Joins; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Joins" (
    "StudentAMKA" character varying NOT NULL,
    "ProgramID" integer NOT NULL
);


ALTER TABLE public."Joins" OWNER TO postgres;

--
-- TOC entry 210 (class 1259 OID 18857)
-- Name: Lab; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Lab" (
    lab_code integer NOT NULL,
    sector_code integer NOT NULL,
    lab_title character(100) NOT NULL,
    lab_description character varying,
    profdirects character varying
);


ALTER TABLE public."Lab" OWNER TO postgres;

--
-- TOC entry 211 (class 1259 OID 18863)
-- Name: LabTeacher; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."LabTeacher" (
    amka character varying NOT NULL,
    labworks integer,
    level public.level_type NOT NULL
);


ALTER TABLE public."LabTeacher" OWNER TO postgres;

--
-- TOC entry 212 (class 1259 OID 18869)
-- Name: Name; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Name" (
    name character varying NOT NULL,
    sex character(1) NOT NULL
);


ALTER TABLE public."Name" OWNER TO postgres;

--
-- TOC entry 213 (class 1259 OID 18875)
-- Name: Person; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Person" (
    amka character varying NOT NULL,
    name character varying(30) NOT NULL,
    father_name character varying(30) NOT NULL,
    surname character varying(30) NOT NULL,
    email character varying(30)
);


ALTER TABLE public."Person" OWNER TO postgres;

--
-- TOC entry 214 (class 1259 OID 18881)
-- Name: Professor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Professor" (
    amka character varying NOT NULL,
    labjoins integer,
    rank public.rank_type NOT NULL
);


ALTER TABLE public."Professor" OWNER TO postgres;

--
-- TOC entry 215 (class 1259 OID 18887)
-- Name: Program; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Program" (
    "ProgramID" integer NOT NULL,
    "Duration" integer,
    "MinCourses" integer,
    "MinCredits" integer,
    "Obligatory" boolean,
    "CommitteeNum" integer,
    "DiplomaType" public.diploma_type,
    "NumOfParticipants" integer,
    "Year" character(4)
);


ALTER TABLE public."Program" OWNER TO postgres;

--
-- TOC entry 216 (class 1259 OID 18890)
-- Name: ProgramOffersCourse; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ProgramOffersCourse" (
    "ProgramID" integer NOT NULL,
    "CourseCode" character(7) NOT NULL
);


ALTER TABLE public."ProgramOffersCourse" OWNER TO postgres;

--
-- TOC entry 217 (class 1259 OID 18893)
-- Name: RefersTo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."RefersTo" (
    "CustomUnitID" integer NOT NULL,
    "SeasonalProgramID" integer NOT NULL,
    "CourseRunCode" character(7) NOT NULL,
    "CourseRunSerial" integer NOT NULL
);


ALTER TABLE public."RefersTo" OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 18896)
-- Name: Register; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Register" (
    amka character varying NOT NULL,
    serial_number integer NOT NULL,
    course_code character(7) NOT NULL,
    exam_grade numeric,
    final_grade numeric,
    lab_grade numeric,
    register_status public.register_status_type
);


ALTER TABLE public."Register" OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 18902)
-- Name: SeasonalProgram; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."SeasonalProgram" (
    "ProgramID" integer NOT NULL,
    "Season" character varying
);


ALTER TABLE public."SeasonalProgram" OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 18908)
-- Name: Sector; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Sector" (
    sector_code integer NOT NULL,
    sector_title character(100) NOT NULL,
    sector_description character varying
);


ALTER TABLE public."Sector" OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 18914)
-- Name: Semester; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Semester" (
    semester_id integer NOT NULL,
    academic_year integer,
    academic_season public.semester_season_type,
    start_date date,
    end_date date,
    semester_status public.semester_status_type NOT NULL
);


ALTER TABLE public."Semester" OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 18917)
-- Name: Student; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Student" (
    amka character varying NOT NULL,
    am character(10),
    entry_date date
);


ALTER TABLE public."Student" OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 18923)
-- Name: StudentDetails; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public."StudentDetails" AS
 SELECT s.am,
    p.name,
    p.surname,
        CASE
            WHEN (sr.academic_season = 'winter'::public.semester_season_type) THEN ((date_part('year'::text, sr.end_date) - date_part('year'::text, s.entry_date)) + (1)::double precision)
            WHEN (sr.academic_season = 'spring'::public.semester_season_type) THEN (date_part('year'::text, sr.end_date) - date_part('year'::text, s.entry_date))
            ELSE NULL::double precision
        END AS "YearOfStudy",
    ( SELECT COALESCE((sum(
                CASE
                    WHEN (c.units = ANY (ARRAY[1, 2])) THEN (r.final_grade * (1)::numeric)
                    WHEN (c.units = ANY (ARRAY[3, 4])) THEN (r.final_grade * 1.5)
                    ELSE (r.final_grade * (2)::numeric)
                END) / NULLIF(sum(
                CASE
                    WHEN (c.units = ANY (ARRAY[1, 2])) THEN (1)::numeric
                    WHEN (c.units = ANY (ARRAY[3, 4])) THEN 1.5
                    ELSE (2)::numeric
                END), (0)::numeric)), (0)::numeric) AS "coalesce"
           FROM ((public."Register" r
             JOIN public."Course" c ON ((r.course_code = c.course_code)))
             JOIN public."ProgramOffersCourse" poc ON ((c.course_code = poc."CourseCode")))
          WHERE (((r.amka)::text = (s.amka)::text) AND (r.register_status = 'pass'::public.register_status_type) AND (poc."ProgramID" = ( SELECT max(po."ProgramID") AS max
                   FROM public."ProgramOffersCourse" po
                  WHERE (po."CourseCode" = c.course_code))))) AS student_avg_grade
   FROM ((public."Student" s
     JOIN public."Person" p ON (((s.amka)::text = (p.amka)::text)))
     JOIN public."Semester" sr ON ((sr.semester_status = 'present'::public.semester_status_type)));


ALTER TABLE public."StudentDetails" OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 18928)
-- Name: Student_Information_View; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public."Student_Information_View" AS
 SELECT s.am,
    p.name,
    p.surname,
        CASE
            WHEN (sr.academic_season = 'winter'::public.semester_season_type) THEN ((date_part('year'::text, sr.end_date) - date_part('year'::text, s.entry_date)) + (1)::double precision)
            WHEN (sr.academic_season = 'spring'::public.semester_season_type) THEN (date_part('year'::text, sr.end_date) - date_part('year'::text, s.entry_date))
            ELSE NULL::double precision
        END AS "YearOfStudy",
    ( SELECT COALESCE((sum(
                CASE
                    WHEN (c.units = ANY (ARRAY[1, 2])) THEN (r.final_grade * (1)::numeric)
                    WHEN (c.units = ANY (ARRAY[3, 4])) THEN (r.final_grade * 1.5)
                    ELSE (r.final_grade * (2)::numeric)
                END) / NULLIF(sum(
                CASE
                    WHEN (c.units = ANY (ARRAY[1, 2])) THEN (1)::numeric
                    WHEN (c.units = ANY (ARRAY[3, 4])) THEN 1.5
                    ELSE (2)::numeric
                END), (0)::numeric)), (0)::numeric) AS "AverageGrade"
           FROM ((public."Register" r
             JOIN public."Course" c ON ((r.course_code = c.course_code)))
             JOIN public."ProgramOffersCourse" poc ON ((c.course_code = poc."CourseCode")))
          WHERE (((r.amka)::text = (s.amka)::text) AND (r.register_status = 'pass'::public.register_status_type) AND (EXISTS ( SELECT 1
                   FROM public."CourseRun" cr
                  WHERE (((cr.semesterrunsin = ( SELECT (max("Semester".semester_id) - 1)
                           FROM public."Semester")) OR (cr.semesterrunsin = ( SELECT (max("Semester".semester_id) - 2)
                           FROM public."Semester"))) AND (cr.course_code IN ( SELECT r_1.course_code
                           FROM public."Register" r_1
                          WHERE (((r_1.amka)::text = (s.amka)::text) AND (r_1.register_status = 'pass'::public.register_status_type))))))))) AS "AverageGrade"
   FROM ((public."Student" s
     JOIN public."Person" p ON (((s.amka)::text = (p.amka)::text)))
     JOIN public."Semester" sr ON ((sr.semester_id IN ( SELECT max("Semester".semester_id) AS max
           FROM public."Semester"))))
  WHERE (sr.semester_status = 'present'::public.semester_status_type);


ALTER TABLE public."Student_Information_View" OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 18933)
-- Name: Supports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Supports" (
    amka character varying NOT NULL,
    serial_number integer NOT NULL,
    course_code character(7) NOT NULL
);


ALTER TABLE public."Supports" OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 18939)
-- Name: Surname; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Surname" (
    surname character varying NOT NULL
);


ALTER TABLE public."Surname" OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 18945)
-- Name: Teaches; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Teaches" (
    amka character varying NOT NULL,
    serial_number integer NOT NULL,
    course_code character(7) NOT NULL
);


ALTER TABLE public."Teaches" OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 18951)
-- Name: Thesis; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Thesis" (
    "ThesisID" integer NOT NULL,
    "Grade" numeric,
    "Title" character varying,
    "StudentAMKA" character varying,
    "ProgramID" integer
);


ALTER TABLE public."Thesis" OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 18957)
-- Name: course_info; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.course_info AS
 SELECT course.course_code,
    course.course_title,
    person.surname,
    person.name
   FROM (((public."Course" course
     JOIN public."Semester" semester ON (((semester.semester_status = 'present'::public.semester_status_type) AND (semester.academic_season = course.typical_season))))
     JOIN public."Teaches" teach ON ((teach.course_code = course.course_code)))
     JOIN public."Person" person ON (((person.amka)::text = (teach.amka)::text)))
  ORDER BY course.course_code;


ALTER TABLE public.course_info OWNER TO postgres;

--
-- TOC entry 3032 (class 2606 OID 18963)
-- Name: Committee Committee_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Committee"
    ADD CONSTRAINT "Committee_pkey" PRIMARY KEY ("ProfessorAMKA", "ThesisID");


--
-- TOC entry 3036 (class 2606 OID 18965)
-- Name: CourseRun CourseRun_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."CourseRun"
    ADD CONSTRAINT "CourseRun_pkey" PRIMARY KEY (course_code, serial_number);


--
-- TOC entry 3038 (class 2606 OID 18967)
-- Name: Course_depends Course_depends_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Course_depends"
    ADD CONSTRAINT "Course_depends_pkey" PRIMARY KEY (dependent, main);


--
-- TOC entry 3034 (class 2606 OID 18969)
-- Name: Course Course_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Course"
    ADD CONSTRAINT "Course_pkey" PRIMARY KEY (course_code);


--
-- TOC entry 3046 (class 2606 OID 18971)
-- Name: CustomUnits CustomUnits_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."CustomUnits"
    ADD CONSTRAINT "CustomUnits_pkey" PRIMARY KEY ("CustomUnitID", "SeasonalProgramID");


--
-- TOC entry 3048 (class 2606 OID 18973)
-- Name: Diploma Diploma_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Diploma"
    ADD CONSTRAINT "Diploma_pkey" PRIMARY KEY ("DiplomaNum", "StudentAMKA", "ProgramID");


--
-- TOC entry 3050 (class 2606 OID 18975)
-- Name: Field Fields_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Field"
    ADD CONSTRAINT "Fields_pkey" PRIMARY KEY (code);


--
-- TOC entry 3052 (class 2606 OID 18977)
-- Name: ForeignLanguageProgram ForeignLanguageProgram_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ForeignLanguageProgram"
    ADD CONSTRAINT "ForeignLanguageProgram_pkey" PRIMARY KEY ("ProgramID");


--
-- TOC entry 3054 (class 2606 OID 18979)
-- Name: Joins Joins_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Joins"
    ADD CONSTRAINT "Joins_pkey" PRIMARY KEY ("StudentAMKA", "ProgramID");


--
-- TOC entry 3059 (class 2606 OID 18981)
-- Name: LabTeacher LabStaff_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."LabTeacher"
    ADD CONSTRAINT "LabStaff_pkey" PRIMARY KEY (amka);


--
-- TOC entry 3042 (class 2606 OID 18983)
-- Name: Covers Lab_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Covers"
    ADD CONSTRAINT "Lab_fields_pkey" PRIMARY KEY (field_code, lab_code);


--
-- TOC entry 3056 (class 2606 OID 18985)
-- Name: Lab Lab_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Lab"
    ADD CONSTRAINT "Lab_pkey" PRIMARY KEY (lab_code);


--
-- TOC entry 3061 (class 2606 OID 18987)
-- Name: Name Names_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Name"
    ADD CONSTRAINT "Names_pkey" PRIMARY KEY (name);


--
-- TOC entry 3063 (class 2606 OID 18989)
-- Name: Person Person_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Person"
    ADD CONSTRAINT "Person_pkey" PRIMARY KEY (amka);


--
-- TOC entry 3065 (class 2606 OID 18991)
-- Name: Professor Professor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Professor"
    ADD CONSTRAINT "Professor_pkey" PRIMARY KEY (amka);


--
-- TOC entry 3069 (class 2606 OID 18993)
-- Name: ProgramOffersCourse ProgramOffersCourse_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ProgramOffersCourse"
    ADD CONSTRAINT "ProgramOffersCourse_pkey" PRIMARY KEY ("ProgramID", "CourseCode");


--
-- TOC entry 3067 (class 2606 OID 18995)
-- Name: Program Program_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Program"
    ADD CONSTRAINT "Program_pkey" PRIMARY KEY ("ProgramID");


--
-- TOC entry 3071 (class 2606 OID 18997)
-- Name: RefersTo RefersTo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."RefersTo"
    ADD CONSTRAINT "RefersTo_pkey" PRIMARY KEY ("CustomUnitID", "CourseRunCode", "SeasonalProgramID", "CourseRunSerial");


--
-- TOC entry 3073 (class 2606 OID 18999)
-- Name: Register Register_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Register"
    ADD CONSTRAINT "Register_pkey" PRIMARY KEY (course_code, serial_number, amka);


--
-- TOC entry 3075 (class 2606 OID 19001)
-- Name: SeasonalProgram SeasonalProgram_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."SeasonalProgram"
    ADD CONSTRAINT "SeasonalProgram_pkey" PRIMARY KEY ("ProgramID");


--
-- TOC entry 3077 (class 2606 OID 19003)
-- Name: Sector Sector_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Sector"
    ADD CONSTRAINT "Sector_pkey" PRIMARY KEY (sector_code);


--
-- TOC entry 3079 (class 2606 OID 19005)
-- Name: Semester Semester_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Semester"
    ADD CONSTRAINT "Semester_pkey" PRIMARY KEY (semester_id);


--
-- TOC entry 3081 (class 2606 OID 19007)
-- Name: Student Student_am_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Student"
    ADD CONSTRAINT "Student_am_key" UNIQUE (am);


--
-- TOC entry 3083 (class 2606 OID 19009)
-- Name: Student Student_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Student"
    ADD CONSTRAINT "Student_pkey" PRIMARY KEY (amka);


--
-- TOC entry 3085 (class 2606 OID 19011)
-- Name: Supports Supports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Supports"
    ADD CONSTRAINT "Supports_pkey" PRIMARY KEY (amka, serial_number, course_code);


--
-- TOC entry 3087 (class 2606 OID 19013)
-- Name: Surname Surnames_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Surname"
    ADD CONSTRAINT "Surnames_pkey" PRIMARY KEY (surname);


--
-- TOC entry 3089 (class 2606 OID 19015)
-- Name: Teaches Teaches_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Teaches"
    ADD CONSTRAINT "Teaches_pkey" PRIMARY KEY (amka, serial_number, course_code);


--
-- TOC entry 3091 (class 2606 OID 19017)
-- Name: Thesis Thesis_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Thesis"
    ADD CONSTRAINT "Thesis_pkey" PRIMARY KEY ("ThesisID");


--
-- TOC entry 3039 (class 1259 OID 19018)
-- Name: fk_course_depends_dependent; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fk_course_depends_dependent ON public."Course_depends" USING btree (dependent);


--
-- TOC entry 3040 (class 1259 OID 19019)
-- Name: fk_course_depends_main; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fk_course_depends_main ON public."Course_depends" USING btree (main);


--
-- TOC entry 3043 (class 1259 OID 19020)
-- Name: fk_lab_field_lab_code; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fk_lab_field_lab_code ON public."Covers" USING btree (lab_code);


--
-- TOC entry 3044 (class 1259 OID 19021)
-- Name: fk_lab_fields_field_code; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fk_lab_fields_field_code ON public."Covers" USING btree (field_code);


--
-- TOC entry 3057 (class 1259 OID 19022)
-- Name: fk_lab_sector_code; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fk_lab_sector_code ON public."Lab" USING btree (sector_code);


--
-- TOC entry 3127 (class 2620 OID 19023)
-- Name: Committee check_committee_constraint_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_committee_constraint_trigger BEFORE INSERT ON public."Committee" FOR EACH ROW EXECUTE FUNCTION public.check_committee_constraint();


--
-- TOC entry 3133 (class 2620 OID 19024)
-- Name: Semester check_semester_overlap_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_semester_overlap_trigger BEFORE INSERT ON public."Semester" FOR EACH ROW EXECUTE FUNCTION public.check_semester_overlap();


--
-- TOC entry 3129 (class 2620 OID 19025)
-- Name: Register check_status_change; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_status_change BEFORE UPDATE ON public."Register" FOR EACH ROW EXECUTE FUNCTION public.check_register_status_change();


--
-- TOC entry 3132 (class 2620 OID 19026)
-- Name: Semester semester_status_update; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER semester_status_update AFTER UPDATE ON public."Semester" FOR EACH ROW EXECUTE FUNCTION public.update_semester_status();


--
-- TOC entry 3128 (class 2620 OID 19027)
-- Name: ForeignLanguageProgram trg_check_foreignlanguageprogram_year_constraint; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_foreignlanguageprogram_year_constraint BEFORE INSERT ON public."ForeignLanguageProgram" FOR EACH ROW EXECUTE FUNCTION public.check_foreignlanguageprogram_year_constraint();


--
-- TOC entry 3130 (class 2620 OID 19028)
-- Name: SeasonalProgram trg_check_seasonalprogram_year_constraint; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_seasonalprogram_year_constraint BEFORE INSERT ON public."SeasonalProgram" FOR EACH ROW EXECUTE FUNCTION public.check_seasonalprogram_year_constraint();


--
-- TOC entry 3131 (class 2620 OID 19029)
-- Name: Semester update_previous_semester_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_previous_semester_trigger BEFORE UPDATE ON public."Semester" FOR EACH ROW EXECUTE FUNCTION public.update_previous_semester();


--
-- TOC entry 3094 (class 2606 OID 19030)
-- Name: CourseRun CourseRun_course_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."CourseRun"
    ADD CONSTRAINT "CourseRun_course_code_fkey" FOREIGN KEY (course_code) REFERENCES public."Course"(course_code);


--
-- TOC entry 3095 (class 2606 OID 19035)
-- Name: CourseRun CourseRun_labuses_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."CourseRun"
    ADD CONSTRAINT "CourseRun_labuses_fkey" FOREIGN KEY (labuses) REFERENCES public."Lab"(lab_code);


--
-- TOC entry 3096 (class 2606 OID 19040)
-- Name: CourseRun CourseRun_semesterrunsin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."CourseRun"
    ADD CONSTRAINT "CourseRun_semesterrunsin_fkey" FOREIGN KEY (semesterrunsin) REFERENCES public."Semester"(semester_id);


--
-- TOC entry 3101 (class 2606 OID 19045)
-- Name: CustomUnits CustomUnits_fk_1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."CustomUnits"
    ADD CONSTRAINT "CustomUnits_fk_1" FOREIGN KEY ("SeasonalProgramID") REFERENCES public."SeasonalProgram"("ProgramID") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3104 (class 2606 OID 19050)
-- Name: ForeignLanguageProgram ForeignLanguageProgram_fk_1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ForeignLanguageProgram"
    ADD CONSTRAINT "ForeignLanguageProgram_fk_1" FOREIGN KEY ("ProgramID") REFERENCES public."Program"("ProgramID");


--
-- TOC entry 3109 (class 2606 OID 19055)
-- Name: LabTeacher LabStaff_labworks_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."LabTeacher"
    ADD CONSTRAINT "LabStaff_labworks_fkey" FOREIGN KEY (labworks) REFERENCES public."Lab"(lab_code);


--
-- TOC entry 3099 (class 2606 OID 19060)
-- Name: Covers Lab_fields_field_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Covers"
    ADD CONSTRAINT "Lab_fields_field_code_fkey" FOREIGN KEY (field_code) REFERENCES public."Field"(code) MATCH FULL NOT VALID;


--
-- TOC entry 3100 (class 2606 OID 19065)
-- Name: Covers Lab_fields_lab_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Covers"
    ADD CONSTRAINT "Lab_fields_lab_code_fkey" FOREIGN KEY (lab_code) REFERENCES public."Lab"(lab_code) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3107 (class 2606 OID 19070)
-- Name: Lab Lab_professor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Lab"
    ADD CONSTRAINT "Lab_professor_fkey" FOREIGN KEY (profdirects) REFERENCES public."Professor"(amka) ON UPDATE CASCADE ON DELETE SET NULL NOT VALID;


--
-- TOC entry 3108 (class 2606 OID 19075)
-- Name: Lab Lab_sector_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Lab"
    ADD CONSTRAINT "Lab_sector_code_fkey" FOREIGN KEY (sector_code) REFERENCES public."Sector"(sector_code) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3111 (class 2606 OID 19080)
-- Name: Professor Professor_labJoins_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Professor"
    ADD CONSTRAINT "Professor_labJoins_fkey" FOREIGN KEY (labjoins) REFERENCES public."Lab"(lab_code);


--
-- TOC entry 3112 (class 2606 OID 19085)
-- Name: Professor Professor_person_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Professor"
    ADD CONSTRAINT "Professor_person_fkey" FOREIGN KEY (amka) REFERENCES public."Person"(amka) ON UPDATE RESTRICT ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3117 (class 2606 OID 19090)
-- Name: Register Register_course_run_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Register"
    ADD CONSTRAINT "Register_course_run_fkey" FOREIGN KEY (course_code, serial_number) REFERENCES public."CourseRun"(course_code, serial_number) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3118 (class 2606 OID 19095)
-- Name: Register Register_student_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Register"
    ADD CONSTRAINT "Register_student_fkey" FOREIGN KEY (amka) REFERENCES public."Student"(amka) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3119 (class 2606 OID 19100)
-- Name: SeasonalProgram SeasonalProgram_fk_1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."SeasonalProgram"
    ADD CONSTRAINT "SeasonalProgram_fk_1" FOREIGN KEY ("ProgramID") REFERENCES public."Program"("ProgramID");


--
-- TOC entry 3121 (class 2606 OID 19105)
-- Name: Supports Supports_course_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Supports"
    ADD CONSTRAINT "Supports_course_code_fkey" FOREIGN KEY (course_code, serial_number) REFERENCES public."CourseRun"(course_code, serial_number);


--
-- TOC entry 3122 (class 2606 OID 19110)
-- Name: Supports Supports_labteacher_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Supports"
    ADD CONSTRAINT "Supports_labteacher_fkey" FOREIGN KEY (amka) REFERENCES public."LabTeacher"(amka) NOT VALID;


--
-- TOC entry 3123 (class 2606 OID 19115)
-- Name: Teaches Teaches_course_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Teaches"
    ADD CONSTRAINT "Teaches_course_code_fkey" FOREIGN KEY (serial_number, course_code) REFERENCES public."CourseRun"(serial_number, course_code) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3124 (class 2606 OID 19120)
-- Name: Teaches Teaches_professor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Teaches"
    ADD CONSTRAINT "Teaches_professor_fkey" FOREIGN KEY (amka) REFERENCES public."Professor"(amka) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3092 (class 2606 OID 19125)
-- Name: Committee committee_fk_1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Committee"
    ADD CONSTRAINT committee_fk_1 FOREIGN KEY ("ProfessorAMKA") REFERENCES public."Professor"(amka);


--
-- TOC entry 3093 (class 2606 OID 19130)
-- Name: Committee committee_fk_2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Committee"
    ADD CONSTRAINT committee_fk_2 FOREIGN KEY ("ThesisID") REFERENCES public."Thesis"("ThesisID");


--
-- TOC entry 3097 (class 2606 OID 19135)
-- Name: Course_depends dependent; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Course_depends"
    ADD CONSTRAINT dependent FOREIGN KEY (dependent) REFERENCES public."Course"(course_code) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3102 (class 2606 OID 19140)
-- Name: Diploma diploma_fk_1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Diploma"
    ADD CONSTRAINT diploma_fk_1 FOREIGN KEY ("StudentAMKA") REFERENCES public."Student"(amka) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3103 (class 2606 OID 19145)
-- Name: Diploma diploma_fk_2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Diploma"
    ADD CONSTRAINT diploma_fk_2 FOREIGN KEY ("ProgramID") REFERENCES public."Program"("ProgramID") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3105 (class 2606 OID 19150)
-- Name: Joins joins_fk_1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Joins"
    ADD CONSTRAINT joins_fk_1 FOREIGN KEY ("StudentAMKA") REFERENCES public."Student"(amka);


--
-- TOC entry 3106 (class 2606 OID 19155)
-- Name: Joins joins_fk_2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Joins"
    ADD CONSTRAINT joins_fk_2 FOREIGN KEY ("ProgramID") REFERENCES public."Program"("ProgramID");


--
-- TOC entry 3110 (class 2606 OID 19160)
-- Name: LabTeacher labStaff_person_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."LabTeacher"
    ADD CONSTRAINT "labStaff_person_fkey" FOREIGN KEY (amka) REFERENCES public."Person"(amka) ON UPDATE RESTRICT ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3098 (class 2606 OID 19165)
-- Name: Course_depends main; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Course_depends"
    ADD CONSTRAINT main FOREIGN KEY (main) REFERENCES public."Course"(course_code) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3113 (class 2606 OID 19170)
-- Name: ProgramOffersCourse offers_fk_1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ProgramOffersCourse"
    ADD CONSTRAINT offers_fk_1 FOREIGN KEY ("ProgramID") REFERENCES public."Program"("ProgramID");


--
-- TOC entry 3114 (class 2606 OID 19175)
-- Name: ProgramOffersCourse offers_fk_2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ProgramOffersCourse"
    ADD CONSTRAINT offers_fk_2 FOREIGN KEY ("CourseCode") REFERENCES public."Course"(course_code);


--
-- TOC entry 3115 (class 2606 OID 19180)
-- Name: RefersTo refersto_fk_1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."RefersTo"
    ADD CONSTRAINT refersto_fk_1 FOREIGN KEY ("CustomUnitID", "SeasonalProgramID") REFERENCES public."CustomUnits"("CustomUnitID", "SeasonalProgramID");


--
-- TOC entry 3116 (class 2606 OID 19185)
-- Name: RefersTo refersto_fk_2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."RefersTo"
    ADD CONSTRAINT refersto_fk_2 FOREIGN KEY ("CourseRunCode", "CourseRunSerial") REFERENCES public."CourseRun"(course_code, serial_number);


--
-- TOC entry 3120 (class 2606 OID 19190)
-- Name: Student student_fkey1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Student"
    ADD CONSTRAINT student_fkey1 FOREIGN KEY (amka) REFERENCES public."Person"(amka) ON UPDATE RESTRICT ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3125 (class 2606 OID 19195)
-- Name: Thesis thesis_fk_1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Thesis"
    ADD CONSTRAINT thesis_fk_1 FOREIGN KEY ("StudentAMKA") REFERENCES public."Student"(amka);


--
-- TOC entry 3126 (class 2606 OID 19200)
-- Name: Thesis thesis_fk_2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Thesis"
    ADD CONSTRAINT thesis_fk_2 FOREIGN KEY ("ProgramID") REFERENCES public."Program"("ProgramID");


-- Completed on 2025-12-19 16:58:00

--
-- PostgreSQL database dump complete
--

