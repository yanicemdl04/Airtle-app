import { ApiProperty } from '@nestjs/swagger';
import {
  IsNotEmpty,
  IsOptional,
  IsString,
  Length,
  Matches,
} from 'class-validator';

export class RegisterDto {
  @ApiProperty({ example: 'Mutombo Kabila' })
  @IsString()
  @IsNotEmpty()
  @Length(2, 100)
  fullName: string;

  @ApiProperty({ example: '+243999939477' })
  @IsString()
  @Matches(/^\+?[0-9]{8,15}$/, {
    message: 'Le numéro de téléphone est invalide',
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
