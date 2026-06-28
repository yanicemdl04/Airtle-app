import { Injectable } from '@nestjs/common';
import * as crypto from 'crypto';

/**
 * Service de chiffrement des données sensibles (PII).
 * Utilise AES-256-GCM avec AAD (Additional Authenticated Data).
 * 
 * Pour MVP : clé en .env
 * Pour prod : clé dans Vault Transit Engine
 */
@Injectable()
export class EncryptionService {
private encryptionKey: Buffer;

constructor() {
    // MVP: clé depuis .env (32 bytes = 256 bits)
    const keyEnv = process.env.ENCRYPTION_KEY;
    if (!keyEnv) {
    throw new Error('ENCRYPTION_KEY not set in .env');
    }
    this.encryptionKey = Buffer.from(keyEnv, 'hex');
    if (this.encryptionKey.length !== 32) {
    throw new Error('ENCRYPTION_KEY must be 32 bytes (256 bits)');
    }
}

/**
 * Chiffre une chaîne avec AES-256-GCM
 * @param plaintext Texte en clair
 * @param aad Additional Authenticated Data (ex: user_id)
 * @returns Buffer chiffré (nonce + ciphertext + tag)
 */
encrypt(plaintext: string, aad: string): Buffer {
    // Générer un nonce aléatoire (96 bits pour GCM)
    const nonce = crypto.randomBytes(12);

    // Créer le cipher
    const cipher = crypto.createCipheriv('aes-256-gcm', this.encryptionKey, nonce);

    // Ajouter l'AAD (Additional Authenticated Data)
    cipher.setAAD(Buffer.from(aad));

    // Chiffrer
    let encrypted = cipher.update(plaintext, 'utf8');
    encrypted = Buffer.concat([encrypted, cipher.final()]);

    // Récupérer le tag d'authentification
    const tag = cipher.getAuthTag();

    // Retourner: nonce + encrypted + tag
    return Buffer.concat([nonce, encrypted, tag]);
}

/**
 * Déchiffre une chaîne chiffrée avec AES-256-GCM
 * @param buffer Buffer chiffré (nonce + ciphertext + tag)
 * @param aad Additional Authenticated Data (doit matcher celui du chiffrement)
 * @returns Texte en clair
 */
decrypt(buffer: Buffer, aad: string): string {
    // Extraire les composants
    const nonce = buffer.slice(0, 12);
    const tag = buffer.slice(-16); // Derniers 16 bytes
    const ciphertext = buffer.slice(12, -16); // Entre nonce et tag

    // Créer le decipher
    const decipher = crypto.createDecipheriv('aes-256-gcm', this.encryptionKey, nonce);

    // Ajouter l'AAD (DOIT être identique à celui du chiffrement)
    decipher.setAAD(Buffer.from(aad));
    decipher.setAuthTag(tag);

    // Déchiffrer
    let decrypted = decipher.update(ciphertext);
    decrypted = Buffer.concat([decrypted, decipher.final()]);

    return decrypted.toString('utf8');
}

/**
 * Hash SHA-256 avec salt (pour les lookups, pas réversible)
 */
hash(plaintext: string, salt: string = ''): string {
    return crypto
    .createHash('sha256')
    .update(plaintext + salt)
    .digest('hex');
}
}