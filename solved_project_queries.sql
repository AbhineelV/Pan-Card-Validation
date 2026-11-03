-- Pan Card Validation Project

CREATE TABLE pan_number_dataset(
pan_number TEXT
);

-- Data has been Imported
SELECT * FROM pan_number_dataset;

-- 1. Identify missing data
SELECT * FROM pan_number_dataset WHERE pan_number IS NULL;

-- 2. Check for duplicates
SELECT pan_number, COUNT(1) FROM pan_number_dataset
WHERE pan_number IS NOT NULL
GROUP BY pan_number
HAVING COUNT(1) > 1;

-- 3. Handle leading/trailing spaces
SELECT * FROM pan_number_dataset WHERE pan_number = TRIM(pan_number);

-- 4. Correct letter case
SELECT * FROM pan_number_dataset WHERE pan_number = UPPER(pan_number);

-- New cleaned table:
CREATE TABLE pan_number_dataset_cleaned AS
SELECT DISTINCT UPPER(TRIM(pan_number)) AS pan_number
FROM pan_number_dataset 
WHERE pan_number IS NOT NULL AND TRIM(pan_number) <> '';

-- Function to check if adjacent characters are repetitive. 
CREATE OR REPLACE FUNCTION fn_check_adjacent_repetition(p_str text)
RETURNS boolean
LANGUAGE plpgsql
AS $$
BEGIN
	FOR i IN 1 .. (LENGTH(p_str) - 1)
	LOOP
		IF SUBSTRING(p_str, i, 1) = SUBSTRING(p_str, i+1, 1)
		THEN 
			RETURN true;
		END IF;
	END LOOP;
	RETURN false;
END;
$$;

-- Function to check if characters are sequential.
CREATE OR REPLACE FUNCTION fn_check_sequence(p_str text)
RETURNS boolean
LANGUAGE plpgsql
AS $$
BEGIN
	FOR i IN 1 .. (LENGTH(p_str) - 1)
	LOOP
		IF ascii(SUBSTRING(p_str, i+1, 1)) - ascii(SUBSTRING(p_str, i, 1)) <> 1
		THEN 
			RETURN false;
		END IF;
	END LOOP;
	RETURN true;
END;
$$;

-- Valid Invalid PAN categorization view
CREATE OR REPLACE VIEW view_valid_invalid_pan 
AS WITH cte_cleaned_pan AS (
	SELECT DISTINCT UPPER(TRIM(pan_number)) AS pan_number
	FROM pan_number_dataset 
	WHERE pan_number IS NOT NULL AND TRIM(pan_number) <> '' 
),
cte_valid_pan AS (
	SELECT pan_number FROM cte_cleaned_pan
	WHERE fn_check_adjacent_repetition(pan_number) = false
	AND fn_check_sequence(SUBSTRING(pan_number, 1, 5)) = false
	AND pan_number ~ '^[A-Z]{5}[0-9]{4}[A-Z]$'
)
SELECT 
	cln.pan_number,
	CASE 
		WHEN vld.pan_number IS NULL THEN 'Invalid PAN' 
		ELSE 'Valid PAN' 
	END AS status
FROM cte_cleaned_pan cln
LEFT JOIN cte_valid_pan vld ON vld.pan_number = cln.pan_number;

-- Summary report
-- Summary report
WITH raw_stats AS (
    SELECT 
        COUNT(*) AS total_processed_records,
        COUNT(*) FILTER (WHERE pan_number IS NULL OR TRIM(pan_number) = '') AS null_or_blank_records
    FROM pan_number_dataset
),
view_stats AS (
    SELECT 
        COUNT(*) FILTER (WHERE status = 'Valid PAN') AS total_valid_pans,
        COUNT(*) FILTER (WHERE status = 'Invalid PAN') AS total_invalid_pans
    FROM view_valid_invalid_pan
)
SELECT 
    r.total_processed_records,
    v.total_valid_pans,
    v.total_invalid_pans,
    r.null_or_blank_records,
    (r.total_processed_records - (v.total_valid_pans + v.total_invalid_pans)) AS total_filtered_out_records
FROM raw_stats r, view_stats v;
