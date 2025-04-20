-- Timezone names with efficient caching
DO $$
BEGIN
  -- Create the cache table if it doesn't exist
  IF NOT EXISTS (
    SELECT FROM pg_catalog.pg_tables 
    WHERE tablename = 'cached_timezone_names' AND schemaname = 'public'
  ) THEN
    CREATE TABLE public.cached_timezone_names AS 
    SELECT name, now() AS last_refreshed FROM pg_timezone_names;
    
    COMMENT ON TABLE public.cached_timezone_names IS 'Cached timezone names to improve performance, refreshed daily';
  ELSE
    -- Check if cache needs refreshing (older than 24 hours)
    IF NOT EXISTS (
      SELECT 1 FROM public.cached_timezone_names
      WHERE (now() - last_refreshed) < interval '24 hours'
      LIMIT 1
    ) THEN
      -- Truncate and refresh the cache
      TRUNCATE TABLE public.cached_timezone_names;
      INSERT INTO public.cached_timezone_names
      SELECT name, now() AS last_refreshed FROM pg_timezone_names;
    END IF;
  END IF;
END;
$$;

-- Return results from cache
SELECT name 
FROM public.cached_timezone_names
ORDER BY name;