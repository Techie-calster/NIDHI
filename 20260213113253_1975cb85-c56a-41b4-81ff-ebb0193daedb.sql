
-- Update handle_new_user to save ALL registration fields and auto-create patient card
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  new_profile_id uuid;
BEGIN
  INSERT INTO public.profiles (
    user_id, email, full_name, user_type,
    dob, gender, blood_group, mobile_number,
    state, city, address, emergency_contact
  )
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE((NEW.raw_user_meta_data->>'user_type')::public.user_type, 'patient'),
    CASE WHEN NEW.raw_user_meta_data->>'dob' IS NOT NULL AND NEW.raw_user_meta_data->>'dob' != '' 
      THEN (NEW.raw_user_meta_data->>'dob')::date ELSE NULL END,
    NEW.raw_user_meta_data->>'gender',
    NEW.raw_user_meta_data->>'blood_group',
    NEW.raw_user_meta_data->>'mobile_number',
    NEW.raw_user_meta_data->>'state',
    NEW.raw_user_meta_data->>'city',
    NEW.raw_user_meta_data->>'address',
    NEW.raw_user_meta_data->>'emergency_contact'
  )
  RETURNING id INTO new_profile_id;

  -- Auto-create patient card if user_type is patient and nidhi_id is provided
  IF COALESCE(NEW.raw_user_meta_data->>'user_type', 'patient') = 'patient'
     AND NEW.raw_user_meta_data->>'nidhi_id' IS NOT NULL THEN
    INSERT INTO public.patient_cards (
      profile_id, nidhi_id, card_number, barcode_data
    ) VALUES (
      new_profile_id,
      NEW.raw_user_meta_data->>'nidhi_id',
      NEW.raw_user_meta_data->>'card_number',
      NEW.raw_user_meta_data->>'barcode_data'
    );
  END IF;

  RETURN NEW;
END;
$function$;
