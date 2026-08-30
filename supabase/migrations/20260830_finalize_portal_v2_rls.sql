-- Stanford Portal V2 security and booking fixes.
-- Applied to the connected Supabase project on 2026-08-30.

DROP POLICY IF EXISTS "members submit own pending garden booking" ON public.garden_area_booking_requests;
CREATE POLICY "members submit own pending garden booking"
ON public.garden_area_booking_requests
FOR INSERT TO authenticated
WITH CHECK (
  auth.uid() = user_id
  AND status = 'pending'
  AND (unit_id IS NULL OR unit_id = (SELECT p.unit_id FROM public.profiles p WHERE p.id = auth.uid()))
);

DROP POLICY IF EXISTS "authenticated users view published notices" ON public.notices;
CREATE POLICY "authenticated users view published notices"
ON public.notices
FOR SELECT TO authenticated
USING (
  published = true
  AND (
    visibility_scope IN ('public','all')
    OR (
      visibility_scope = 'specific'
      AND EXISTS (
        SELECT 1
        FROM public.notice_unit_targets t
        JOIN public.member_directory d ON d.id = t.directory_id
        JOIN public.profiles p ON p.id = auth.uid()
        JOIN public.units u ON u.id = p.unit_id
        JOIN public.wings w ON w.id = u.wing_id
        WHERE t.notice_id = notices.id
          AND t.target_scope = 'specific'
          AND d.flat_unit_number = u.unit_number
          AND d.wing = w.code
          AND d.active = true
      )
    )
  )
);

CREATE INDEX IF NOT EXISTS idx_garden_booking_date_status
  ON public.garden_area_booking_requests (booking_date,status);
CREATE INDEX IF NOT EXISTS idx_garden_booking_user
  ON public.garden_area_booking_requests (user_id,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notice_targets_notice_directory
  ON public.notice_unit_targets (notice_id,directory_id);
