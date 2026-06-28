import { ApiProperty } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  IsNotEmpty,
  IsOptional,
  IsString,
  Length,
  Matches,
} from 'class-validator';
import { normalizePhone } from '../utils/phone.util';

export class RegisterDto {
  @ApiProperty({ example: 'Mutombo Kabila' })
  @IsString()
  @IsNotEmpty()
  @Length(2, 100)
  fullName: string;

  @ApiProperty({ example: '+243999939477' })
  @Transform(({ value }) =>
    typeof value === 'string' ? normalizePhone(value) : value,
  )
  @IsString()
  @Matches(/^\+243\d{9}$/, {
    message: 'Numéro RDC invalide (attendu : +243 suivi de 9 chiffres)',
  })
  phone: string;

  @ApiProperty({ example: 'CD' })
  @IsString()
  @IsNotEmpty()
  country: string;

  @ApiProperty({ example: 'Airtel' })
  @IsString()
  @IsNotEmpty()
  operator: string;

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
  deviceId?: string;
}
