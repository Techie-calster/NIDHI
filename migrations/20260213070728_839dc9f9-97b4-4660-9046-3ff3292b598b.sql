
-- Create user type enum
CREATE TYPE public.user_type AS ENUM ('patient', 'hospital', 'diagnostic_centre');

-- Profiles table
CREATE TABLE public.profiles (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  user_type public.user_type NOT NULL DEFAULT 'patient',
  full_name TEXT NOT NULL,
  dob DATE,
  gender TEXT,
  blood_group TEXT,
  mobile_number TEXT,
  email TEXT NOT NULL,
  state TEXT,
  city TEXT,
  address TEXT,
  emergency_contact TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Patient cards table
CREATE TABLE public.patient_cards (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  nidhi_id TEXT NOT NULL UNIQUE,
  card_number TEXT NOT NULL UNIQUE,
  barcode_data TEXT NOT NULL,
  issued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.patient_cards ENABLE ROW LEVEL SECURITY;

-- Lab reports table
CREATE TABLE public.lab_reports (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  patient_profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  diagnostic_centre_profile_id UUID REFERENCES public.profiles(id) NOT NULL,
  report_name TEXT NOT NULL,
  report_type TEXT,
  file_url TEXT,
  notes TEXT,
  report_date DATE NOT NULL DEFAULT CURRENT_DATE,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.lab_reports ENABLE ROW LEVEL SECURITY;

-- Updated_at trigger function
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_lab_reports_updated_at BEFORE UPDATE ON public.lab_reports FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Helper: check if current user owns this profile
CREATE OR REPLACE FUNCTION public.is_own_profile(p_id UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = p_id AND user_id = auth.uid()
  );
$$;

-- Helper: get current user's profile id
CREATE OR REPLACE FUNCTION public.get_my_profile_id()
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT id FROM public.profiles WHERE user_id = auth.uid() LIMIT 1;
$$;

-- Profiles RLS
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (user_id = auth.uid());

-- Patient cards RLS
CREATE POLICY "Patients can view own cards" ON public.patient_cards FOR SELECT USING (public.is_own_profile(profile_id));
CREATE POLICY "System can insert cards" ON public.patient_cards FOR INSERT WITH CHECK (public.is_own_profile(profile_id));

-- Lab reports RLS
CREATE POLICY "Patients can view own reports" ON public.lab_reports FOR SELECT USING (public.is_own_profile(patient_profile_id));
CREATE POLICY "Diagnostic centres can insert reports" ON public.lab_reports FOR INSERT WITH CHECK (public.is_own_profile(diagnostic_centre_profile_id));
CREATE POLICY "Diagnostic centres can view own uploaded reports" ON public.lab_reports FOR SELECT USING (public.is_own_profile(diagnostic_centre_profile_id));

-- Auto-create profile on signup trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (user_id, email, full_name, user_type)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE((NEW.raw_user_meta_data->>'user_type')::public.user_type, 'patient')
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
