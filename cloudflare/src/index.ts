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
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Sync-Key, X-RedGrid-App",
};

const SECURITY_HEADERS: Record<string, string> = {
  ...CORS_HEADERS,
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "Referrer-Policy": "no-referrer",
};

const DEFAULT_APP_KEY = "rg_sec_2026_9b8e4f1a";
const VALID_BLOOD_GROUPS = new Set(["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-", "Oh"]);
const VALID_GENDERS = new Set(["MALE", "FEMALE"]);
const BANGLADESH_PHONE_REGEX = /^01[3-9]\d{8}$/;
const DATE_REGEX = /^\d{4}-\d{2}-\d{2}$/;
const MAX_BATCH_SIZE = 500;
const MAX_FUTURE_DRIFT_MS = 5 * 60 * 1000; // 5 minutes

// Sliding-window IP Rate Limiter
interface RateLimitEntry {
  count: number;
  resetAt: number;
}
const rateLimitMap = new Map<string, RateLimitEntry>();
const RATE_LIMIT_WINDOW_MS = 60 * 1000; // 1 minute
const MAX_REQUESTS_PER_WINDOW = 30; // Max 30 requests per minute per IP

function isRateLimited(ip: string): boolean {
  const now = Date.now();
  const entry = rateLimitMap.get(ip);
  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(ip, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS });
    if (rateLimitMap.size > 5000) {
      for (const [key, val] of rateLimitMap.entries()) {
        if (now > val.resetAt) rateLimitMap.delete(key);
      }
    }
    return false;
  }
  entry.count++;
  return entry.count > MAX_REQUESTS_PER_WINDOW;
}

function normalizePhone(input: unknown): string | null {
  if (typeof input !== "string") return null;
  let digits = input.replace(/\D/g, "");
  if (digits.length === 13 && digits.startsWith("880")) {
    digits = digits.substring(2);
  }
  return BANGLADESH_PHONE_REGEX.test(digits) ? digits : null;
}

function validateDonor(d: any): { error?: string; donor?: DonorRecord } {
  if (!d || typeof d !== "object") return { error: "Invalid donor object" };
  
  if (typeof d.name !== "string" || d.name.trim().length === 0 || d.name.trim().length > 80) {
    return { error: "Donor name must be between 1 and 80 characters" };
  }
  
  const blood = typeof d.blood_group === "string" ? d.blood_group.trim() : "";
  if (!VALID_BLOOD_GROUPS.has(blood)) {
    return { error: `Invalid blood group '${d.blood_group}'` };
  }
  
  const gender = typeof d.gender === "string" ? d.gender.trim().toUpperCase() : "MALE";
  if (!VALID_GENDERS.has(gender)) {
    return { error: `Invalid gender '${d.gender}'` };
  }
  
  const phone = normalizePhone(d.phone);
  if (!phone) {
    return { error: `Invalid Bangladeshi phone number '${d.phone}'` };
  }
  
  if (typeof d.district !== "string" || d.district.trim().length === 0 || d.district.trim().length > 60) {
    return { error: "District must be between 1 and 60 characters" };
  }
  
  if (typeof d.area !== "string" || d.area.trim().length === 0 || d.area.trim().length > 60) {
    return { error: "Area must be between 1 and 60 characters" };
  }
  
  let consent = 0;
  if (d.consent_to_share === 1 || d.consent_to_share === true || d.consent_to_share === "1") {
    consent = 1;
  }
  
  let lastDonation: string | null = null;
  if (d.last_donation_date && typeof d.last_donation_date === "string" && d.last_donation_date.trim().length > 0) {
    const trimmedDate = d.last_donation_date.trim();
    if (!DATE_REGEX.test(trimmedDate)) {
      return { error: `Invalid last_donation_date '${d.last_donation_date}' (format must be YYYY-MM-DD)` };
    }
    lastDonation = trimmedDate;
  }
  
  const total = typeof d.total_donations === "number" && d.total_donations >= 0
    ? Math.floor(d.total_donations)
    : 0;
    
  let notes: string | null = null;
  if (d.notes && typeof d.notes === "string") {
    const trimmedNotes = d.notes.trim();
    if (trimmedNotes.length > 300) {
      return { error: "Notes cannot exceed 300 characters" };
    }
    notes = trimmedNotes.length > 0 ? trimmedNotes : null;
  }

  const now = new Date().toISOString();
  const nowMs = Date.now();

  // Clamp timestamps to server time if client attempts future date tampering
  let createdAt = typeof d.created_at === "string" && d.created_at.length > 0 ? d.created_at : now;
  const parsedCreated = Date.parse(createdAt);
  if (isNaN(parsedCreated) || parsedCreated > nowMs + MAX_FUTURE_DRIFT_MS) {
    createdAt = now;
  }

  let updatedAt = typeof d.updated_at === "string" && d.updated_at.length > 0 ? d.updated_at : now;
  const parsedUpdated = Date.parse(updatedAt);
  if (isNaN(parsedUpdated) || parsedUpdated > nowMs + MAX_FUTURE_DRIFT_MS) {
    updatedAt = now;
  }

  return {
    donor: {
      name: d.name.trim(),
      blood_group: blood,
      gender: gender,
      phone: phone,
      consent_to_share: consent,
      district: d.district.trim(),
      area: d.area.trim(),
      last_donation_date: lastDonation,
      total_donations: total,
      notes: notes,
      created_at: createdAt,
      updated_at: updatedAt,
    },
  };
}

function validateLog(l: any): { error?: string; log?: DonationLogRecord } {
  if (!l || typeof l !== "object") return { error: "Invalid log object" };
  const phone = normalizePhone(l.donor_phone);
  if (!phone) return { error: `Invalid donor phone in log: '${l.donor_phone}'` };
  
  if (typeof l.donation_date !== "string" || !DATE_REGEX.test(l.donation_date.trim())) {
    return { error: `Invalid donation date '${l.donation_date}' (format must be YYYY-MM-DD)` };
  }
  
  const now = new Date().toISOString();
  return {
    log: {
      donor_phone: phone,
      donation_date: l.donation_date.trim(),
      created_at: typeof l.created_at === "string" && l.created_at.length > 0 ? l.created_at : now,
    },
  };
}

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...SECURITY_HEADERS,
    },
  });
}

function errorResponse(message: string, status = 400): Response {
  return jsonResponse({ error: message, success: false }, status);
}

function verifyAuth(request: Request, env: Env): boolean {
  const validKeys = new Set<string>();
  validKeys.add(DEFAULT_APP_KEY);
  if (env.SYNC_KEY && env.SYNC_KEY.trim() !== "") {
    validKeys.add(env.SYNC_KEY.trim());
  }

  const xSyncKey = request.headers.get("X-Sync-Key");
  if (xSyncKey && validKeys.has(xSyncKey.trim())) {
    return true;
  }

  const authHeader = request.headers.get("Authorization");
  if (authHeader) {
    const parts = authHeader.split(" ");
    if (parts.length === 2 && parts[0].toLowerCase() === "bearer") {
      if (validKeys.has(parts[1].trim())) {
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
        headers: SECURITY_HEADERS,
      });
    }

    // 2. Health check endpoint
    if (url.pathname === "/" || url.pathname === "/health" || url.pathname === "/api/health") {
      return jsonResponse({
        status: "ok",
        app: "RedGrid Sync Server",
        version: "1.2.0",
        timestamp: new Date().toISOString(),
      });
    }

    // 3. Bi-directional Sync Endpoint
    if (url.pathname === "/api/sync") {
      if (request.method !== "POST") {
        return errorResponse("Method not allowed", 405);
      }

      // Rate limit check
      const clientIp = request.headers.get("CF-Connecting-IP") || request.headers.get("X-Forwarded-For") || "anonymous";
      if (isRateLimited(clientIp)) {
        return errorResponse("Too many requests from this IP. Please wait a minute.", 429);
      }

      // Authentication check
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

        // Rate & Batch Limit Protection
        if (Array.isArray(body.donors) && body.donors.length > MAX_BATCH_SIZE) {
          return errorResponse(`Too many donors in one request (limit ${MAX_BATCH_SIZE})`, 400);
        }
        if (Array.isArray(body.logs) && body.logs.length > MAX_BATCH_SIZE) {
          return errorResponse(`Too many logs in one request (limit ${MAX_BATCH_SIZE})`, 400);
        }
        if (Array.isArray(body.deleted_phones) && body.deleted_phones.length > MAX_BATCH_SIZE) {
          return errorResponse(`Too many deleted phones in one request (limit ${MAX_BATCH_SIZE})`, 400);
        }

        // Validate and sanitize records before database operations
        const validDonors: DonorRecord[] = [];
        if (Array.isArray(body.donors) && body.donors.length > 0) {
          for (const rawDonor of body.donors) {
            const result = validateDonor(rawDonor);
            if (result.error) {
              return errorResponse(`Validation error in donor: ${result.error}`, 400);
            }
            validDonors.push(result.donor!);
          }
        }

        const validLogs: DonationLogRecord[] = [];
        if (Array.isArray(body.logs) && body.logs.length > 0) {
          for (const rawLog of body.logs) {
            const result = validateLog(rawLog);
            if (result.error) {
              return errorResponse(`Validation error in donation log: ${result.error}`, 400);
            }
            validLogs.push(result.log!);
          }
        }

        const validDeletedPhones: string[] = [];
        if (Array.isArray(body.deleted_phones) && body.deleted_phones.length > 0) {
          for (const rawPhone of body.deleted_phones) {
            const phone = normalizePhone(rawPhone);
            if (!phone) {
              return errorResponse(`Invalid phone number in deleted list: '${rawPhone}'`, 400);
            }
            validDeletedPhones.push(phone);
          }
        }

        const statements: D1PreparedStatement[] = [];

        // A. Process incoming deletions (Safe soft-delete without wiping historical donation logs)
        if (validDeletedPhones.length > 0) {
          for (const phone of validDeletedPhones) {
            statements.push(
              env.DB.prepare(
                "UPDATE donors SET is_deleted = 1, updated_at = ? WHERE phone = ?"
              ).bind(now, phone)
            );
          }
        }

        // B. Process incoming donors (Upsert with Last-Write-Wins on clamped updated_at)
        if (validDonors.length > 0) {
          for (const d of validDonors) {
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
                d.gender,
                d.phone,
                d.consent_to_share,
                d.district,
                d.area,
                d.last_donation_date,
                d.total_donations,
                d.notes,
                d.created_at,
                d.updated_at
              )
            );
          }
        }

        // C. Process incoming donation logs
        if (validLogs.length > 0) {
          for (const log of validLogs) {
            statements.push(
              env.DB.prepare(`
                INSERT INTO donation_logs (donor_phone, donation_date, created_at)
                VALUES (?, ?, ?)
                ON CONFLICT(donor_phone, donation_date) DO NOTHING
              `).bind(log.donor_phone, log.donation_date, log.created_at)
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
