import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as argon2 from 'argon2';
import { SessionsService } from '../sessions/sessions.service';
import { UsersService } from '../users/users.service';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';
import { RegisterDto } from './dto/register.dto';
import { JwtPayload } from './jwt.strategy';
import { normalizePhone } from './utils/phone.util';

interface RequestContext {
  ipAddress?: string;
  deviceId?: string;
}

export interface TokenPair {
  access_token: string;
  refresh_token: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly users: UsersService,
    private readonly sessions: SessionsService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async register(dto: RegisterDto, ctx: RequestContext): Promise<TokenPair> {
    const phone = normalizePhone(dto.phone);
    const existing = await this.users.findByPhone(phone);
    if (existing) {
      throw new ConflictException('Ce numéro de téléphone est déjà utilisé');
    }

    const pinHash = await argon2.hash(dto.pin.trim());
    const user = await this.users.create({
      fullName: dto.fullName.trim(),
      phone,
      country: dto.country,
      operator: dto.operator,
      pinHash,
    });

    return this.createSession(user.id, user.phone, {
      ipAddress: ctx.ipAddress,
      deviceId: dto.deviceId?.trim() ?? ctx.deviceId,
    });
  }

  async login(dto: LoginDto, ctx: RequestContext): Promise<TokenPair> {
    const phone = normalizePhone(dto.phone);
    const pin = dto.pin.trim();

    const user = await this.users.findByPhone(phone);
    if (!user) {
      throw new UnauthorizedException('Identifiants invalides');
    }

    const pinOk = await argon2.verify(user.pinHash, pin);
    if (!pinOk) {
      throw new UnauthorizedException('Identifiants invalides');
    }

    return this.createSession(user.id, user.phone, {
      ipAddress: ctx.ipAddress,
      deviceId: dto.deviceId?.trim() ?? ctx.deviceId,
    });
  }

  /** Rotation du refresh token après validation en base. */
  async refresh(dto: RefreshDto): Promise<TokenPair> {
    let payload: JwtPayload;
    try {
      payload = await this.jwt.verifyAsync<JwtPayload>(dto.refreshToken, {
        secret: this.config.get<string>('JWT_REFRESH_SECRET'),
      });
    } catch {
      throw new UnauthorizedException('Refresh token invalide ou expiré');
    }

    const session = await this.sessions.findValidSession(
      payload.sub,
      dto.refreshToken,
    );
    if (!session) {
      throw new UnauthorizedException('Session invalide ou révoquée');
    }

    const tokens = await this.signTokens(payload.sub, payload.phone);
    await this.sessions.rotate(
      session.id,
      tokens.refresh_token,
      this.refreshExpiresAt(),
    );
    return tokens;
  }

  private async createSession(
    userId: string,
    phone: string,
    ctx: RequestContext,
  ): Promise<TokenPair> {
    const tokens = await this.signTokens(userId, phone);
    await this.sessions.create({
      userId,
      deviceId: ctx.deviceId?.trim() || 'unknown-device',
      ipAddress: ctx.ipAddress,
      refreshToken: tokens.refresh_token,
      expiresAt: this.refreshExpiresAt(),
    });
    return tokens;
  }

  private async signTokens(userId: string, phone: string): Promise<TokenPair> {
    const payload: JwtPayload = { sub: userId, phone };

    const [access_token, refresh_token] = await Promise.all([
      this.jwt.signAsync(payload, {
        secret: this.config.get<string>('JWT_SECRET'),
        expiresIn: this.config.get<string>('JWT_EXPIRES_IN', '15m'),
      }),
      this.jwt.signAsync(payload, {
        secret: this.config.get<string>('JWT_REFRESH_SECRET'),
        expiresIn: this.config.get<string>('JWT_REFRESH_EXPIRES_IN', '7d'),
      }),
    ]);

    return { access_token, refresh_token };
  }

  private refreshExpiresAt(): Date {
    const raw = this.config.get<string>('JWT_REFRESH_EXPIRES_IN', '7d');
    return new Date(Date.now() + this.parseDurationMs(raw));
  }

  private parseDurationMs(value: string): number {
    const match = /^(\d+)([smhd])$/.exec(value.trim());
    if (!match) return 7 * 24 * 60 * 60 * 1000;
    const amount = Number(match[1]);
    const factors: Record<string, number> = {
      s: 1000,
      m: 60 * 1000,
      h: 60 * 60 * 1000,
      d: 24 * 60 * 60 * 1000,
    };
    return amount * factors[match[2]];
  }
}
