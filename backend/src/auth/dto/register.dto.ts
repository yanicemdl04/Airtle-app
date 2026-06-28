import { ApiProperty } from '@nestjs/swagger';
import {
  IsNotEmpty,
  IsOptional,
  IsString,
  Length,
  Matches,
  IsEnum,
} from 'class-validator';

enum AccountType {
  PERSONAL = 'PERSONAL',
  MERCHANT = 'MERCHANT',
}

export class RegisterDto {
  @ApiProperty({ example: 'Marie Mukendi' })
  @IsString()
  @IsNotEmpty()
  @Length(2, 100)
  displayName: string;

  @ApiProperty({ example: '+243999939477' })
  @IsString()
  @Matches(/^\+?[0-9]{8,15}$/, {
    message: 'Le numéro de téléphone est invalide',
  })
  phone: string;

  @ApiProperty({ example: 'CD', required: false })
  @IsOptional()
  @IsString()
  country?: string;

  @ApiProperty({ example: 'Airtel', required: false })
  @IsOptional()
  @IsString()
  operator?: string;

  @ApiProperty({ example: '1234', description: 'PIN à 4-6 chiffres' })
  @IsString()
  @Matches(/^[0-9]{4,6}$/, {
    message: 'Le PIN doit contenir entre 4 et 6 chiffres',
  })
  pin: string;

  @ApiProperty({
    example: 'PERSONAL',
    enum: AccountType,
    required: false,
    description: 'Type de compte : PERSONAL ou MERCHANT',
  })
  @IsOptional()
  @IsEnum(AccountType)
  accountType?: AccountType;

  @ApiProperty({ example: 'device-abc-123', required: false })
  @IsOptional()
  @IsString()
  deviceId?: string;
}