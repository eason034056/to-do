import { initializeApp } from "firebase-admin/app";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { MulticastMessage, getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";

initializeApp();
const db = getFirestore();
const publicCallableOptions = { invoker: "public" as const };

type ClockTime = { hour: number; minute: number };

type ReminderConfig = {
  planningReminderTime: ClockTime;
  planningCutoffTime: ClockTime;
  planningEscalationEveryMinutes: number;
  dailySettlementTime: ClockTime;
  dailySettlementGraceMinutes: number;
};

type PenaltyPolicy = {
  mode: "flat_per_day";
  amount: number;
  currency: string;
  enabled: boolean;
  planningMissPenaltyEnabled: boolean;
};

type ParsedTaskInput = {
  id: string;
  title: string;
  notes: string | null;
  bucket: "required" | "optional";
  priority: "p0" | "p1" | "p2" | "p3";
  status: "pending" | "completed" | "missed" | "carriedOver";
  sortOrder: number;
  completedAtClient: Date | null;
  carriedFromTaskId: string | null;
  deleted: boolean;
};

type NotificationPrefs = {
  planningReminderEnabled: boolean;
  settlementReminderEnabled: boolean;
  timeSensitiveAllowed: boolean;
};

const defaultReminderConfig: ReminderConfig = {
  planningReminderTime: { hour: 21, minute: 30 },
  planningCutoffTime: { hour: 23, minute: 0 },
  planningEscalationEveryMinutes: 15,
  dailySettlementTime: { hour: 23, minute: 59 },
  dailySettlementGraceMinutes: 5,
};

const defaultPenaltyPolicy: PenaltyPolicy = {
  mode: "flat_per_day",
  amount: 50,
  currency: "USD",
  enabled: true,
  planningMissPenaltyEnabled: false,
};

const dateKeyPattern = /^\d{4}-\d{2}-\d{2}$/;
const rewardTextMaxLength = 200;

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null;

const requireAuthUid = (request: unknown): string => {
  if (!isRecord(request)) {
    throw new HttpsError("unauthenticated", "unauthenticated");
  }
  const auth = request.auth;
  if (!isRecord(auth) || typeof auth.uid !== "string" || auth.uid.trim().length === 0) {
    throw new HttpsError("unauthenticated", "unauthenticated");
  }
  return auth.uid.trim();
};

const asString = (value: unknown): string | undefined => (typeof value === "string" ? value : undefined);

const asFiniteNumber = (value: unknown): number | undefined => {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }
  return undefined;
};

const asBoolean = (value: unknown, fallback: boolean): boolean =>
  typeof value === "boolean" ? value : fallback;

const asStringArray = (value: unknown): string[] =>
  Array.isArray(value) ? value.filter((entry): entry is string => typeof entry === "string") : [];

const asDate = (value: unknown): Date | null => {
  if (value instanceof Date) {
    return value;
  }
  if (value instanceof Timestamp) {
    return value.toDate();
  }
  if (typeof value === "string") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
};

const asStringMap = (value: unknown): Record<string, string> => {
  if (!isRecord(value)) return {};
  const map: Record<string, string> = {};
  for (const [key, item] of Object.entries(value)) {
    if (typeof item === "string") {
      map[key] = item;
    }
  }
  return map;
};

const asBoolMap = (value: unknown): Record<string, boolean> => {
  if (!isRecord(value)) return {};
  const map: Record<string, boolean> = {};
  for (const [key, item] of Object.entries(value)) {
    if (typeof item === "boolean") {
      map[key] = item;
    }
  }
  return map;
};

const normalizeWeekStartsOn = (value: unknown): "monday" | "sunday" =>
  value === "sunday" ? "sunday" : "monday";

const parseClock = (value: unknown, fallback: ClockTime): ClockTime => {
  if (!isRecord(value)) return fallback;
  return {
    hour: asFiniteNumber(value.hour) ?? fallback.hour,
    minute: asFiniteNumber(value.minute) ?? fallback.minute,
  };
};

const parseReminderConfig = (value: unknown): ReminderConfig => {
  if (!isRecord(value)) return defaultReminderConfig;
  return {
    planningReminderTime: parseClock(value.planningReminderTime, defaultReminderConfig.planningReminderTime),
    planningCutoffTime: parseClock(value.planningCutoffTime, defaultReminderConfig.planningCutoffTime),
    planningEscalationEveryMinutes:
      asFiniteNumber(value.planningEscalationEveryMinutes) ?? defaultReminderConfig.planningEscalationEveryMinutes,
    dailySettlementTime: parseClock(value.dailySettlementTime, defaultReminderConfig.dailySettlementTime),
    dailySettlementGraceMinutes:
      asFiniteNumber(value.dailySettlementGraceMinutes) ?? defaultReminderConfig.dailySettlementGraceMinutes,
  };
};

const parsePenaltyPolicy = (value: unknown): PenaltyPolicy => {
  if (!isRecord(value)) return defaultPenaltyPolicy;
  return {
    mode: "flat_per_day",
    amount: asFiniteNumber(value.amount) ?? defaultPenaltyPolicy.amount,
    currency: (asString(value.currency) ?? defaultPenaltyPolicy.currency).toUpperCase(),
    enabled: asBoolean(value.enabled, defaultPenaltyPolicy.enabled),
    planningMissPenaltyEnabled: asBoolean(
      value.planningMissPenaltyEnabled,
      defaultPenaltyPolicy.planningMissPenaltyEnabled,
    ),
  };
};

const validateCreatePolicyOrThrow = (config: ReminderConfig, penalty: PenaltyPolicy): void => {
  const isValidClock = (clock: ClockTime) =>
    Number.isInteger(clock.hour) &&
    Number.isInteger(clock.minute) &&
    clock.hour >= 0 &&
    clock.hour <= 23 &&
    clock.minute >= 0 &&
    clock.minute <= 59;

  const reminderMinutes = config.planningReminderTime.hour * 60 + config.planningReminderTime.minute;
  const cutoffMinutes = config.planningCutoffTime.hour * 60 + config.planningCutoffTime.minute;

  const isConfigValid =
    isValidClock(config.planningReminderTime) &&
    isValidClock(config.planningCutoffTime) &&
    isValidClock(config.dailySettlementTime) &&
    reminderMinutes <= cutoffMinutes &&
    Number.isInteger(config.planningEscalationEveryMinutes) &&
    config.planningEscalationEveryMinutes > 0 &&
    config.planningEscalationEveryMinutes <= 180 &&
    Number.isInteger(config.dailySettlementGraceMinutes) &&
    config.dailySettlementGraceMinutes >= 0 &&
    config.dailySettlementGraceMinutes <= 180;

  const currencyValid = /^[A-Z]{3}$/.test(penalty.currency);
  const penaltyValid = Number.isFinite(penalty.amount) && penalty.amount >= 0 && currencyValid;

  if (!isConfigValid || !penaltyValid) {
    throw new HttpsError("invalid-argument", "invalid_policy");
  }
};

const isValidTimezone = (timezone: string): boolean => {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: timezone }).format(new Date());
    return true;
  } catch {
    return false;
  }
};

const normalizeTimezone = (timezone: unknown, fallback = "UTC"): string => {
  if (typeof timezone !== "string") return fallback;
  return isValidTimezone(timezone) ? timezone : fallback;
};

const pad2 = (value: number): string => String(value).padStart(2, "0");

const parseDateKey = (dateKey: string): { year: number; month: number; day: number } | null => {
  if (!dateKeyPattern.test(dateKey)) return null;
  const [yearRaw, monthRaw, dayRaw] = dateKey.split("-");
  const year = Number(yearRaw);
  const month = Number(monthRaw);
  const day = Number(dayRaw);
  if (!Number.isInteger(year) || !Number.isInteger(month) || !Number.isInteger(day)) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return { year, month, day };
};

const formatDateKey = (year: number, month: number, day: number): string => `${year}-${pad2(month)}-${pad2(day)}`;

const addDaysToDateKey = (dateKey: string, days: number): string => {
  const parsed = parseDateKey(dateKey);
  if (!parsed) return dateKey;
  const date = new Date(Date.UTC(parsed.year, parsed.month - 1, parsed.day));
  date.setUTCDate(date.getUTCDate() + days);
  return formatDateKey(date.getUTCFullYear(), date.getUTCMonth() + 1, date.getUTCDate());
};

const getTimezoneOffsetMinutes = (timezone: string, date: Date): number => {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    timeZoneName: "shortOffset",
  });
  const tzPart = formatter.formatToParts(date).find((part) => part.type === "timeZoneName")?.value ?? "GMT";
  if (tzPart === "GMT" || tzPart === "UTC") {
    return 0;
  }
  const match = tzPart.match(/(?:GMT|UTC)([+-])(\d{1,2})(?::?(\d{2}))?$/);
  if (!match) {
    return 0;
  }
  const sign = match[1] === "-" ? -1 : 1;
  const hour = Number(match[2]);
  const minute = Number(match[3] ?? "0");
  return sign * (hour * 60 + minute);
};

const localPartsFromUtc = (
  date: Date,
  timezone: string,
): { year: number; month: number; day: number; hour: number; minute: number } => {
  const offset = getTimezoneOffsetMinutes(timezone, date);
  const local = new Date(date.getTime() + offset * 60_000);
  return {
    year: local.getUTCFullYear(),
    month: local.getUTCMonth() + 1,
    day: local.getUTCDate(),
    hour: local.getUTCHours(),
    minute: local.getUTCMinutes(),
  };
};

const dateKeyForTimezone = (date: Date, timezone: string): string => {
  const local = localPartsFromUtc(date, timezone);
  return formatDateKey(local.year, local.month, local.day);
};

const localMinutesForTimezone = (date: Date, timezone: string): number => {
  const local = localPartsFromUtc(date, timezone);
  return local.hour * 60 + local.minute;
};

const localDateTimeToUtc = (dateKey: string, time: ClockTime, timezone: string): Date => {
  const parsed = parseDateKey(dateKey);
  if (!parsed) return new Date();

  let utcMillis = Date.UTC(parsed.year, parsed.month - 1, parsed.day, time.hour, time.minute, 0, 0);
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const offsetMinutes = getTimezoneOffsetMinutes(timezone, new Date(utcMillis));
    const candidate = Date.UTC(parsed.year, parsed.month - 1, parsed.day, time.hour, time.minute, 0, 0) - offsetMinutes * 60_000;
    if (candidate === utcMillis) break;
    utcMillis = candidate;
  }
  return new Date(utcMillis);
};

const isoWeekKeyForDateKey = (dateKey: string): string => {
  const parsed = parseDateKey(dateKey);
  if (!parsed) return "1970-W01";

  const date = new Date(Date.UTC(parsed.year, parsed.month - 1, parsed.day));
  let weekday = date.getUTCDay();
  if (weekday === 0) weekday = 7;
  date.setUTCDate(date.getUTCDate() + 4 - weekday);
  const year = date.getUTCFullYear();
  const yearStart = new Date(Date.UTC(year, 0, 1));
  const week = Math.ceil(((date.getTime() - yearStart.getTime()) / 86_400_000 + 1) / 7);
  return `${year}-W${pad2(week)}`;
};

const weekStartDateKey = (dateKey: string, weekStartsOn: "monday" | "sunday"): string => {
  const parsed = parseDateKey(dateKey);
  if (!parsed) return dateKey;
  const date = new Date(Date.UTC(parsed.year, parsed.month - 1, parsed.day));
  const weekday = date.getUTCDay();
  const delta = weekStartsOn === "monday" ? (weekday + 6) % 7 : weekday;
  date.setUTCDate(date.getUTCDate() - delta);
  return formatDateKey(date.getUTCFullYear(), date.getUTCMonth() + 1, date.getUTCDate());
};

const randomInviteCode = (): string =>
  Math.random().toString(36).replace(/[^A-Z0-9]+/gi, "").toUpperCase().slice(0, 6);

const generateInviteCode = async (): Promise<string> => {
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const inviteCode = randomInviteCode();
    if (inviteCode.length < 6) continue;
    const existing = await db.collection("couples").where("inviteCode", "==", inviteCode).limit(1).get();
    if (existing.empty) return inviteCode;
  }
  throw new HttpsError("internal", "invite_code_generation_failed");
};

const sanitizeEventPayload = (payload: Record<string, unknown>): Record<string, string> => {
  const out: Record<string, string> = {};
  for (const [key, value] of Object.entries(payload)) {
    if (typeof value === "string") out[key] = value;
    else if (typeof value === "number" || typeof value === "boolean") out[key] = String(value);
  }
  return out;
};

const makeNotificationPrefs = (userData: Record<string, unknown>): NotificationPrefs => {
  const raw = isRecord(userData.notificationPreferences) ? userData.notificationPreferences : {};
  return {
    planningReminderEnabled: asBoolean(raw.planningReminderEnabled, true),
    settlementReminderEnabled: asBoolean(raw.settlementReminderEnabled, true),
    timeSensitiveAllowed: asBoolean(raw.timeSensitiveAllowed, true),
  };
};

const reserveDedupeKey = async (
  dedupeKey: string,
  jobType: string,
  metadata: Record<string, unknown>,
): Promise<boolean> => {
  const ref = db.collection("_jobDedupe").doc(dedupeKey);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (snapshot.exists) {
      return false;
    }
    transaction.set(ref, {
      key: dedupeKey,
      jobType,
      metadata: sanitizeEventPayload(metadata),
      status: "reserved",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return true;
  });
};

type PushRequest = {
  userId: string;
  jobType: string;
  dedupeKey: string;
  category: string;
  title: string;
  body: string;
  timeSensitive: boolean;
  data: Record<string, string>;
};

const sendPushIfPossible = async (request: PushRequest): Promise<boolean> => {
  const reserved = await reserveDedupeKey(request.dedupeKey, request.jobType, {
    userId: request.userId,
    category: request.category,
  });
  if (!reserved) return false;

  const dedupeRef = db.collection("_jobDedupe").doc(request.dedupeKey);
  const installations = await db.collection("deviceInstallations").where("userId", "==", request.userId).get();
  const tokens = [...new Set(installations.docs.map((doc) => asString(doc.get("fcmToken"))).filter((item): item is string => !!item))];

  if (tokens.length === 0) {
    await dedupeRef.set(
      {
        status: "skipped_no_token",
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return false;
  }

  const message: MulticastMessage = {
    tokens,
    notification: {
      title: request.title,
      body: request.body,
    },
    data: {
      ...request.data,
      category: request.category,
    },
    apns: {
      headers: {
        "apns-push-type": "alert",
        "apns-priority": "10",
      },
      payload: {
        aps: {
          category: request.category,
          sound: "default",
          ...(request.timeSensitive ? { "interruption-level": "time-sensitive" } : {}),
        },
      },
    },
  };

  try {
    const result = await getMessaging().sendEachForMulticast(message);
    await dedupeRef.set(
      {
        status: "sent",
        successCount: result.successCount,
        failureCount: result.failureCount,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    if (result.failureCount > 0) {
      logger.warn("push partial failure", {
        dedupeKey: request.dedupeKey,
        failureCount: result.failureCount,
      });
    }
    return result.successCount > 0;
  } catch (error) {
    await dedupeRef.set(
      {
        status: "failed",
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    logger.error("push send failed", {
      dedupeKey: request.dedupeKey,
      error: error instanceof Error ? error.message : String(error),
    });
    return false;
  }
};

const parseTaskInput = (
  value: unknown,
  index: number,
  uid: string,
  targetDateKey: string,
  timezone: string,
): ParsedTaskInput => {
  if (!isRecord(value)) {
    throw new HttpsError("invalid-argument", "empty_tasks");
  }

  const id = asString(value.id)?.trim();
  if (!id) {
    throw new HttpsError("invalid-argument", "empty_tasks");
  }

  const ownerUserId = asString(value.ownerUserId)?.trim();
  if (ownerUserId && ownerUserId !== uid) {
    throw new HttpsError("permission-denied", "forbidden");
  }

  const dateKey = asString(value.dateKey)?.trim();
  if (dateKey && dateKey !== targetDateKey) {
    throw new HttpsError("invalid-argument", "date_mismatch");
  }

  const taskTimezone = asString(value.localTimezone)?.trim();
  if (taskTimezone && normalizeTimezone(taskTimezone) !== normalizeTimezone(timezone)) {
    throw new HttpsError("invalid-argument", "date_mismatch");
  }

  const title = asString(value.title)?.trim() ?? "";
  if (title.length === 0) {
    throw new HttpsError("invalid-argument", "empty_tasks");
  }

  const bucket = asString(value.bucket) === "optional" ? "optional" : "required";
  const priorityRaw = asString(value.priority);
  const priority: ParsedTaskInput["priority"] =
    priorityRaw === "p0" || priorityRaw === "p1" || priorityRaw === "p2" || priorityRaw === "p3" ? priorityRaw : "p1";
  const statusRaw = asString(value.status);
  const status: ParsedTaskInput["status"] =
    statusRaw === "completed" || statusRaw === "missed" || statusRaw === "carriedOver" || statusRaw === "pending"
      ? statusRaw
      : "pending";
  const sortOrder = asFiniteNumber(value.sortOrder) ?? index;
  const completedAtClient = asDate(value.completedAtClient);
  const carriedFromTaskId = asString(value.carriedFromTaskId)?.trim() ?? null;
  const notes = asString(value.notes) ?? null;
  const deleted = asBoolean(value.deleted, false);

  return {
    id,
    title,
    notes,
    bucket,
    priority,
    status,
    sortOrder,
    completedAtClient,
    carriedFromTaskId,
    deleted,
  };
};

export const createCouple = onCall(publicCallableOptions, async (request) => {
  const uid = requireAuthUid(request);
  const data = isRecord(request.data) ? request.data : {};

  const weekStartsOn = normalizeWeekStartsOn(data.weekStartsOn);
  const reminderConfig = parseReminderConfig(data.reminderConfig);
  const penaltyPolicy = parsePenaltyPolicy(data.penaltyPolicy);
  validateCreatePolicyOrThrow(reminderConfig, penaltyPolicy);

  const displayName = asString(data.displayName)?.trim();
  const inviteCode = await generateInviteCode();
  const coupleRef = db.collection("couples").doc();

  const result = await db.runTransaction(async (transaction) => {
    const userRef = db.doc(`users/${uid}`);
    const userSnapshot = await transaction.get(userRef);
    const existingCoupleId = asString(userSnapshot.get("coupleId"));

    if (existingCoupleId) {
      throw new HttpsError("failed-precondition", "already_paired");
    }

    transaction.set(
      coupleRef,
      {
        id: coupleRef.id,
        memberIds: [uid],
        status: "pending",
        weekStartsOn,
        penaltyPolicy,
        reminderConfig,
        inviteCode,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const userPayload: Record<string, unknown> = {
      id: uid,
      coupleId: coupleRef.id,
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (displayName && displayName.length > 0) {
      userPayload.displayName = displayName;
    }
    transaction.set(userRef, userPayload, { merge: true });

    return {
      coupleId: coupleRef.id,
      memberIds: [uid],
      status: "pending",
      inviteCode,
    };
  });

  logger.info("createCouple callable completed", { uid, coupleId: result.coupleId });
  return result;
});

export const joinCouple = onCall(publicCallableOptions, async (request) => {
  const uid = requireAuthUid(request);
  const data = isRecord(request.data) ? request.data : {};
  const inviteCode = (asString(data.inviteCode) ?? "").trim().toUpperCase();
  if (!inviteCode) {
    throw new HttpsError("invalid-argument", "invite_not_found");
  }

  const lookup = await db.collection("couples").where("inviteCode", "==", inviteCode).limit(1).get();
  if (lookup.empty) {
    throw new HttpsError("not-found", "invite_not_found");
  }
  const coupleRef = lookup.docs[0].ref;

  const result = await db.runTransaction(async (transaction) => {
    const userRef = db.doc(`users/${uid}`);
    const userSnapshot = await transaction.get(userRef);
    const coupleSnapshot = await transaction.get(coupleRef);
    if (!coupleSnapshot.exists) {
      throw new HttpsError("not-found", "invite_not_found");
    }

    const userCoupleId = asString(userSnapshot.get("coupleId"));
    const memberIds = asStringArray(coupleSnapshot.get("memberIds"));

    if (userCoupleId && userCoupleId !== coupleRef.id) {
      throw new HttpsError("failed-precondition", "already_paired");
    }
    if (!memberIds.includes(uid) && memberIds.length >= 2) {
      throw new HttpsError("failed-precondition", "couple_full");
    }

    const updatedMemberIds = memberIds.includes(uid) ? memberIds : [...memberIds, uid];
    const status = updatedMemberIds.length >= 2 ? "active" : "pending";

    transaction.set(
      coupleRef,
      {
        memberIds: updatedMemberIds,
        status,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    transaction.set(
      userRef,
      {
        id: uid,
        coupleId: coupleRef.id,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return {
      coupleId: coupleRef.id,
      memberIds: updatedMemberIds,
      status,
      inviteCode,
    };
  });

  logger.info("joinCouple callable completed", { uid, coupleId: result.coupleId });
  return result;
});

export const submitPlan = onCall(publicCallableOptions, async (request) => {
  const uid = requireAuthUid(request);
  const data = isRecord(request.data) ? request.data : {};
  const coupleId = (asString(data.coupleId) ?? "").trim();
  const targetDateKey = (asString(data.targetDateKey) ?? "").trim();
  const timezoneRaw = (asString(data.timezone) ?? "").trim();
  const timezone = normalizeTimezone(timezoneRaw, "");
  const noRequiredTasksConfirmed = asBoolean(data.noRequiredTasksConfirmed, false);
  const rawTasks = Array.isArray(data.tasks) ? data.tasks : [];

  if (!coupleId) throw new HttpsError("permission-denied", "forbidden");
  if (!targetDateKey || !dateKeyPattern.test(targetDateKey)) {
    throw new HttpsError("invalid-argument", "date_mismatch");
  }
  if (!timezone) {
    throw new HttpsError("invalid-argument", "date_mismatch");
  }
  if (rawTasks.length === 0) {
    throw new HttpsError("invalid-argument", "empty_tasks");
  }

  const tasks = rawTasks.map((item, index) => parseTaskInput(item, index, uid, targetDateKey, timezone));
  const hasRequiredTask = tasks.some((task) => task.bucket === "required" && !task.deleted);
  if (!hasRequiredTask && !noRequiredTasksConfirmed) {
    throw new HttpsError("failed-precondition", "empty_tasks");
  }

  const now = new Date();
  const nowDateKey = dateKeyForTimezone(now, timezone);
  const expectedTargetDateKey = addDaysToDateKey(nowDateKey, 1);
  if (targetDateKey !== expectedTargetDateKey) {
    throw new HttpsError("invalid-argument", "date_mismatch");
  }

  const coupleRef = db.doc(`couples/${coupleId}`);
  const planId = `${uid}_${targetDateKey}`;
  const planRef = db.doc(`couples/${coupleId}/plans/${planId}`);
  const tasksCollection = db.collection(`couples/${coupleId}/plans/${planId}/tasks`);

  const transactionResult = await db.runTransaction(async (transaction) => {
    const [coupleSnapshot, planSnapshot] = await Promise.all([transaction.get(coupleRef), transaction.get(planRef)]);
    if (!coupleSnapshot.exists) {
      throw new HttpsError("permission-denied", "forbidden");
    }

    const memberIds = asStringArray(coupleSnapshot.get("memberIds"));
    if (!memberIds.includes(uid)) {
      throw new HttpsError("permission-denied", "forbidden");
    }

    const reminderConfig = parseReminderConfig(coupleSnapshot.get("reminderConfig"));
    const reminderBoundary = localDateTimeToUtc(nowDateKey, reminderConfig.planningReminderTime, timezone);
    const cutoffBoundary = localDateTimeToUtc(nowDateKey, reminderConfig.planningCutoffTime, timezone);
    const startOfTargetDay = localDateTimeToUtc(targetDateKey, { hour: 0, minute: 0 }, timezone);

    const existingSubmittedAt = asDate(planSnapshot.get("submittedAt"));
    if (existingSubmittedAt) {
      if (now >= startOfTargetDay) {
        throw new HttpsError("failed-precondition", "invalid_window");
      }
    } else if (now < reminderBoundary || now > cutoffBoundary) {
      throw new HttpsError("failed-precondition", "invalid_window");
    }

    const requiredCount = tasks.filter((task) => task.bucket === "required" && !task.deleted).length;
    const optionalCount = tasks.filter((task) => task.bucket === "optional" && !task.deleted).length;
    const currentVersion = asFiniteNumber(planSnapshot.get("version")) ?? 0;
    const nextVersion = currentVersion + 1;
    const localOffsetMinutes = getTimezoneOffsetMinutes(timezone, now);

    transaction.set(
      planRef,
      {
        id: planId,
        userId: uid,
        coupleId,
        dateKey: targetDateKey,
        localTimezone: timezone,
        submittedAt: FieldValue.serverTimestamp(),
        planningMissed: false,
        localUtcOffsetMinutes: localOffsetMinutes,
        lastEditedAt: FieldValue.serverTimestamp(),
        requiredCount,
        optionalCount,
        version: nextVersion,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const eventRef = db.collection(`couples/${coupleId}/events`).doc();
    transaction.set(eventRef, {
      id: eventRef.id,
      coupleId,
      type: "plan_submitted",
      actorUserId: uid,
      subjectId: planId,
      payload: sanitizeEventPayload({
        dateKey: targetDateKey,
        requiredCount,
        optionalCount,
      }),
      createdAt: FieldValue.serverTimestamp(),
    });

    return { requiredCount, optionalCount };
  });

  const existingTasksSnapshot = await tasksCollection.get();
  const existingTasks = new Map<string, Record<string, unknown>>();
  for (const doc of existingTasksSnapshot.docs) {
    const data = doc.data();
    if (isRecord(data)) existingTasks.set(doc.id, data);
  }

  const retainedIds = new Set(tasks.map((task) => task.id));
  const batch = db.batch();

  for (const doc of existingTasksSnapshot.docs) {
    if (!retainedIds.has(doc.id)) {
      batch.delete(doc.ref);
    }
  }

  for (const task of tasks) {
    const taskRef = tasksCollection.doc(task.id);
    const existing = existingTasks.get(task.id);
    const existingCompletedAtServer = existing ? asDate(existing.completedAtServer) : null;
    const completedAtServerValue =
      task.status === "completed"
        ? existingCompletedAtServer
          ? Timestamp.fromDate(existingCompletedAtServer)
          : FieldValue.serverTimestamp()
        : FieldValue.delete();

    const payload: Record<string, unknown> = {
      id: task.id,
      ownerUserId: uid,
      dateKey: targetDateKey,
      localTimezone: timezone,
      title: task.title,
      notes: task.notes,
      bucket: task.bucket,
      priority: task.priority,
      status: task.status,
      sortOrder: task.sortOrder,
      localUtcOffsetMinutes: getTimezoneOffsetMinutes(timezone, now),
      completedAtClient: task.completedAtClient ? Timestamp.fromDate(task.completedAtClient) : null,
      completedAtServer: completedAtServerValue,
      carriedFromTaskId: task.carriedFromTaskId,
      deleted: task.deleted,
      syncState: "synced",
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (!existing) {
      payload.createdAt = FieldValue.serverTimestamp();
    }
    batch.set(taskRef, payload, { merge: true });
  }

  await batch.commit();
  const submittedAt = new Date().toISOString();

  logger.info("submitPlan callable completed", {
    uid,
    coupleId,
    planId,
    taskCount: tasks.length,
  });

  return {
    planId,
    submittedAt,
    requiredCount: transactionResult.requiredCount,
    optionalCount: transactionResult.optionalCount,
  };
});

export const acknowledgeSettlement = onCall(publicCallableOptions, async (request) => {
  const uid = requireAuthUid(request);
  const data = isRecord(request.data) ? request.data : {};
  const coupleId = (asString(data.coupleId) ?? "").trim();
  const settlementId = (asString(data.settlementId) ?? "").trim();
  if (!coupleId || !settlementId) {
    throw new HttpsError("invalid-argument", "settlement_not_found");
  }

  const coupleRef = db.doc(`couples/${coupleId}`);
  const settlementRef = db.doc(`couples/${coupleId}/settlements/${settlementId}`);

  const result = await db.runTransaction(async (transaction) => {
    const [coupleSnapshot, settlementSnapshot] = await Promise.all([
      transaction.get(coupleRef),
      transaction.get(settlementRef),
    ]);

    if (!settlementSnapshot.exists) {
      throw new HttpsError("not-found", "settlement_not_found");
    }
    if (!coupleSnapshot.exists) {
      throw new HttpsError("permission-denied", "forbidden");
    }

    const memberIds = asStringArray(coupleSnapshot.get("memberIds"));
    if (!memberIds.includes(uid)) {
      throw new HttpsError("permission-denied", "forbidden");
    }

    const pending = asStringArray(settlementSnapshot.get("pendingAcknowledgementUserIds"));
    const nextPending = pending.filter((memberId) => memberId !== uid);
    if (nextPending.length !== pending.length) {
      transaction.set(
        settlementRef,
        {
          pendingAcknowledgementUserIds: nextPending,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

    const eventRef = db.collection(`couples/${coupleId}/events`).doc();
    transaction.set(eventRef, {
      id: eventRef.id,
      coupleId,
      type: "settlement_acknowledged",
      actorUserId: uid,
      subjectId: settlementId,
      payload: sanitizeEventPayload({ settlementId }),
      createdAt: FieldValue.serverTimestamp(),
    });

    return nextPending;
  });

  logger.info("acknowledgeSettlement callable completed", { uid, coupleId, settlementId });
  return {
    settlementId,
    pendingAcknowledgementUserIds: result,
  };
});

export const saveNextWeekReward = onCall(publicCallableOptions, async (request) => {
  const uid = requireAuthUid(request);
  const data = isRecord(request.data) ? request.data : {};
  const coupleId = (asString(data.coupleId) ?? "").trim();
  const rewardText = (asString(data.rewardText) ?? "").trim();
  if (!coupleId) throw new HttpsError("permission-denied", "forbidden");
  if (rewardText.length === 0 || rewardText.length > rewardTextMaxLength) {
    throw new HttpsError("invalid-argument", "invalid_text");
  }

  const userSnapshot = await db.doc(`users/${uid}`).get();
  const userData = userSnapshot.data() ?? {};
  const timezone = normalizeTimezone(isRecord(userData) ? userData.currentTimezone : undefined);
  const now = new Date();
  const currentDateKey = dateKeyForTimezone(now, timezone);
  const nextWeekDateKey = addDaysToDateKey(currentDateKey, 7);
  const currentWeekKey = isoWeekKeyForDateKey(currentDateKey);
  const weekKey = isoWeekKeyForDateKey(nextWeekDateKey);

  const coupleRef = db.doc(`couples/${coupleId}`);
  const rewardRef = db.doc(`couples/${coupleId}/rewardWeeks/${weekKey}`);

  const result = await db.runTransaction(async (transaction) => {
    const [coupleSnapshot, rewardSnapshot] = await Promise.all([
      transaction.get(coupleRef),
      transaction.get(rewardRef),
    ]);

    if (!coupleSnapshot.exists) {
      throw new HttpsError("permission-denied", "forbidden");
    }

    const coupleData = coupleSnapshot.data() ?? {};
    const memberIds = asStringArray(coupleData.memberIds);
    if (!memberIds.includes(uid)) {
      throw new HttpsError("permission-denied", "forbidden");
    }

    const existingStatus = asString(rewardSnapshot.get("status"));
    if (rewardSnapshot.exists && existingStatus !== "draft") {
      throw new HttpsError("failed-precondition", "reward_locked");
    }

    const weekStartsOn = normalizeWeekStartsOn(coupleData.weekStartsOn);
    const effectiveWeekStartDate = weekStartDateKey(nextWeekDateKey, weekStartsOn);
    const eligibility = rewardSnapshot.exists
      ? asBoolMap(rewardSnapshot.get("eligibility"))
      : Object.fromEntries(memberIds.map((memberId) => [memberId, true]));
    const memberLocalWeekKeys = rewardSnapshot.exists ? asStringMap(rewardSnapshot.get("memberLocalWeekKeys")) : {};

    transaction.set(
      rewardRef,
      {
        id: `${coupleId}_${weekKey}`,
        coupleId,
        weekKey,
        effectiveWeekStartDate,
        draftedInWeekKey: currentWeekKey,
        rewardText,
        status: "draft",
        eligibility,
        memberLocalWeekKeys,
        finalizeWhenBothMembersWeekClosed: true,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const eventRef = db.collection(`couples/${coupleId}/events`).doc();
    transaction.set(eventRef, {
      id: eventRef.id,
      coupleId,
      type: "weekly_reward_drafted",
      actorUserId: uid,
      subjectId: `${coupleId}_${weekKey}`,
      payload: sanitizeEventPayload({ weekKey }),
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      rewardWeekId: `${coupleId}_${weekKey}`,
      weekKey,
      status: "draft",
    };
  });

  logger.info("saveNextWeekReward callable completed", { uid, coupleId, weekKey });
  return result;
});

export const markPaymentPaid = onCall(publicCallableOptions, async (request) => {
  const uid = requireAuthUid(request);
  const data = isRecord(request.data) ? request.data : {};
  const coupleId = (asString(data.coupleId) ?? "").trim();
  const paymentRecordId = (asString(data.paymentRecordId) ?? "").trim();
  if (!coupleId || !paymentRecordId) {
    throw new HttpsError("not-found", "record_not_found");
  }

  const coupleRef = db.doc(`couples/${coupleId}`);
  const paymentRef = db.doc(`couples/${coupleId}/payments/${paymentRecordId}`);

  const result = await db.runTransaction(async (transaction) => {
    const [coupleSnapshot, paymentSnapshot] = await Promise.all([
      transaction.get(coupleRef),
      transaction.get(paymentRef),
    ]);

    if (!paymentSnapshot.exists) {
      throw new HttpsError("not-found", "record_not_found");
    }
    if (!coupleSnapshot.exists) {
      throw new HttpsError("permission-denied", "forbidden");
    }

    const memberIds = asStringArray(coupleSnapshot.get("memberIds"));
    if (!memberIds.includes(uid)) {
      throw new HttpsError("permission-denied", "forbidden");
    }

    const debtorUserId = asString(paymentSnapshot.get("debtorUserId"));
    if (debtorUserId !== uid) {
      throw new HttpsError("permission-denied", "forbidden");
    }
    const status = asString(paymentSnapshot.get("status")) ?? "pending";
    if (status !== "pending") {
      throw new HttpsError("failed-precondition", "invalid_state");
    }

    const alreadyMarkedBy = asString(paymentSnapshot.get("markedByUserId"));
    const alreadyMarkedAt = asDate(paymentSnapshot.get("markedPaidAt"));
    if (!(alreadyMarkedBy === uid && alreadyMarkedAt)) {
      transaction.set(
        paymentRef,
        {
          markedPaidAt: FieldValue.serverTimestamp(),
          markedByUserId: uid,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      const eventRef = db.collection(`couples/${coupleId}/events`).doc();
      transaction.set(eventRef, {
        id: eventRef.id,
        coupleId,
        type: "payment_marked_paid",
        actorUserId: uid,
        subjectId: paymentRecordId,
        payload: sanitizeEventPayload({ paymentRecordId }),
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    return { paymentRecordId, status };
  });

  const updatedPaymentSnapshot = await paymentRef.get();
  const markedPaidAt = asDate(updatedPaymentSnapshot.get("markedPaidAt")) ?? new Date();

  logger.info("markPaymentPaid callable completed", { uid, coupleId, paymentRecordId });
  return {
    paymentRecordId: result.paymentRecordId,
    status: result.status,
    markedPaidAt: markedPaidAt.toISOString(),
  };
});

const computeSettlementResult = (
  tasksSnapshot: FirebaseFirestore.QuerySnapshot<FirebaseFirestore.DocumentData>,
  cutoff: Date,
  penaltyPolicy: PenaltyPolicy,
): {
  requiredTotal: number;
  requiredCompleted: number;
  missedRequiredCount: number;
  outcome: "pass" | "fail";
  owesAmount: number;
} => {
  let requiredTotal = 0;
  let requiredCompleted = 0;

  for (const taskDoc of tasksSnapshot.docs) {
    const data = taskDoc.data();
    const bucket = asString(data.bucket) ?? "required";
    const deleted = asBoolean(data.deleted, false);
    if (bucket !== "required" || deleted) continue;

    requiredTotal += 1;
    const status = asString(data.status) ?? "pending";
    const completedAtServer = asDate(data.completedAtServer);
    if (status === "completed" && completedAtServer && completedAtServer <= cutoff) {
      requiredCompleted += 1;
    }
  }

  const missedRequiredCount = Math.max(0, requiredTotal - requiredCompleted);
  const outcome: "pass" | "fail" = missedRequiredCount === 0 ? "pass" : "fail";
  const owesAmount = outcome === "fail" && penaltyPolicy.enabled ? penaltyPolicy.amount : 0;

  return {
    requiredTotal,
    requiredCompleted,
    missedRequiredCount,
    outcome,
    owesAmount,
  };
};

const tryMarkPlanningMissed = async (
  userId: string,
  userTimezone: string,
  coupleId: string,
  planningDateKey: string,
  now: Date,
): Promise<boolean> => {
  const targetDateKey = addDaysToDateKey(planningDateKey, 1);
  const planId = `${userId}_${targetDateKey}`;
  const planRef = db.doc(`couples/${coupleId}/plans/${planId}`);
  const rewardWeekKey = isoWeekKeyForDateKey(planningDateKey);
  const rewardRef = db.doc(`couples/${coupleId}/rewardWeeks/${rewardWeekKey}`);

  return db.runTransaction(async (transaction) => {
    const [planSnapshot, rewardSnapshot] = await Promise.all([transaction.get(planRef), transaction.get(rewardRef)]);
    const submittedAt = asDate(planSnapshot.get("submittedAt"));
    const alreadyMissed = asBoolean(planSnapshot.get("planningMissed"), false);
    if (submittedAt || alreadyMissed) {
      return false;
    }

    const currentVersion = asFiniteNumber(planSnapshot.get("version")) ?? 0;
    transaction.set(
      planRef,
      {
        id: planId,
        userId,
        coupleId,
        dateKey: targetDateKey,
        localTimezone: userTimezone,
        submittedAt: null,
        planningMissed: true,
        localUtcOffsetMinutes: getTimezoneOffsetMinutes(userTimezone, now),
        lastEditedAt: FieldValue.serverTimestamp(),
        requiredCount: asFiniteNumber(planSnapshot.get("requiredCount")) ?? 0,
        optionalCount: asFiniteNumber(planSnapshot.get("optionalCount")) ?? 0,
        version: currentVersion + 1,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const eventRef = db.collection(`couples/${coupleId}/events`).doc();
    transaction.set(eventRef, {
      id: eventRef.id,
      coupleId,
      type: "planning_missed",
      actorUserId: userId,
      subjectId: planId,
      payload: sanitizeEventPayload({ dateKey: targetDateKey }),
      createdAt: FieldValue.serverTimestamp(),
    });

    if (rewardSnapshot.exists) {
      const rewardStatus = asString(rewardSnapshot.get("status")) ?? "draft";
      if (rewardStatus === "draft" || rewardStatus === "active") {
        const eligibility = asBoolMap(rewardSnapshot.get("eligibility"));
        const memberLocalWeekKeys = asStringMap(rewardSnapshot.get("memberLocalWeekKeys"));
        eligibility[userId] = false;
        memberLocalWeekKeys[userId] = rewardWeekKey;

        transaction.set(
          rewardRef,
          {
            eligibility,
            memberLocalWeekKeys,
            status: rewardStatus === "draft" ? "active" : rewardStatus,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }
    }

    return true;
  });
};

const maybeFinalizeSettlement = async (
  userId: string,
  coupleId: string,
  dateKey: string,
  timezone: string,
  reminderConfig: ReminderConfig,
  penaltyPolicy: PenaltyPolicy,
  memberIds: string[],
  now: Date,
): Promise<{ finalized: boolean; paymentRecordId: string | null }> => {
  const settlementId = `${userId}_${dateKey}`;
  const settlementRef = db.doc(`couples/${coupleId}/settlements/${settlementId}`);
  const existingSettlement = await settlementRef.get();
  if (existingSettlement.exists && asString(existingSettlement.get("state")) === "finalized") {
    return { finalized: false, paymentRecordId: null };
  }

  const counterpartyUserId = memberIds.find((memberId) => memberId !== userId) ?? "";
  if (!counterpartyUserId) return { finalized: false, paymentRecordId: null };

  const planId = `${userId}_${dateKey}`;
  const planRef = db.doc(`couples/${coupleId}/plans/${planId}`);
  const tasksCollection = db.collection(`couples/${coupleId}/plans/${planId}/tasks`);
  const rewardWeekKey = isoWeekKeyForDateKey(dateKey);
  const rewardRef = db.doc(`couples/${coupleId}/rewardWeeks/${rewardWeekKey}`);

  const cutoffBase = localDateTimeToUtc(dateKey, reminderConfig.dailySettlementTime, timezone);
  const cutoff = new Date(cutoffBase.getTime() + reminderConfig.dailySettlementGraceMinutes * 60_000);

  const [planSnapshot, tasksSnapshot, rewardSnapshot, counterpartySettlementSnapshot] = await Promise.all([
    planRef.get(),
    tasksCollection.get(),
    rewardRef.get(),
    db
      .collection(`couples/${coupleId}/settlements`)
      .where("subjectUserId", "==", counterpartyUserId)
      .orderBy("computedAt", "desc")
      .limit(1)
      .get(),
  ]);

  const result = computeSettlementResult(tasksSnapshot, cutoff, penaltyPolicy);
  const planningMissed = asBoolean(planSnapshot.get("planningMissed"), false);
  const latestCounterparty = counterpartySettlementSnapshot.docs[0];
  const latestCounterpartyDateKey = latestCounterparty ? asString(latestCounterparty.get("dateKey")) : undefined;
  const latestCounterpartyOutcome = latestCounterparty
    ? asString(isRecord(latestCounterparty.get("subjectResult")) ? latestCounterparty.get("subjectResult").outcome : undefined)
    : undefined;

  let rewardImpact: Record<string, unknown> | null = null;
  let rewardUpdate: Record<string, unknown> | null = null;

  if (rewardSnapshot.exists) {
    const rewardStatus = asString(rewardSnapshot.get("status")) ?? "draft";
    const eligibility = asBoolMap(rewardSnapshot.get("eligibility"));
    const memberLocalWeekKeys = asStringMap(rewardSnapshot.get("memberLocalWeekKeys"));
    const stillEligible = result.outcome === "pass" && !planningMissed && (eligibility[userId] ?? true);
    eligibility[userId] = stillEligible;
    memberLocalWeekKeys[userId] = rewardWeekKey;
    rewardImpact = {
      weekKey: rewardWeekKey,
      stillEligible,
    };
    rewardUpdate = {
      eligibility,
      memberLocalWeekKeys,
      status: rewardStatus === "draft" ? "active" : rewardStatus,
      updatedAt: FieldValue.serverTimestamp(),
    };
  }

  const paymentRecordId = result.owesAmount > 0 ? settlementId : null;
  const paymentRef = paymentRecordId ? db.doc(`couples/${coupleId}/payments/${paymentRecordId}`) : null;

  const finalized = await db.runTransaction(async (transaction) => {
    const settlementSnapshot = await transaction.get(settlementRef);
    if (settlementSnapshot.exists && asString(settlementSnapshot.get("state")) === "finalized") {
      return false;
    }

    transaction.set(
      settlementRef,
      {
        id: settlementId,
        coupleId,
        subjectUserId: userId,
        counterpartyUserId,
        dateKey,
        localTimezone: timezone,
        localWeekKey: rewardWeekKey,
        state: "finalized",
        computedAt: FieldValue.serverTimestamp(),
        graceAppliedUntil: Timestamp.fromDate(cutoff),
        subjectResult: {
          requiredTotal: result.requiredTotal,
          requiredCompleted: result.requiredCompleted,
          missedRequiredCount: result.missedRequiredCount,
          outcome: result.outcome,
          owesAmount: result.owesAmount,
        },
        counterpartySnapshot: {
          latestKnownDateKey: latestCounterpartyDateKey ?? null,
          latestKnownOutcome: latestCounterpartyOutcome ?? null,
        },
        pendingAcknowledgementUserIds: memberIds,
        rewardImpact: rewardImpact ?? null,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const eventRef = db.collection(`couples/${coupleId}/events`).doc();
    transaction.set(eventRef, {
      id: eventRef.id,
      coupleId,
      type: "settlement_finalized",
      actorUserId: "system",
      subjectId: settlementId,
      payload: sanitizeEventPayload({ dateKey, subjectUserId: userId }),
      createdAt: FieldValue.serverTimestamp(),
    });

    if (rewardUpdate) {
      transaction.set(rewardRef, rewardUpdate, { merge: true });
    }

    if (paymentRef && paymentRecordId) {
      transaction.set(
        paymentRef,
        {
          id: paymentRecordId,
          coupleId,
          debtorUserId: userId,
          creditorUserId: counterpartyUserId,
          sourceSettlementId: settlementId,
          sourceDateKey: dateKey,
          amount: result.owesAmount,
          currency: penaltyPolicy.currency,
          status: "pending",
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

    return true;
  });

  return {
    finalized,
    paymentRecordId: finalized ? paymentRecordId : null,
  };
};

export const planningReminderJob = onSchedule("every 5 minutes", async () => {
  const now = new Date();
  const usersSnapshot = await db.collection("users").get();
  const coupleCache = new Map<string, Record<string, unknown> | null>();
  let sent = 0;
  let scanned = 0;

  for (const userDoc of usersSnapshot.docs) {
    scanned += 1;
    const userData = userDoc.data();
    const uid = userDoc.id;
    const coupleId = asString(userData.coupleId);
    if (!coupleId) continue;

    const prefs = makeNotificationPrefs(userData);
    if (!prefs.planningReminderEnabled) continue;

    const timezone = normalizeTimezone(userData.currentTimezone);
    const localDateKey = dateKeyForTimezone(now, timezone);

    let coupleData = coupleCache.get(coupleId) ?? null;
    if (coupleData === null && !coupleCache.has(coupleId)) {
      const coupleSnapshot = await db.doc(`couples/${coupleId}`).get();
      coupleData = (coupleSnapshot.data() as Record<string, unknown> | undefined) ?? null;
      coupleCache.set(coupleId, coupleData);
    }
    if (!coupleData) continue;

    const memberIds = asStringArray(coupleData.memberIds);
    if (!memberIds.includes(uid)) continue;
    const reminderConfig = parseReminderConfig(coupleData.reminderConfig);
    const reminderMinutes =
      reminderConfig.planningReminderTime.hour * 60 + reminderConfig.planningReminderTime.minute;
    const cutoffMinutes = reminderConfig.planningCutoffTime.hour * 60 + reminderConfig.planningCutoffTime.minute;
    const localMinutes = localMinutesForTimezone(now, timezone);
    if (localMinutes < reminderMinutes || localMinutes > cutoffMinutes) continue;

    const targetDateKey = addDaysToDateKey(localDateKey, 1);
    const planId = `${uid}_${targetDateKey}`;
    const planSnapshot = await db.doc(`couples/${coupleId}/plans/${planId}`).get();
    if (asDate(planSnapshot.get("submittedAt"))) continue;
    if (asBoolean(planSnapshot.get("planningMissed"), false)) continue;

    const escalationEvery = Math.max(1, reminderConfig.planningEscalationEveryMinutes);
    const bucket = Math.floor((localMinutes - reminderMinutes) / escalationEvery);
    const category = bucket === 0 ? "planning_reminder" : "planning_escalation";
    const pushSent = await sendPushIfPossible({
      userId: uid,
      jobType: "planningReminderJob",
      dedupeKey: `planning_${uid}_${targetDateKey}_${bucket}`,
      category,
      title: "Tomorrow plan reminder",
      body: "Fill out tomorrow's plan before cutoff.",
      timeSensitive: prefs.timeSensitiveAllowed,
      data: {
        coupleId,
        dateKey: targetDateKey,
        deepLink: `coupletodo://planning/${targetDateKey}`,
      },
    });
    if (pushSent) sent += 1;
  }

  logger.info("planningReminderJob completed", { scannedUsers: scanned, pushesSent: sent });
});

export const planningMissJob = onSchedule("every 5 minutes", async () => {
  const now = new Date();
  const usersSnapshot = await db.collection("users").get();
  const coupleCache = new Map<string, Record<string, unknown> | null>();
  let updatedPlans = 0;

  for (const userDoc of usersSnapshot.docs) {
    const userData = userDoc.data();
    const uid = userDoc.id;
    const coupleId = asString(userData.coupleId);
    if (!coupleId) continue;

    let coupleData = coupleCache.get(coupleId) ?? null;
    if (coupleData === null && !coupleCache.has(coupleId)) {
      const snapshot = await db.doc(`couples/${coupleId}`).get();
      coupleData = (snapshot.data() as Record<string, unknown> | undefined) ?? null;
      coupleCache.set(coupleId, coupleData);
    }
    if (!coupleData) continue;
    if ((asString(coupleData.status) ?? "pending") !== "active") continue;

    const memberIds = asStringArray(coupleData.memberIds);
    if (!memberIds.includes(uid)) continue;

    const reminderConfig = parseReminderConfig(coupleData.reminderConfig);
    const timezone = normalizeTimezone(userData.currentTimezone);
    const todayDateKey = dateKeyForTimezone(now, timezone);
    const candidatePlanningDates = [todayDateKey, addDaysToDateKey(todayDateKey, -1)];

    for (const planningDateKey of candidatePlanningDates) {
      const cutoffAt = localDateTimeToUtc(planningDateKey, reminderConfig.planningCutoffTime, timezone);
      if (now < cutoffAt) continue;
      const changed = await tryMarkPlanningMissed(uid, timezone, coupleId, planningDateKey, now);
      if (changed) updatedPlans += 1;
    }
  }

  logger.info("planningMissJob completed", { updatedPlans });
});

export const dailySettlementJob = onSchedule("every 5 minutes", async () => {
  const now = new Date();
  const usersSnapshot = await db.collection("users").get();
  const coupleCache = new Map<string, Record<string, unknown> | null>();
  let finalizedCount = 0;
  let paymentCount = 0;

  for (const userDoc of usersSnapshot.docs) {
    const userData = userDoc.data();
    const uid = userDoc.id;
    const coupleId = asString(userData.coupleId);
    if (!coupleId) continue;

    let coupleData = coupleCache.get(coupleId) ?? null;
    if (coupleData === null && !coupleCache.has(coupleId)) {
      const snapshot = await db.doc(`couples/${coupleId}`).get();
      coupleData = (snapshot.data() as Record<string, unknown> | undefined) ?? null;
      coupleCache.set(coupleId, coupleData);
    }
    if (!coupleData) continue;
    if ((asString(coupleData.status) ?? "pending") !== "active") continue;

    const memberIds = asStringArray(coupleData.memberIds);
    if (!memberIds.includes(uid) || memberIds.length < 2) continue;

    const timezone = normalizeTimezone(userData.currentTimezone);
    const reminderConfig = parseReminderConfig(coupleData.reminderConfig);
    const penaltyPolicy = parsePenaltyPolicy(coupleData.penaltyPolicy);
    const localDateKey = dateKeyForTimezone(now, timezone);
    const candidateDateKeys = [localDateKey, addDaysToDateKey(localDateKey, -1)];

    for (const targetDateKey of candidateDateKeys) {
      const triggerAtBase = localDateTimeToUtc(targetDateKey, reminderConfig.dailySettlementTime, timezone);
      const triggerAt = new Date(triggerAtBase.getTime() + reminderConfig.dailySettlementGraceMinutes * 60_000);
      if (now < triggerAt) continue;

      const finalized = await maybeFinalizeSettlement(
        uid,
        coupleId,
        targetDateKey,
        timezone,
        reminderConfig,
        penaltyPolicy,
        memberIds,
        now,
      );
      if (!finalized.finalized) continue;

      finalizedCount += 1;
      const settlementId = `${uid}_${targetDateKey}`;
      for (const memberId of memberIds) {
        const memberSnapshot = await db.doc(`users/${memberId}`).get();
        const memberData = memberSnapshot.data() ?? {};
        const memberPrefs = makeNotificationPrefs(memberData as Record<string, unknown>);
        if (!memberPrefs.settlementReminderEnabled) continue;
        await sendPushIfPossible({
          userId: memberId,
          jobType: "dailySettlementJob",
          dedupeKey: `settlement_${memberId}_${settlementId}`,
          category: "settlement_ready",
          title: "Settlement ready",
          body: "Today's settlement is ready for review.",
          timeSensitive: memberPrefs.timeSensitiveAllowed,
          data: {
            coupleId,
            dateKey: targetDateKey,
            settlementId,
            deepLink: `coupletodo://settlement/${targetDateKey}`,
          },
        });
      }

      if (finalized.paymentRecordId) {
        paymentCount += 1;
        const paymentSnapshot = await db.doc(`couples/${coupleId}/payments/${finalized.paymentRecordId}`).get();
        const creditorUserId = asString(paymentSnapshot.get("creditorUserId"));
        if (creditorUserId) {
          const creditorUserSnapshot = await db.doc(`users/${creditorUserId}`).get();
          const creditorPrefs = makeNotificationPrefs((creditorUserSnapshot.data() ?? {}) as Record<string, unknown>);
          await sendPushIfPossible({
            userId: creditorUserId,
            jobType: "dailySettlementJob",
            dedupeKey: `payment_${creditorUserId}_${finalized.paymentRecordId}`,
            category: "payment_pending",
            title: "Payment pending acknowledgement",
            body: "A payment was marked for your review.",
            timeSensitive: creditorPrefs.timeSensitiveAllowed,
            data: {
              coupleId,
              paymentRecordId: finalized.paymentRecordId,
              deepLink: `coupletodo://payments/${finalized.paymentRecordId}`,
            },
          });
        }
      }
    }

  }

  logger.info("dailySettlementJob completed", {
    finalizedSettlements: finalizedCount,
    paymentRecordsCreated: paymentCount,
  });
});

export const weeklyRewardFinalizeJob = onSchedule("every 24 hours", async () => {
  const now = new Date();
  const couplesSnapshot = await db.collection("couples").where("status", "==", "active").get();
  let finalizedRewards = 0;

  for (const coupleDoc of couplesSnapshot.docs) {
    const coupleId = coupleDoc.id;
    const coupleData = coupleDoc.data();
    const memberIds = asStringArray(coupleData.memberIds);
    if (memberIds.length < 2) continue;

    const memberCurrentWeekKeys: Record<string, string> = {};
    for (const memberId of memberIds) {
      const userSnapshot = await db.doc(`users/${memberId}`).get();
      const userData = userSnapshot.data() ?? {};
      const timezone = normalizeTimezone((userData as Record<string, unknown>).currentTimezone);
      memberCurrentWeekKeys[memberId] = isoWeekKeyForDateKey(dateKeyForTimezone(now, timezone));
    }

    const rewardSnapshot = await db.collection(`couples/${coupleId}/rewardWeeks`).where("status", "==", "active").get();
    for (const rewardDoc of rewardSnapshot.docs) {
      const rewardWeekKey = asString(rewardDoc.get("weekKey")) ?? rewardDoc.id;
      const allMembersClosedWeek = memberIds.every((memberId) => memberCurrentWeekKeys[memberId] !== rewardWeekKey);
      if (!allMembersClosedWeek) continue;

      const rewardRef = rewardDoc.ref;
      const updated = await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(rewardRef);
        if (!snapshot.exists) return { changed: false, status: "active" };
        if ((asString(snapshot.get("status")) ?? "draft") !== "active") return { changed: false, status: "active" };

        const eligibility = asBoolMap(snapshot.get("eligibility"));
        const earned = memberIds.every((memberId) => eligibility[memberId] !== false);
        const status = earned ? "earned" : "missed";

        transaction.set(
          rewardRef,
          {
            status,
            memberLocalWeekKeys: memberCurrentWeekKeys,
            earnedAt: earned ? FieldValue.serverTimestamp() : FieldValue.delete(),
            missedAt: earned ? FieldValue.delete() : FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

        const eventRef = db.collection(`couples/${coupleId}/events`).doc();
        transaction.set(eventRef, {
          id: eventRef.id,
          coupleId,
          type: earned ? "weekly_reward_earned" : "weekly_reward_missed",
          actorUserId: "system",
          subjectId: rewardDoc.id,
          payload: sanitizeEventPayload({ weekKey: rewardWeekKey }),
          createdAt: FieldValue.serverTimestamp(),
        });

        return { changed: true, status };
      });

      if (!updated.changed) continue;
      finalizedRewards += 1;

      if (updated.status === "earned") {
        for (const memberId of memberIds) {
          const userSnapshot = await db.doc(`users/${memberId}`).get();
          const prefs = makeNotificationPrefs((userSnapshot.data() ?? {}) as Record<string, unknown>);
          await sendPushIfPossible({
            userId: memberId,
            jobType: "weeklyRewardFinalizeJob",
            dedupeKey: `reward_${memberId}_${rewardWeekKey}`,
            category: "reward_earned",
            title: "Weekly reward earned",
            body: "Both of you completed the week. Reward unlocked.",
            timeSensitive: prefs.timeSensitiveAllowed,
            data: {
              coupleId,
              weekKey: rewardWeekKey,
              deepLink: `coupletodo://rewards/${rewardWeekKey}`,
            },
          });
        }
      }
    }
  }

  logger.info("weeklyRewardFinalizeJob completed", { finalizedRewards });
});

export const snapshotCompactionJob = onSchedule("every 24 hours", async () => {
  const now = new Date();
  const compactionCutoff = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
  const snapshotCutoff = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  const couplesSnapshot = await db.collection("couples").get();
  let deletedEvents = 0;

  for (const coupleDoc of couplesSnapshot.docs) {
    const coupleId = coupleDoc.id;
    const eventsSnapshot = await db
      .collection(`couples/${coupleId}/events`)
      .where("createdAt", "<", Timestamp.fromDate(compactionCutoff))
      .limit(500)
      .get();

    const eventCounts: Record<string, number> = {};
    if (!eventsSnapshot.empty) {
      const batch = db.batch();
      for (const eventDoc of eventsSnapshot.docs) {
        const eventType = asString(eventDoc.get("type")) ?? "unknown";
        eventCounts[eventType] = (eventCounts[eventType] ?? 0) + 1;
        batch.delete(eventDoc.ref);
      }
      await batch.commit();
      deletedEvents += eventsSnapshot.size;
    }

    await db.doc(`couples/${coupleId}/readModels/eventCompaction`).set(
      {
        id: "eventCompaction",
        deletedBefore: Timestamp.fromDate(compactionCutoff),
        deletedCount: eventsSnapshot.size,
        deletedByType: eventCounts,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const paymentsSnapshot = await db.collection(`couples/${coupleId}/payments`).get();
    const memberIds = asStringArray(coupleDoc.get("memberIds"));
    const pendingNetByUser: Record<string, number> = Object.fromEntries(memberIds.map((memberId) => [memberId, 0]));
    let pendingCount = 0;

    for (const paymentDoc of paymentsSnapshot.docs) {
      const status = asString(paymentDoc.get("status")) ?? "pending";
      if (status !== "pending") continue;
      const amount = asFiniteNumber(paymentDoc.get("amount")) ?? 0;
      const debtor = asString(paymentDoc.get("debtorUserId"));
      const creditor = asString(paymentDoc.get("creditorUserId"));
      if (!debtor || !creditor) continue;
      pendingNetByUser[debtor] = (pendingNetByUser[debtor] ?? 0) - amount;
      pendingNetByUser[creditor] = (pendingNetByUser[creditor] ?? 0) + amount;
      pendingCount += 1;
    }

    await db.doc(`couples/${coupleId}/readModels/paymentNetSummary`).set(
      {
        id: "paymentNetSummary",
        pendingNetByUser,
        pendingCount,
        generatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const sharedSnapshotRef = db.doc(`couples/${coupleId}/readModels/sharedSnapshot`);
    const sharedSnapshot = await sharedSnapshotRef.get();
    if (sharedSnapshot.exists) {
      const generatedAt = asDate(sharedSnapshot.get("generatedAt"));
      const expiresAt = asDate(sharedSnapshot.get("expiresAt"));
      if ((generatedAt && generatedAt < snapshotCutoff) || (expiresAt && expiresAt < now)) {
        await sharedSnapshotRef.delete();
      }
    }
  }

  logger.info("snapshotCompactionJob completed", {
    deletedEvents,
    couplesProcessed: couplesSnapshot.size,
  });
});
