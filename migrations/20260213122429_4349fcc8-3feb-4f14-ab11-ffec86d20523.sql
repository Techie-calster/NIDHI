
-- Table for storing OTP codes for patient verification
CREATE TABLE public.verification_otps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  requester_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  otp_code text NOT NULL,
  patient_email text NOT NULL,
  verified boolean NOT NULL DEFAULT false,
  expires_at timestamp with time zone NOT NULL DEFAULT (now() + interval '10 minutes'),
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.verification_otps ENABLE ROW LEVEL SECURITY;

-- Diagnostic centres can view OTPs they created
CREATE POLICY "Requesters can view own OTPs"
ON public.verification_otps FOR SELECT
USING (is_own_profile(requester_profile_id));

-- Diagnostic centres can insert OTPs
CREATE POLICY "Requesters can insert OTPs"
ON public.verification_otps FOR INSERT
WITH CHECK (is_own_profile(requester_profile_id));

-- Diagnostic centres can update OTPs they created (to mark verified)
CREATE POLICY "Requesters can update own OTPs"
ON public.verification_otps FOR UPDATE
USING (is_own_profile(requester_profile_id));

-- Storage bucket for lab report files
INSERT INTO storage.buckets (id, name, public) VALUES ('lab-reports', 'lab-reports', false);

-- Only authenticated users can upload to lab-reports bucket
CREATE POLICY "Authenticated users can upload lab reports"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'lab-reports');

-- Users can view their own reports (via folder structure: patient_profile_id/filename)
CREATE POLICY "Users can view lab report files"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'lab-reports');
