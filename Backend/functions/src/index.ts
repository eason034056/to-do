import { onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { initializeApp } from "firebase-admin/app";
import { logger } from "firebase-functions";

initializeApp();

export const createCouple = onCall(async () => {
  logger.info("createCouple callable invoked");
  return { status: "not_implemented" };
});

export const joinCouple = onCall(async () => {
  logger.info("joinCouple callable invoked");
  return { status: "not_implemented" };
});

export const submitPlan = onCall(async () => {
  logger.info("submitPlan callable invoked");
  return { status: "not_implemented" };
});

export const acknowledgeSettlement = onCall(async () => {
  logger.info("acknowledgeSettlement callable invoked");
  return { status: "not_implemented" };
});

export const saveNextWeekReward = onCall(async () => {
  logger.info("saveNextWeekReward callable invoked");
  return { status: "not_implemented" };
});

export const planningReminderJob = onSchedule("every 5 minutes", async () => {
  logger.info("planningReminderJob triggered");
});

export const planningMissJob = onSchedule("every 5 minutes", async () => {
  logger.info("planningMissJob triggered");
});

export const dailySettlementJob = onSchedule("every 5 minutes", async () => {
  logger.info("dailySettlementJob triggered");
});

export const weeklyRewardFinalizeJob = onSchedule("every 24 hours", async () => {
  logger.info("weeklyRewardFinalizeJob triggered");
});

export const snapshotCompactionJob = onSchedule("every 24 hours", async () => {
  logger.info("snapshotCompactionJob triggered");
});
