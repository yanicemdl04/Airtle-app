import { createParamDecorator, ExecutionContext } from '@nestjs/common';

/** Forme du payload utilisateur injecté dans la requête par la JwtStrategy. */
export interface AuthUser {
  userId: string;
  phone: string;
}

/**
 * Décorateur de paramètre permettant de récupérer l'utilisateur authentifié
 * directement dans la signature d'une méthode de contrôleur.
 *
 * Exemple : `getProfile(@CurrentUser() user: AuthUser)`.
 */
export const CurrentUser = createParamDecorator(
  (data: keyof AuthUser | undefined, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();
    const user: AuthUser = request.user;
    return data ? user?.[data] : user;
  },
);
