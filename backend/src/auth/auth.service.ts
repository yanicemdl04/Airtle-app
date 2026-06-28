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
import { JwtPayload } from './jwt.strategy';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';
import { RegisterDto } from './dto/register.dto';

interface RequestContext {
  ipAddress?: string;
  deviceId?: string;
}

export interface TokenPair {
  access_token: string;
  refresh_token: string;
}

export interface LoginResponse extends TokenPair {
  new_device?: boolean;
}

/**
 * Service d'authentification.
 *
 * - PIN hashé avec Argon2 (jamais stocké ni renvoyé en clair).
 * - Access token court + refresh token long avec rotation par session.
 * - Détection de nouvel appareil au login.
 */
@Injectable()
export class AuthService {
  constructor(
    private readonly users: UsersService,
    private readonly sessions: SessionsService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async register(dto: RegisterDto, ctx: RequestContext): Promise<TokenPair> {
    const existing = await this.users.findByPhone(dto.phone);
    if (existing) {
      throw new ConflictException('Ce numéro de téléphone est déjà utilisé');
    }

    const pinHash = await argon2.hash(dto.pin);
    const user = await this.users.create({
      fullName: dto.fullName,
      phone: dto.phone,
      country: dto.country,
      operator: dto.operator,
      pinHash,
    });

    return this.issueSession(user.id, user.phone, {
      ipAddress: ctx.ipAddress,
      deviceId: dto.deviceId ?? ctx.deviceId,
    });
  }

  async login(dto: LoginDto, ctx: RequestContext): Promise<LoginResponse> {
    const user = await this.users.findByPhone(dto.phone);
    // Message générique pour ne pas révéler l'existence du compte.
    if (!user) {
      throw new UnauthorizedException('Identifiants invalides');
    }

    const valid = await argon2.verify(user.pinHash, dto.pin);
    if (!valid) {
      throw new UnauthorizedException('Identifiants invalides');
    }

    const deviceId = dto.deviceId ?? ctx.deviceId ?? 'unknown-device';
    const isNew = await this.sessions.isNewDevice(user.id, deviceId);

    const tokens = await this.issueSession(user.id, user.phone, {
      ipAddress: ctx.ipAddress,
      deviceId,
    });

    return { ...tokens, ...(isNew && { new_device: true }) };
  }

  /** Rotation du refresh token : valide l'ancien puis le remplace. */
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

    const tokens = await this.generateTokens(payload.sub, payload.phone);
    await this.sessions.rotate(
      session.id,
      tokens.refresh_token,
      this.refreshExpiryDate(),
    );
    return tokens;
  }

  // -------------------------------------------------------------------------
  // Helpers privés
  // -------------------------------------------------------------------------

  private async issueSession(
    userId: string,
    phone: string,
    ctx: RequestContext,
  ): Promise<TokenPair> {
    const tokens = await this.generateTokens(userId, phone);
    await this.sessions.create({
      userId,
      deviceId: ctx.deviceId ?? 'unknown-device',
      ipAddress: ctx.ipAddress,
      refreshToken: tokens.refresh_token,
      expiresAt: this.refreshExpiryDate(),
    });
    return tokens;
  }

  private async generateTokens(
    userId: string,
    phone: string,
  ): Promise<TokenPair> {
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

  private refreshExpiryDate(): Date {
    const raw = this.config.get<string>('JWT_REFRESH_EXPIRES_IN', '7d');
    return new Date(Date.now() + this.durationToMs(raw));
  }

  /** Convertit une durée type "15m", "7d", "3600s" en millisecondes. */
  private durationToMs(value: string): number {
    const match = /^(\d+)([smhd])$/.exec(value.trim());
    if (!match) {
      return 7 * 24 * 60 * 60 * 1000;
    }
    const amount = Number(match[1]);
    const unit = match[2];
    const factors: Record<string, number> = {
      s: 1000,
      m: 60 * 1000,
      h: 60 * 60 * 1000,
      d: 24 * 60 * 60 * 1000,
    };
    return amount * factors[unit];
  }
}
