IF OBJECT_ID('[dbo].[funcParseDelimitedString]', 'TF') IS NOT NULL
	DROP FUNCTION [dbo].[funcParseDelimitedString]
GO

CREATE FUNCTION [dbo].[funcParseDelimitedString]( @delimitedString NVARCHAR(MAX), @delimiter varchar(5) = ',')
RETURNS @values TABLE(
	idx int NOT NULL IDENTITY(1,1) PRIMARY KEY,
	value varchar(max)
  )
AS
BEGIN
	WITH params AS(
		-- load parameters to table
		SELECT
			'string' as which,
			'~' + @delimitedString + '~' as val
		UNION SELECT
			'delimiter' as which,
			'~' + @delimiter + '~' as val
	)
	, encode AS(
		-- encode to XML (to handle special characters)
		SELECT
			which,
			(SELECT TRIM(val) FOR XML PATH('')) val
		FROM params
	)
	, strip AS(
		-- Take the qualifiers (added in first query) off the values
		SELECT
			which,
			SUBSTRING(val, 2, LEN(val)-2) val
		FROM encode
	)
	, xmlString AS(
		-- Split text into XML nodes
		SELECT
			'<val>' + REPLACE(string, delimiter, '</val><val>') + '</val>' as xmlInput,
			(SELECT ' ' FOR XML PATH('')) as xmlSpace
		FROM strip e
		PIVOT (MAX(val)
			FOR which IN(string, delimiter)) pvt
	)
	, toXml AS(
		-- Convert to actual XML
		SELECT
			xmlVal = CAST(REPLACE(xmlInput, ' ', xmlSpace) as xml)
		FROM xmlString
	)
	, vals AS(
		-- Parse XML nodes to individual values
		SELECT
			s.val.value('.','nvarchar(max)') val,
			s.val.value('string-length(.)','int') size
		FROM toXml
		CROSS APPLY xmlVal.nodes('/val')s(val)
	)
	-- Populate results, including empty spaces
	INSERT INTO @values
	SELECT
		CASE WHEN val = '' AND size > 0
			THEN REPLICATE(' ', size)
			ELSE val
		END
	FROM vals

	RETURN
END
GO
