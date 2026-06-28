import { Injectable, NotFoundException } from '@nestjs/common';
import { phoneLookupVariants } from '../auth/utils/phone.util';
import { PrismaService } from '../prisma/prisma.service';

interface CreateUserInput {
  fullName: string;
  phone: string;
  country: string;
  operator: string;
  pinHash: string;
}

/**
 * Gère l'identité des utilisateurs. À la création d'un utilisateur, un wallet
 * par défaut est provisionné dans la même transaction (un utilisateur possède
 * toujours au moins un portefeuille).
 */
@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async findByPhone(rawPhone: string) {
    const variants = phoneLookupVariants(rawPhone);

    for (const phone of variants) {
      const user = await this.prisma.user.findUnique({ where: { phone } });
      if (user) return user;
    }

    return null;
  }

  async findById(id: string) {
    return this.prisma.user.findUnique({ where: { id } });
  }

  async create(input: CreateUserInput) {
    return this.prisma.$transaction(async (tx) => {
      const user = await tx.user.create({ data: input });
      await tx.wallet.create({ data: { userId: user.id } });
      return user;
    });
  }

  /** Profil sanitizé : ne renvoie jamais le hash du PIN. */
  async getProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        fullName: true,
        phone: true,
        country: true,
        operator: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    if (!user) {
      throw new NotFoundException('Utilisateur introuvable');
    }
    return user;
  }
}
