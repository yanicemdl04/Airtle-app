import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';

/**
 * Marque une route comme publique : le JwtAuthGuard global la laissera passer
 * sans exiger de token (ex: /auth/login, /auth/register).
 */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
