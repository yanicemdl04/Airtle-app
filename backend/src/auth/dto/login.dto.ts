import { ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsString, Matches } from 'class-validator';

export class LoginDto {
  @ApiProperty({ example: '+243999939477' })
  @IsString()
  @Matches(/^\+?[0-9]{8,15}$/, {
    message: 'Le numéro de téléphone est invalide',
  })
  phone: string;

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
