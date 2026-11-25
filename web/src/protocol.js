import cjs from '../protocol.js';

export const DEVICE_STALE_MS = cjs.DEVICE_STALE_MS;
export const canonicalState = cjs.canonicalState;
export const stateBadgeLabel = cjs.stateBadgeLabel;
export const parseCloudTelemetry = cjs.parseCloudTelemetry;
export const parseCloudConfig = cjs.parseCloudConfig;
export const buildConfigPatch = cjs.buildConfigPatch;
export const formatEmptyCupSerialCmd = cjs.formatEmptyCupSerialCmd;
export const parseSerialLine = cjs.parseSerialLine;
export const computeEffectiveIntervalMs = cjs.computeEffectiveIntervalMs;
export const applySseEvent = cjs.applySseEvent;
export const isNewTelemetryFrame = cjs.isNewTelemetryFrame;
export const isDeviceStale = cjs.isDeviceStale;
export const computeLiveRemainingSec = cjs.computeLiveRemainingSec;
