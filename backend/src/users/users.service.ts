import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { EncryptionService } from '../common/encryption.service';

interface CreateUserInput {
  displayName: string;
  phoneHash: string;
  phoneEncrypted: Buffer;
  nameEncrypted: Buffer;
  country?: string;
  operator?: string;
  pinHash: string;
  accountType?: string;
  createdVia?: string;
}

interface UpdateUserInput {
  displayName?: string;
  avatarUrl?: string;
  failedPinAttempts?: number;
  lockedUntil?: Date | null;
  pinHash?: string;
}

/**
 * Gère l'identité des utilisateurs.
 * - Phone et name chiffrés en AES-256-GCM
 * - Phone hashé (SHA-256) pour lookup
 * - Wallet créé automatiquement à la création
 */
@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly encryption: EncryptionService,
  ) {}

  /**
   * Trouver par téléphone hashé
   * Déchiffre le téléphone réel si besoin
   */
  async findByPhone(phone: string) {
    const phoneHash = this.encryption.hash(phone, process.env.PHONE_HASH_SALT || 'default-salt');
    return this.prisma.user.findUnique({ where: { phoneHash } });
  }

  async findById(id: string) {
    return this.prisma.user.findUnique({ where: { id } });
  }

  /**
   * Crée un utilisateur avec chiffrement
   */
  async create(input: CreateUserInput) {
    return this.prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          phoneHash: input.phoneHash,
          phoneEncrypted: input.phoneEncrypted,
          nameEncrypted: input.nameEncrypted,
          displayName: input.displayName,
          country: input.country,
          operator: input.operator,
          pinHash: input.pinHash,
          accountType: input.accountType || 'PERSONAL',
          createdVia: input.createdVia || 'MOBILE',
        },
      });
      
      // Créer le wallet par défaut
      await tx.wallet.create({ data: { userId: user.id } });
      
      return user;
    });
  }

  /**
   * Met à jour un utilisateur
   */
  async update(userId: string, data: UpdateUserInput) {
    return this.prisma.user.update({
      where: { id: userId },
      data: {
        displayName: data.displayName,
        avatarUrl: data.avatarUrl,
        failedPinAttempts: data.failedPinAttempts,
        lockedUntil: data.lockedUntil,
        pinHash: data.pinHash,
      },
    });
  }

  /**
   * Profil sanitizé (ne contient jamais PIN, tokens ou données chiffrées en clair)
   */
  async getProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        displayName: true,
        avatarUrl: true,
        country: true,
        operator: true,
        accountType: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    if (!user) {
      throw new NotFoundException('Utilisateur introuvable');
    }
    return user;
  }

  /**
   * Déchiffre le téléphone réel d'un utilisateur
   * (usage interne seulement)
   */
  async getDecryptedPhone(userId: string): Promise<string> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { phoneEncrypted: true },
    });

    if (!user) {
      throw new NotFoundException('Utilisateur introuvable');
    }

    return this.encryption.decrypt(user.phoneEncrypted, userId);
  }
}