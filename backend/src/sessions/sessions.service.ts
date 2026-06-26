import { Injectable, NotFoundException } from '@nestjs/common';
import * as argon2 from 'argon2';
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
 * révocation unitaire et déconnexion globale, détection de nouvel appareil.
 *
 * Les refresh tokens sont stockés hashés (Argon2), jamais en clair.
 */
@Injectable()
export class SessionsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Indique si l'appareil n'a jamais été vu pour cet utilisateur. */
  async isNewDevice(userId: string, deviceId: string): Promise<boolean> {
    const existing = await this.prisma.userSession.findFirst({
      where: { userId, deviceId },
    });
    return existing === null;
  }

  async create(input: CreateSessionInput) {
    const refreshTokenHash = await argon2.hash(input.refreshToken);
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

  /**
   * Vérifie qu'un refresh token correspond bien à une session active et
   * non expirée appartenant à l'utilisateur.
   */
  async findValidSession(userId: string, refreshToken: string) {
    const sessions = await this.prisma.userSession.findMany({
      where: { userId, revoked: false, expiresAt: { gt: new Date() } },
    });

    for (const session of sessions) {
      const matches = await argon2.verify(
        session.refreshToken,
        refreshToken,
      );
      if (matches) {
        return session;
      }
    }
    return null;
  }

  /** Rotation : remplace le refresh token hashé d'une session existante. */
  async rotate(sessionId: string, newRefreshToken: string, expiresAt: Date) {
    const refreshTokenHash = await argon2.hash(newRefreshToken);
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

  /** Déconnexion globale : révoque toutes les sessions de l'utilisateur. */
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
