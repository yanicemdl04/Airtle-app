import { Currency, PrismaClient } from '@prisma/client';
import * as argon2 from 'argon2';

const prisma = new PrismaClient();

/**
 * Données de démonstration : deux utilisateurs avec leur portefeuille,
 * pratiques pour tester les transferts depuis Flutter.
 */
async function main() {
  const pinHash = await argon2.hash('1234');

  const alice = await prisma.user.upsert({
    where: { phone: '+243999939477' },
    update: { pinHash },
    create: {
      fullName: 'Mutombo Kabila',
      phone: '+243999939477',
      country: 'CD',
      operator: 'Airtel',
      pinHash,
      wallets: {
        create: {
          balanceUsd: 20,
          balanceCdf: 10000,
          currencyDefault: Currency.CDF,
        },
      },
    },
  });

  const bob = await prisma.user.upsert({
    where: { phone: '+243888112233' },
    update: { pinHash },
    create: {
      fullName: 'Furaha Nzuzi',
      phone: '+243888112233',
      country: 'CD',
      operator: 'Airtel',
      pinHash,
      wallets: {
        create: {
          balanceUsd: 5,
          balanceCdf: 2500,
          currencyDefault: Currency.CDF,
        },
      },
    },
  });

  // eslint-disable-next-line no-console
  console.log('Utilisateurs de démonstration créés :', {
    alice: alice.id,
    bob: bob.id,
    pin: '1234',
  });
}

main()
  .catch((e) => {
    // eslint-disable-next-line no-console
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
