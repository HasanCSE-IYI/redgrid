export interface Env {
  DB: D1Database;
  SYNC_KEY?: string;
}

interface DonorRecord {
  name: string;
  blood_group: string;
  gender: string;
  phone: string;
  consent_to_share: number;
  district: string;
  area: string;
  last_donation_date?: string | null;
  total_donations: number;
  notes?: string | null;
  created_at: string;
  updated_at: string;
}

interface DonationLogRecord {
  donor_phone: string;
  donation_date: string;
  created_at: string;
}

interface SyncPayload {
  last_synced_at?: string | null;
  donors?: DonorRecord[];
  logs?: DonationLogRecord[];
  deleted_phones?: string[];
}

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Sync-Key",
};

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...CORS_HEADERS,
    },
  });
}

function errorResponse(message: string, status = 400): Response {
  return jsonResponse({ error: message, success: false }, status);
}

function verifyAuth(request: Request, env: Env): boolean {
  if (!env.SYNC_KEY || env.SYNC_KEY.trim() === "") {
    return true; // No key configured -> open sync
  }

  const authHeader = request.headers.get("Authorization");
  const xSyncKey = request.headers.get("X-Sync-Key");

  if (xSyncKey && xSyncKey.trim() === env.SYNC_KEY.trim()) {
    return true;
  }

  if (authHeader) {
    const parts = authHeader.split(" ");
    if (parts.length === 2 && parts[0].toLowerCase() === "bearer") {
      if (parts[1].trim() === env.SYNC_KEY.trim()) {
        return true;
      }
    }
  }

  return false;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    // 1. CORS Preflight
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: CORS_HEADERS,
      });
    }

    // 2. Health check endpoint
    if (url.pathname === "/" || url.pathname === "/health" || url.pathname === "/api/health") {
      return jsonResponse({
        status: "ok",
        app: "RedGrid Sync Server",
        version: "1.0.0",
        timestamp: new Date().toISOString(),
      });
    }

    // 3. Bi-directional Sync Endpoint
    if (url.pathname === "/api/sync") {
      if (request.method !== "POST") {
        return errorResponse("Method not allowed", 405);
      }

      if (!verifyAuth(request, env)) {
        return errorResponse("Unauthorized: Invalid or missing sync key", 401);
      }

      if (!env.DB) {
        return errorResponse("D1 database binding 'DB' is missing. Please check wrangler.toml", 500);
      }

      try {
        const body = (await request.json()) as SyncPayload;
        const now = new Date().toISOString();
        const lastSyncedAt = body.last_synced_at ? body.last_synced_at.trim() : null;

        const statements: D1PreparedStatement[] = [];

        // A. Process incoming deletions
        if (Array.isArray(body.deleted_phones) && body.deleted_phones.length > 0) {
          for (const phone of body.deleted_phones) {
            statements.push(
              env.DB.prepare(
                "UPDATE donors SET is_deleted = 1, updated_at = ? WHERE phone = ?"
              ).bind(now, phone)
            );
            statements.push(
              env.DB.prepare("DELETE FROM donation_logs WHERE donor_phone = ?").bind(phone)
            );
          }
        }

        // B. Process incoming donors (Upsert with Last-Write-Wins on updated_at)
        if (Array.isArray(body.donors) && body.donors.length > 0) {
          for (const d of body.donors) {
            statements.push(
              env.DB.prepare(`
                INSERT INTO donors (
                  name, blood_group, gender, phone, consent_to_share,
                  district, area, last_donation_date, total_donations,
                  notes, is_deleted, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
                ON CONFLICT(phone) DO UPDATE SET
                  name = excluded.name,
                  blood_group = excluded.blood_group,
                  gender = excluded.gender,
                  consent_to_share = excluded.consent_to_share,
                  district = excluded.district,
                  area = excluded.area,
                  last_donation_date = excluded.last_donation_date,
                  total_donations = excluded.total_donations,
                  notes = excluded.notes,
                  is_deleted = 0,
                  updated_at = excluded.updated_at
                WHERE excluded.updated_at >= donors.updated_at
              `).bind(
                d.name,
                d.blood_group,
                d.gender || "MALE",
                d.phone,
                d.consent_to_share ? 1 : 0,
                d.district,
                d.area,
                d.last_donation_date || null,
                d.total_donations || 0,
                d.notes || null,
                d.created_at || now,
                d.updated_at || now
              )
            );
          }
        }

        // C. Process incoming donation logs
        if (Array.isArray(body.logs) && body.logs.length > 0) {
          for (const log of body.logs) {
            statements.push(
              env.DB.prepare(`
                INSERT INTO donation_logs (donor_phone, donation_date, created_at)
                VALUES (?, ?, ?)
                ON CONFLICT(donor_phone, donation_date) DO NOTHING
              `).bind(log.donor_phone, log.donation_date, log.created_at || now)
            );
          }
        }

        // Execute write statements in chunks of 50 to respect D1 limits
        const CHUNK_SIZE = 50;
        for (let i = 0; i < statements.length; i += CHUNK_SIZE) {
          const chunk = statements.slice(i, i + CHUNK_SIZE);
          await env.DB.batch(chunk);
        }

        // D. Pull changes to send back to client
        let remoteDonors: unknown[] = [];
        let remoteDeleted: string[] = [];
        let remoteLogs: unknown[] = [];

        if (lastSyncedAt) {
          // Delta query: modified since client's last sync
          const donorsResult = await env.DB.prepare(`
            SELECT name, blood_group, gender, phone, consent_to_share,
                   district, area, last_donation_date, total_donations,
                   notes, created_at, updated_at
            FROM donors
            WHERE updated_at > ? AND is_deleted = 0
            ORDER BY updated_at ASC
          `).bind(lastSyncedAt).all();

          remoteDonors = donorsResult.results || [];

          const deletedResult = await env.DB.prepare(`
            SELECT phone FROM donors
            WHERE updated_at > ? AND is_deleted = 1
          `).bind(lastSyncedAt).all();

          remoteDeleted = (deletedResult.results || []).map((r: any) => r.phone as string);

          const logsResult = await env.DB.prepare(`
            SELECT donor_phone, donation_date, created_at
            FROM donation_logs
            WHERE created_at > ?
            ORDER BY created_at ASC
          `).bind(lastSyncedAt).all();

          remoteLogs = logsResult.results || [];
        } else {
          // Full initial sync
          const donorsResult = await env.DB.prepare(`
            SELECT name, blood_group, gender, phone, consent_to_share,
                   district, area, last_donation_date, total_donations,
                   notes, created_at, updated_at
            FROM donors
            WHERE is_deleted = 0
            ORDER BY name ASC
          `).all();

          remoteDonors = donorsResult.results || [];

          const logsResult = await env.DB.prepare(`
            SELECT donor_phone, donation_date, created_at
            FROM donation_logs
            ORDER BY donation_date DESC
          `).all();

          remoteLogs = logsResult.results || [];
        }

        return jsonResponse({
          synced_at: now,
          donors: remoteDonors,
          logs: remoteLogs,
          deleted_phones: remoteDeleted,
        });
      } catch (err: any) {
        return errorResponse(`Sync execution failed: ${err.message || String(err)}`, 500);
      }
    }

    return errorResponse("Endpoint not found", 404);
  },
};
