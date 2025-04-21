-- Function to fetch timezone names efficiently
-- Uses the materialized view if available, falls back to pg_timezone_names if not

CREATE OR REPLACE FUNCTION public.get_timezone_names()
RETURNS TABLE (name text) AS
$$
BEGIN
    -- Check if our materialized view exists and is populated
    IF EXISTS (
        SELECT 1 FROM pg_matviews 
        WHERE schemaname = 'public' 
        AND matviewname = 'timezone_names_mv'
        AND ispopulated
    ) THEN
        -- Use the materialized view (fast)
        RETURN QUERY SELECT tzn.name FROM public.timezone_names_mv tzn;
    ELSE
        -- Fall back to direct query (slower)
        RETURN QUERY SELECT tzn.name FROM pg_timezone_names tzn;
    END IF;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Example usage:
-- SELECT * FROM public.get_timezone_names();