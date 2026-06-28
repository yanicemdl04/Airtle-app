    import { Injectable, Logger } from '@nestjs/common';
    import * as crypto from 'crypto';
    import { PrismaService } from '../prisma/prisma.service';

    /**
     * Service d'audit immuable — signé en chaîne (prev_hash)
     * Chaque log est lié au précédent pour détecter les modifications
     */
    @Injectable()
    export class AuditService {
    private readonly logger = new Logger(AuditService.name);

    constructor(private prisma: PrismaService) {}

    /**
     * Enregistre une action d'audit
     * @param action Type d'action (LOGIN, QR_CREATE, PAYMENT_SENT, etc.)
     * @param userId ID de l'utilisateur (optionnel)
     * @param metadata Données additionnelles (sans PII)
     */
    async log(
        action: string,
        userId: string | null,
        metadata: Record<string, any> = {},
    ): Promise<void> {
        try {
        // Récupérer le dernier log pour chaîner les hashes
        const lastLog = await this.prisma.auditLog.findFirst({
            orderBy: { createdAt: 'desc' },
            take: 1,
        });

        const prevHash = lastLog?.hash || 'genesis';

        // Créer l'entrée (sans PII)
        const entry = JSON.stringify({
            action,
            user_id: userId,
            timestamp: new Date().toISOString(),
            metadata: {
            // Filtrer les données sensibles
            ...Object.fromEntries(
                Object.entries(metadata).filter(([key]) => {
                const sensitiveKeys = ['pin', 'password', 'token', 'phone', 'email', 'plaintext'];
                return !sensitiveKeys.some(sensitive => key.toLowerCase().includes(sensitive));
                }),
            ),
            },
        });

        // Hash chaîné : SHA-256(prev_hash + current_entry)
        const hash = crypto
            .createHash('sha256')
            .update(prevHash + entry)
            .digest('hex');

        // Enregistrer en DB
        await this.prisma.auditLog.create({
            data: {
            action,
            userId,
            metadata,
            prevHash,
            hash,
            },
        });

        this.logger.debug(`Audit logged: ${action} for user ${userId}`);
        } catch (error) {
        // Ne pas arrêter le flux si l'audit échoue, mais logger l'erreur
        this.logger.error(`Failed to log audit: ${error.message}`);
        }
    }

    /**
     * Vérifie l'intégrité de la chaîne d'audit (détecte les modifications)
     */
    async verifyIntegrity(): Promise<boolean> {
        const logs = await this.prisma.auditLog.findMany({
        orderBy: { createdAt: 'asc' },
        });

        let prevHash = 'genesis';
        for (const log of logs) {
        if (log.prevHash !== prevHash) {
            this.logger.warn(`Audit chain broken at log ${log.id}`);
            return false;
        }

        // Recalculer le hash pour vérifier
        const entry = JSON.stringify({
            action: log.action,
            user_id: log.userId,
            metadata: log.metadata,
        });

        const expectedHash = crypto
            .createHash('sha256')
            .update(prevHash + entry)
            .digest('hex');

        if (log.hash !== expectedHash) {
            this.logger.warn(`Audit log ${log.id} has been tampered with`);
            return false;
        }

        prevHash = log.hash;
        }

        return true;
    }
    }