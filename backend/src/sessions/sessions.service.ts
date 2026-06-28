import { Injectable, NotFoundException } from '@nestjs/common';
import * as argon2 from 'argon2';
import { createHash, timingSafeEqual } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';

interface CreateSessionInput {
  userId: string;
  deviceId: string;
  ipAddress?: string;
  refreshToken: string;
  expiresAt: Date;
}

/**
 * Gère les sessions par appareil : création, rotation du refresh token,
 * révocation unitaire et déconnexion globale.
 *
 * Les refresh tokens sont stockés hashés (SHA-256) — rapide au login mobile.
 */
@Injectable()
export class SessionsService {
  constructor(private readonly prisma: PrismaService) {}

  private hashRefreshToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  /** SHA-256 (nouveau) ou Argon2 (sessions existantes). */
  private async verifyStoredRefreshToken(
    token: string,
    stored: string,
  ): Promise<boolean> {
    if (/^[a-f0-9]{64}$/i.test(stored)) {
      const expected = this.hashRefreshToken(token);
      const a = Buffer.from(expected, 'hex');
      const b = Buffer.from(stored, 'hex');
      return a.length === b.length && timingSafeEqual(a, b);
    }
    try {
      return await argon2.verify(stored, token);
    } catch {
      return false;
    }
  }

  async isNewDevice(userId: string, deviceId: string): Promise<boolean> {
    const existing = await this.prisma.userSession.findFirst({
      where: { userId, deviceId },
    });
    return existing === null;
  }

  async create(input: CreateSessionInput) {
    const refreshTokenHash = this.hashRefreshToken(input.refreshToken);
    return this.prisma.userSession.create({
      data: {
        userId: input.userId,
        deviceId: input.deviceId,
        ipAddress: input.ipAddress,
        refreshToken: refreshTokenHash,
        expiresAt: input.expiresAt,
      },
    });
  }

  async findValidSession(userId: string, refreshToken: string) {
    const sessions = await this.prisma.userSession.findMany({
      where: { userId, revoked: false, expiresAt: { gt: new Date() } },
    });

    for (const session of sessions) {
      const matches = await this.verifyStoredRefreshToken(
        refreshToken,
        session.refreshToken,
      );
      if (matches) {
        return session;
      }
    }
    return null;
  }

  async rotate(sessionId: string, newRefreshToken: string, expiresAt: Date) {
    const refreshTokenHash = this.hashRefreshToken(newRefreshToken);
    return this.prisma.userSession.update({
      where: { id: sessionId },
      data: { refreshToken: refreshTokenHash, expiresAt },
    });
  }

  async revoke(userId: string, sessionId: string): Promise<void> {
    const session = await this.prisma.userSession.findFirst({
      where: { id: sessionId, userId },
    });
    if (!session) {
      throw new NotFoundException('Session introuvable');
    }
    await this.prisma.userSession.update({
      where: { id: sessionId },
      data: { revoked: true },
    });
  }

  async revokeAll(userId: string): Promise<{ count: number }> {
    const result = await this.prisma.userSession.updateMany({
      where: { userId, revoked: false },
      data: { revoked: true },
    });
    return { count: result.count };
  }

  async listActive(userId: string) {
    return this.prisma.userSession.findMany({
      where: { userId, revoked: false, expiresAt: { gt: new Date() } },
      select: {
        id: true,
        deviceId: true,
        ipAddress: true,
        createdAt: true,
        expiresAt: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }
}
