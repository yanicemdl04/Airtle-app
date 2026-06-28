/**
 * Normalise un numéro saisi (099…, 243…, +243…) au format stocké en base (+243…).
 */
export function normalizePhone(raw: string): string {
  let phone = raw.trim().replace(/[\s\-()]/g, '');
  if (!phone) return phone;

  if (!phone.startsWith('+')) {
    if (phone.startsWith('00')) {
      phone = `+${phone.slice(2)}`;
    } else if (phone.startsWith('0') && phone.length >= 10) {
      phone = `+243${phone.slice(1)}`;
    } else if (phone.startsWith('243')) {
      phone = `+${phone}`;
    } else if (/^\d{9,10}$/.test(phone)) {
      phone = `+243${phone.length === 10 ? phone.slice(1) : phone}`;
    } else {
      phone = `+${phone}`;
    }
  }

  return phone;
}

/** Variantes possibles en base pour retrouver un utilisateur. */
export function phoneLookupVariants(raw: string): string[] {
  const normalized = normalizePhone(raw);
  const digits = normalized.replace(/\D/g, '');
  const local9 = digits.length >= 9 ? digits.slice(-9) : digits;

  const variants = [
    normalized,
    raw.trim(),
    digits,
    local9,
    `+243${local9}`,
    `243${local9}`,
    `0${local9}`,
  ];

  return [...new Set(variants.filter(Boolean))];
}
