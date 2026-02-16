-- Allow diagnostic centres to view patient cards (for barcode lookup)
CREATE POLICY "Diagnostic centres can view patient cards"
ON public.patient_cards
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.user_id = auth.uid()
    AND profiles.user_type = 'diagnostic_centre'
  )
);