import { ApiProperty } from '@nestjs/swagger';
import { Currency } from '@prisma/client';
import {
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsPositive,
  IsString,
  IsUUID,
  Max,
} from 'class-validator';

export class SendTransactionDto {
  @ApiProperty({ example: '7c9e6679-7425-40de-944b-e07fc1f90ae7' })
  @IsUUID()
  receiver_id: string;

  @ApiProperty({ example: 1500.5 })
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  @Max(100000000)
  amount: number;

  @ApiProperty({ enum: Currency, example: Currency.CDF })
  @IsEnum(Currency)
  currency: Currency;

  @ApiProperty({
    example: 'b3f1c2a4-idempotency-key',
    description: 'Clé unique empêchant le double traitement',
  })
  @IsString()
  @IsNotEmpty()
  idempotency_key: string;
}
