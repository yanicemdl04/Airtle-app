import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, Matches } from 'class-validator';

export class ResolveQrDto {
  @ApiProperty({ example: 'airtel:CD:a1b2c3d4' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^airtel:[A-Z]{2}:[a-f0-9]{8,}$/, {
    message: 'Format de pay_id invalide',
  })
  pay_id: string;
}
