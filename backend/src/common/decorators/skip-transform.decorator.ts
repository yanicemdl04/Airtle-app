import { SetMetadata } from '@nestjs/common';

export const SKIP_TRANSFORM_KEY = 'skipTransform';

/** Exclut la route de l'enveloppe `{ success, data }` du TransformInterceptor. */
export const SkipTransform = () => SetMetadata(SKIP_TRANSFORM_KEY, true);
