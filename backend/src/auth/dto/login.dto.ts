import { ApiProperty } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';
import { normalizePhone } from '../utils/phone.util';

export class LoginDto {
  @ApiProperty({
    example: '+243999939477',
    description: 'Numéro RDC : +243…, 099…, 999… ou 243…',
  })
  @Transform(({ value }) =>
    typeof value === 'string' ? normalizePhone(value) : value,
  )
  @IsString()
  @MinLength(12, { message: 'Numéro de téléphone invalide' })
  @MaxLength(16)
  @Matches(/^\+243\d{9}$/, {
    message: 'Numéro RDC invalide (attendu : +243 suivi de 9 chiffres)',
  })
  phone: string;

  @ApiProperty({ example: '1234', description: 'PIN à 4-6 chiffres' })
  @Transform(({ value }) => String(value ?? '').trim())
  @IsString()
  @Matches(/^[0-9]{4,6}$/, {
    message: 'Le PIN doit contenir entre 4 et 6 chiffres',
  })
  pin: string;

  @ApiProperty({ example: 'device-abc-123', required: false })
  @IsOptional()
  @IsString()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  deviceId?: string;
}
